#include <metal_stdlib>
using namespace metal;

// MARK: - Uniforms
struct StabilizerUniforms {
    float roll;           // radians, counter-rotate by this angle
    float pitch;          // radians, vertical shift factor
    float yaw;            // radians, horizontal shift factor
    float strength;       // 0..1, how much stabilization to apply
    float outputFov;      // degrees, horizontal FOV of output crop
    float2 viewportSize;  // output pixel dimensions
    float2 sourceTextureSize; // input pixel dimensions
};

// MARK: - Vertex I/O
struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// MARK: - Vertex Shader
vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    float4 positions[4] = {
        float4(-1.0, -1.0, 0.0, 1.0),
        float4( 1.0, -1.0, 0.0, 1.0),
        float4(-1.0,  1.0, 0.0, 1.0),
        float4( 1.0,  1.0, 0.0, 1.0)
    };
    float2 texCoords[4] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0)
    };
    VertexOut out;
    out.position = positions[vertexID];
    out.texCoord = texCoords[vertexID];
    return out;
}

// MARK: - Fragment Shader
// Stable-Action style 2D crop + rotation from fisheye source
fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> cameraTexture [[texture(0)]],
    constant StabilizerUniforms &u [[buffer(0)]])
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);

    // Output pixel position in UV [0,1]
    float2 outUV = in.texCoord;
    float2 outSize = u.viewportSize;
    float2 srcSize = u.sourceTextureSize;

    // --- Step 1: Compute output crop rectangle in source pixels ---
    // Aspect ratio of output
    float outAspect = outSize.x / outSize.y;
    // Aspect ratio of source
    float srcAspect = srcSize.x / srcSize.y;

    // Output FOV in radians
    float halfFovRad = radians(u.outputFov * 0.5);
    float tanHalfFov = tan(halfFovRad);

    // Crop size in source pixels: the output covers a certain angular width
    // For a fisheye lens, angular coverage is roughly proportional to pixel distance from center
    // We'll use a simple approximation: crop width = focal_length * angular_width
    // where focal_length is estimated from source dimensions
    float focalLength = srcSize.x / (2.0 * tan(halfFovRad * 2.0)); // rough estimate for wide angle

    // Actually, simpler: just define crop as a fraction of source
    // For 238° fisheye, a 100° output FOV is about 42% of the angular range
    float cropFraction = u.outputFov / 238.0;

    float cropW = srcSize.x * cropFraction;
    float cropH = cropW / outAspect;

    // Clamp to available source
    cropW = min(cropW, srcSize.x * 0.95);
    cropH = min(cropH, srcSize.y * 0.95);

    // Margins: how much we can shift before hitting edges
    float marginX = (srcSize.x - cropW) * 0.5;
    float marginY = (srcSize.y - cropH) * 0.5;

    // --- Step 2: Apply stabilization offsets (Stable-Action style) ---
    float s = u.strength;

    // Roll: rotate the crop window around center
    float angle = -u.roll * s;  // counter-rotate

    // Pitch: vertical shift (phone tilts forward → scene moves up → crop moves up)
    // Stable-Action uses normalized offset [-1,1] multiplied by margin
    // We convert pitch angle to normalized offset
    float maxPitchRange = 3.14159265 / 6.0; // 30°
    float pitchNorm = clamp(u.pitch / maxPitchRange, -1.0, 1.0) * s;
    float pitchShiftY = pitchNorm * marginY;

    // Yaw: horizontal shift (similar to pitch)
    float maxYawRange = 3.14159265 / 6.0; // 30°
    float yawNorm = clamp(u.yaw / maxYawRange, -1.0, 1.0) * s;
    float yawShiftX = yawNorm * marginX;

    // --- Step 3: Map output pixel to source pixel ---
    // Output UV [-0.5, 0.5] relative to center
    float2 outCentered = outUV - 0.5;

    // Rotate by roll angle
    float cosA = cos(angle);
    float sinA = sin(angle);
    float2 rotated;
    rotated.x = outCentered.x * cosA - outCentered.y * sinA;
    rotated.y = outCentered.x * sinA + outCentered.y * cosA;

    // Scale to crop size and apply shifts
    float2 srcPixel;
    srcPixel.x = srcSize.x * 0.5 + rotated.x * cropW + yawShiftX;
    srcPixel.y = srcSize.y * 0.5 - rotated.y * cropH + pitchShiftY; // flip Y

    // Convert to UV
    float2 srcUV = srcPixel / srcSize;

    // Sample
    float4 color = cameraTexture.sample(textureSampler, srcUV);
    return color;
}
