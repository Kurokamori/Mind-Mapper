class_name PlainTextOutlineDialog
extends Window

signal applied(text: String)

const DEFAULT_HINT: String = "One entry per line. Start lines with '-' for top level, '--' for one indent, '---' for two indents, and so on."

@onready var _heading_label: Label = %HeadingLabel
@onready var _hint_label: Label = %HintLabel
@onready var _text_edit: TextEdit = %TextEdit
@onready var _ok_button: Button = %OkButton
@onready var _cancel_button: Button = %CancelButton

var _initial_text: String = ""
var _heading: String = "Plain Text Editor"
var _hint: String = DEFAULT_HINT


func bind(heading: String, initial_text: String, hint: String = "") -> void:
	_heading = heading
	_initial_text = initial_text
	_hint = hint if hint != "" else DEFAULT_HINT


func _ready() -> void:
	close_requested.connect(_on_cancel)
	_heading_label.text = _heading
	_hint_label.text = _hint
	_text_edit.text = _initial_text
	_text_edit.grab_focus()
	_ok_button.pressed.connect(_on_apply)
	_cancel_button.pressed.connect(_on_cancel)


func _on_apply() -> void:
	emit_signal("applied", _text_edit.text)
	queue_free()


func _on_cancel() -> void:
	queue_free()
