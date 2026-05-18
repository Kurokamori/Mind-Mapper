class_name MobileToastLayer
extends Control

const TOAST_LIFETIME_SEC: float = 3.4
const TOAST_FADE_SEC: float = 0.45
const TOAST_MARGIN_PX: float = 16.0
const TOAST_SPACING_PX: float = 8.0
const TOAST_MAX_WIDTH_PX: float = 520.0
const TOAST_MIN_WIDTH_PX: float = 180.0
const TOAST_CONTENT_MARGIN_PX: float = 12.0

const COLOR_INFO_BG: Color = Color(0.10, 0.18, 0.30, 0.94)
const COLOR_INFO_FG: Color = Color(0.96, 0.97, 1.00, 1.00)
const COLOR_WARNING_BG: Color = Color(0.32, 0.22, 0.06, 0.94)
const COLOR_WARNING_FG: Color = Color(1.00, 0.95, 0.82, 1.00)
const COLOR_ERROR_BG: Color = Color(0.36, 0.10, 0.10, 0.94)
const COLOR_ERROR_FG: Color = Color(1.00, 0.92, 0.92, 1.00)
const COLOR_SUCCESS_BG: Color = Color(0.06, 0.30, 0.18, 0.94)
const COLOR_SUCCESS_FG: Color = Color(0.92, 1.00, 0.94, 1.00)

const STICKY_GROUP_PREFIX: String = "mobile_toast_sticky_"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func toast(severity: String, message: String) -> void:
	var entry: PanelContainer = _build_panel(severity, message)
	add_child(entry)
	_position_entry(entry)
	var tween: Tween = create_tween()
	tween.tween_property(entry, "modulate:a", 1.0, 0.18).from(0.0)
	tween.tween_interval(TOAST_LIFETIME_SEC)
	tween.tween_property(entry, "modulate:a", 0.0, TOAST_FADE_SEC)
	tween.tween_callback(entry.queue_free)


func show_sticky(id: String, severity: String, message: String) -> void:
	dismiss_sticky(id)
	var entry: PanelContainer = _build_panel(severity, message)
	entry.add_to_group(STICKY_GROUP_PREFIX + id)
	add_child(entry)
	_position_entry(entry)
	var tween: Tween = create_tween()
	tween.tween_property(entry, "modulate:a", 1.0, 0.18).from(0.0)


func dismiss_sticky(id: String) -> void:
	var group_name: String = STICKY_GROUP_PREFIX + id
	for node: Node in get_tree().get_nodes_in_group(group_name):
		if node is PanelContainer and node.get_parent() == self:
			(node as PanelContainer).queue_free()


func _position_entry(entry: PanelContainer) -> void:
	var target_width: float = min(TOAST_MAX_WIDTH_PX, max(TOAST_MIN_WIDTH_PX, size.x - TOAST_MARGIN_PX * 2.0))
	var label: Label = entry.get_child(0) as Label
	var wrap_width: float = max(1.0, target_width - TOAST_CONTENT_MARGIN_PX * 2.0)
	var font: Font = label.get_theme_default_font()
	var font_size: int = label.get_theme_default_font_size()
	var text_size: Vector2 = font.get_multiline_string_size(
		label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		wrap_width,
		font_size
	)
	var panel_height: float = ceil(text_size.y) + TOAST_CONTENT_MARGIN_PX * 2.0
	label.custom_minimum_size = Vector2(wrap_width, ceil(text_size.y))
	entry.custom_minimum_size = Vector2(target_width, panel_height)
	entry.size = Vector2(target_width, panel_height)
	entry.position = Vector2(TOAST_MARGIN_PX, _next_top(entry))


func _next_top(skip: PanelContainer) -> float:
	var y: float = TOAST_MARGIN_PX
	for child: Node in get_children():
		if child == skip:
			continue
		if child is PanelContainer:
			y += (child as PanelContainer).size.y + TOAST_SPACING_PX
	return y


func _build_panel(severity: String, message: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var styles: Array = _styles_for(severity)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = styles[0]
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12.0)
	panel.add_theme_stylebox_override("panel", sb)
	var label: Label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", styles[1])
	panel.add_child(label)
	panel.modulate.a = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _styles_for(severity: String) -> Array:
	match severity:
		"warning":
			return [COLOR_WARNING_BG, COLOR_WARNING_FG]
		"error":
			return [COLOR_ERROR_BG, COLOR_ERROR_FG]
		"success":
			return [COLOR_SUCCESS_BG, COLOR_SUCCESS_FG]
		_:
			return [COLOR_INFO_BG, COLOR_INFO_FG]
