class_name AlignmentGuides
extends Node2D

const GUIDE_COLOR: Color = Color(0.95, 0.78, 0.30, 0.85)
const GUIDE_LENGTH: float = 20000.0
const GUIDE_WIDTH: float = 1.0
const GAP_COLOR: Color = Color(0.40, 0.85, 1.00, 0.95)
const GAP_WIDTH: float = 1.5
const GAP_TICK_HALF: float = 6.0
const DIM_COLOR: Color = Color(0.55, 1.00, 0.55, 0.95)
const DIM_WIDTH: float = 1.5
const DIM_OFFSET: float = 8.0
const DIM_TICK_HALF: float = 5.0

var _guides: Array = []


func _ready() -> void:
	AlignmentGuideService.guides_changed.connect(_on_guides_changed)


func _on_guides_changed(guides: Array) -> void:
	_guides = guides
	queue_redraw()


func _draw() -> void:
	for g in _guides:
		var t: String = String(g.get("type", "edge"))
		if t == "edge":
			_draw_edge_guide(g)
		elif t == "gap":
			_draw_gap_guide(g)
		elif t == "dim":
			_draw_dim_guide(g)


func _draw_edge_guide(g: Dictionary) -> void:
	var axis: String = String(g.get("axis", ""))
	var value: float = float(g.get("value", 0.0))
	if axis == "x":
		draw_line(Vector2(value, -GUIDE_LENGTH), Vector2(value, GUIDE_LENGTH), GUIDE_COLOR, GUIDE_WIDTH)
	elif axis == "y":
		draw_line(Vector2(-GUIDE_LENGTH, value), Vector2(GUIDE_LENGTH, value), GUIDE_COLOR, GUIDE_WIDTH)


func _draw_gap_guide(g: Dictionary) -> void:
	var axis: String = String(g.get("axis", ""))
	var from_v: float = float(g.get("from", 0.0))
	var to_v: float = float(g.get("to", 0.0))
	var perp: float = float(g.get("perp", 0.0))
	if axis == "x":
		draw_line(Vector2(from_v, perp), Vector2(to_v, perp), GAP_COLOR, GAP_WIDTH)
		draw_line(Vector2(from_v, perp - GAP_TICK_HALF), Vector2(from_v, perp + GAP_TICK_HALF), GAP_COLOR, GAP_WIDTH)
		draw_line(Vector2(to_v, perp - GAP_TICK_HALF), Vector2(to_v, perp + GAP_TICK_HALF), GAP_COLOR, GAP_WIDTH)
	elif axis == "y":
		draw_line(Vector2(perp, from_v), Vector2(perp, to_v), GAP_COLOR, GAP_WIDTH)
		draw_line(Vector2(perp - GAP_TICK_HALF, from_v), Vector2(perp + GAP_TICK_HALF, from_v), GAP_COLOR, GAP_WIDTH)
		draw_line(Vector2(perp - GAP_TICK_HALF, to_v), Vector2(perp + GAP_TICK_HALF, to_v), GAP_COLOR, GAP_WIDTH)


func _draw_dim_guide(g: Dictionary) -> void:
	var axis: String = String(g.get("axis", ""))
	var active_rect: Rect2 = g.get("active_rect", Rect2())
	var source_rect: Rect2 = g.get("source_rect", Rect2())
	if axis == "x":
		_draw_horizontal_dim_ruler(active_rect)
		_draw_horizontal_dim_ruler(source_rect)
	elif axis == "y":
		_draw_vertical_dim_ruler(active_rect)
		_draw_vertical_dim_ruler(source_rect)


func _draw_horizontal_dim_ruler(rect: Rect2) -> void:
	var y: float = rect.position.y - DIM_OFFSET
	var x0: float = rect.position.x
	var x1: float = rect.position.x + rect.size.x
	draw_line(Vector2(x0, y), Vector2(x1, y), DIM_COLOR, DIM_WIDTH)
	draw_line(Vector2(x0, y - DIM_TICK_HALF), Vector2(x0, y + DIM_TICK_HALF), DIM_COLOR, DIM_WIDTH)
	draw_line(Vector2(x1, y - DIM_TICK_HALF), Vector2(x1, y + DIM_TICK_HALF), DIM_COLOR, DIM_WIDTH)


func _draw_vertical_dim_ruler(rect: Rect2) -> void:
	var x: float = rect.position.x - DIM_OFFSET
	var y0: float = rect.position.y
	var y1: float = rect.position.y + rect.size.y
	draw_line(Vector2(x, y0), Vector2(x, y1), DIM_COLOR, DIM_WIDTH)
	draw_line(Vector2(x - DIM_TICK_HALF, y0), Vector2(x + DIM_TICK_HALF, y0), DIM_COLOR, DIM_WIDTH)
	draw_line(Vector2(x - DIM_TICK_HALF, y1), Vector2(x + DIM_TICK_HALF, y1), DIM_COLOR, DIM_WIDTH)
