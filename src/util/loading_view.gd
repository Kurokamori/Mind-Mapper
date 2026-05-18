class_name LoadingView
extends Control

const FADE_IN_SEC: float = 0.14
const FADE_OUT_SEC: float = 0.18
const PANEL_CORNER_RADIUS: int = 14
const PANEL_CONTENT_MARGIN: int = 28
const PANEL_BORDER_WIDTH: int = 1
const BACKDROP_ALPHA: float = 0.72

@onready var _backdrop: ColorRect = %LoadingBackdrop
@onready var _panel: PanelContainer = %LoadingPanel
@onready var _title_label: Label = %LoadingTitleLabel
@onready var _subtitle_label: Label = %LoadingSubtitleLabel
@onready var _spinner: LoadingSpinner = %LoadingSpinner

var _active: bool = false
var _fade_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0
	if ThemeManager != null and not ThemeManager.theme_applied.is_connected(_apply_theme):
		ThemeManager.theme_applied.connect(_apply_theme)
	_apply_theme()


func _exit_tree() -> void:
	if ThemeManager != null and ThemeManager.theme_applied.is_connected(_apply_theme):
		ThemeManager.theme_applied.disconnect(_apply_theme)


func show_loading(title: String, subtitle: String = "") -> void:
	_title_label.text = title
	set_subtitle(subtitle)
	_active = true
	visible = true
	_bring_to_top()
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SEC)


func set_title(text: String) -> void:
	if _title_label == null:
		return
	_title_label.text = text


func set_subtitle(text: String) -> void:
	if _subtitle_label == null:
		return
	_subtitle_label.text = text
	_subtitle_label.visible = text != ""


func hide_loading() -> void:
	if not _active:
		return
	_active = false
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SEC)
	_fade_tween.tween_callback(_finalize_hide)


func is_active() -> bool:
	return _active


func _finalize_hide() -> void:
	if _active:
		return
	visible = false


func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _bring_to_top() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	parent.move_child(self, parent.get_child_count() - 1)


func _apply_theme() -> void:
	if ThemeManager == null:
		return
	var bg: Color = ThemeManager.background_color()
	if _backdrop != null:
		_backdrop.color = Color(bg.r, bg.g, bg.b, BACKDROP_ALPHA)
	if _panel != null:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = ThemeManager.panel_color()
		sb.border_color = ThemeManager.subtle_color()
		sb.set_corner_radius_all(PANEL_CORNER_RADIUS)
		sb.set_content_margin_all(PANEL_CONTENT_MARGIN)
		sb.set_border_width_all(PANEL_BORDER_WIDTH)
		_panel.add_theme_stylebox_override("panel", sb)
	var fg: Color = ThemeManager.foreground_color()
	if _title_label != null:
		_title_label.add_theme_color_override("font_color", fg)
	if _subtitle_label != null:
		_subtitle_label.add_theme_color_override("font_color", ThemeManager.dim_foreground_color())
