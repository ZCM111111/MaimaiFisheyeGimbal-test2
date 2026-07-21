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

struct StabilizationUniforms {
    float roll;
    float pitch;
    float yaw;
    float strength;
    float outputFov;
    float focalLength;
    float2 principalPoint;
    float k1;
    float k2;
};

vertex VertexOut vertexShader(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}

// Rotation matrices for roll (Z), pitch (X), yaw (Y)
float3x3 rotationX(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float3x3(
        float3(1, 0, 0),
        float3(0, c, -s),
        float3(0, s, c)
    );
}

float3x3 rotationY(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float3x3(
        float3(c, 0, s),
        float3(0, 1, 0),
        float3(-s, 0, c)
    );
}

float3x3 rotationZ(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float3x3(
        float3(c, -s, 0),
        float3(s, c, 0),
        float3(0, 0, 1)
    );
}

fragment float4 fragmentFunction(VertexOut in [[stage_in]],
                                  texture2d<float> cameraTexture [[texture(0)]],
                                  sampler textureSampler [[sampler(0)]],
                                  constant StabilizationUniforms &uniforms [[buffer(0)]]) {
    float2 texSize = float2(cameraTexture.get_width(), cameraTexture.get_height());

    // 1. Convert UV to normalized device coordinates (-1 to 1)
    float2 ndc = (in.texCoord - 0.5) * 2.0;

    // 2. Generate ray for the OUTPUT rectilinear camera
    //    The ray points into the scene from the virtual camera center
    float fovRad = uniforms.outputFov * (M_PI_F / 180.0);
    float aspect = texSize.x / texSize.y;
    float tanHalfFov = tan(fovRad * 0.5);

    float3 ray = normalize(float3(
        ndc.x * tanHalfFov * aspect,
        -ndc.y * tanHalfFov,
        1.0
    ));

    // 3. Apply inverse rotation (counter-rotate by phone's current orientation)
    //    This "un-does" the phone's motion, keeping the output stable
    float s = uniforms.strength;
    float3x3 rot = rotationX(uniforms.pitch * s) *
                   rotationY(uniforms.yaw * s) *
                   rotationZ(uniforms.roll * s);
    ray = rot * ray;

    // 4. Map the ray to the FISHEYE image using equidistant projection
    //    r = f * theta, where theta = angle from optical axis (Z)
    float theta = acos(clamp(ray.z, -1.0, 1.0));
    float phi = atan2(ray.y, ray.x);

    // Equidistant fisheye: r = f * theta
    float r = uniforms.focalLength * theta;

    // Apply barrel distortion (k1, k2) for fine-tuning
    float r2 = r * r;
    float distortion = 1.0 + uniforms.k1 * r2 + uniforms.k2 * r2 * r2;
    r *= distortion;

    // Convert polar to Cartesian in pixel space
    float2 fisheyePixel = float2(
        uniforms.principalPoint.x + r * cos(phi),
        uniforms.principalPoint.y + r * sin(phi)
    );

    // 5. Normalize to UV coordinates
    float2 fisheyeUV = fisheyePixel / texSize;

    // 6. Clamp to edge to avoid black borders
    //    If the ray points outside the fisheye circle, sample the edge
    if (fisheyeUV.x < 0.0 || fisheyeUV.x > 1.0 || fisheyeUV.y < 0.0 || fisheyeUV.y > 1.0) {
        float2 clampedUV = clamp(fisheyeUV, 0.0, 1.0);
        return cameraTexture.sample(textureSampler, clampedUV);
    }

    return cameraTexture.sample(textureSampler, fisheyeUV);
}
