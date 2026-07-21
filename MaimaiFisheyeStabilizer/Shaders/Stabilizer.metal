#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Quaternion stored as float4: x=0, y=1, z=2, w=3
// orientation.xyzw = (x, y, z, w)

struct StabilizationUniforms {
    float4 orientation;      // Current phone orientation quaternion (x,y,z,w)
    float4 reference;        // Reference (stable) orientation quaternion (x,y,z,w)
    float strength;          // Stabilization strength (0-1)
    float outputFov;         // Output field of view in degrees
    float focalLength;       // Focal length in pixels (for fisheye)
    float2 principalPoint;   // Lens center (cx, cy)
    float4 k;                // Fisheye distortion coefficients (k1-k4)
    float2 inputSize;        // Input texture size
    float2 outputSize;       // Output texture size
};

vertex VertexOut vertexShader(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}

// Quaternion multiplication: q = (x,y,z,w)
float4 quatMul(float4 a, float4 b) {
    return float4(
        a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
        a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
        a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
        a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z
    );
}

// Quaternion conjugate
float4 quatConj(float4 q) {
    return float4(-q.x, -q.y, -q.z, q.w);
}

// Convert quaternion to 3x3 rotation matrix
float3x3 quatToMatrix(float4 q) {
    float x2 = q.x + q.x;
    float y2 = q.y + q.y;
    float z2 = q.z + q.z;
    float xx = q.x * x2;
    float yy = q.y * y2;
    float zz = q.z * z2;
    float xy = q.x * y2;
    float xz = q.x * z2;
    float yz = q.y * z2;
    float wx = q.w * x2;
    float wy = q.w * y2;
    float wz = q.w * z2;

    return float3x3(
        float3(1.0 - (yy + zz), xy - wz, xz + wy),
        float3(xy + wz, 1.0 - (xx + zz), yz - wx),
        float3(xz - wy, yz + wx, 1.0 - (xx + yy))
    );
}

// OpenCV Fisheye distort: project 3D point to fisheye image coordinates
float2 fisheyeDistort(float3 p, float focalLength, float2 center, float4 k) {
    float r = sqrt(p.x * p.x + p.y * p.y);
    float theta = atan2(r, p.z);

    if (r < 1e-6) return center;

    float theta2 = theta * theta;
    float theta4 = theta2 * theta2;
    float theta6 = theta4 * theta2;
    float theta8 = theta4 * theta4;
    float theta_d = theta * (1.0 + k[0] * theta2 + k[1] * theta4 + k[2] * theta6 + k[3] * theta8);

    float scale = theta_d / r;

    return float2(
        center.x + p.x * scale * focalLength,
        center.y + p.y * scale * focalLength
    );
}

fragment float4 fragmentFunction(VertexOut in [[stage_in]],
                                  texture2d<float> cameraTexture [[texture(0)]],
                                  sampler textureSampler [[sampler(0)]],
                                  constant StabilizationUniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;

    // Counter-rotation: reference * inverse(current)
    float4 counterQuat = quatMul(uniforms.reference, quatConj(uniforms.orientation));
    float3x3 rotMatrix = quatToMatrix(counterQuat);

    // Output ray
    float fovRad = uniforms.outputFov * (M_PI_F / 180.0);
    float aspect = uniforms.outputSize.x / uniforms.outputSize.y;
    float tanHalfFov = tan(fovRad * 0.5);

    float2 ndc = (uv - 0.5) * 2.0;
    float3 outputRay = normalize(float3(
        ndc.x * tanHalfFov * aspect,
        -ndc.y * tanHalfFov,
        1.0
    ));

    // Apply counter-rotation
    float3 rotatedRay = rotMatrix * outputRay;

    // Project to fisheye
    float2 fisheyePixel = fisheyeDistort(
        rotatedRay,
        uniforms.focalLength,
        uniforms.principalPoint,
        uniforms.k
    );

    float2 fisheyeUV = fisheyePixel / uniforms.inputSize;

    // Clamp to edge
    if (fisheyeUV.x < 0.0 || fisheyeUV.x > 1.0 || fisheyeUV.y < 0.0 || fisheyeUV.y > 1.0) {
        float2 clampedUV = clamp(fisheyeUV, 0.0, 1.0);
        return cameraTexture.sample(textureSampler, clampedUV);
    }

    return cameraTexture.sample(textureSampler, fisheyeUV);
}
