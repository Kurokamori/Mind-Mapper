shader_type canvas_item;

// Alpha mask for ColorPickerButton swatches: clips the rectangular
// output to a rounded rectangle of `corner_radius` pixels using the
// standard rounded-rect signed-distance field. The button emits two
// separate draw calls (a tiled checkerboard via draw_texture_rect for
// transparent colors, then draw_rect for the color itself). UV cannot
// be used because the tiled checkerboard draw sends UV in 0..N units
// (rect/texture ratio), not 0..1, which would leave the checkerboard
// unmasked at the corners. VERTEX in a canvas_item shader is the
// canvas-item-local position in pixels and is correct for both draw
// calls, so we forward it via a varying. `rect_size` is the button's
// current pixel size, refreshed from ThemeManager on the button's
// resized signal.
//
// The SDF formula folds the point into the first quadrant and
// measures distance from the inner box (whose corners sit
// `corner_radius` inside the swatch edges). Distance is negative
// inside the rounded rect, zero on the boundary, positive outside.
// AA is one screen pixel wide and centered on the boundary, so
// straight edges stay sharp instead of fading inward.

uniform float corner_radius : hint_range(0.0, 64.0) = 6.0;
uniform vec2 rect_size = vec2(32.0, 32.0);

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 half_size = rect_size * 0.5;
	vec2 from_center = local_pos - half_size;
	vec2 inner_corner = half_size - vec2(corner_radius);
	vec2 q = abs(from_center) - inner_corner;
	float outside_dist = length(max(q, vec2(0.0))) - corner_radius;
	float aa = max(fwidth(outside_dist), 1.0);
	float alpha = 1.0 - smoothstep(-aa * 0.5, aa * 0.5, outside_dist);
	COLOR.a *= alpha;
}
