#version 460 core

#include <flutter/runtime_effect.glsl>

uniform float u_amplitude;
uniform float u_wavelength;
uniform float u_bias;
uniform float u_seed;
uniform float u_resolution_x;
uniform float u_resolution_y;

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

void main() {
    vec2 fragCoord = FlutterFragCoord();
    vec2 u_resolution = vec2(u_resolution_x, u_resolution_y);

    // PROPER CENTERING, do not change this!
    float minRes = min(u_resolution.x, u_resolution.y);
    vec2 centered = (fragCoord - 0.5 * u_resolution) / (0.5 * minRes);

    float dist = length(centered);
    float islandRadius = 0.8; // Increase for larger island, decrease for smaller

    // Noise for terrain
    vec2 noiseCoord = centered / u_wavelength + vec2(u_seed * 0.01);
    float noiseValue = fbm(noiseCoord);

    // Normalize noise to [0,1]
    noiseValue = (noiseValue + 1.0) * 0.5;

    // Apply amplitude and bias
    noiseValue = noiseValue * u_amplitude + u_bias;

    // Island falloff, softens edges
    float falloff = 1.0 - (dist / islandRadius);
    falloff = clamp(falloff, 0.0, 1.0);
    noiseValue *= falloff;

    // Color bands (edit thresholds as needed for your style)
    vec3 deepWater = vec3(0.13, 0.52, 0.77);    // #2185C5 - deep blue
    vec3 beach = vec3(1.0, 1.0, 0.65);          // #FFFFA6 - light yellow
    vec3 land = vec3(0.74, 0.95, 0.44);         // #BDF271 - bright green

    vec3 color;
    if (dist > islandRadius) {
        color = deepWater;
    } else if (noiseValue < 0.25) {
        color = deepWater;
    } else if (noiseValue < 0.35) {
        color = beach;
    } else {
        color = land;
    }

    fragColor = vec4(color, 1.0);
}