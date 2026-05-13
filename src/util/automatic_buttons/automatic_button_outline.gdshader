shader_type canvas_item;

// Solid-color tint pass used by the outline overlay NinePatchRect. The overlay
// sits behind the main visual at a slightly larger rect; the fragment replaces
// every texel's RGB with outline_color while preserving the texture's alpha
// shape, so where the larger overlay extends past the main visual a colored
// halo remains visible.

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_alpha_mul : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a = tex.a * outline_color.a * outline_alpha_mul;
	if (a <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = vec4(outline_color.rgb, a) * vec4(1.0, 1.0, 1.0, COLOR.a);
	}
}
