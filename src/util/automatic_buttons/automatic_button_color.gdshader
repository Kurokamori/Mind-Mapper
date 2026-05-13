shader_type canvas_item;

// HSV-based recolor pass for buttons. The fragment converts the source texel
// to HSV, shifts hue / multiplies saturation / multiplies value (luminosity),
// then multiplies the final alpha. The result is multiplied by the node's
// COLOR so per-instance modulate still composes on top of the shader.

uniform float hue_shift : hint_range(-1.0, 1.0) = 0.0;
uniform float saturation_mul : hint_range(0.0, 8.0) = 1.0;
uniform float luminosity_mul : hint_range(0.0, 8.0) = 1.0;
uniform float alpha_mul : hint_range(0.0, 1.0) = 1.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = c.g < c.b ? vec4(c.bg, K.wz) : vec4(c.gb, K.xy);
	vec4 q = c.r < p.x ? vec4(p.xyw, c.r) : vec4(c.r, p.yzx);
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		vec3 hsv = rgb_to_hsv(tex.rgb);
		hsv.x = fract(hsv.x + hue_shift + 1.0);
		hsv.y = clamp(hsv.y * saturation_mul, 0.0, 1.0);
		hsv.z = clamp(hsv.z * luminosity_mul, 0.0, 1.0);
		vec3 rgb = clamp(hsv_to_rgb(hsv), 0.0, 1.0);
		COLOR = vec4(rgb, tex.a * alpha_mul) * COLOR;
	}
}
