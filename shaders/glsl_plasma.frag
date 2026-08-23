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
};

void main() {
    vec2 uv = qt_TexCoord0 * 2.0 - 1.0;
    
    // Per-pixel GLSL fluid plasma synthesis
    float t = u_time * (1.0 + u_bass * 1.5);
    
    float v1 = sin(uv.x * 6.0 + t);
    float v2 = sin(uv.y * 6.0 - t * 0.8 + v1);
    float cx = uv.x + sin(t * 0.5) * 0.3;
    float cy = uv.y + cos(t * 0.3) * 0.3;
    float v3 = sin(sqrt(cx * cx + cy * cy) * 12.0 - t * 2.0);
    
    float plasma = (v1 + v2 + v3) / 3.0;
    
    // Audio energy color modulation
    vec3 col = u_accent * (0.6 + 0.4 * sin(plasma * 3.14159 + vec3(0.0, 1.0, 2.0)));
    col += vec3(1.0) * pow(max(0.0, plasma), 4.0) * (u_beat * 0.8 + u_bass * 0.4);
    
    // Edge vignette
    float vig = 1.0 - length(uv * vec2(0.8, 1.2));
    col *= clamp(vig * 1.5, 0.0, 1.0);
    
    fragColor = vec4(col, 0.95) * qt_Opacity;
}
