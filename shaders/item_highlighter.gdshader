shader_type spatial;
render_mode unshaded, depth_draw_never;

uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float cycle_interval : hint_range(0.5, 5.0) = 1.0;
uniform float shine_speed : hint_range(1.0, 5.0) = 3.0;
uniform float shine_width : hint_range(1.0, 100.0) = 3.0;
uniform vec3 shine_direction = vec3(0.0, 0.0, 1.0); // NEW: Configurable axis

void fragment() {
	vec3 vertex = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Project the vertex onto the direction vector
	float shine_offset = dot(vertex, normalize(shine_direction));

	// Animate shine along the axis
	float width = shine_width * 0.001 * cycle_interval;
	float frequency = floor(sin(shine_offset * cycle_interval + TIME * shine_speed * cycle_interval) + width);

	ALBEDO = shine_color.rgb;
	ALPHA = clamp((1.0 - dot(NORMAL, VIEW)) * frequency * shine_color.a, 0.0, 1.0);
}
