class_name MobileViewModeToggle
extends PanelContainer

signal toggle_requested()

const TEXT_ENABLE_EDIT: String = "Enable Edit"
const TEXT_ENABLE_VIEW: String = "Enable View"

@onready var _toggle_button: Button = %ViewModeToggleButton

var _is_edit_active: bool = false


func _ready() -> void:
	_toggle_button.pressed.connect(_on_button_pressed)
	_refresh_label()


func set_edit_active(active: bool) -> void:
	if _is_edit_active == active:
		return
	_is_edit_active = active
	_refresh_label()


func is_edit_active() -> bool:
	return _is_edit_active


func _on_button_pressed() -> void:
	toggle_requested.emit()


func _refresh_label() -> void:
	if _toggle_button == null:
		return
	_toggle_button.text = TEXT_ENABLE_VIEW if _is_edit_active else TEXT_ENABLE_EDIT
