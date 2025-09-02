shader_type canvas_item;

uniform sampler2D screen_texture: hint_screen_texture;
uniform float alpha : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Sample the current screen color at this pixel
	vec4 screen_color = texture(screen_texture, SCREEN_UV);

	// Green tint color with variable alpha
	vec4 green_tint = vec4(0.0, 1.0, 0.0, alpha);

	// Blend the green tint over the screen color using alpha
	COLOR = mix(screen_color, green_tint, green_tint.a);
}
