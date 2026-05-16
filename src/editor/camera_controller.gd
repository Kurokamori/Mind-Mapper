class_name EditorCameraController
extends Camera2D

const MIN_ZOOM: float = 0.01
const MAX_ZOOM: float = 10.0
const ZOOM_STEP: float = 1.1
const PINCH_MIN_FACTOR: float = 0.001

var _panning: bool = false
var _touch_points: Dictionary = {}
var _two_finger_initial_distance: float = 0.0
var _two_finger_initial_zoom: float = 1.0


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
	elif event is InputEventMagnifyGesture:
		var mag: InputEventMagnifyGesture = event as InputEventMagnifyGesture
		if mag.factor > PINCH_MIN_FACTOR:
			zoom_at_screen(mag.position, mag.factor)
			get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		var pan: InputEventPanGesture = event as InputEventPanGesture
		position += pan.delta / zoom
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_points[event.index] = event.position
		if _touch_points.size() == 2:
			_setup_two_finger()
		return
	_touch_points.erase(event.index)
	if _touch_points.size() < 2:
		_two_finger_initial_distance = 0.0


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_touch_points[event.index] = event.position
	if _touch_points.size() != 2:
		return
	_apply_two_finger()
	get_viewport().set_input_as_handled()


func _setup_two_finger() -> void:
	var positions: Array = _touch_points.values()
	if positions.size() < 2:
		return
	var a: Vector2 = positions[0]
	var b: Vector2 = positions[1]
	_two_finger_initial_distance = max(a.distance_to(b), 0.001)
	_two_finger_initial_zoom = zoom.x


func _apply_two_finger() -> void:
	var positions: Array = _touch_points.values()
	if positions.size() < 2:
		return
	var a: Vector2 = positions[0]
	var b: Vector2 = positions[1]
	var distance: float = max(a.distance_to(b), 0.001)
	var factor: float = distance / max(_two_finger_initial_distance, 0.001)
	var target_zoom: float = clamp(_two_finger_initial_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var size_vp: Vector2 = viewport.get_visible_rect().size
	var anchor_screen: Vector2 = (a + b) * 0.5
	var world_before: Vector2 = position + (anchor_screen - size_vp * 0.5) / zoom
	zoom = Vector2(target_zoom, target_zoom)
	var world_after: Vector2 = position + (anchor_screen - size_vp * 0.5) / zoom
	position += world_before - world_after


func zoom_in() -> void:
	_zoom_at_viewport_center(ZOOM_STEP)


func zoom_out() -> void:
	_zoom_at_viewport_center(1.0 / ZOOM_STEP)


func _zoom_at_viewport_center(factor: float) -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	zoom_at_screen(viewport.get_visible_rect().size * 0.5, factor)


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
