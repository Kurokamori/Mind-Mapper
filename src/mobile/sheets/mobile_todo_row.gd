class_name MobileTodoRow
extends PanelContainer

signal completed_toggled(card_id: String, completed: bool)
signal text_committed(card_id: String, new_text: String)
signal delete_requested(card_id: String)
signal add_child_requested(card_id: String)

const INDENT_PX_PER_LEVEL: float = 16.0

@onready var _indent_spacer: Control = %IndentSpacer
@onready var _check_button: CheckBox = %CheckButton
@onready var _text_edit: LineEdit = %TextEdit
@onready var _priority_indicator: Label = %PriorityIndicator
@onready var _add_child_button: Button = %AddChildButton
@onready var _delete_button: Button = %DeleteButton

var _card_id: String = ""
var _suppress: bool = false


func _ready() -> void:
	_check_button.toggled.connect(_on_checked)
	_text_edit.text_submitted.connect(_on_text_submitted)
	_text_edit.focus_exited.connect(_on_text_focus_exited)
	_add_child_button.pressed.connect(func() -> void: add_child_requested.emit(_card_id))
	_delete_button.pressed.connect(func() -> void: delete_requested.emit(_card_id))


func bind(card_dict: Dictionary, indent_level: int) -> void:
	_card_id = String(card_dict.get("id", ""))
	_indent_spacer.custom_minimum_size = Vector2(indent_level * INDENT_PX_PER_LEVEL, 0)
	_suppress = true
	_check_button.button_pressed = bool(card_dict.get("completed", false))
	_text_edit.text = String(card_dict.get("text", ""))
	_apply_completed_visual(_check_button.button_pressed)
	_apply_priority(int(card_dict.get("priority", 0)))
	_suppress = false


func _apply_completed_visual(completed: bool) -> void:
	var color: Color = Color(0.55, 0.60, 0.65) if completed else Color(0.95, 0.96, 0.98)
	_text_edit.add_theme_color_override("font_color", color)


func _apply_priority(priority: int) -> void:
	match priority:
		3:
			_priority_indicator.text = "!!!"
			_priority_indicator.add_theme_color_override("font_color", Color(0.95, 0.30, 0.30))
		2:
			_priority_indicator.text = "!!"
			_priority_indicator.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
		1:
			_priority_indicator.text = "!"
			_priority_indicator.add_theme_color_override("font_color", Color(0.40, 0.78, 0.40))
		_:
			_priority_indicator.text = ""


func _on_checked(value: bool) -> void:
	if _suppress:
		return
	_apply_completed_visual(value)
	completed_toggled.emit(_card_id, value)


func _on_text_submitted(text: String) -> void:
	if _suppress:
		return
	text_committed.emit(_card_id, text)
	_text_edit.release_focus()


func _on_text_focus_exited() -> void:
	if _suppress:
		return
	text_committed.emit(_card_id, _text_edit.text)
