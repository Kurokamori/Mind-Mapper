class_name MobileAlignmentGuideLayer
extends Node2D

const EDGE_COLOR: Color = Color(0.42, 0.92, 0.55, 0.95)
const GAP_COLOR: Color = Color(0.95, 0.78, 0.30, 0.95)
const DIM_COLOR: Color = Color(0.62, 0.78, 1.0, 0.95)

var _board_view: Node = null
var _guides: Array = []


func _ready() -> void:
	z_index = 7


func bind_board_view(view: Node) -> void:
	_board_view = view


func set_guides(guides: Array) -> void:
	_guides = guides.duplicate()
	queue_redraw()


func clear() -> void:
	if _guides.is_empty():
		return
	_guides = []
	queue_redraw()


func _zoom() -> float:
	if _board_view == null or not _board_view.has_method("camera_node"):
		return 1.0
	var cam: MobileCameraController = _board_view.camera_node()
	if cam == null:
		return 1.0
	return cam.zoom.x


func _draw() -> void:
	if _guides.is_empty():
		return
	var zoom: float = _zoom()
	var width: float = 1.5 / max(zoom, 0.05)
	var span: float = 12000.0 / max(zoom, 0.05)
	for entry_v: Variant in _guides:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var type_id: String = String(entry.get("type", ""))
		var axis: String = String(entry.get("axis", ""))
		match type_id:
			"edge":
				var value: float = float(entry.get("value", 0.0))
				if axis == "x":
					draw_line(Vector2(value, -span), Vector2(value, span), EDGE_COLOR, width, true)
				else:
					draw_line(Vector2(-span, value), Vector2(span, value), EDGE_COLOR, width, true)
			"gap":
				var from_v: float = float(entry.get("from", 0.0))
				var to_v: float = float(entry.get("to", 0.0))
				var perp: float = float(entry.get("perp", 0.0))
				if axis == "x":
					draw_line(Vector2(from_v, perp), Vector2(to_v, perp), GAP_COLOR, width, true)
				else:
					draw_line(Vector2(perp, from_v), Vector2(perp, to_v), GAP_COLOR, width, true)
			"dim":
				var source_raw: Variant = entry.get("source_rect", null)
				var active_raw: Variant = entry.get("active_rect", null)
				if source_raw is Rect2:
					_outline_rect(source_raw, DIM_COLOR, width)
				if active_raw is Rect2:
					_outline_rect(active_raw, DIM_COLOR, width)


func _outline_rect(rect: Rect2, color: Color, width: float) -> void:
	draw_rect(rect, color, false, width)
