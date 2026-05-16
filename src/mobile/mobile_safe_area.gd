class_name MobileSafeArea
extends Control

## Renders panel-colored bands over the device "unsafe" areas (notches, punch-hole
## cameras, rounded corners, gesture/home indicators) and exposes the resulting
## insets so other UI can move out of them. Reads DisplayServer.get_display_safe_area()
## and get_display_cutouts(), translates the pixel rect to the viewport's logical
## coordinate space (the mobile app uses content_scale_factor), and applies sensible
## per-orientation minimums for desktop/emulator runs where the OS reports no insets.

signal insets_changed(top: float, right: float, bottom: float, left: float)

const PORTRAIT_MIN_TOP: float = 24.0
const PORTRAIT_MIN_BOTTOM: float = 16.0
const LANDSCAPE_MIN_SIDE: float = 12.0
const CUTOUT_PADDING: float = 4.0

@onready var _top_band: ColorRect = %TopBand
@onready var _bottom_band: ColorRect = %BottomBand
@onready var _left_band: ColorRect = %LeftBand
@onready var _right_band: ColorRect = %RightBand

var _insets: Rect2 = Rect2(0.0, 0.0, 0.0, 0.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.size_changed.connect(_refresh)
	if ThemeManager != null:
		ThemeManager.theme_applied.connect(_apply_band_color)
	_apply_band_color()
	call_deferred("_refresh")


func top_inset() -> float:
	return _insets.position.y


func left_inset() -> float:
	return _insets.position.x


func right_inset() -> float:
	return _insets.size.x


func bottom_inset() -> float:
	return _insets.size.y


func force_refresh() -> void:
	_refresh()


func _refresh() -> void:
	var insets: Rect2 = _compute_insets()
	_insets = insets
	_layout_bands(insets)
	emit_signal("insets_changed", insets.position.y, insets.size.x, insets.size.y, insets.position.x)


func _compute_insets() -> Rect2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Rect2(0.0, 0.0, 0.0, 0.0)
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2(0.0, 0.0, 0.0, 0.0)
	var window_size_i: Vector2i = DisplayServer.window_get_size()
	var window_size: Vector2 = Vector2(window_size_i)
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		window_size = viewport_size
	var scale: Vector2 = Vector2(viewport_size.x / window_size.x, viewport_size.y / window_size.y)
	var safe_px: Rect2i = DisplayServer.get_display_safe_area()
	var safe_top: float = 0.0
	var safe_left: float = 0.0
	var safe_right: float = 0.0
	var safe_bottom: float = 0.0
	if safe_px.size.x > 0 and safe_px.size.y > 0:
		safe_top = float(safe_px.position.y)
		safe_left = float(safe_px.position.x)
		safe_right = max(0.0, window_size.x - float(safe_px.position.x + safe_px.size.x))
		safe_bottom = max(0.0, window_size.y - float(safe_px.position.y + safe_px.size.y))
	var cutout_top: float = 0.0
	var cutout_left: float = 0.0
	var cutout_right: float = 0.0
	var cutout_bottom: float = 0.0
	var cutouts: Array[Rect2] = DisplayServer.get_display_cutouts()
	for cutout: Rect2 in cutouts:
		if cutout.size.x <= 0.0 or cutout.size.y <= 0.0:
			continue
		var top_edge: float = cutout.position.y
		var left_edge: float = cutout.position.x
		var right_edge: float = window_size.x - (cutout.position.x + cutout.size.x)
		var bottom_edge: float = window_size.y - (cutout.position.y + cutout.size.y)
		var nearest: float = min(min(top_edge, left_edge), min(right_edge, bottom_edge))
		if nearest == top_edge:
			cutout_top = max(cutout_top, cutout.position.y + cutout.size.y + CUTOUT_PADDING)
		elif nearest == bottom_edge:
			cutout_bottom = max(cutout_bottom, window_size.y - cutout.position.y + CUTOUT_PADDING)
		elif nearest == left_edge:
			cutout_left = max(cutout_left, cutout.position.x + cutout.size.x + CUTOUT_PADDING)
		else:
			cutout_right = max(cutout_right, window_size.x - cutout.position.x + CUTOUT_PADDING)
	var raw_top: float = max(safe_top, cutout_top) * scale.y
	var raw_left: float = max(safe_left, cutout_left) * scale.x
	var raw_right: float = max(safe_right, cutout_right) * scale.x
	var raw_bottom: float = max(safe_bottom, cutout_bottom) * scale.y
	var is_portrait: bool = viewport_size.y > viewport_size.x
	if is_portrait:
		raw_top = max(raw_top, PORTRAIT_MIN_TOP)
		raw_bottom = max(raw_bottom, PORTRAIT_MIN_BOTTOM)
	else:
		raw_left = max(raw_left, LANDSCAPE_MIN_SIDE)
		raw_right = max(raw_right, LANDSCAPE_MIN_SIDE)
	return Rect2(raw_left, raw_top, raw_right, raw_bottom)


func _layout_bands(insets: Rect2) -> void:
	var color: Color = _band_color()
	for band: ColorRect in [_top_band, _bottom_band, _left_band, _right_band]:
		if band != null:
			band.color = color
	if _top_band != null:
		_top_band.visible = insets.position.y > 0.0
		_top_band.offset_left = 0.0
		_top_band.offset_right = 0.0
		_top_band.offset_top = 0.0
		_top_band.offset_bottom = insets.position.y
	if _bottom_band != null:
		_bottom_band.visible = insets.size.y > 0.0
		_bottom_band.offset_left = 0.0
		_bottom_band.offset_right = 0.0
		_bottom_band.offset_top = -insets.size.y
		_bottom_band.offset_bottom = 0.0
	if _left_band != null:
		_left_band.visible = insets.position.x > 0.0
		_left_band.offset_left = 0.0
		_left_band.offset_right = insets.position.x
		_left_band.offset_top = insets.position.y
		_left_band.offset_bottom = -insets.size.y
	if _right_band != null:
		_right_band.visible = insets.size.x > 0.0
		_right_band.offset_left = -insets.size.x
		_right_band.offset_right = 0.0
		_right_band.offset_top = insets.position.y
		_right_band.offset_bottom = -insets.size.y


func _apply_band_color() -> void:
	_layout_bands(_insets)


func _band_color() -> Color:
	if ThemeManager != null:
		var panel: Color = ThemeManager.panel_color()
		return Color(panel.r, panel.g, panel.b, 1.0)
	return Color(0.11, 0.105, 0.135, 1.0)
