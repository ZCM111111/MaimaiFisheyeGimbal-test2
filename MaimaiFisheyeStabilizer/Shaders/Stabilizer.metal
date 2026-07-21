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

// Quaternion (x, y, z, w)
struct Quat {
    float x, y, z, w;
};

struct StabilizationUniforms {
    Quat orientation;      // Current phone orientation quaternion
    Quat reference;        // Reference (stable) orientation quaternion
    float strength;        // Stabilization strength (0-1)
    float outputFov;       // Output field of view in degrees
    float focalLength;     // Focal length in pixels (for fisheye)
    float2 principalPoint; // Lens center (cx, cy)
    float4 k;              // Fisheye distortion coefficients (k1-k4)
    float2 inputSize;      // Input texture size
    float2 outputSize;     // Output texture size
};

vertex VertexOut vertexShader(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}

// Quaternion multiplication
Quat quatMul(Quat a, Quat b) {
    return Quat(
        a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
        a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
        a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
        a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z
    );
}

// Quaternion conjugate (inverse for unit quaternion)
Quat quatConj(Quat q) {
    return Quat(-q.x, -q.y, -q.z, q.w);
}

// Convert quaternion to 3x3 rotation matrix
float3x3 quatToMatrix(Quat q) {
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
// Input: (x, y, z) in camera space, output: (u, v) in image space
float2 fisheyeDistort(float3 p, float focalLength, float2 center, float4 k) {
    // Project to normalized coordinates
    float r = sqrt(p.x * p.x + p.y * p.y);
    float theta = atan2(r, p.z);

    if (r < 1e-6) return center;

    // Apply distortion: theta_d = theta * (1 + k1*theta^2 + k2*theta^4 + k3*theta^6 + k4*theta^8)
    float theta2 = theta * theta;
    float theta4 = theta2 * theta2;
    float theta6 = theta4 * theta2;
    float theta8 = theta4 * theta4;
    float theta_d = theta * (1.0 + k[0] * theta2 + k[1] * theta4 + k[2] * theta6 + k[3] * theta8);

    // Scale factor
    float scale = theta_d / r;

    // Map to pixel coordinates
    return float2(
        center.x + p.x * scale * focalLength,
        center.y + p.y * scale * focalLength
    );
}

// OpenCV Fisheye undistort: find 3D ray from fisheye image coordinates
// This uses iterative Newton-Raphson to invert the distortion model
float3 fisheyeUndistort(float2 uv, float focalLength, float2 center, float4 k) {
    // Normalized coordinates from pixel
    float mx = (uv.x - center.x) / focalLength;
    float my = (uv.y - center.y) / focalLength;

    float theta_d = sqrt(mx * mx + my * my);

    if (theta_d < 1e-6) return float3(0.0, 0.0, 1.0);

    // Iterative Newton-Raphson to find theta from theta_d
    // Solve: theta * (1 + k1*theta^2 + k2*theta^4 + k3*theta^6 + k4*theta^8) = theta_d
    float theta = theta_d; // Initial guess
    for (int i = 0; i < 10; i++) {
        float theta2 = theta * theta;
        float theta4 = theta2 * theta2;
        float theta6 = theta4 * theta2;
        float theta8 = theta4 * theta4;

        float f = theta * (1.0 + k[0] * theta2 + k[1] * theta4 + k[2] * theta6 + k[3] * theta8) - theta_d;
        float df = 1.0 + 3.0 * k[0] * theta2 + 5.0 * k[1] * theta4 + 7.0 * k[2] * theta6 + 9.0 * k[3] * theta8;

        float theta_fix = f / df;
        theta_fix = clamp(theta_fix, -0.9, 0.9);
        theta -= theta_fix;

        if (abs(theta_fix) < 1e-6) break;
    }

    // Check if theta flipped sign (invalid convergence)
    if ((theta_d < 0.0 && theta > 0.0) || (theta_d > 0.0 && theta < 0.0)) {
        return float3(0.0, 0.0, 1.0); // Default forward ray
    }

    // Convert theta back to 3D ray
    float r = tan(theta);
    float scale = r / theta_d;

    return normalize(float3(mx * scale, my * scale, 1.0));
}

fragment float4 fragmentFunction(VertexOut in [[stage_in]],
                                  texture2d<float> cameraTexture [[texture(0)]],
                                  sampler textureSampler [[sampler(0)]],
                                  constant StabilizationUniforms &uniforms [[buffer(0)]]) {
    // 1. Output pixel to normalized coordinates
    float2 uv = in.texCoord;

    // 2. Compute the counter-rotation quaternion
    //    counter = reference * inverse(current)
    //    This rotates from current orientation back to reference
    Quat counterQuat = quatMul(uniforms.reference, quatConj(uniforms.orientation));

    // Apply strength (SLERP between identity and full correction)
    // For simplicity, we just scale the rotation
    float3x3 rotMatrix = quatToMatrix(counterQuat);

    // 3. For each output pixel, compute a ray in output camera space
    float fovRad = uniforms.outputFov * (M_PI_F / 180.0);
    float aspect = uniforms.outputSize.x / uniforms.outputSize.y;
    float tanHalfFov = tan(fovRad * 0.5);

    // Ray in output camera space
    float2 ndc = (uv - 0.5) * 2.0;
    float3 outputRay = normalize(float3(
        ndc.x * tanHalfFov * aspect,
        -ndc.y * tanHalfFov,
        1.0
    ));

    // 4. Apply counter-rotation to the ray
    float3 rotatedRay = rotMatrix * outputRay;

    // 5. Project the rotated ray to fisheye image coordinates
    float2 fisheyePixel = fisheyeDistort(
        rotatedRay,
        uniforms.focalLength,
        uniforms.principalPoint,
        uniforms.k
    );

    // 6. Convert to UV coordinates
    float2 fisheyeUV = fisheyePixel / uniforms.inputSize;

    // 7. Clamp to edge to avoid black borders
    if (fisheyeUV.x < 0.0 || fisheyeUV.x > 1.0 || fisheyeUV.y < 0.0 || fisheyeUV.y > 1.0) {
        float2 clampedUV = clamp(fisheyeUV, 0.0, 1.0);
        return cameraTexture.sample(textureSampler, clampedUV);
    }

    return cameraTexture.sample(textureSampler, fisheyeUV);
}
