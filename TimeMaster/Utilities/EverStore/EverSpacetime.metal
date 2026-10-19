/*
Schwarzschild integration adapted from Selkomark/Blackhole-Sim.
Copyright (c) 2025 Mahan Hazrati Sagharchi (Selkomark)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
#include <metal_stdlib>
using namespace metal;

constant float2 everFlightStretch = float2(1.32, 0.86);

struct EverWarpUniforms {
    float4 viewport;
    float4 rect;
    float4 motion;
    float4 style;
    float4 effect;
    float4 sampling;
};

struct EverWarpVertex {
    float4 position [[position]];
    float2 uv;
};

float2 everQuadUV(uint index) {
    constexpr float2 corners[] = {float2(0, 0), float2(1, 0), float2(0, 1),
                                 float2(1, 0), float2(1, 1), float2(0, 1)};
    return corners[index % 6];
}


float2 everWarpPosition(float2 uv, constant EverWarpUniforms &u) {
    if (u.effect.x > 0.0) {
        float2 center = u.viewport.xy * 0.5;
        float2 delta = u.rect.xy + uv * u.rect.zw - center;
        float radius = length(delta);
        float relative = radius / max(u.effect.w, 1.0);
        float remaining = pow(max(0.0, pow(relative, 1.5) - u.effect.x), 2.0 / 3.0) * u.effect.w;
        return center + delta * (remaining / max(radius, 0.0001));
    }
    if (u.effect.z > 0.5) {
        float x = uv.x * 2.0;
        float tension = sin(saturate(u.motion.x) * M_PI_F);
        float waist = exp(-pow((x - 1.0) / 0.34, 2.0));
        float bowed = sin(uv.y * M_PI_F);
        float along = x - u.motion.x + tension * (0.20 * tanh((x - 1.0) / 0.22) + 0.16 * bowed - 0.08);
        float across = 0.5 + (uv.y - 0.5) * (1.0 - tension * waist * 0.58);
        return u.rect.xy + float2(along, across) * u.rect.zw;
    }
    bool vertical = u.style.z > 0.5;
    float2 size = vertical ? u.rect.wz : u.rect.zw;
    float2 axes = vertical ? uv.yx : uv;
    float2 local = (axes - 0.5) * size;
    float stretch = clamp(u.motion.y, 0.0, 0.95);
    float direction = u.style.y < 0.0 ? -1.0 : 1.0;
    float tail = direction > 0.0 ? axes.x : 1.0 - axes.x;
    float bowedEdge = sin(axes.y * M_PI_F);
    local.x += size.x * (u.motion.x + direction * stretch * (0.66 * tail * tail + 0.12 * bowedEdge * tail));
    local.y *= 1.0 - stretch * (0.18 + 0.46 * tail * tail);
    return u.rect.xy + u.rect.zw * 0.5 + (vertical ? local.yx : local);
}

vertex EverWarpVertex everSpacetimeVertex(uint index [[vertex_id]], constant EverWarpUniforms &u [[buffer(0)]]) {
    uint columns = u.effect.z > 0.5 ? 64 : 32;
    uint cell = index / 6;
    float2 uv = u.style.w > 0.5 ? everQuadUV(index)
        : (float2(cell % columns, cell / columns) + everQuadUV(index)) / float2(columns, 48);
    float2 point = everWarpPosition(uv, u);
    EverWarpVertex out;
    out.position = float4(point.x / u.viewport.x * 2.0 - 1.0, 1.0 - point.y / u.viewport.y * 2.0, 0, 1);
    out.uv = uv;
    return out;
}

half4 everSurfaceSample(float2 uv, constant EverWarpUniforms &u, texture2d<half> image, texture2d<half> next) {
    constexpr sampler sampling(coord::normalized, address::clamp_to_zero, filter::linear);
    if (u.effect.z > 0.5) {
        float x = uv.x * 2.0;
        float blend = smoothstep(0.975, 1.025, x);
        half4 left = image.sample(sampling, float2(min(x, 0.999), uv.y));
        half4 right = next.sample(sampling, float2(max(x - 1.0, 0.001), uv.y));
        return mix(left, right, half(blend));
    }
    if (any(uv < 0.0) || any(uv > 1.0)) return half4(0);
    return image.sample(sampling, u.sampling.xy + uv * u.sampling.zw);
}

fragment half4 everSpacetimeFragment(EverWarpVertex in [[stage_in]],
                                    constant EverWarpUniforms &u [[buffer(0)]],
                                    texture2d<half> image [[texture(0)]],
                                    texture2d<half> next [[texture(1)]]) {
    float2 shutter = u.style.z > 0.5 ? float2(0, u.effect.y) : float2(u.effect.y, 0);
    half4 color = half4(0);
    if (abs(u.effect.y) > 0.0001) {
        for (uint sample = 0; sample < 9; ++sample) {
            float offset = float(sample) / 8.0 - 0.5;
            color += everSurfaceSample(in.uv + shutter * offset, u, image, next) / 9.0h;
        }
    } else {
        color = everSurfaceSample(in.uv, u, image, next);
    }
    float radius = u.style.x;
    float2 point = abs((in.uv - 0.5) * u.rect.zw) - u.rect.zw * 0.5 + radius;
    float edge = length(max(point, 0.0)) + min(max(point.x, point.y), 0.0) - radius;
    float coverage = radius > 0 ? 1.0 - smoothstep(-0.75, 0.75, edge) : 1.0;
    float grain = fract(sin(dot(floor(in.uv * u.rect.zw * 0.65), float2(12.9898, 78.233))) * 43758.5453);
    float dissolve = 1.0 - smoothstep(grain - 0.12, grain + 0.12, u.motion.w * 1.25 - 0.13);
    return color * half(u.motion.z * coverage * dissolve);
}

float everStarHash(float value) {
    return fract(sin(value * 127.1 + 311.7) * 43758.5453);
}

float everNoise(float2 p) {
    float2 cell = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float n = dot(cell, float2(127.1, 311.7));
    return mix(mix(everStarHash(n), everStarHash(n + 127.1), f.x),
               mix(everStarHash(n + 311.7), everStarHash(n + 438.8), f.x), f.y);
}

struct EverFlightCamera {
    float3 position;
    float3 forward;
    float3 right;
    float3 up;
};

EverFlightCamera everFlightCamera(float progress) {
    progress = saturate(progress);
    if (progress < 0.12) {
        float t = progress / 0.12;
        progress = 0.12 * t * t * t * (6.0 - 8.0 * t + 3.0 * t * t);
    }
    float remaining = 1.0 - progress;
    float fall = progress + progress * remaining * remaining * remaining * remaining;
    float distance = 0.82 + 159.18 * (1.0 - fall) * (1.0 - fall);
    EverFlightCamera camera;
    camera.position = float3(0.18 - progress * 0.11, 0.14, -1.0) * distance;
    camera.forward = normalize(-camera.position);
    camera.right = normalize(cross(float3(0, 1, 0), camera.forward));
    camera.up = cross(camera.forward, camera.right);
    return camera;
}

float3 everGeodesicAcceleration(float3 position, float3 velocity) {
    float r2 = max(dot(position, position), 0.16);
    float3 h = cross(position, velocity);
    return position * (-1.5 * dot(h, h) / (r2 * r2 * sqrt(r2)));
}

void everGeodesicStep(thread float3 &position, thread float3 &velocity, float dt) {
    float3 a = everGeodesicAcceleration(position, velocity);
    float3 vb = velocity + a * (dt * 0.5);
    float3 b = everGeodesicAcceleration(position + velocity * (dt * 0.5), vb);
    float3 vc = velocity + b * (dt * 0.5);
    float3 c = everGeodesicAcceleration(position + vb * (dt * 0.5), vc);
    float3 vd = velocity + c * dt;
    float3 d = everGeodesicAcceleration(position + vc * dt, vd);
    position += (velocity + 2.0 * vb + 2.0 * vc + vd) * (dt / 6.0);
    velocity = normalize(velocity + (a + 2.0 * b + 2.0 * c + d) * (dt / 6.0));
}

float everDiskDensity(float3 position, float time) {
    float radius = length(position.xz);
    if (radius < 3.0 || radius > 5.6) return 0.0;
    float height = position.y / (0.035 * radius);
    if (abs(height) > 3.0) return 0.0;
    float angle = atan2(position.z, position.x) - time * 2.8 / pow(radius, 1.5);
    float2 flow = float2(angle * 7.0, radius * 5.0);
    float turbulence = 0.55 * everNoise(flow) + 0.30 * everNoise(flow * 2.07) + 0.15 * everNoise(flow * 4.11);
    float filament = pow(0.5 + 0.5 * sin(radius * 31.0 + angle * 4.0 + turbulence * 3.0), 3.0);
    float boundary = smoothstep(3.0, 3.25, radius) * (1.0 - smoothstep(4.6, 5.6, radius));
    return boundary * exp(-height * height * 0.5) * (0.28 + turbulence * 0.58 + filament * 0.14);
}

float3 everDiskEmission(float3 position, float3 direction) {
    float radius = max(3.0, length(position.xz));
    float speed = sqrt(0.5 / radius);
    float3 orbitalVelocity = normalize(float3(position.z, 0, -position.x)) * speed;
    float doppler = sqrt(1.0 - speed * speed) / (1.0 + dot(orbitalVelocity, direction));
    float redshift = sqrt(1.0 - 1.0 / radius);
    float temperature = pow(3.0 / radius, 0.75);
    float3 tint = mix(float3(0.72, 0.78, 0.9), float3(1.0, 0.98, 0.94), temperature);
    return tint * temperature * 2.5 * pow(doppler * redshift, 3.0);
}

struct EverRayResult {
    float3 light;
    float3 direction;
    float transmission;
};

EverRayResult everTraceBlackHole(float3 origin, float3 direction, float time) {
    EverRayResult result = {float3(0), direction, 1.0};
    float initialRadius = length(origin);
    float closest = max(0.0, -dot(origin, direction));
    float3 impactVector = origin + direction * closest;
    float impact = length(impactVector);
    if (impact > 10.0) {
        float inverse = 1.0 / impact;
        float correction = inverse * (2.0 + inverse * (15.0 * M_PI_F / 16.0
            + inverse * (16.0 / 3.0 + inverse * 3465.0 * M_PI_F / 1024.0)));
        correction *= 0.5 * (1.0 + closest / initialRadius);
        result.direction = normalize(direction * cos(correction) - normalize(impactVector) * sin(correction));
        return result;
    }
    float3 position = origin;
    float3 velocity = direction;
    for (uint step = 0; step < 192; ++step) {
        float radius = length(position);
        if (radius < 1.01) {
            result.transmission = 0.0;
            break;
        }
        if (radius > max(initialRadius + 2.0, 28.0) && dot(position, velocity) > 0.0) break;
        float dt = clamp((radius - 1.0) * 0.13, 0.012, 12.0);
        float3 previous = position;
        everGeodesicStep(position, velocity, dt);
        float3 samplePosition = (previous + position) * 0.5;
        float density = everDiskDensity(samplePosition, time);
        if (density > 0.001) {
            float opacity = 1.0 - exp(-density * dt * 8.0);
            result.light += everDiskEmission(samplePosition, velocity) * opacity * result.transmission;
            result.transmission *= 1.0 - opacity;
        }
        if (result.transmission < 0.005) {
            result.transmission = 0.0;
            break;
        }
        if (step == 191) result.transmission = 0.0;
    }
    result.direction = velocity;
    return result;
}


vertex EverWarpVertex everBlackHoleVertex(uint index [[vertex_id]]) {
    float2 uv = everQuadUV(index);
    EverWarpVertex out;
    out.position = float4(uv * 2.0 - 1.0, 0, 1);
    out.uv = uv;
    return out;
}

fragment half4 everBlackHoleFragment(EverWarpVertex in [[stage_in]], constant float4 &u [[buffer(0)]]) {
    EverFlightCamera camera = everFlightCamera(u.z);
    float2 point = (in.uv * 2.0 - 1.0) * float2(u.x / u.y, 1.0) / everFlightStretch;
    float3 direction = normalize(camera.forward * 1.6 + camera.right * point.x + camera.up * point.y);
    EverRayResult ray = everTraceBlackHole(camera.position, direction, u.z);
    float3 color = 1.0 - exp(-ray.light * 1.45);
    float blackout = 1.0 - smoothstep(0.985, 1.0, u.z);
    return half4(half3(color * blackout), half(1.0 - ray.transmission * blackout));
}

struct EverDeviceExtractionInput {
    float4 position [[attribute(0)]];
};

struct EverDeviceExtractionUniforms {
    float4 deviceExtraction;
};

vertex EverWarpVertex everDeviceExtractionVertex(EverDeviceExtractionInput in [[stage_in]]) {
    EverWarpVertex out;
    out.position = float4(in.position.xy, 0.0, 1.0);
    out.uv = float2(in.position.x * 0.5 + 0.5, 0.5 - in.position.y * 0.5);
    return out;
}

fragment half4 everDeviceExtractionFragment(EverWarpVertex in [[stage_in]],
                                            constant EverDeviceExtractionUniforms &u [[buffer(0)]],
                                            texture2d<half> colorSampler [[texture(0)]]) {
    constexpr sampler sampling(coord::normalized, address::clamp_to_zero, filter::linear);
    float2 offset = in.uv - u.deviceExtraction.xy;
    float waist = 1.0 - smoothstep(0.0, 0.5, abs(offset.y) / max(u.deviceExtraction.z, 0.001));
    float tension = saturate(u.deviceExtraction.w);
    offset.x /= 1.0 - 0.42 * tension * waist;
    offset.y /= 1.0 + 0.14 * tension;
    return colorSampler.sample(sampling, u.deviceExtraction.xy + offset);
}

float2 everFlightScreenUV(float2 uv, float progress) {
    float strength = smoothstep(0.82, 0.97, progress);
    if (strength <= 0.0) return uv;
    float2 point = uv * 2.0 - 1.0;
    float2 squared = point * point;
    float edge = (1.0 - squared.x) * (1.0 - squared.y);
    float tension = 0.45 * strength * dot(point, point) * edge;
    return 0.5 + (uv - 0.5) * (1.0 + tension);
}

fragment half4 everFlightBlurFragment(EverWarpVertex in [[stage_in]], constant float4 &u [[buffer(0)]],
                                     texture2d<half> image [[texture(0)]]) {
    constexpr sampler sampling(coord::normalized, address::clamp_to_zero, filter::linear);
    float2 uv = everFlightScreenUV(float2(in.uv.x, 1.0 - in.uv.y), u.z);
    float remaining = 1.0 - saturate(u.z);
    float spread = 6.0 / max(length(u.xy), 1.0) * remaining * remaining * smoothstep(0.0, 0.12, u.z);
    float2 shutter = (uv - 0.5) * spread;
    half4 color = half4(0);
    for (uint sample = 0; sample < 7; ++sample) {
        color += image.sample(sampling, uv + shutter * (float(sample) / 6.0 - 0.5)) / 7.0h;
    }
    return color;
}

struct EverStarVertex {
    float4 position [[position]];
    float2 uv;
    float brightness;
};

float3 everStarWorld(uint index) {
    float seed = float(index) + 1.0;
    float angle = everStarHash(seed) * 2.0 * M_PI_F;
    float depth = index % 3 == 0 ? mix(-148.0, -6.0, everStarHash(seed + 63.0))
        : mix(8.0, 480.0, everStarHash(seed + 63.0));
    float extent = depth < 0.0 ? 68.0 : 80.0 + depth * 0.55;
    float radius = 0.3 + sqrt(everStarHash(seed + 17.0)) * extent;
    return float3(cos(angle) * radius, sin(angle) * radius, depth);
}

struct EverStarProjection {
    float2 point;
    float2 radial;
    float radialScale;
    float tangentScale;
    float depth;
    float visibility;
};

EverStarProjection everProjectStar(float3 world, EverFlightCamera camera, float aspect, bool secondary) {
    float3 relative = world - camera.position;
    float depth = dot(relative, camera.forward);
    float lensDepth = dot(-camera.position, camera.forward);
    float2 angle = float2(dot(relative, camera.right), dot(relative, camera.up)) / max(0.08, depth);
    float beta = max(0.00001, length(angle));
    float2 radial = angle / beta;
    float theta = beta;
    float radialScale = 1.0;
    float tangentScale = 1.0;
    float visibility = depth > 0.2 ? 1.0 : 0.0;
    if (depth > lensDepth && lensDepth > 1.0) {
        float einsteinSquared = 2.0 * (depth - lensDepth) / (lensDepth * depth);
        float root = sqrt(beta * beta + 4.0 * einsteinSquared);
        float sign = secondary ? -1.0 : 1.0;
        theta = 0.5 * (beta + sign * root);
        radialScale = abs(0.5 * (1.0 + sign * beta / root));
        tangentScale = min(80.0, abs(theta / beta));
        visibility *= smoothstep(0.015, 0.08, radialScale * tangentScale);
    } else if (secondary) {
        visibility = 0.0;
    }
    return {radial * theta * 1.6 * everFlightStretch / float2(aspect, 1.0), radial, radialScale, tangentScale, depth, visibility};
}

vertex EverStarVertex everLightspeedVertex(uint index [[vertex_id]], uint instance [[instance_id]],
                                           constant float4 &u [[buffer(0)]]) {
    uint star = instance / 2;
    bool secondary = instance % 2 != 0;
    float seed = float(star) + 1.0;
    float3 world = everStarWorld(star);
    EverFlightCamera camera = everFlightCamera(u.z);
    EverFlightCamera previousCamera = everFlightCamera(max(0.0, u.z - 0.008));
    float aspect = u.x / u.y;
    EverStarProjection current = everProjectStar(world, camera, aspect, secondary);
    EverStarProjection previous = everProjectStar(world, previousCamera, aspect, secondary);
    float2 velocity = current.point - previous.point;
    float magnitude = length(velocity);
    if (magnitude > 0.8) velocity *= 0.8 / magnitude;
    float width = clamp((1.1 + everStarHash(seed + 91.0) * 1.5) * sqrt(90.0 / max(0.2, current.depth)), 0.8, 6.0) / u.y;
    float2 uv = everQuadUV(index);
    float2 radial = current.radial * everFlightStretch / float2(aspect, 1);
    float2 tangent = float2(-current.radial.y, current.radial.x) * everFlightStretch / float2(aspect, 1);
    float2 point = current.point + radial * (uv.x * 2.0 - 1.0) * width * max(0.3, current.radialScale)
        + tangent * (uv.y * 2.0 - 1.0) * width * current.tangentScale - velocity * uv.y;
    bool foreground = current.depth < dot(-camera.position, camera.forward);
    float visibility = current.visibility * ((u.w > 0.5) == foreground ? 1.0 : 0.0);
    EverStarVertex out;
    out.position = float4(point, 0, 1);
    out.uv = uv;
    out.brightness = visibility * (0.8 + everStarHash(seed + 39.0) * 1.25)
        * (1.0 - smoothstep(0.975, 1.0, u.z));
    return out;
}

fragment half4 everLightspeedFragment(EverStarVertex in [[stage_in]]) {
    float across = exp(-pow(in.uv.x * 2.0 - 1.0, 2.0) * 3.4);
    float along = exp(-pow(in.uv.y * 2.0 - 1.0, 2.0) * 2.6);
    half light = half(across * along * in.brightness);
    return half4(light * half3(0.9, 0.95, 1.0), min(light, 1.0h));
}
