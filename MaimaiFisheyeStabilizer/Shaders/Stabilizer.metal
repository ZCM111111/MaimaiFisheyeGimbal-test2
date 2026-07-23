#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

// ── Vertex pipeline ──────────────────────────────────────────────

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut vertexMain(uint vid [[vertex_id]]) {
    const float2 positions[6] = {
        {-1, -1}, { 1, -1}, {-1,  1},
        { 1, -1}, { 1,  1}, {-1,  1}
    };
    const float2 uvs[6] = {
        {0, 1}, {1, 1}, {0, 0},
        {1, 1}, {1, 0}, {0, 0}
    };
    VertexOut out;
    out.position = float4(positions[vid], 0, 1);
    out.uv = uvs[vid];
    return out;
}

// ── Constants (passed once per frame) ────────────────────────────

struct Lens {
    float  focalLength;   // px — f·θ model
    float2 center;        // normalized [0-1]
    float  k1, k2;        // radial distortion
    float  outputScale;
};

struct Stabilizer {
    float  roll, pitch, yaw;  // radians — inverse rotation to apply
    float  hFov;              // output horizontal FOV (radians)
    float  aspect;            // output width / height
    float  strength;          // 0..1 blend
    float2 inputSize;         // source texture pixels
    float  maxRadius;         // clamp bound (normalized)
};

// ── 3×3 rotation matrix helpers ─────────────────────────────────

float3x3 rotationX(float a) {
    float c = cos(a), s = sin(a);
    return float3x3(float3(1, 0, 0),
                    float3(0, c,-s),
                    float3(0, s, c));
}

float3x3 rotationY(float a) {
    float c = cos(a), s = sin(a);
    return float3x3(float3( c, 0, s),
                    float3( 0, 1, 0),
                    float3(-s, 0, c));
}

float3x3 rotationZ(float a) {
    float c = cos(a), s = sin(a);
    return float3x3(float3(c,-s, 0),
                    float3(s, c, 0),
                    float3(0, 0, 1));
}

// Apply inverse rotation: undo yaw, then pitch, then roll.
float3 unrotate(float3 ray, constant Stabilizer &stab) {
    float s = stab.strength;
    // Blend toward identity: R_blended = I + s*(R_inv - I)
    float3 r0 = ray;
    float3 r1 = rotationY(-stab.yaw * s) * ray;
    r1 = rotationX(-stab.pitch * s) * r1;
    r1 = rotationZ(-stab.roll * s) * r1;
    return normalize(mix(r0, r1, s));
}

// ── Rectilinear ray from output UV ───────────────────────────────

float3 outputRay(float2 uv, constant Stabilizer &stab) {
    float2 ndc = (uv - 0.5) * 2.0;               // [-1, 1]
    float hh = stab.hFov * 0.5;
    float vh = atan(tan(hh) / stab.aspect);

    float x = ndc.x * tan(hh);
    float y = ndc.y * tan(vh);
    // Camera looks along +Z; image Y is down → negate.
    return normalize(float3(x, -y, 1.0));
}

// ── Fisheye lookup (equidistant) ─────────────────────────────────

float2 fisheyeLookup(float3 dir, constant Lens &lens, constant Stabilizer &stab) {
    // dir.z = cos(theta)
    float theta = acos(clamp(dir.z, -1.0, 1.0));
    if (theta < 1e-6) return lens.center;

    // Equidistant radius
    float r = lens.focalLength * theta;

    // Radial distortion
    float rn = r / max(stab.inputSize.x, stab.inputSize.y);
    float distortion = 1.0 + lens.k1 * rn * rn + lens.k2 * rn * rn * rn * rn;
    float rd = r * distortion;

    // Direction in image plane
    float phi = atan2(dir.y, dir.x);

    float2 px;
    px.x = lens.center.x * stab.inputSize.x + rd * cos(phi);
    px.y = lens.center.y * stab.inputSize.y + rd * sin(phi);

    return px / stab.inputSize;   // normalize
}

// ── Fragment entry ───────────────────────────────────────────────

fragment float4 fragmentMain(VertexOut in           [[stage_in]],
                             texture2d<float> src   [[texture(0)]],
                             constant Lens       &lens [[buffer(0)]],
                             constant Stabilizer &stab [[buffer(1)]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float3 ray = outputRay(in.uv, stab);
    ray = unrotate(ray, stab);
    float2 srcUV = fisheyeLookup(ray, lens, stab);

    // Clamp to avoid black borders — extend edge color
    srcUV = clamp(srcUV, float2(0.0), float2(1.0));

    return src.sample(s, srcUV);
}
