#version 460 core

#include <flutter/runtime_effect.glsl>

uniform float u_amplitude;
uniform float u_wavelength;
uniform float u_bias;
uniform float u_seed;
uniform float u_resolution_x;
uniform float u_resolution_y;
uniform float u_island_radius;
uniform float u_mode; // 0=normal render, 1=detection mode
uniform float u_detection_threshold; // threshold for detection

// New uniforms for camera transform:
uniform float u_camera_x; // world x of visible area top-left
uniform float u_camera_y; // world y of visible area top-left
uniform float u_view_w;   // visible width in world units
uniform float u_view_h;   // visible height in world units

out vec4 fragColor;

#define NUM_NOISE_OCTAVES 5

float hash(float n) { 
    return fract(sin(n) * 1e4); 
}

float hash(vec2 p) { 
    return fract(1e4 * sin(17.0 * p.x + p.y * 0.1) * (0.1 + abs(sin(p.y * 13.0 + p.x)))); 
}

float noise(vec2 x) {
    vec2 i = floor(x);
    vec2 f = fract(x);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 x) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100);
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.50));
    for (int i = 0; i < NUM_NOISE_OCTAVES; ++i) {
        v += a * noise(x);
        x = rot * x * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

float add_peak(vec2 pos, vec2 center, float radius, float intensity) {
    float d = length(pos - center);
    return intensity * exp(-pow(d / radius, 2.0));
}

vec2 computeNormal(vec2 pos, float eps, float u_wavelength, float u_seed) {
    float hL = fbm((pos + vec2(-eps, 0.0)) / u_wavelength + vec2(u_seed * 0.01));
    float hR = fbm((pos + vec2( eps, 0.0)) / u_wavelength + vec2(u_seed * 0.01));
    float hD = fbm((pos + vec2(0.0, -eps)) / u_wavelength + vec2(u_seed * 0.01));
    float hU = fbm((pos + vec2(0.0,  eps)) / u_wavelength + vec2(u_seed * 0.01));
    vec2 n = vec2(hL - hR, hD - hU);
    return normalize(n);
}

float getElevation(vec2 centered, float dist) {
    vec2 noiseCoord = centered / u_wavelength + vec2(u_seed * 0.01);
    float noiseValue = fbm(noiseCoord);
    noiseValue = (noiseValue + 1.0) * 0.5;
    noiseValue = noiseValue * u_amplitude + u_bias;
    
    vec2 peak1 = vec2(0.3 * sin(u_seed + 1.3), 0.25 * cos(u_seed + 2.7));
    vec2 peak2 = vec2(-0.26 * cos(u_seed + 3.4), 0.12 * sin(u_seed + 5.8));
    vec2 peak3 = vec2(0.15 * sin(u_seed + 4.1), -0.20 * cos(u_seed + 2.3));
    
    noiseValue += add_peak(centered, peak1, 0.13, 0.12);
    noiseValue += add_peak(centered, peak2, 0.10, 0.08);
    noiseValue += add_peak(centered, peak3, 0.09, 0.06);
    
    noiseValue = clamp(noiseValue, 0.0, 1.0);
    float falloff = 1.0 - (dist / u_island_radius);
    falloff = clamp(falloff, 0.0, 1.0);
    noiseValue *= falloff;
    
    return noiseValue;
}

void main() {
    // Camera-aware mapping: map visible fragment to world coordinate
    vec2 u_resolution = vec2(u_resolution_x, u_resolution_y);

    vec2 fragCoord = FlutterFragCoord();

    // Map this visible pixel to world pixel:
    // If u_view_w == u_resolution_x, then world_x = fragCoord.x + u_camera_x (no zoom/pan)
    // Otherwise, scale accordingly:
    float world_x = u_camera_x + fragCoord.x * (u_resolution.x / u_view_w);
    float world_y = u_camera_y + fragCoord.y * (u_resolution.y / u_view_h);

    // Now "worldFragCoord" runs from (0,0) to (u_resolution_x, u_resolution_y) over the full world
    vec2 worldFragCoord = vec2(world_x, world_y);

    float minRes = min(u_resolution.x, u_resolution.y);
    vec2 centered = (worldFragCoord - 0.5 * u_resolution) / (0.5 * minRes);

    float dist = length(centered);
    float noiseValue = getElevation(centered, dist);

    if (u_mode < 0.5) {
        // Normal rendering mode
        vec3 water1 = vec3(0.13, 0.52, 0.77);
        vec3 water2 = vec3(0.29, 0.67, 0.91);
        vec3 water3 = vec3(0.53, 0.82, 0.98);
        vec3 sand    = vec3(1.0, 1.0, 0.65);
        vec3 lowland = vec3(0.74, 0.95, 0.44);
        vec3 upland  = vec3(0.61, 0.80, 0.31);
        vec3 peak = vec3(0.85, 0.85, 0.83);

        vec3 color;
        if (dist > u_island_radius) {
            color = water1;
        } else if (noiseValue < 0.18) {
            color = water1;
        } else if (noiseValue < 0.25) {
            color = water2;
        } else if (noiseValue < 0.32) {
            color = water3;
        } else {
            float eps = 0.008;
            vec2 lightDir = normalize(vec2(-0.6, -1.0));
            vec2 n = computeNormal(centered, eps, u_wavelength, u_seed);
            float highlight = clamp(dot(n, lightDir)*0.4 + 0.7, 0.7, 1.1);

            if (noiseValue < 0.39) {
                color = sand * highlight;
            } else if (noiseValue < 0.54) {
                color = lowland * highlight;
            } else if (noiseValue < 0.7) {
                color = upland * highlight;
            } else {
                color = peak * highlight;
            }
        }
        fragColor = vec4(color, 1.0);
        
    } else {
        // Detection mode - find edges at the specified threshold
        vec2 texel = vec2(1.0) / u_resolution;
        float center = noiseValue;
        float edgeStrength = 0.0;
        int samples = 0;
        for (int dx = -1; dx <= 1; dx++) {
            for (int dy = -1; dy <= 1; dy++) {
                if (dx == 0 && dy == 0) continue;
                vec2 offset = vec2(float(dx), float(dy));
                vec2 sampleFragCoord = worldFragCoord + offset;
                vec2 sampleCentered = (sampleFragCoord - 0.5 * u_resolution) / (0.5 * minRes);
                float sampleDist = length(sampleCentered);
                float sampleValue = getElevation(sampleCentered, sampleDist);
                if ((center >= u_detection_threshold && sampleValue < u_detection_threshold) ||
                    (center < u_detection_threshold && sampleValue >= u_detection_threshold)) {
                    edgeStrength += 1.0;
                }
                samples++;
            }
        }
        edgeStrength /= float(samples);

        if (edgeStrength > 0.2) {
            float normalizedX = worldFragCoord.x / u_resolution.x;
            float normalizedY = worldFragCoord.y / u_resolution.y;
            fragColor = vec4(normalizedX, edgeStrength, normalizedY, 1.0);
        } else {
            fragColor = vec4(0.0, 0.0, 0.0, 0.0);
        }
    }
}