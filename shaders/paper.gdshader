shader_type spatial;
render_mode unshaded;

uniform sampler2D text_texture;

void fragment() {
    ALBEDO = texture(text_texture, UV).rgb;
}
