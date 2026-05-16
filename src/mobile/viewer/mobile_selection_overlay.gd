class_name MobileSelectionOverlay
extends Node2D

const OUTLINE_COLOR: Color = Color(0.35, 0.7, 1.0, 1.0)
const SECONDARY_OUTLINE_COLOR: Color = Color(0.35, 0.7, 1.0, 0.55)
const OUTLINE_WIDTH: float = 2.0
const HANDLE_RADIUS_BASE: float = 14.0
const HANDLE_FILL: Color = Color(0.13, 0.15, 0.21, 0.95)
const HANDLE_OUTLINE: Color = Color(0.95, 0.97, 1.0, 1.0)
const HANDLE_GLYPH: Color = Color(0.85, 0.92, 1.0, 1.0)

var _board_view: Node = null
var _selected_ids: Array[String] = []
var _resize_handle_visible: bool = false
var _resize_active: bool = false


func _ready() -> void:
	z_index = 5


func bind_board_view(view: Node) -> void:
	_board_view = view


func set_selection(item_ids: Array) -> void:
	_selected_ids = []
	for id_v: Variant in item_ids:
		_selected_ids.append(String(id_v))
	queue_redraw()


func set_resize_handle_visible(visible: bool) -> void:
	if _resize_handle_visible == visible:
		return
	_resize_handle_visible = visible
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if _board_view == null:
		return
	var primary_id: String = _selected_ids[0] if _selected_ids.size() > 0 else ""
	for id: String in _selected_ids:
		var node: BoardItem = _board_view.find_item_node(id) if _board_view.has_method("find_item_node") else null
		if node == null:
			continue
		var rect: Rect2 = Rect2(node.position, node.size)
		var color: Color = OUTLINE_COLOR if id == primary_id else SECONDARY_OUTLINE_COLOR
		_draw_outline(rect, color)
	if _resize_handle_visible and primary_id != "":
		var primary_node: BoardItem = _board_view.find_item_node(primary_id) if _board_view.has_method("find_item_node") else null
		if primary_node != null and not primary_node.locked:
			_draw_resize_handle(primary_node.position + primary_node.size)


func _draw_outline(rect: Rect2, color: Color) -> void:
	var camera: MobileCameraController = _board_view.camera_node() if _board_view.has_method("camera_node") else null
	var zoom: float = camera.zoom.x if camera != null else 1.0
	var width: float = OUTLINE_WIDTH / max(zoom, 0.05)
	draw_rect(rect, color, false, width)


func _draw_resize_handle(corner_world: Vector2) -> void:
	var camera: MobileCameraController = _board_view.camera_node() if _board_view.has_method("camera_node") else null
	var zoom: float = camera.zoom.x if camera != null else 1.0
	var radius: float = HANDLE_RADIUS_BASE / max(zoom, 0.05)
	draw_circle(corner_world, radius, HANDLE_FILL)
	draw_arc(corner_world, radius, 0.0, TAU, 24, HANDLE_OUTLINE, 1.5 / max(zoom, 0.05), true)
	var arrow_a: Vector2 = corner_world + Vector2(-radius * 0.4, -radius * 0.4)
	var arrow_b: Vector2 = corner_world + Vector2(radius * 0.4, radius * 0.4)
	draw_line(arrow_a, arrow_b, HANDLE_GLYPH, 1.4 / max(zoom, 0.05), true)
	draw_line(arrow_b, arrow_b + Vector2(-radius * 0.25, 0.0), HANDLE_GLYPH, 1.4 / max(zoom, 0.05), true)
	draw_line(arrow_b, arrow_b + Vector2(0.0, -radius * 0.25), HANDLE_GLYPH, 1.4 / max(zoom, 0.05), true)
	draw_line(arrow_a, arrow_a + Vector2(radius * 0.25, 0.0), HANDLE_GLYPH, 1.4 / max(zoom, 0.05), true)
	draw_line(arrow_a, arrow_a + Vector2(0.0, radius * 0.25), HANDLE_GLYPH, 1.4 / max(zoom, 0.05), true)
