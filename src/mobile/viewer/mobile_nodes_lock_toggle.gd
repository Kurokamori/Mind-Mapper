class_name MobileNodesLockToggle
extends PanelContainer

signal toggle_requested()

const ICON_UNLOCKED: Texture2D = preload("res://assets/ui/icons/unlocked.png")
const ICON_LOCKED: Texture2D = preload("res://assets/ui/icons/locked.png")
const TEXT_LOCKED: String = "Nodes Locked"
const ICON_MAX_WIDTH: int = 24
const BUTTON_THEME_VARIATION: StringName = &"MobileButton"

@onready var _lock_button: Button = %NodesLockButton

var _is_locked: bool = false


func _ready() -> void:
	_lock_button.pressed.connect(_on_button_pressed)
	_lock_button.add_theme_constant_override("icon_max_width", ICON_MAX_WIDTH)
	_lock_button.add_theme_constant_override("h_separation", 8)
	_lock_button.expand_icon = false
	_refresh_appearance()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh_icon_modulate()


func set_locked(value: bool) -> void:
	if _is_locked == value:
		return
	_is_locked = value
	_refresh_appearance()


func is_locked() -> bool:
	return _is_locked


func _on_button_pressed() -> void:
	toggle_requested.emit()


func _refresh_appearance() -> void:
	if _lock_button == null:
		return
	if _is_locked:
		_lock_button.icon = ICON_LOCKED
		_lock_button.text = TEXT_LOCKED
		_lock_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_lock_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_lock_button.tooltip_text = "Unlock nodes for editing"
	else:
		_lock_button.icon = ICON_UNLOCKED
		_lock_button.text = ""
		_lock_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lock_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lock_button.tooltip_text = "Lock nodes (prevent moves & edits)"
	_refresh_icon_modulate()


func _refresh_icon_modulate() -> void:
	if _lock_button == null:
		return
	var theme_owner: Theme = _lock_button.get_theme()
	var color: Color = Color(1, 1, 1, 1)
	if _lock_button.has_theme_color("font_color", BUTTON_THEME_VARIATION):
		color = _lock_button.get_theme_color("font_color", BUTTON_THEME_VARIATION)
	elif theme_owner != null and theme_owner.has_color("font_color", "Button"):
		color = theme_owner.get_color("font_color", "Button")
	_lock_button.add_theme_color_override("icon_normal_color", color)
	_lock_button.add_theme_color_override("icon_hover_color", color)
	_lock_button.add_theme_color_override("icon_pressed_color", color)
	_lock_button.add_theme_color_override("icon_focus_color", color)
