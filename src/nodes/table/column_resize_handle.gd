class_name TableColumnResizeHandle
extends Control

signal drag_started(column: int)
signal drag_motion(column: int, delta_x: float)
signal drag_ended(column: int)

const HANDLE_WIDTH: float = 8.0

var column: int = -1
var _dragging: bool = false


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_HSIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(HANDLE_WIDTH, 0.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				emit_signal("drag_started", column)
				accept_event()
			else:
				if _dragging:
					_dragging = false
					emit_signal("drag_ended", column)
					accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion: InputEventMouseMotion = event
		emit_signal("drag_motion", column, motion.relative.x)
		accept_event()
