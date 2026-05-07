class_name ExportMapDialog
extends ConfirmationDialog

signal export_requested(output_dir: String, godot_root: String, mode: String)

@onready var _output_edit: LineEdit = %OutputEdit
@onready var _output_browse: Button = %OutputBrowse
@onready var _root_edit: LineEdit = %RootEdit
@onready var _root_browse: Button = %RootBrowse
@onready var _mode_reference: CheckBox = %ModeReference
@onready var _mode_bundle: CheckBox = %ModeBundle
@onready var _info_label: Label = %InfoLabel
@onready var _output_dialog: FileDialog = %OutputDialog
@onready var _root_dialog: FileDialog = %RootDialog


func _ready() -> void:
	add_cancel_button("Cancel")
	confirmed.connect(_on_confirmed)
	ThemeManager.apply_relative_font_size(_info_label, 0.85)
	_output_browse.pressed.connect(_on_output_browse)
	_root_browse.pressed.connect(_on_root_browse)
	_output_dialog.dir_selected.connect(_on_output_chosen)
	_root_dialog.dir_selected.connect(_on_root_chosen)
	_mode_reference.toggled.connect(_on_mode_toggled.bind("reference"))
	_mode_bundle.toggled.connect(_on_mode_toggled.bind("bundle"))
	_mode_reference.button_pressed = true


func open() -> void:
	popup_centered()


func _on_output_browse() -> void:
	_output_dialog.popup_centered_ratio(0.7)


func _on_root_browse() -> void:
	_root_dialog.popup_centered_ratio(0.7)


func _on_output_chosen(dir: String) -> void:
	_output_edit.text = dir
	_validate()


func _on_root_chosen(dir: String) -> void:
	_root_edit.text = dir
	_validate()


func _on_mode_toggled(p: bool, which: String) -> void:
	if not p:
		return
	if which == "reference":
		_mode_bundle.button_pressed = false
	else:
		_mode_reference.button_pressed = false
	_validate()


func _validate() -> void:
	var out: String = _output_edit.text.strip_edges()
	if out == "":
		_info_label.text = "Pick an output folder."
		return
	if _mode_reference.button_pressed and _root_edit.text.strip_edges() == "":
		_info_label.text = "Reference mode needs the Godot project root for res:// path resolution."
		return
	_info_label.text = "Ready to export."


func _on_confirmed() -> void:
	var out: String = _output_edit.text.strip_edges()
	var root: String = _root_edit.text.strip_edges()
	var mode: String = "reference" if _mode_reference.button_pressed else "bundle"
	if out == "":
		return
	emit_signal("export_requested", out, root, mode)
