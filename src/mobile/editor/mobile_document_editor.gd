class_name MobileDocumentEditor
extends Window

signal applied(title: String, markdown_text: String)

const SIZE_BODY: int = 0
const SIZE_H1_DEFAULT: int = 28
const SIZE_H2_DEFAULT: int = 24
const SIZE_H3_DEFAULT: int = 20

@onready var _title_edit: LineEdit = %TitleEdit
@onready var _cancel_button: Button = %CancelButton
@onready var _save_button: Button = %SaveButton
@onready var _editor: WysiwygRichEditor = %WysiwygEditor

@onready var _bold_button: Button = %BoldButton
@onready var _italic_button: Button = %ItalicButton
@onready var _underline_button: Button = %UnderlineButton
@onready var _strike_button: Button = %StrikeButton
@onready var _code_button: Button = %CodeButton

@onready var _h1_button: Button = %H1Button
@onready var _h2_button: Button = %H2Button
@onready var _h3_button: Button = %H3Button
@onready var _body_button: Button = %BodyButton

@onready var _color_button: ColorPickerButton = %ColorButton
@onready var _link_button: Button = %LinkButton
@onready var _clear_format_button: Button = %ClearFormatButton

@onready var _undo_button: Button = %UndoButton
@onready var _redo_button: Button = %RedoButton

@onready var _image_button: Button = %ImageButton
@onready var _import_button: Button = %ImportButton
@onready var _status_label: Label = %StatusLabel

@onready var _link_dialog: AcceptDialog = %LinkDialog
@onready var _link_url_edit: LineEdit = %LinkUrlEdit
@onready var _link_label_edit: LineEdit = %LinkLabelEdit

static var IMAGE_FILTERS: PackedStringArray = PackedStringArray([
	"*.png,*.jpg,*.jpeg,*.webp,*.bmp,*.tga,*.svg ; Images",
])
static var IMPORT_FILTERS: PackedStringArray = PackedStringArray([
	"*.md,*.markdown ; Markdown",
	"*.txt ; Plain Text",
	"*.rtf ; Rich Text Format",
	"*.docx ; Word Document",
	"*.pdf ; PDF",
])

var _initial_title: String = ""
var _initial_markdown: String = ""
var _body_font_size: int = 14
var _h1_size: int = SIZE_H1_DEFAULT
var _h2_size: int = SIZE_H2_DEFAULT
var _h3_size: int = SIZE_H3_DEFAULT
var _max_image_width: int = 0

var _engine_image_dialog: FileDialog = null
var _engine_import_dialog: FileDialog = null


func bind(title: String, markdown_text: String, body_font_size: int = 14, h1_size: int = SIZE_H1_DEFAULT, h2_size: int = SIZE_H2_DEFAULT, h3_size: int = SIZE_H3_DEFAULT, max_image_width: int = 0) -> void:
	_initial_title = title
	_initial_markdown = markdown_text
	_body_font_size = body_font_size
	_h1_size = h1_size
	_h2_size = h2_size
	_h3_size = h3_size
	_max_image_width = max(0, max_image_width)


func _ready() -> void:
	close_requested.connect(_on_cancel)
	_title_edit.text = _initial_title
	_editor.default_font_size = _body_font_size
	_editor.max_image_width = _max_image_width
	_editor.set_bbcode(_initial_markdown)
	_status_label.text = ""
	_cancel_button.pressed.connect(_on_cancel)
	_save_button.pressed.connect(_on_save)
	_bold_button.pressed.connect(func() -> void: _editor.toggle_attribute_in_selection("bold"))
	_italic_button.pressed.connect(func() -> void: _editor.toggle_attribute_in_selection("italic"))
	_underline_button.pressed.connect(func() -> void: _editor.toggle_attribute_in_selection("underline"))
	_strike_button.pressed.connect(func() -> void: _editor.toggle_attribute_in_selection("strike"))
	_code_button.pressed.connect(func() -> void: _editor.toggle_attribute_in_selection("code"))
	_h1_button.pressed.connect(func() -> void: _apply_size(_h1_size))
	_h2_button.pressed.connect(func() -> void: _apply_size(_h2_size))
	_h3_button.pressed.connect(func() -> void: _apply_size(_h3_size))
	_body_button.pressed.connect(func() -> void: _apply_size(SIZE_BODY))
	_color_button.color_changed.connect(_on_color_changed)
	_link_button.pressed.connect(_on_link_pressed)
	_clear_format_button.pressed.connect(func() -> void: _editor.clear_formatting_in_selection())
	_undo_button.pressed.connect(func() -> void: _editor.undo())
	_redo_button.pressed.connect(func() -> void: _editor.redo())
	_image_button.pressed.connect(_on_image_pressed)
	_import_button.pressed.connect(_on_import_pressed)
	_link_dialog.confirmed.connect(_on_link_dialog_confirmed)
	_editor.grab_focus()


func _apply_size(size: int) -> void:
	_editor.apply_attribute_to_selection("size", size)
	_editor.grab_focus()


func _on_color_changed(color: Color) -> void:
	_editor.apply_attribute_to_selection("color", color)
	_editor.grab_focus()


func _on_link_pressed() -> void:
	_link_url_edit.text = ""
	_link_label_edit.text = _editor.get_selected_text()
	_link_dialog.popup_centered_ratio(0.9)
	_link_url_edit.grab_focus()


func _on_link_dialog_confirmed() -> void:
	var url: String = _link_url_edit.text.strip_edges()
	var label: String = _link_label_edit.text.strip_edges()
	if url == "":
		return
	_editor.insert_link(url, label)
	_editor.grab_focus()


func _on_cancel() -> void:
	queue_free()


func _on_save() -> void:
	var final_title: String = _title_edit.text.strip_edges()
	if final_title == "":
		final_title = DocumentNode.DEFAULT_TITLE
	var bbcode: String = _editor.get_bbcode()
	var final_markdown: String = MarkdownConverter.normalize_to_markdown(bbcode)
	emit_signal("applied", final_title, final_markdown)
	queue_free()


func _on_image_pressed() -> void:
	_open_native_or_engine_file_dialog("Select image", IMAGE_FILTERS, _on_image_file_chosen, true)


func _on_image_file_chosen(absolute_path: String) -> void:
	if absolute_path == "":
		return
	var reference_path: String = _store_image_asset(absolute_path)
	if reference_path == "":
		_status_label.text = "Could not load image: %s" % absolute_path.get_file()
		return
	_editor.insert_image(reference_path, 0, 0)
	_status_label.text = "Inserted %s" % absolute_path.get_file()
	_editor.grab_focus()


func _store_image_asset(absolute_path: String) -> String:
	if absolute_path == "":
		return ""
	if AppState.current_project == null:
		return absolute_path
	var copied_name: String = AppState.current_project.copy_asset_into_project(absolute_path)
	if copied_name == "":
		return absolute_path
	return MarkdownImageRenderer.ASSET_SCHEME + copied_name


func _on_import_pressed() -> void:
	_open_native_or_engine_file_dialog("Import document", IMPORT_FILTERS, _on_import_file_chosen, false)


func _on_import_file_chosen(absolute_path: String) -> void:
	if absolute_path == "":
		return
	var result: DocumentImporter.ImportResult = DocumentImporter.import_to_markdown(absolute_path)
	if not result.ok:
		_status_label.text = result.error_message
		return
	_editor.set_bbcode(result.markdown)
	if _title_edit.text == "" or _title_edit.text == DocumentNode.DEFAULT_TITLE:
		_title_edit.text = absolute_path.get_file().get_basename()
	_status_label.text = result.notice if result.notice != "" else "Imported %s" % absolute_path.get_file()
	_editor.grab_focus()


func _open_native_or_engine_file_dialog(title_text: String, filters: PackedStringArray, callback: Callable, is_image: bool) -> void:
	var start_dir: String = _default_picker_dir()
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE) and _native_file_dialog_supported():
		var native_callback: Callable = func(status: bool, paths: PackedStringArray, _filter_idx: int) -> void:
			if not status or paths.is_empty():
				return
			callback.call(paths[0])
		var ok: Error = DisplayServer.file_dialog_show(
			title_text,
			start_dir,
			"",
			false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
			filters,
			native_callback,
		)
		if ok == OK:
			return
	_open_engine_file_dialog(title_text, filters, callback, is_image, start_dir)


func _native_file_dialog_supported() -> bool:
	var platform: String = OS.get_name()
	return platform == "Windows" or platform == "macOS" or platform == "Linux" or platform == "Android"


func _open_engine_file_dialog(title_text: String, filters: PackedStringArray, callback: Callable, is_image: bool, start_dir: String) -> void:
	var dialog: FileDialog = _engine_image_dialog if is_image else _engine_import_dialog
	if dialog == null:
		dialog = FileDialog.new()
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		dialog.use_native_dialog = false
		dialog.size = Vector2i(720, 540)
		add_child(dialog)
		if is_image:
			_engine_image_dialog = dialog
		else:
			_engine_import_dialog = dialog
		dialog.file_selected.connect(func(path: String) -> void: callback.call(path))
	dialog.title = title_text
	dialog.filters = filters
	if DirAccess.dir_exists_absolute(start_dir):
		dialog.current_dir = start_dir
	dialog.popup_centered_ratio(1.0)


func _default_picker_dir() -> String:
	var sandbox: String = MobileStoragePaths.sandbox_root()
	if sandbox != "":
		if not DirAccess.dir_exists_absolute(sandbox):
			MobileStoragePaths.ensure_dirs()
		if DirAccess.dir_exists_absolute(sandbox):
			return sandbox
	var fallback: String = OS.get_user_data_dir()
	if fallback != "" and DirAccess.dir_exists_absolute(fallback):
		return fallback
	return ""
