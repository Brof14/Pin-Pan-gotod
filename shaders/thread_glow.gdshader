shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float time : hint_range(0.0, 100.0) = 0.0;

void fragment() {
    vec4 color = TEXTURE(UV, TEXTURE);

    // Add glow effect
    float glow = (sin(time * 2.0) + 1.0) * 0.5 * glow_intensity;
    color.rgb += vec3(glow * 0.5);

    // Fade edges
    float dist = length(UV - vec2(0.5));
    color.a *= (1.0 - dist * 0.5);

    COLOR = color;
}
