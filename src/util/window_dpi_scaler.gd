class_name WindowDpiScaler
extends Node

const BASE_DPI: float = 96.0
const META_MARKER: String = "_dpi_scaler_attached"

@export var track_dpi: bool = true
@export var minimum_scale: float = 0.5
@export var maximum_scale: float = 6.0
@export var poll_interval: float = 0.25

var _window: Window = null
var _last_screen: int = -1
var _last_dpi: int = -1
var _last_zoom: float = -1.0
var _accumulator: float = 0.0


static func attach(target: Window, with_dpi_tracking: bool = true) -> WindowDpiScaler:
	if target == null:
		return null
	if target.has_meta(META_MARKER):
		var existing: Variant = target.get_meta(META_MARKER)
		if existing is WindowDpiScaler and is_instance_valid(existing):
			var current: WindowDpiScaler = existing as WindowDpiScaler
			if current.track_dpi != with_dpi_tracking:
				current.track_dpi = with_dpi_tracking
				current.refresh()
			return current
	var scaler: WindowDpiScaler = WindowDpiScaler.new()
	scaler.name = "WindowDpiScaler"
	scaler.track_dpi = with_dpi_tracking
	target.set_meta(META_MARKER, scaler)
	target.add_child(scaler)
	return scaler


func _ready() -> void:
	_window = get_parent() as Window
	if _window == null:
		push_warning("WindowDpiScaler must be a child of a Window")
		set_process(false)
		return
	if UserPrefs != null and not UserPrefs.ui_zoom_changed.is_connected(_on_ui_zoom_changed):
		UserPrefs.ui_zoom_changed.connect(_on_ui_zoom_changed)
	_apply_scale(true)


func _exit_tree() -> void:
	if UserPrefs != null and UserPrefs.ui_zoom_changed.is_connected(_on_ui_zoom_changed):
		UserPrefs.ui_zoom_changed.disconnect(_on_ui_zoom_changed)


func _process(delta: float) -> void:
	if _window == null:
		return
	if not track_dpi:
		set_process(false)
		return
	_accumulator += delta
	if _accumulator < poll_interval:
		return
	_accumulator = 0.0
	_apply_scale(false)


func refresh() -> void:
	_apply_scale(true)
	set_process(track_dpi)


func _on_ui_zoom_changed(_value: float) -> void:
	_apply_scale(true)


func _apply_scale(force: bool) -> void:
	if _window == null:
		return
	var manual_zoom: float = _current_manual_zoom()
	var dpi_scale: float = 1.0
	var screen_index: int = -1
	var dpi: int = int(BASE_DPI)
	if track_dpi:
		screen_index = _resolve_screen_index()
		if screen_index < 0:
			return
		dpi = DisplayServer.screen_get_dpi(screen_index)
		if dpi <= 0:
			dpi = int(BASE_DPI)
		dpi_scale = float(dpi) / BASE_DPI
	if not force and screen_index == _last_screen and dpi == _last_dpi and is_equal_approx(manual_zoom, _last_zoom):
		return
	_last_screen = screen_index
	_last_dpi = dpi
	_last_zoom = manual_zoom
	var combined: float = dpi_scale * manual_zoom
	combined = clampf(combined, minimum_scale, maximum_scale)
	if not is_equal_approx(_window.content_scale_factor, combined):
		_window.content_scale_factor = combined


func _current_manual_zoom() -> float:
	if UserPrefs == null:
		return 1.0
	var z: float = UserPrefs.ui_zoom
	if z <= 0.0:
		return 1.0
	return z


func _resolve_screen_index() -> int:
	if _window == null:
		return -1
	var screen_count: int = DisplayServer.get_screen_count()
	if screen_count <= 0:
		return -1
	var idx: int = _window.current_screen
	if idx < 0 or idx >= screen_count:
		idx = DisplayServer.window_get_current_screen(_window.get_window_id())
	if idx < 0 or idx >= screen_count:
		idx = DisplayServer.get_primary_screen()
	if idx < 0 or idx >= screen_count:
		idx = 0
	return idx
