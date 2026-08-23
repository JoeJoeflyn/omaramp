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
    
    // Polar coordinates for volumetric 3D tunnel
    float r = length(uv);
    float a = atan(uv.y, uv.x);
    
    // Depth projection
    float depth = 0.35 / max(0.01, r);
    
    // Travel velocity directly tracks audio energy and beat onsets
    float t = u_time * (0.8 + u_bass * 1.8 + u_beat * 2.0);
    
    vec2 tunnelUV = vec2(a * 4.0 / 3.14159, depth + t);
    
    // Neon tunnel rings & spokes
    float rings = sin(tunnelUV.y * 8.0) * 0.5 + 0.5;
    float spokes = sin(tunnelUV.x * 4.0 + depth * 0.4) * 0.5 + 0.5;
    
    // Wireframe neon brightness directly modulated by song energy
    float wireframe = pow(rings * spokes, 3.0) * (0.8 + u_bass * 1.2 + u_beat * 1.5);
    
    vec3 col = u_accent * wireframe;
    col += vec3(0.1, 0.8, 1.0) * pow(rings, 6.0) * (0.6 + u_bass * 0.9 + u_beat * 0.8);
    
    // Event horizon core glow (Flares on beat drop)
    float coreGlow = (0.05 + u_bass * 0.06 + u_beat * 0.08) / (r + 0.04);
    col += vec3(1.0) * coreGlow;
    
    // Depth fog
    col *= clamp(r * 1.8, 0.0, 1.0);
    
    fragColor = vec4(col, 0.95) * qt_Opacity;
}
