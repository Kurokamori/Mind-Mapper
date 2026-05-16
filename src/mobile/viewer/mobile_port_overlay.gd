class_name MobilePortOverlay
extends Node2D

const PORT_RADIUS_PX: float = 9.0
const PORT_HIT_RADIUS_PX: float = 22.0
const PORT_FILL: Color = Color(0.13, 0.15, 0.21, 0.95)
const PORT_OUTLINE: Color = Color(0.55, 0.78, 1.0, 1.0)
const PORT_HOT_FILL: Color = Color(0.45, 0.78, 1.0, 1.0)
const PORT_HOT_OUTLINE: Color = Color(0.95, 0.97, 1.0, 1.0)
const SOURCE_OUTLINE: Color = Color(1.0, 0.85, 0.35, 1.0)

var _board_view: Node = null
var _enabled: bool = false
var _pending_source_id: String = ""
var _pending_source_anchor: String = ""


func _ready() -> void:
	z_index = 6
	visible = false


func bind_board_view(view: Node) -> void:
	_board_view = view


func set_enabled(value: bool) -> void:
	if _enabled == value:
		return
	_enabled = value
	visible = value
	queue_redraw()


func set_pending_source(item_id: String, anchor: String) -> void:
	if _pending_source_id == item_id and _pending_source_anchor == anchor:
		return
	_pending_source_id = item_id
	_pending_source_anchor = anchor
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func hit_test(world_pos: Vector2) -> Dictionary:
	if _board_view == null or not _enabled:
		return {}
	var zoom: float = _zoom()
	var hit_radius: float = PORT_HIT_RADIUS_PX / max(zoom, 0.05)
	var best_distance: float = hit_radius
	var best_anchor: String = ""
	var best_item: BoardItem = null
	for item_v: Variant in _board_view.all_items():
		var item: BoardItem = item_v
		for anchor: String in BoardItem.PORT_ANCHORS:
			var port_world: Vector2 = item.port_world_position(anchor)
			var dist: float = world_pos.distance_to(port_world)
			if dist <= best_distance:
				best_distance = dist
				best_anchor = anchor
				best_item = item
	if best_item == null:
		return {}
	return {"item_id": best_item.item_id, "anchor": best_anchor}


func _zoom() -> float:
	if _board_view == null or not _board_view.has_method("camera_node"):
		return 1.0
	var cam: MobileCameraController = _board_view.camera_node()
	if cam == null:
		return 1.0
	return cam.zoom.x


func _draw() -> void:
	if not _enabled or _board_view == null:
		return
	var zoom: float = _zoom()
	var radius: float = PORT_RADIUS_PX / max(zoom, 0.05)
	var outline_w: float = 1.5 / max(zoom, 0.05)
	for item_v: Variant in _board_view.all_items():
		var item: BoardItem = item_v
		var is_source: bool = item.item_id == _pending_source_id
		for anchor: String in BoardItem.PORT_ANCHORS:
			var port_world: Vector2 = item.port_world_position(anchor)
			var is_hot: bool = is_source and anchor == _pending_source_anchor and _pending_source_anchor != ""
			var fill: Color = PORT_HOT_FILL if is_hot else PORT_FILL
			var outline: Color = SOURCE_OUTLINE if (is_source and not is_hot) else (PORT_HOT_OUTLINE if is_hot else PORT_OUTLINE)
			var r: float = radius * (1.2 if is_hot else 1.0)
			draw_circle(port_world, r, fill)
			draw_arc(port_world, r, 0.0, TAU, 24, outline, outline_w, true)
