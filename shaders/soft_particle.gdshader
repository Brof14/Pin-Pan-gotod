shader_type canvas_item;

uniform float softness : hint_range(0.0, 1.0) = 0.5;
uniform float glow : hint_range(0.0, 2.0) = 1.0;

void fragment() {
    vec4 color = texture(TEXTURE, UV);

    // Soft particle effect
    float alpha = color.a;
    alpha = pow(alpha, 1.0 - softness);

    // Add glow
    float glow_amount = glow * (1.0 - alpha);
    color.rgb += vec3(glow_amount * 0.5);

    // Apply alpha with glow
    color.a = alpha + glow_amount;

    COLOR = color;
}
