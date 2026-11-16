#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float tmaxGlowRadius(float2 p, float2 center, float2 axes) {
    float2 d = (p - center) / max(axes, float2(0.001));
    return length(d);
}

static void tmaxGlowOver(thread float3 &rgb, float3 color, float alpha) {
    rgb = mix(rgb, color, clamp(alpha, 0.0, 1.0));
}

static float tmaxRamp(float t, float l0, float l1, float v0, float v1) {
    return mix(v0, v1, clamp((t - l0) / max(l1 - l0, 0.0001), 0.0, 1.0));
}

[[ stitchable ]] half4 tmaxGlow(
    float2 position,
    half4 currentColor,
    float4 bounds,
    float3 waves,
    float reach,
    float strength,
    half4 background,
    half4 umber,
    half4 rust,
    half4 ember,
    half4 flame,
    half4 blaze,
    half4 peach
) {
    float w = max(bounds.z, 1.0);
    float h = max(bounds.w, 1.0);
    float2 p = position - bounds.xy;
    float drift = waves.x;
    float breathe = waves.y;
    float wander = waves.z;

    float3 rgb = float3(background.rgb);
    float3 cUmber = float3(umber.rgb);
    float3 cRust = float3(rust.rgb);
    float3 cEmber = float3(ember.rgb);
    float3 cFlame = float3(flame.rgb);
    float3 cBlaze = float3(blaze.rgb);
    float3 cPeach = float3(peach.rgb);

    {
        float t = tmaxGlowRadius(p, float2(w * 0.5, h), float2(w * 1.2, h * 0.7 * reach));
        tmaxGlowOver(rgb, cUmber, tmaxRamp(t, 0.0, 1.0, 0.9 * strength, 0.0));
    }
    {
        float2 center = float2(w * (0.5 + 0.06 * drift), h * 1.03);
        float2 axes = float2(w * 0.95, h * 0.41 * reach * (0.94 + 0.06 * breathe));
        float t = tmaxGlowRadius(p, center, axes);
        float3 color;
        float alpha;
        if (t < 0.28) {
            float f = t / 0.28;
            color = mix(cFlame, cEmber, f);
            alpha = mix(0.85, 0.62, f) * strength;
        } else if (t < 0.55) {
            float f = (t - 0.28) / 0.27;
            color = mix(cEmber, cRust, f);
            alpha = mix(0.62, 0.38, f) * strength;
        } else {
            float f = clamp((t - 0.55) / 0.45, 0.0, 1.0);
            color = mix(cRust, cUmber, f);
            alpha = mix(0.38, 0.0, f) * strength;
        }
        tmaxGlowOver(rgb, color, alpha);
    }
    {
        float2 center = float2(w * (0.5 - 0.07 * drift), h * 1.01);
        float2 axes = float2(w * 0.625, h * 0.13 * reach * (0.88 + 0.12 * breathe));
        float t = tmaxGlowRadius(p, center, axes);
        float3 color;
        float alpha;
        if (t < 0.4) {
            float f = t / 0.4;
            color = mix(cPeach, cBlaze, f);
            alpha = mix(0.9, 0.55, f) * strength;
        } else {
            float f = clamp((t - 0.4) / 0.6, 0.0, 1.0);
            color = mix(cBlaze, cFlame, f);
            alpha = mix(0.55, 0.0, f) * strength;
        }
        tmaxGlowOver(rgb, color, alpha);
    }
    {
        float2 center = float2(w * (0.5 + 0.34 * wander), h * (0.9 + 0.03 * breathe));
        float2 axes = float2(w * 0.55, h * 0.25 * reach);
        float t = tmaxGlowRadius(p, center, axes);
        float alpha;
        if (t < 0.5) {
            alpha = mix(0.3, 0.12, t / 0.5) * strength;
        } else {
            alpha = mix(0.12, 0.0, clamp((t - 0.5) / 0.5, 0.0, 1.0)) * strength;
        }
        float3 color = t < 0.5 ? mix(cBlaze, cEmber, t / 0.5) : cEmber;
        tmaxGlowOver(rgb, color, alpha);
    }

    return half4(half3(rgb), half(1.0));
}
