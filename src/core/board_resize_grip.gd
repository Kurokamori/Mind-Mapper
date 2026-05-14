class_name BoardResizeGrip
extends Control

signal grip_pressed
signal grip_motion(local_at_item: Vector2)
signal grip_released

const VISIBLE_SQUARE: float = 20.0
const FILL_COLOR: Color = Color(0.30, 0.65, 0.95, 1.0)
const DIAG_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)

var _pressed: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	focus_mode = Control.FOCUS_NONE
	set_process_input(false)


func _draw() -> void:
	var inset: float = max(0.0, size.x - VISIBLE_SQUARE)
	var inset_y: float = max(0.0, size.y - VISIBLE_SQUARE)
	var rect: Rect2 = Rect2(Vector2(inset, inset_y), Vector2(VISIBLE_SQUARE, VISIBLE_SQUARE))
	draw_rect(rect, FILL_COLOR, true)
	var line_from: Vector2 = Vector2(rect.position.x + rect.size.x - 3.0, rect.position.y + 3.0)
	var line_to: Vector2 = Vector2(rect.position.x + 3.0, rect.position.y + rect.size.y - 3.0)
	draw_line(line_from, line_to, DIAG_COLOR, 1.5)
	var line2_from: Vector2 = Vector2(rect.position.x + rect.size.x - 3.0, rect.position.y + 8.0)
	var line2_to: Vector2 = Vector2(rect.position.x + 8.0, rect.position.y + rect.size.y - 3.0)
	draw_line(line2_from, line2_to, DIAG_COLOR, 1.5)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed and not _pressed:
			_pressed = true
			set_process_input(true)
			emit_signal("grip_pressed")
			accept_event()


func _input(event: InputEvent) -> void:
	if not _pressed:
		return
	if event is InputEventMouseMotion:
		var parent_item: Control = get_parent() as Control
		if parent_item != null:
			emit_signal("grip_motion", parent_item.get_local_mouse_position())
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_pressed = false
			set_process_input(false)
			emit_signal("grip_released")


func is_active() -> bool:
	return _pressed


func cancel_press() -> void:
	if _pressed:
		_pressed = false
		set_process_input(false)
