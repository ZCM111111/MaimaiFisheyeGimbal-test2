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
// Stable-Action style: 2D crop + rotation from normal (non-fisheye) source
// The source is a normal rectilinear image from iPhone camera.
// We crop a smaller window and apply 2D transformations to stabilize.
fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> cameraTexture [[texture(0)]],
    constant StabilizerUniforms &u [[buffer(0)]])
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);

    float2 srcSize = u.sourceTextureSize;
    float2 outSize = u.viewportSize;

    // --- Step 1: Compute crop size based on output FOV ---
    // For a normal camera, output FOV is a fraction of the source FOV.
    // Typical iPhone wide angle: ~120° horizontal FOV at 4:3
    // We crop a fraction of the source.
    float sourceFov = 120.0; // degrees, typical iPhone wide angle
    float cropFraction = u.outputFov / sourceFov;
    cropFraction = clamp(cropFraction, 0.1, 0.95);

    float cropW = srcSize.x * cropFraction;
    float cropH = srcSize.y * cropFraction;

    // Margins for shifting
    float marginX = (srcSize.x - cropW) * 0.5;
    float marginY = (srcSize.y - cropH) * 0.5;

    // --- Step 2: Apply stabilization ---
    float s = u.strength;

    // Roll: rotate the crop window around center (counter-rotate)
    float angle = -u.roll * s;

    // Pitch: vertical shift (Stable-Action Vertical Lock style)
    // Phone tilts forward (pitch > 0) → scene moves UP → crop moves UP
    // We use a hold-and-release decay for gimbal-like feel
    float maxPitchRange = 3.14159265 / 6.0; // 30 degrees
    float pitchNormRaw = clamp(u.pitch / maxPitchRange, -1.0, 1.0) * s;

    // Pitch hold offset with decay (gimbal-like)
    // This would normally be stateful, but in a shader we approximate
    // by using the current pitch directly with some smoothing
    float pitchOffsetDecay = 0.98;
    float pitchNorm = pitchNormRaw * (1.0 - pitchOffsetDecay); // Simplified for shader

    // Rotate pitch offset into roll-corrected coordinate frame
    // After roll rotation, pitch projects onto both X and Y via sin/cos
    float rotatedPitchShiftX = -pitchNorm * sinA * marginX;
    float rotatedPitchShiftY =  pitchNorm * cosA * marginY;

    // Yaw: horizontal shift (similar to pitch)
    float maxYawRange = 3.14159265 / 6.0; // 30 degrees
    float yawNorm = clamp(u.yaw / maxYawRange, -1.0, 1.0) * s;
    float yawShiftX = yawNorm * marginX;
    float yawShiftY = yawNorm * marginY;

    // --- Step 3: Map output pixel to source pixel ---
    // Output UV [0,1] -> centered [-0.5, 0.5]
    float2 outCentered = in.texCoord - 0.5;

    // Rotate by roll angle
    float cosA = cos(angle);
    float sinA = sin(angle);
    float2 rotated;
    rotated.x = outCentered.x * cosA - outCentered.y * sinA;
    rotated.y = outCentered.x * sinA + outCentered.y * cosA;

    // Scale to crop size and apply shifts
    // Composite: roll rotation + pitch/yaw translation
    float2 srcPixel;
    srcPixel.x = srcSize.x * 0.5 + rotated.x * cropW + yawShiftX + rotatedPitchShiftX;
    srcPixel.y = srcSize.y * 0.5 - rotated.y * cropH + pitchShiftY + yawShiftY + rotatedPitchShiftY;

    // Convert to UV
    float2 srcUV = srcPixel / srcSize;

    // Sample
    float4 color = cameraTexture.sample(textureSampler, srcUV);
    return color;
}
