shader_type spatial;  // For 3D mesh materials in Godot 4.x

uniform sampler2D albedo_texture;
uniform float blur_radius = 2.0;  // How much to blur (in UV units)
uniform int sample_count = 9;     // Number of samples for blur

void fragment() {
    vec2 uv = UV;
    vec4 color = vec4(0.0);
    float total = 0.0;

    // Sample neighboring pixels in a simple grid pattern
    for (int x = -sample_count/2; x <= sample_count/2; x++) {
        for (int y = -sample_count/2; y <= sample_count/2; y++) {
            vec2 offset = vec2(float(x), float(y)) * blur_radius / 100.0;
            color += texture(albedo_texture, uv + offset);
            total += 1.0;
        }
    }

    color /= total;

    ALBEDO = color.rgb;
    ALPHA = color.a;
}
