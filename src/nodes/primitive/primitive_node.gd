class_name PrimitiveNode
extends BoardItem

enum Shape {
	RECT,
	ROUNDED_RECT,
	ELLIPSE,
	TRIANGLE,
	DIAMOND,
	LINE,
	ARROW,
}

const DEFAULT_FILL: Color = Color(0.30, 0.55, 0.85, 1.0)
const DEFAULT_OUTLINE: Color = Color(0.05, 0.10, 0.18, 1.0)
const DEFAULT_OUTLINE_WIDTH: float = 2.0
const DEFAULT_CORNER_RADIUS: float = 12.0
const ELLIPSE_SEGMENTS: int = 64

@export var shape: int = Shape.RECT
@export var fill_enabled: bool = true
@export var fill_color: Color = DEFAULT_FILL
@export var outline_color: Color = DEFAULT_OUTLINE
@export var outline_width: float = DEFAULT_OUTLINE_WIDTH
@export var corner_radius: float = DEFAULT_CORNER_RADIUS


func _ready() -> void:
	super._ready()
	queue_redraw()


func default_size() -> Vector2:
	return Vector2(160, 100)


func display_name() -> String:
	return "Primitive"


func _draw_body() -> void:
	var w: float = size.x
	var h: float = size.y
	match shape:
		Shape.RECT:
			_draw_rect_shape(Vector2.ZERO, Vector2(w, h))
		Shape.ROUNDED_RECT:
			_draw_rounded_rect(Vector2.ZERO, Vector2(w, h), corner_radius)
		Shape.ELLIPSE:
			_draw_ellipse(Vector2(w * 0.5, h * 0.5), Vector2(w * 0.5, h * 0.5))
		Shape.TRIANGLE:
			_draw_triangle(Vector2(w, h))
		Shape.DIAMOND:
			_draw_diamond(Vector2(w, h))
		Shape.LINE:
			draw_line(Vector2(0, h), Vector2(w, 0), outline_color, max(1.0, outline_width))
		Shape.ARROW:
			_draw_arrow(Vector2(w, h))


func _draw_rect_shape(origin: Vector2, dim: Vector2) -> void:
	var rect: Rect2 = Rect2(origin, dim)
	if fill_enabled:
		draw_rect(rect, fill_color, true)
	if outline_width > 0.0:
		draw_rect(rect, outline_color, false, outline_width)


func _draw_rounded_rect(origin: Vector2, dim: Vector2, r: float) -> void:
	var radius: float = clamp(r, 0.0, min(dim.x, dim.y) * 0.5)
	var pts: PackedVector2Array = _rounded_rect_points(origin, dim, radius, 8)
	if fill_enabled and pts.size() >= 3:
		var colors: PackedColorArray = PackedColorArray()
		colors.resize(pts.size())
		for i in range(pts.size()):
			colors[i] = fill_color
		draw_polygon(pts, colors)
	if outline_width > 0.0:
		var loop: PackedVector2Array = pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, outline_color, outline_width)


func _rounded_rect_points(origin: Vector2, dim: Vector2, r: float, steps_per_corner: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var corners: Array = [
		Vector2(origin.x + dim.x - r, origin.y + r),
		Vector2(origin.x + dim.x - r, origin.y + dim.y - r),
		Vector2(origin.x + r, origin.y + dim.y - r),
		Vector2(origin.x + r, origin.y + r),
	]
	var start_angles: Array = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for i in range(4):
		var center: Vector2 = corners[i]
		var start_angle: float = start_angles[i]
		for s in range(steps_per_corner + 1):
			var t: float = float(s) / float(steps_per_corner)
			var angle: float = start_angle + t * (PI * 0.5)
			pts.append(center + Vector2(cos(angle), sin(angle)) * r)
	return pts


func _draw_ellipse(center: Vector2, radii: Vector2) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(ELLIPSE_SEGMENTS)
	for i in range(ELLIPSE_SEGMENTS):
		var a: float = (float(i) / float(ELLIPSE_SEGMENTS)) * TAU
		pts[i] = center + Vector2(cos(a) * radii.x, sin(a) * radii.y)
	if fill_enabled:
		var colors: PackedColorArray = PackedColorArray()
		colors.resize(pts.size())
		for i in range(pts.size()):
			colors[i] = fill_color
		draw_polygon(pts, colors)
	if outline_width > 0.0:
		var loop: PackedVector2Array = pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, outline_color, outline_width)


func _draw_triangle(dim: Vector2) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(dim.x * 0.5, 0.0),
		Vector2(dim.x, dim.y),
		Vector2(0.0, dim.y),
	])
	if fill_enabled:
		var colors: PackedColorArray = PackedColorArray([fill_color, fill_color, fill_color])
		draw_polygon(pts, colors)
	if outline_width > 0.0:
		var loop: PackedVector2Array = pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, outline_color, outline_width)


func _draw_diamond(dim: Vector2) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(dim.x * 0.5, 0.0),
		Vector2(dim.x, dim.y * 0.5),
		Vector2(dim.x * 0.5, dim.y),
		Vector2(0.0, dim.y * 0.5),
	])
	if fill_enabled:
		var colors: PackedColorArray = PackedColorArray()
		colors.resize(pts.size())
		for i in range(pts.size()):
			colors[i] = fill_color
		draw_polygon(pts, colors)
	if outline_width > 0.0:
		var loop: PackedVector2Array = pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, outline_color, outline_width)


func _draw_arrow(dim: Vector2) -> void:
	var head_size: float = min(dim.x, dim.y) * 0.5
	var head_size_clamped: float = clamp(head_size, 8.0, min(dim.x * 0.5, dim.y))
	var start: Vector2 = Vector2(0.0, dim.y * 0.5)
	var end_pt: Vector2 = Vector2(dim.x - head_size_clamped, dim.y * 0.5)
	var tip: Vector2 = Vector2(dim.x, dim.y * 0.5)
	var head_top: Vector2 = Vector2(dim.x - head_size_clamped, dim.y * 0.5 - head_size_clamped * 0.5)
	var head_bottom: Vector2 = Vector2(dim.x - head_size_clamped, dim.y * 0.5 + head_size_clamped * 0.5)
	draw_line(start, end_pt, outline_color, max(1.0, outline_width))
	var pts: PackedVector2Array = PackedVector2Array([tip, head_top, head_bottom])
	if fill_enabled:
		var colors: PackedColorArray = PackedColorArray([fill_color, fill_color, fill_color])
		draw_polygon(pts, colors)
	if outline_width > 0.0:
		var loop: PackedVector2Array = pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, outline_color, outline_width)


func serialize_payload() -> Dictionary:
	return {
		"shape": shape,
		"fill_enabled": fill_enabled,
		"fill_color": ColorUtil.to_array(fill_color),
		"outline_color": ColorUtil.to_array(outline_color),
		"outline_width": outline_width,
		"corner_radius": corner_radius,
	}


func deserialize_payload(d: Dictionary) -> void:
	shape = int(d.get("shape", shape))
	fill_enabled = bool(d.get("fill_enabled", fill_enabled))
	fill_color = ColorUtil.from_array(d.get("fill_color", null), fill_color)
	outline_color = ColorUtil.from_array(d.get("outline_color", null), outline_color)
	outline_width = float(d.get("outline_width", outline_width))
	corner_radius = float(d.get("corner_radius", corner_radius))
	queue_redraw()


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"shape":
			shape = int(value)
		"fill_enabled":
			fill_enabled = bool(value)
		"fill_color":
			fill_color = ColorUtil.from_array(value, fill_color)
		"outline_color":
			outline_color = ColorUtil.from_array(value, outline_color)
		"outline_width":
			outline_width = float(value)
		"corner_radius":
			corner_radius = float(value)
	queue_redraw()


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/primitive/primitive_inspector.tscn")
	var inst: PrimitiveInspector = scene.instantiate()
	inst.bind(self)
	return inst
