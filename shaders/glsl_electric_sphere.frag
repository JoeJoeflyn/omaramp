#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float u_time;
    float u_bass;
    float u_mids;
    float u_highs;
    float u_beat;
    vec3 u_accent;
    float u_aspect;
};

void main() {
    vec2 uv = qt_TexCoord0 * 2.0 - 1.0;
    
    // Fit the orb to the shorter axis without stretching the circle.
    vec2 p = uv * vec2(max(1.0, u_aspect), 1.0 / min(1.0, u_aspect));
    float r = length(p);
    float a = atan(p.y, p.x);
    
    float t = u_time;
    
    // 1. Taller, Volumetric Plasma Sphere Core
    float sphereRadius = 0.48 * (0.80 + u_bass * 0.40 + u_beat * 0.30);
    
    // 2. Electric Corona Arcs
    float arc1 = sin(a * 7.0 + t * 2.0) * (0.020 + u_highs * 0.07 + u_beat * 0.05);
    float arc2 = sin(a * 13.0 - t * 2.5 + sin(r * 15.0)) * (0.015 + u_mids * 0.05);
    float distortedR = r - (arc1 + arc2);
    
    vec3 col = vec3(0.0);
    
    if (distortedR < sphereRadius) {
        // Inner glowing core
        float core = clamp(1.0 - distortedR / sphereRadius, 0.0, 1.0);
        col = mix(u_accent, vec3(1.0), pow(core, 1.8));
    } else {
        // Outer electric corona bloom
        float coronaDist = max(0.006, abs(distortedR - sphereRadius));
        float coronaIntensity = (0.032 + u_bass * 0.045 + u_beat * 0.05) / coronaDist;
        col = u_accent * coronaIntensity;
        col += vec3(0.3, 0.85, 1.0) * pow(clamp(coronaIntensity * 0.35, 0.0, 1.0), 2.0);
    }
    
    // Vignette
    col *= clamp(1.5 - r * 1.1, 0.0, 1.0);
    
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
