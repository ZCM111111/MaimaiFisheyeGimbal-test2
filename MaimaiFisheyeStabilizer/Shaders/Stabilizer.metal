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

fragment float4 fragmentFunction(VertexOut in [[stage_in]],
                                  texture2d<float> cameraTexture [[texture(0)]],
                                  sampler textureSampler [[sampler(0)]],
                                  constant StabilizationUniforms &uniforms [[buffer(0)]]) {
    // Passthrough for now — stabilization logic added in Task 7
    return cameraTexture.sample(textureSampler, in.texCoord);
}
