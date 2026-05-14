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
	if _window is Popup and not (_window as Popup).about_to_popup.is_connected(_on_about_to_popup):
		(_window as Popup).about_to_popup.connect(_on_about_to_popup)
	if _is_subwindow():
		var tree: SceneTree = get_tree()
		if tree != null and tree.root != null and not tree.root.size_changed.is_connected(_on_root_size_changed):
			tree.root.size_changed.connect(_on_root_size_changed)
	_apply_scale(true)


func _exit_tree() -> void:
	if UserPrefs != null and UserPrefs.ui_zoom_changed.is_connected(_on_ui_zoom_changed):
		UserPrefs.ui_zoom_changed.disconnect(_on_ui_zoom_changed)
	if _window is Popup and (_window as Popup).about_to_popup.is_connected(_on_about_to_popup):
		(_window as Popup).about_to_popup.disconnect(_on_about_to_popup)
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null and tree.root.size_changed.is_connected(_on_root_size_changed):
		tree.root.size_changed.disconnect(_on_root_size_changed)


func _on_root_size_changed() -> void:
	if _is_subwindow():
		_apply_scale(true)


func _process(delta: float) -> void:
	if _window == null:
		return
	if not track_dpi:
		set_process(false)
		return
	if _is_subwindow():
		set_process(false)
		return
	_accumulator += delta
	if _accumulator < poll_interval:
		return
	_accumulator = 0.0
	_apply_scale(false)


func refresh() -> void:
	_apply_scale(true)
	set_process(track_dpi and not _is_subwindow())


func _on_ui_zoom_changed(_value: float) -> void:
	_apply_scale(true)


func _on_about_to_popup() -> void:
	_apply_scale(true)


func _is_subwindow() -> bool:
	if _window == null:
		return false
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	return _window != tree.root


func _root_scale_factor() -> float:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return 1.0
	var root: Window = tree.root
	var factor: float = root.content_scale_factor
	if factor <= 0.0:
		factor = 1.0
	var stretch: float = _root_stretch_scale(root)
	return factor * stretch


func _root_stretch_scale(root: Window) -> float:
	if root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED:
		return 1.0
	var base: Vector2i = root.content_scale_size
	if base.x <= 0 or base.y <= 0:
		base = Vector2i(
			int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)),
			int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
		)
	if base.x <= 0 or base.y <= 0:
		return 1.0
	var win_size: Vector2i = root.size
	if win_size.x <= 0 or win_size.y <= 0:
		return 1.0
	var sx: float = float(win_size.x) / float(base.x)
	var sy: float = float(win_size.y) / float(base.y)
	match root.content_scale_aspect:
		Window.CONTENT_SCALE_ASPECT_IGNORE:
			return (sx + sy) * 0.5
		Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH:
			return sx
		Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT:
			return sy
		_:
			return min(sx, sy)


func _apply_scale(force: bool) -> void:
	if _window == null:
		return
	if _is_subwindow():
		var inherited: float = _root_scale_factor()
		inherited = clampf(inherited, minimum_scale, maximum_scale)
		if not is_equal_approx(_window.content_scale_factor, inherited):
			_window.content_scale_factor = inherited
		_last_zoom = inherited
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
