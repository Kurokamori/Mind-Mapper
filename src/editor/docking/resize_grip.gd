class_name ResizeGrip
extends Control

const DIR_NONE: int = 0
const DIR_TOP: int = 1
const DIR_BOTTOM: int = 2
const DIR_LEFT: int = 4
const DIR_RIGHT: int = 8

signal grip_drag_started(directions: int)
signal grip_drag_moved(directions: int, global_delta: Vector2)
signal grip_drag_ended(directions: int)

@export_flags("Top:1", "Bottom:2", "Left:4", "Right:8") var directions: int = 0

var _dragging: bool = false
var _last_mouse: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_cursor()
	gui_input.connect(_on_gui_input)


func _apply_cursor() -> void:
	var has_h: bool = (directions & (DIR_LEFT | DIR_RIGHT)) != 0
	var has_v: bool = (directions & (DIR_TOP | DIR_BOTTOM)) != 0
	if has_h and has_v:
		var diag_pos: bool = (directions & DIR_LEFT) != 0 and (directions & DIR_BOTTOM) != 0
		var diag_pos2: bool = (directions & DIR_RIGHT) != 0 and (directions & DIR_TOP) != 0
		if diag_pos or diag_pos2:
			mouse_default_cursor_shape = Control.CURSOR_BDIAGSIZE
		else:
			mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	elif has_h:
		mouse_default_cursor_shape = Control.CURSOR_HSIZE
	elif has_v:
		mouse_default_cursor_shape = Control.CURSOR_VSIZE
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_dragging = true
			_last_mouse = mb.global_position
			emit_signal("grip_drag_started", directions)
			accept_event()
		else:
			if _dragging:
				_dragging = false
				emit_signal("grip_drag_ended", directions)
				accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		var delta: Vector2 = mm.global_position - _last_mouse
		_last_mouse = mm.global_position
		if delta != Vector2.ZERO:
			emit_signal("grip_drag_moved", directions, delta)
		accept_event()
