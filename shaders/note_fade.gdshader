shader_type canvas_item;

uniform float rect_width_px;
uniform float fade_width_px = 100.0;
uniform float fade_strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    float pixel_x = UV.x * rect_width_px;

    // Fade from 0 (transparent) at 0 px to 1 (opaque) at fade_width_px
    float fade = smoothstep(0.0, fade_width_px, pixel_x);
	float noise = fract(sin(dot(UV.xy ,vec2(12.9898,78.233))) * 43758.5453);
	fade += (noise - 0.5) * 0.02;  // small noise adjustment
	fade = clamp(fade, 0.0, 1.0);

    COLOR = vec4(0.0, 0.0, 0.0, fade * fade_strength);
}
