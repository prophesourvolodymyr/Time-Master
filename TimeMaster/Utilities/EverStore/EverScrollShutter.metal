#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

float2 everArcLensPosition(float2 position, float4 arc, float3 stretch) {
    if (arc.z <= 0 || position.y < arc.y - stretch.x || position.y > arc.y + arc.w) return position;
    float x = clamp((position.x - arc.x) / arc.z, 0.0, 1.0);
    float t = x;
    for (uint iteration = 0; iteration < 3; ++iteration) {
        float projected = t * (0.75 + t * (0.75 - 0.5 * t));
        t -= (projected - x) / (0.75 + 1.5 * t * (1 - t));
    }
    float edge = arc.w * 0.72 + 8;
    float control = arc.w * 0.12 + 8;
    float curve = arc.y + edge + 3 * (control - edge) * t * (1 - t);
    float distance = curve - position.y;
    if (distance < 0 || distance >= stretch.x) return position;
    float falloff = 1 - smoothstep(0.0, stretch.x, distance);
    return position + float2((x - 0.5) * 2 * stretch.z, -stretch.y) * falloff * falloff;
}

[[ stitchable ]] half4 everScrollShutter(
    float2 position, SwiftUI::Layer layer, float trail, float4 arc, float3 stretch
) {
    position = everArcLensPosition(position, arc, stretch);
    if (abs(trail) < 0.01) return layer.sample(position);
    half4 color = half4(0);
    for (uint sample = 0; sample < 9; ++sample) {
        float exposure = float(sample) / 8.0;
        half weight = half(9 - sample) / half(45);
        color += layer.sample(position - float2(0, trail * exposure)) * weight;
    }
    return color;
}
