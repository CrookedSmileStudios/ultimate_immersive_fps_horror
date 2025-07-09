shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 outline_color : source_color;
uniform float outline_width = 1.0;
uniform float pulse_speed = 1.0; // Speed of the pulse
uniform float min_alpha = 0.0;   // Minimum alpha in pulse
uniform float max_alpha = 1.0;   // Maximum alpha in pulse

void vertex() {
	vec4 clip_position = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 clip_normal = mat3(PROJECTION_MATRIX) * (mat3(MODELVIEW_MATRIX) * NORMAL);
	
	vec2 offset = normalize(clip_normal.xy) / VIEWPORT_SIZE * clip_position.w * outline_width * 2.0;
	
	clip_position.xy += offset;
	
	POSITION = clip_position;
}

void fragment() {
	// Pulse alpha with sine wave over time
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5; // range: 0 to 1
	float alpha = mix(min_alpha, max_alpha, pulse);

	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a * alpha;
}