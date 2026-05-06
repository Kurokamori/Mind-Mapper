class_name Marquee
extends Control

const FILL: Color = Color(0.35, 0.7, 1.0, 0.15)
const BORDER: Color = Color(0.35, 0.7, 1.0, 0.9)

var active: bool = false
var _start_local: Vector2 = Vector2.ZERO
var _end_local: Vector2 = Vector2.ZERO
var _camera: EditorCameraController = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func bind_camera(camera: EditorCameraController) -> void:
	_camera = camera


func begin_drag() -> void:
	active = true
	_start_local = get_local_mouse_position()
	_end_local = _start_local
	queue_redraw()


func update_drag() -> void:
	if not active:
		return
	_end_local = get_local_mouse_position()
	queue_redraw()


func finish() -> Rect2:
	active = false
	queue_redraw()
	return world_rect()


func world_rect() -> Rect2:
	if _camera == null:
		return _rect_from(_start_local, _end_local)
	var a: Vector2 = _camera.screen_to_world(_start_local)
	var b: Vector2 = _camera.screen_to_world(_end_local)
	return _rect_from(a, b)


func _rect_from(a: Vector2, b: Vector2) -> Rect2:
	var x_min: float = min(a.x, b.x)
	var y_min: float = min(a.y, b.y)
	var x_max: float = max(a.x, b.x)
	var y_max: float = max(a.y, b.y)
	return Rect2(Vector2(x_min, y_min), Vector2(x_max - x_min, y_max - y_min))


func _draw() -> void:
	if not active:
		return
	var r: Rect2 = _rect_from(_start_local, _end_local)
	draw_rect(r, FILL, true)
	draw_rect(r, BORDER, false, 1.0)
