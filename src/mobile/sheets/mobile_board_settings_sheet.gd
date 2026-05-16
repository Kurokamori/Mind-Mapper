class_name MobileBoardSettingsSheet
extends Control

signal settings_changed()

@onready var _name_edit: LineEdit = %NameEdit
@onready var _bg_color_picker: ColorPickerButton = %BackgroundColorPicker
@onready var _bg_override_check: CheckBox = %BackgroundOverrideCheck
@onready var _apply_button: Button = %ApplyButton

var _project: Project = null
var _board: Board = null
var _board_view: MobileBoardView = null
var _applying: bool = false


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(_on_name_submitted)
	_name_edit.focus_exited.connect(_on_name_focus_exited)
	_bg_color_picker.color_changed.connect(_on_color_changed)
	_bg_override_check.toggled.connect(_on_override_toggled)
	_apply_button.pressed.connect(_on_apply_pressed)


func bind(project: Project, board: Board, board_view: MobileBoardView) -> void:
	_project = project
	_board = board
	_board_view = board_view
	_refresh()


func _refresh() -> void:
	if _board == null:
		return
	_applying = true
	_name_edit.text = _board.name
	_bg_color_picker.color = _board.background_color_override if _board.has_background_color_override() else Board.DEFAULT_BG_COLOR
	_bg_override_check.button_pressed = _board.has_background_color_override()
	_bg_color_picker.disabled = not _bg_override_check.button_pressed
	_applying = false


func _on_name_submitted(text: String) -> void:
	_apply_name(text)


func _on_name_focus_exited() -> void:
	_apply_name(_name_edit.text)


func _apply_name(text: String) -> void:
	if _applying or _board == null or _project == null:
		return
	if text.strip_edges() == "":
		_name_edit.text = _board.name
		return
	if text == _board.name:
		return
	_board.name = text
	_project.write_board(_board)
	AppState.emit_signal("board_modified", _board.id)
	settings_changed.emit()


func _on_color_changed(color: Color) -> void:
	if _applying or _board == null:
		return
	if not _bg_override_check.button_pressed:
		return
	_board.background_color_override = Color(color.r, color.g, color.b, max(color.a, 1.0))
	_project.write_board(_board)
	if _board_view != null:
		_board_view.refresh_background()
	settings_changed.emit()


func _on_override_toggled(pressed: bool) -> void:
	if _applying or _board == null:
		return
	_bg_color_picker.disabled = not pressed
	if pressed:
		var c: Color = _bg_color_picker.color
		_board.background_color_override = Color(c.r, c.g, c.b, 1.0)
	else:
		_board.background_color_override = Color(0.0, 0.0, 0.0, 0.0)
	_project.write_board(_board)
	if _board_view != null:
		_board_view.refresh_background()
	settings_changed.emit()


func _on_apply_pressed() -> void:
	_apply_name(_name_edit.text)
