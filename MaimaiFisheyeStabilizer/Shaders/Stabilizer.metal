#include <metal_stdlib>
using namespace metal;

// MARK: - Uniforms
struct StabilizerUniforms {
    float roll;
    float pitch;
    float yaw;
    float strength;
    float outputFov;
    float focalLength;
    float2 principalPoint;
    float k1;
    float k2;
    float2 viewportSize;
    float2 sourceTextureSize;
};

// MARK: - Vertex I/O
struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// MARK: - Vertex Shader
// Full-screen quad: 6 vertices (2 triangles)
vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    // Triangle strip for a full-screen quad:
    // 0: (-1, -1)  1: ( 1, -1)
    // 2: (-1,  1)  3: ( 1,  1)
    // Using triangle strip: 0,1,2,3
    float4 positions[4] = {
        float4(-1.0, -1.0, 0.0, 1.0),  // bottom-left
        float4( 1.0, -1.0, 0.0, 1.0),  // bottom-right
        float4(-1.0,  1.0, 0.0, 1.0),  // top-left
        float4( 1.0,  1.0, 0.0, 1.0)   // top-right
    };

    float2 texCoords[4] = {
        float2(0.0, 1.0),  // bottom-left
        float2(1.0, 1.0),  // bottom-right
        float2(0.0, 0.0),  // top-left
        float2(1.0, 0.0)   // top-right
    };

    VertexOut out;
    out.position = positions[vertexID];
    out.texCoord = texCoords[vertexID];
    return out;
}

// MARK: - Fragment Shader
fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> cameraTexture [[texture(0)]],
    constant StabilizerUniforms &uniforms [[buffer(0)]])
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);

    // Step 1: Convert output pixel to NDC (-1 to 1)
    float2 ndc = in.texCoord * 2.0 - 1.0;  // Map from [0,1] to [-1,1]
    // Note: in.texCoord is (0,0) top-left in Metal texture coords
    // But NDC y is -1 at bottom, +1 at top, so we flip y
    ndc.y = -ndc.y;

    // Step 2: Generate rectilinear ray based on outputFov and aspect ratio
    float aspectRatio = uniforms.viewportSize.x / uniforms.viewportSize.y;

    // Half FOV in radians
    float halfFovRad = radians(uniforms.outputFov * 0.5);
    float tanHalfFov = tan(halfFovRad);

    // Generate ray in camera space (looking down -Z in Metal)
    float3 ray;
    ray.x = ndc.x * tanHalfFov * aspectRatio;
    ray.y = ndc.y * tanHalfFov;
    ray.z = -1.0;

    // Normalize the ray
    ray = normalize(ray);

    // Step 3: Apply inverse 3D rotation (counter-rotate by phone orientation * strength)
    float roll = uniforms.roll * uniforms.strength;
    float pitch = uniforms.pitch * uniforms.strength;
    float yaw = uniforms.yaw * uniforms.strength;

    // Rotation matrices (column-major convention for Metal)
    // Rx(roll)
    float3x3 Rx = float3x3(
        1.0,  0.0,       0.0,
        0.0,  cos(roll), -sin(roll),
        0.0,  sin(roll),  cos(roll)
    );

    // Ry(pitch)
    float3x3 Ry = float3x3(
        cos(pitch),  0.0, sin(pitch),
        0.0,         1.0, 0.0,
        -sin(pitch), 0.0, cos(pitch)
    );

    // Rz(yaw)
    float3x3 Rz = float3x3(
        cos(yaw), -sin(yaw), 0.0,
        sin(yaw),  cos(yaw), 0.0,
        0.0,       0.0,      1.0
    );

    // Inverse rotation = Rz(-yaw) * Ry(-pitch) * Rx(-roll)
    // Since R(-theta) = transpose(R(theta)) for orthogonal matrices,
    // we negate the angles to get the inverse rotation
    float3x3 R = transpose(Rz) * transpose(Ry) * transpose(Rx);
    float3 rotatedRay = R * ray;

    // Step 4: Project rotated ray to fisheye image plane using equidistant projection: r = f * theta
    // theta = angle from optical axis (z-axis)
    float theta = acos(clamp(rotatedRay.z / length(rotatedRay), -1.0, 1.0));
    float phi = atan2(rotatedRay.y, rotatedRay.x);

    // Equidistant projection: r = f * theta
    float r = uniforms.focalLength * theta;

    // Step 5: Apply radial distortion correction (k1, k2)
    // r_corrected = r * (1 + k1 * r^2 + k2 * r^4)
    float r2 = r * r;
    float r4 = r2 * r2;
    float r_corrected = r * (1.0 + uniforms.k1 * r2 + uniforms.k2 * r4);

    // Step 6: Map to fisheye UV coordinates
    float2 fisheyePixel;
    fisheyePixel.x = uniforms.principalPoint.x + r_corrected * cos(phi);
    fisheyePixel.y = uniforms.principalPoint.y + r_corrected * sin(phi);

    // Convert pixel coordinates to UV
    float2 fisheyeUV = fisheyePixel / uniforms.sourceTextureSize;

    // Step 7: Clamp to edge to avoid black borders (handled by sampler)
    // Step 8: Sample source texture
    float4 color = cameraTexture.sample(textureSampler, fisheyeUV);
    return color;
}
