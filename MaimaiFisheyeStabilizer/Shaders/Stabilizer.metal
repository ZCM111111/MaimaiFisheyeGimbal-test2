#include <metal_stdlib>
using namespace metal;

// MARK: - Uniforms
struct StabilizerUniforms {
    float roll;           // radians, phone roll (counter this to keep horizon level)
    float pitch;          // radians, phone pitch
    float yaw;            // radians, phone yaw
    float strength;       // 0..1, stabilization strength
    float outputFov;      // degrees, horizontal FOV of output
    float2 viewportSize;  // output pixel dimensions
    float2 sourceTextureSize; // input pixel dimensions (fisheye)
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
// Horizon Lock style: output stays level regardless of phone orientation
// For each output pixel, we generate a ray in the stabilized (world) frame,
// rotate it by the phone's orientation to find where it points in the fisheye image,
// then sample.
fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> cameraTexture [[texture(0)]],
    constant StabilizerUniforms &u [[buffer(0)]])
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);

    // --- Step 1: Generate rectilinear ray for this output pixel ---
    // Map texCoord [0,1] to [-1,1] (NDC)
    float2 ndc = in.texCoord * 2.0 - 1.0;
    ndc.y = -ndc.y; // Flip Y: Metal NDC has Y up, texCoord has Y down

    // Aspect ratio
    float aspect = u.viewportSize.x / u.viewportSize.y;

    // Output FOV
    float halfFovRad = radians(u.outputFov * 0.5);
    float tanHalfFov = tan(halfFovRad);

    // Ray direction in stabilized (world) camera space
    // Looking down -Z, X right, Y up
    float3 ray;
    ray.x = ndc.x * tanHalfFov * aspect;
    ray.y = ndc.y * tanHalfFov;
    ray.z = -1.0;
    ray = normalize(ray);

    // --- Step 2: Apply phone's orientation to rotate ray into fisheye image space ---
    // We want to counter-rotate: if phone rolled right, we need to look left in the fisheye
    // So we rotate the ray by the NEGATIVE of the phone's orientation
    float s = u.strength;
    float roll = -u.roll * s;
    float pitch = -u.pitch * s;
    float yaw = -u.yaw * s;

    // Rotation matrices (column-major for Metal)
    float3x3 Rx = float3x3(
        1.0,  0.0,       0.0,
        0.0,  cos(roll), -sin(roll),
        0.0,  sin(roll),  cos(roll)
    );

    float3x3 Ry = float3x3(
        cos(pitch),  0.0, sin(pitch),
        0.0,         1.0, 0.0,
        -sin(pitch), 0.0, cos(pitch)
    );

    float3x3 Rz = float3x3(
        cos(yaw), -sin(yaw), 0.0,
        sin(yaw),  cos(yaw), 0.0,
        0.0,       0.0,      1.0
    );

    // Combined rotation: R = Rz * Ry * Rx (apply roll first, then pitch, then yaw)
    float3x3 R = Rz * Ry * Rx;
    float3 rotatedRay = R * ray;

    // --- Step 3: Convert rotated ray to fisheye image coordinates ---
    // For an equidistant fisheye projection:
    //   theta = angle from optical axis (Z axis)
    //   r = f * theta (fisheye radius)
    //   phi = atan2(y, x) in XY plane
    //
    // We map the ray direction to fisheye polar coordinates,
    // then to image pixel coordinates.

    // Angle from optical axis
    float theta = acos(clamp(rotatedRay.z, -1.0, 1.0));
    float phi = atan2(rotatedRay.y, rotatedRay.x);

    // Fisheye image center
    float2 center = u.sourceTextureSize * 0.5;

    // Fisheye radius for 238° coverage (slightly beyond 180°)
    // The full fisheye circle fits within the image
    float fisheyeRadius = min(center.x, center.y) * 0.95;

    // Map theta to radius (equidistant projection)
    // theta ranges from 0 to pi (or slightly more for 238°)
    float maxTheta = radians(238.0 * 0.5); // Half of 238°
    float r = (theta / maxTheta) * fisheyeRadius;

    // Clamp to fisheye circle
    r = min(r, fisheyeRadius);

    // Convert polar to Cartesian image coordinates
    float2 fisheyePixel;
    fisheyePixel.x = center.x + r * cos(phi);
    fisheyePixel.y = center.y + r * sin(phi);

    // Convert to UV
    float2 fisheyeUV = fisheyePixel / u.sourceTextureSize;

    // --- Step 4: Sample the fisheye image ---
    float4 color = cameraTexture.sample(textureSampler, fisheyeUV);
    return color;
}
