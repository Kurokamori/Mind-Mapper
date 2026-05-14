class_name ImageSizeDialog
extends ConfirmationDialog

enum DialogMode { INSERT, EDIT }

signal accepted_with_values(mode: int, alt_text: String, width: int, height: int)

@onready var _alt_edit: LineEdit = %AltEdit
@onready var _width_spin: SpinBox = %WidthSpin
@onready var _height_spin: SpinBox = %HeightSpin
@onready var _hint_label: Label = %HintLabel
@onready var _path_label: Label = %PathLabel

var _dialog_mode: DialogMode = DialogMode.INSERT


func _ready() -> void:
	add_cancel_button("Cancel")
	confirmed.connect(_on_confirmed)


func open_for_insert(default_alt: String, image_reference: String) -> void:
	_dialog_mode = DialogMode.INSERT
	title = "Insert Image"
	ok_button_text = "Insert"
	_alt_edit.text = default_alt
	_width_spin.value = 0.0
	_height_spin.value = 0.0
	_hint_label.text = "Use 0 to keep that dimension automatic. Both 0 inserts the image at its native size."
	_path_label.text = "Source: %s" % image_reference
	popup_centered()
	_alt_edit.grab_focus()
	_alt_edit.select_all()


func open_for_edit(alt_text: String, width: int, height: int, image_reference: String) -> void:
	_dialog_mode = DialogMode.EDIT
	title = "Edit Image"
	ok_button_text = "Apply"
	_alt_edit.text = alt_text
	_width_spin.value = float(max(0, width))
	_height_spin.value = float(max(0, height))
	_hint_label.text = "Use 0 to keep that dimension automatic. Both 0 removes the explicit size."
	_path_label.text = "Source: %s" % image_reference
	popup_centered()
	_width_spin.grab_focus()


func _on_confirmed() -> void:
	var w: int = int(_width_spin.value)
	var h: int = int(_height_spin.value)
	if w < 0:
		w = 0
	if h < 0:
		h = 0
	emit_signal("accepted_with_values", int(_dialog_mode), _alt_edit.text, w, h)
