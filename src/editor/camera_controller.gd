class_name EditorCameraController
extends Camera2D

const MIN_ZOOM: float = 0.1
const MAX_ZOOM: float = 6.0
const ZOOM_STEP: float = 1.1

var _panning: bool = false


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		var pan_button: bool = mb.button_index == MOUSE_BUTTON_MIDDLE \
			or (mb.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SPACE))
		if pan_button:
			_panning = mb.pressed
			get_viewport().set_input_as_handled()
			return
		if not mb.pressed and _panning and mb.button_index == MOUSE_BUTTON_LEFT:
			_panning = false
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseMotion and _panning:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		position -= motion.relative / zoom
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_panning = false


func zoom_at_screen(screen_pos: Vector2, factor: float) -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var size_vp: Vector2 = viewport.get_visible_rect().size
	var before_world: Vector2 = position + (screen_pos - size_vp * 0.5) / zoom
	var new_z: float = clamp(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(new_z, new_z)
	var after_world: Vector2 = position + (screen_pos - size_vp * 0.5) / zoom
	position += before_world - after_world


func screen_to_world(screen_pos: Vector2) -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return screen_pos
	var size_vp: Vector2 = viewport.get_visible_rect().size
	return position + (screen_pos - size_vp * 0.5) / zoom
