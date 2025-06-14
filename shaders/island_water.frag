#version 460 core

#include <flutter/runtime_effect.glsl>

uniform float u_amplitude;
uniform float u_wavelength;
uniform float u_bias;
uniform float u_seed;
uniform float u_resolution_x;
uniform float u_resolution_y;
uniform float u_island_radius;

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

// Add 1–3 peaks at seeded locations
float add_peak(vec2 pos, vec2 center, float radius, float intensity) {
    float d = length(pos - center);
    return intensity * exp(-pow(d / radius, 2.0));
}

// Compute fake "normal" for simple highlight/shadow
vec2 computeNormal(vec2 pos, float eps, float u_wavelength, float u_seed) {
    float hL = fbm((pos + vec2(-eps, 0.0)) / u_wavelength + vec2(u_seed * 0.01));
    float hR = fbm((pos + vec2( eps, 0.0)) / u_wavelength + vec2(u_seed * 0.01));
    float hD = fbm((pos + vec2(0.0, -eps)) / u_wavelength + vec2(u_seed * 0.01));
    float hU = fbm((pos + vec2(0.0,  eps)) / u_wavelength + vec2(u_seed * 0.01));
    vec2 n = vec2(hL - hR, hD - hU);
    return normalize(n);
}

void main() {
    vec2 fragCoord = FlutterFragCoord();
    vec2 u_resolution = vec2(u_resolution_x, u_resolution_y);

    float minRes = min(u_resolution.x, u_resolution.y);
    vec2 centered = (fragCoord - 0.5 * u_resolution) / (0.5 * minRes);

    float dist = length(centered);
    float islandRadius = u_island_radius;

    // Noise for terrain
    vec2 noiseCoord = centered / u_wavelength + vec2(u_seed * 0.01);
    float noiseValue = fbm(noiseCoord);

    // Normalize noise to [0,1]
    noiseValue = (noiseValue + 1.0) * 0.5;

    // Add amplitude and bias
    noiseValue = noiseValue * u_amplitude + u_bias;

    // Add 2-3 seeded peaks
    vec2 peak1 = vec2(0.3 * sin(u_seed + 1.3), 0.25 * cos(u_seed + 2.7));
    vec2 peak2 = vec2(-0.26 * cos(u_seed + 3.4), 0.12 * sin(u_seed + 5.8));
    vec2 peak3 = vec2(0.15 * sin(u_seed + 4.1), -0.20 * cos(u_seed + 2.3));

    noiseValue += add_peak(centered, peak1, 0.13, 0.12);
    noiseValue += add_peak(centered, peak2, 0.10, 0.08);
    noiseValue += add_peak(centered, peak3, 0.09, 0.06);

    // Clamp to [0, 1]
    noiseValue = clamp(noiseValue, 0.0, 1.0);

    // Island falloff, softens edges
    float falloff = 1.0 - (dist / islandRadius);
    falloff = clamp(falloff, 0.0, 1.0);
    noiseValue *= falloff;

    // Color bands for water and land
    vec3 water1 = vec3(0.13, 0.52, 0.77);    // Deep water
    vec3 water2 = vec3(0.29, 0.67, 0.91);    // Middle water
    vec3 water3 = vec3(0.53, 0.82, 0.98);    // Shallows

    vec3 sand    = vec3(1.0, 1.0, 0.65);     // Sand
    vec3 lowland = vec3(0.74, 0.95, 0.44);   // Light green
    vec3 upland  = vec3(0.61, 0.80, 0.31);   // Darker green
    
    // CHOOSE ONE OF THE FOLLOWING FOR THE HIGH PEAK:
    // Light grey
    vec3 peak = vec3(0.85, 0.85, 0.83);
    // Charcoal
    // vec3 peak = vec3(0.23, 0.25, 0.28);
    // Dark green
    // vec3 peak = vec3(0.21, 0.36, 0.18);

    vec3 color;
    if (dist > islandRadius) {
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
}