class_name LoadingSpinner
extends Control

const ARC_THICKNESS: float = 4.0
const ARC_LENGTH_DEG: float = 110.0
const ROTATION_DEG_PER_SEC: float = 220.0
const ARC_SEGMENTS: int = 48
const TRACK_SEGMENTS: int = 72

var _angle_deg: float = 0.0
var _track_color: Color = Color(1.0, 1.0, 1.0, 0.18)
var _arc_color: Color = Color(1.0, 1.0, 1.0, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ThemeManager != null and not ThemeManager.theme_applied.is_connected(_refresh_colors):
		ThemeManager.theme_applied.connect(_refresh_colors)
	_refresh_colors()
	set_process(true)


func _exit_tree() -> void:
	if ThemeManager != null and ThemeManager.theme_applied.is_connected(_refresh_colors):
		ThemeManager.theme_applied.disconnect(_refresh_colors)


func _process(delta: float) -> void:
	_angle_deg = fmod(_angle_deg + ROTATION_DEG_PER_SEC * delta, 360.0)
	queue_redraw()


func _refresh_colors() -> void:
	if ThemeManager == null:
		queue_redraw()
		return
	var accent: Color = ThemeManager.accent_color()
	_arc_color = Color(accent.r, accent.g, accent.b, 1.0)
	var subtle: Color = ThemeManager.subtle_color()
	_track_color = Color(subtle.r, subtle.g, subtle.b, 0.30)
	queue_redraw()


func _draw() -> void:
	var view_size: Vector2 = size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return
	var center: Vector2 = view_size * 0.5
	var radius: float = (min(view_size.x, view_size.y) * 0.5) - ARC_THICKNESS
	if radius <= 0.0:
		return
	draw_arc(center, radius, 0.0, TAU, TRACK_SEGMENTS, _track_color, ARC_THICKNESS, true)
	var start_rad: float = deg_to_rad(_angle_deg)
	var end_rad: float = deg_to_rad(_angle_deg + ARC_LENGTH_DEG)
	draw_arc(center, radius, start_rad, end_rad, ARC_SEGMENTS, _arc_color, ARC_THICKNESS, true)
