class_name MobileCameraController
extends Camera2D

signal user_tapped_world(world_pos: Vector2)
signal user_long_pressed_world(world_pos: Vector2)
signal user_double_tapped_world(world_pos: Vector2)

const MIN_ZOOM: float = 0.05
const MAX_ZOOM: float = 8.0
const WHEEL_ZOOM_STEP: float = 1.12
const TAP_MAX_DISPLACEMENT_PX: float = 24.0
const TAP_MAX_DURATION_MSEC: int = 350
const LONG_PRESS_DURATION_MSEC: int = 480
const SINGLE_DRAG_THRESHOLD_PX: float = 6.0
const DOUBLE_TAP_MAX_GAP_MSEC: int = 450
const DOUBLE_TAP_MAX_DISTANCE_PX: float = 48.0

var _enabled: bool = true
var _touch_points: Dictionary = {}
var _press_start_msec: int = 0
var _press_start_screen: Vector2 = Vector2.ZERO
var _press_moved: bool = false
var _two_finger_initial_distance: float = 0.0
var _two_finger_initial_zoom: float = 1.0
var _two_finger_initial_midpoint_screen: Vector2 = Vector2.ZERO
var _two_finger_initial_camera_pos: Vector2 = Vector2.ZERO
var _long_press_timer: Timer = null
var _long_press_fired: bool = false
var _pan_active_mouse: bool = false
var _pan_allowed_current: bool = true
var pan_should_be_allowed: Callable = Callable()
var single_touch_pan_enabled: bool = true
var _last_tap_msec: int = -1
var _last_tap_screen: Vector2 = Vector2.ZERO


func _ready() -> void:
	_long_press_timer = Timer.new()
	_long_press_timer.one_shot = true
	_long_press_timer.wait_time = float(LONG_PRESS_DURATION_MSEC) / 1000.0
	_long_press_timer.timeout.connect(_on_long_press_timeout)
	add_child(_long_press_timer)
	make_current()


func _set_enabled(enabled: bool) -> void:
	_enabled = enabled


func screen_to_world(screen_pos: Vector2) -> Vector2:
	var origin: Vector2 = _screen_origin()
	var size_v: Vector2 = _screen_size()
	return position + (screen_pos - origin - size_v * 0.5) / zoom


func _screen_origin() -> Vector2:
	var owner_control: Control = owner as Control
	if owner_control != null:
		return owner_control.get_global_rect().position
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_visible_rect().position


func _screen_size() -> Vector2:
	var owner_control: Control = owner as Control
	if owner_control != null:
		return owner_control.get_global_rect().size
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_visible_rect().size


func zoom_to_fit_rect(world_rect: Rect2, viewport_padding_px: float = 80.0) -> void:
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var size_vp: Vector2 = viewport.get_visible_rect().size
	var usable: Vector2 = size_vp - Vector2(viewport_padding_px * 2.0, viewport_padding_px * 2.0)
	if usable.x <= 0.0 or usable.y <= 0.0:
		return
	var zoom_target: float = min(usable.x / world_rect.size.x, usable.y / world_rect.size.y)
	zoom_target = clamp(zoom_target, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(zoom_target, zoom_target)
	position = world_rect.position + world_rect.size * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
		return
	if event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)
		return
	if event is InputEventMagnifyGesture:
		_handle_magnify(event as InputEventMagnifyGesture)
		return
	if event is InputEventPanGesture:
		_handle_pan_gesture(event as InputEventPanGesture)
		return
	if event is InputEventMouseButton:
		if Input.is_emulating_touch_from_mouse():
			return
		_handle_mouse_button(event as InputEventMouseButton)
		return
	if event is InputEventMouseMotion:
		if Input.is_emulating_touch_from_mouse():
			return
		_handle_mouse_motion(event as InputEventMouseMotion)
		return


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_points[event.index] = event.position
		_press_moved = false
		if _touch_points.size() == 1:
			_press_start_msec = Time.get_ticks_msec()
			_press_start_screen = event.position
			_long_press_fired = false
			_pan_allowed_current = _evaluate_pan_allowed(event.position)
			_long_press_timer.start()
		elif _touch_points.size() == 2:
			_long_press_timer.stop()
			_pan_allowed_current = true
			_setup_pinch()
		return
	var was_pinch: bool = _touch_points.size() == 2
	_touch_points.erase(event.index)
	if was_pinch and _touch_points.size() < 2:
		_two_finger_initial_distance = 0.0
		_long_press_timer.stop()
	if _touch_points.is_empty() and not _press_moved and not _long_press_fired:
		var duration_msec: int = Time.get_ticks_msec() - _press_start_msec
		if duration_msec <= TAP_MAX_DURATION_MSEC:
			_emit_tap(_press_start_screen)
	_long_press_timer.stop()


func _handle_drag(event: InputEventScreenDrag) -> void:
	var previous_position: Vector2 = _touch_points.get(event.index, event.position - event.relative)
	if not _touch_points.has(event.index):
		_touch_points[event.index] = event.position
	_touch_points[event.index] = event.position
	if _touch_points.size() == 1:
		var total_disp: Vector2 = event.position - _press_start_screen
		if total_disp.length() > TAP_MAX_DISPLACEMENT_PX:
			_press_moved = true
			_long_press_timer.stop()
		if single_touch_pan_enabled and _pan_allowed_current:
			_pan_between_screen_positions(previous_position, event.position)
		return
	if _touch_points.size() == 2:
		_long_press_timer.stop()
		_apply_pinch()


func _setup_pinch() -> void:
	var positions: Array = _touch_points.values()
	if positions.size() < 2:
		return
	var a: Vector2 = positions[0]
	var b: Vector2 = positions[1]
	_two_finger_initial_distance = a.distance_to(b)
	if _two_finger_initial_distance <= 0.001:
		_two_finger_initial_distance = 0.001
	_two_finger_initial_zoom = zoom.x
	_two_finger_initial_midpoint_screen = (a + b) * 0.5
	_two_finger_initial_camera_pos = position


func _apply_pinch() -> void:
	var positions: Array = _touch_points.values()
	if positions.size() < 2:
		return
	var a: Vector2 = positions[0]
	var b: Vector2 = positions[1]
	var current_distance: float = a.distance_to(b)
	if current_distance <= 0.001:
		return
	var factor: float = current_distance / max(_two_finger_initial_distance, 0.001)
	var target_zoom: float = clamp(_two_finger_initial_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	var anchor_screen: Vector2 = (a + b) * 0.5
	var world_under_anchor_before: Vector2 = screen_to_world(anchor_screen)
	zoom = Vector2(target_zoom, target_zoom)
	var world_under_anchor_after: Vector2 = screen_to_world(anchor_screen)
	position += world_under_anchor_before - world_under_anchor_after


func _on_long_press_timeout() -> void:
	if _press_moved:
		return
	if _touch_points.size() != 1:
		return
	_long_press_fired = true
	user_long_pressed_world.emit(screen_to_world(_press_start_screen))


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_at_screen(event.position, WHEEL_ZOOM_STEP)
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_at_screen(event.position, 1.0 / WHEEL_ZOOM_STEP)
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_start_screen = event.position
			_press_start_msec = Time.get_ticks_msec()
			_press_moved = false
			_pan_active_mouse = true
			_pan_allowed_current = _evaluate_pan_allowed(event.position)
		else:
			_pan_active_mouse = false
			if not _press_moved and Time.get_ticks_msec() - _press_start_msec < TAP_MAX_DURATION_MSEC:
				_emit_tap(_press_start_screen)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _pan_active_mouse:
		return
	var displacement: Vector2 = event.position - _press_start_screen
	if displacement.length() > SINGLE_DRAG_THRESHOLD_PX:
		_press_moved = true
		if single_touch_pan_enabled and _pan_allowed_current:
			_pan_between_screen_positions(event.position - event.relative, event.position)


func _evaluate_pan_allowed(screen_pos: Vector2) -> bool:
	if not pan_should_be_allowed.is_valid():
		return true
	var result: Variant = pan_should_be_allowed.call(screen_pos)
	if typeof(result) == TYPE_BOOL:
		return bool(result)
	return true


func _pan_between_screen_positions(previous_screen: Vector2, current_screen: Vector2) -> void:
	var previous_world: Vector2 = screen_to_world(previous_screen)
	var current_world: Vector2 = screen_to_world(current_screen)
	position += previous_world - current_world


func _emit_tap(screen_pos: Vector2) -> void:
	var now_msec: int = Time.get_ticks_msec()
	var is_double: bool = false
	if _last_tap_msec >= 0:
		var gap: int = now_msec - _last_tap_msec
		if gap <= DOUBLE_TAP_MAX_GAP_MSEC and screen_pos.distance_to(_last_tap_screen) <= DOUBLE_TAP_MAX_DISTANCE_PX:
			is_double = true
	if is_double:
		_last_tap_msec = -1
		user_double_tapped_world.emit(screen_to_world(screen_pos))
		return
	_last_tap_msec = now_msec
	_last_tap_screen = screen_pos
	user_tapped_world.emit(screen_to_world(screen_pos))


func _handle_magnify(event: InputEventMagnifyGesture) -> void:
	if event.factor <= 0.0:
		return
	_zoom_at_screen(event.position, event.factor)


func _handle_pan_gesture(event: InputEventPanGesture) -> void:
	position += event.delta / zoom


func zoom_in() -> void:
	_zoom_at_viewport_center(WHEEL_ZOOM_STEP)


func zoom_out() -> void:
	_zoom_at_viewport_center(1.0 / WHEEL_ZOOM_STEP)


func _zoom_at_viewport_center(factor: float) -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	_zoom_at_screen(viewport.get_visible_rect().size * 0.5, factor)


func _zoom_at_screen(screen_pos: Vector2, factor: float) -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var world_before: Vector2 = screen_to_world(screen_pos)
	var new_zoom: float = clamp(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(new_zoom, new_zoom)
	var world_after: Vector2 = screen_to_world(screen_pos)
	position += world_before - world_after
