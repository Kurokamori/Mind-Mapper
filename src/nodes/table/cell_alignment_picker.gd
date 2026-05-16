class_name CellAlignmentPicker
extends Control

signal alignment_changed(h_align: int, v_align: int, is_inherit: bool)

const TILE_SIZE: float = 22.0
const TILE_GAP: float = 2.0
const INHERIT_HEIGHT: float = 18.0
const INHERIT_GAP: float = 4.0
const TEXT_BAR_LENGTH: float = 10.0
const TEXT_BAR_THICKNESS: float = 2.0
const TILE_INNER_PADDING: float = 4.0
const TILE_BORDER_ALPHA: float = 0.32
const TILE_CORNER_RADIUS: int = 3

var allow_inherit: bool = false: set = _set_allow_inherit
var _h_align: int = 0
var _v_align: int = 1
var _is_inherit: bool = false
var _hover_tile: Vector2i = Vector2i(-1, -1)
var _hover_inherit: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_recompute_min_size()
	queue_redraw()


func set_alignment(h_align: int, v_align: int, is_inherit_value: bool = false) -> void:
	_h_align = clamp(h_align, 0, 2)
	_v_align = clamp(v_align, 0, 2)
	_is_inherit = is_inherit_value and allow_inherit
	queue_redraw()


func current_h() -> int:
	return _h_align


func current_v() -> int:
	return _v_align


func current_is_inherit() -> bool:
	return _is_inherit


func _set_allow_inherit(value: bool) -> void:
	if allow_inherit == value:
		return
	allow_inherit = value
	if not allow_inherit:
		_is_inherit = false
	_recompute_min_size()
	queue_redraw()


func _recompute_min_size() -> void:
	var w: float = TILE_SIZE * 3.0 + TILE_GAP * 2.0
	var h: float = TILE_SIZE * 3.0 + TILE_GAP * 2.0
	if allow_inherit:
		h += INHERIT_GAP + INHERIT_HEIGHT
	custom_minimum_size = Vector2(w, h)


func _tile_rect(h_idx: int, v_idx: int) -> Rect2:
	var x: float = h_idx * (TILE_SIZE + TILE_GAP)
	var y: float = v_idx * (TILE_SIZE + TILE_GAP)
	return Rect2(Vector2(x, y), Vector2(TILE_SIZE, TILE_SIZE))


func _inherit_rect() -> Rect2:
	var grid_w: float = TILE_SIZE * 3.0 + TILE_GAP * 2.0
	var grid_h: float = TILE_SIZE * 3.0 + TILE_GAP * 2.0
	var y: float = grid_h + INHERIT_GAP
	return Rect2(Vector2(0, y), Vector2(grid_w, INHERIT_HEIGHT))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		_update_hover(motion.position)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(mb.position)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		if _hover_tile != Vector2i(-1, -1) or _hover_inherit:
			_hover_tile = Vector2i(-1, -1)
			_hover_inherit = false
			queue_redraw()


func _update_hover(pos: Vector2) -> void:
	var prev_tile: Vector2i = _hover_tile
	var prev_inherit: bool = _hover_inherit
	_hover_tile = Vector2i(-1, -1)
	_hover_inherit = false
	for h_idx in range(3):
		for v_idx in range(3):
			if _tile_rect(h_idx, v_idx).has_point(pos):
				_hover_tile = Vector2i(h_idx, v_idx)
	if allow_inherit and _inherit_rect().has_point(pos):
		_hover_inherit = true
	if prev_tile != _hover_tile or prev_inherit != _hover_inherit:
		queue_redraw()


func _handle_click(pos: Vector2) -> void:
	for h_idx in range(3):
		for v_idx in range(3):
			if _tile_rect(h_idx, v_idx).has_point(pos):
				_h_align = h_idx
				_v_align = v_idx
				_is_inherit = false
				queue_redraw()
				emit_signal("alignment_changed", _h_align, _v_align, false)
				return
	if allow_inherit and _inherit_rect().has_point(pos):
		_is_inherit = true
		queue_redraw()
		emit_signal("alignment_changed", _h_align, _v_align, true)


func _resolve_fg() -> Color:
	if ThemeManager.has_method("node_fg_color"):
		return ThemeManager.node_fg_color()
	return Color(0.92, 0.94, 0.97, 1.0)


func _resolve_bg() -> Color:
	if ThemeManager.has_method("node_bg_color"):
		return ThemeManager.node_bg_color()
	return Color(0.13, 0.14, 0.17, 1.0)


func _resolve_accent() -> Color:
	if ThemeManager.has_method("heading_bg"):
		return ThemeManager.heading_bg("table")
	return Color(0.20, 0.30, 0.45, 1.0)


func _draw() -> void:
	var fg: Color = _resolve_fg()
	var bg: Color = _resolve_bg()
	var accent: Color = _resolve_accent()
	var base_tile_bg: Color = bg.lerp(fg, 0.10)
	var hover_tile_bg: Color = bg.lerp(fg, 0.22)
	var border_color: Color = fg
	border_color.a = TILE_BORDER_ALPHA
	for h_idx in range(3):
		for v_idx in range(3):
			var rect: Rect2 = _tile_rect(h_idx, v_idx)
			var is_active: bool = (not _is_inherit) and h_idx == _h_align and v_idx == _v_align
			var is_hovered: bool = _hover_tile == Vector2i(h_idx, v_idx)
			var tile_bg: Color = base_tile_bg
			if is_active:
				tile_bg = accent
			elif is_hovered:
				tile_bg = hover_tile_bg
			_draw_rounded_filled(rect, tile_bg, TILE_CORNER_RADIUS)
			_draw_rounded_outline(rect, border_color, 1.0, TILE_CORNER_RADIUS)
			var indicator_color: Color = fg
			if _is_inherit:
				indicator_color = Color(fg.r, fg.g, fg.b, 0.45)
			elif is_active:
				indicator_color = Color(1.0, 1.0, 1.0, 0.95)
			_draw_text_indicator(rect, h_idx, v_idx, indicator_color)
	if allow_inherit:
		var ir: Rect2 = _inherit_rect()
		var inherit_bg: Color = base_tile_bg
		if _is_inherit:
			inherit_bg = accent
		elif _hover_inherit:
			inherit_bg = hover_tile_bg
		_draw_rounded_filled(ir, inherit_bg, TILE_CORNER_RADIUS)
		_draw_rounded_outline(ir, border_color, 1.0, TILE_CORNER_RADIUS)
		var font: Font = get_theme_default_font()
		var font_size: int = get_theme_default_font_size()
		if font == null:
			return
		var label: String = "Inherit"
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var tx: float = ir.position.x + (ir.size.x - text_size.x) * 0.5
		var ty: float = ir.position.y + (ir.size.y + font.get_ascent(font_size)) * 0.5 - 2.0
		var text_color: Color = Color(1.0, 1.0, 1.0, 0.95) if _is_inherit else fg
		draw_string(font, Vector2(tx, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


func _draw_text_indicator(rect: Rect2, h_idx: int, v_idx: int, color: Color) -> void:
	var pad: float = TILE_INNER_PADDING
	var bar_w: float = TEXT_BAR_LENGTH
	var bar_h: float = TEXT_BAR_THICKNESS
	var bar_x: float = rect.position.x + pad
	match h_idx:
		1:
			bar_x = rect.position.x + (rect.size.x - bar_w) * 0.5
		2:
			bar_x = rect.position.x + rect.size.x - pad - bar_w
	var bar_y: float = rect.position.y + pad
	match v_idx:
		1:
			bar_y = rect.position.y + (rect.size.y - bar_h) * 0.5
		2:
			bar_y = rect.position.y + rect.size.y - pad - bar_h
	draw_rect(Rect2(Vector2(bar_x, bar_y), Vector2(bar_w, bar_h)), color, true)


func _draw_rounded_filled(rect: Rect2, color: Color, radius: int) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_width_left = 0
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 0
	draw_style_box(sb, rect)


func _draw_rounded_outline(rect: Rect2, color: Color, width: float, radius: int) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = color
	sb.set_border_width_all(int(width))
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, rect)
