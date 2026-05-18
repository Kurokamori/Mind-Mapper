class_name DocumentInspector
extends VBoxContainer

@onready var _title_edit: LineEdit = %TitleEdit
@onready var _font_size_spin: SpinBox = %FontSizeSpin
@onready var _title_font_size_spin: SpinBox = %TitleFontSizeSpin
@onready var _h1_font_size_spin: SpinBox = %H1FontSizeSpin
@onready var _h2_font_size_spin: SpinBox = %H2FontSizeSpin
@onready var _h3_font_size_spin: SpinBox = %H3FontSizeSpin
@onready var _h4_font_size_spin: SpinBox = %H4FontSizeSpin
@onready var _h5_font_size_spin: SpinBox = %H5FontSizeSpin
@onready var _h6_font_size_spin: SpinBox = %H6FontSizeSpin
@onready var _max_image_width_spin: SpinBox = %MaxImageWidthSpin
@onready var _bg_picker: ColorPickerButton = %BgPicker
@onready var _fg_picker: ColorPickerButton = %FgPicker
@onready var _open_editor_button: Button = %OpenEditorButton
@onready var _word_count_label: Label = %WordCountLabel
@onready var _export_markdown_button: Button = %ExportMarkdownButton
@onready var _export_pdf_button: Button = %ExportPdfButton
@onready var _replace_from_file_button: Button = %ReplaceFromFileButton
@onready var _file_status_label: Label = %FileStatusLabel

static var REPLACE_FILTERS: PackedStringArray = PackedStringArray([
	"*.md,*.markdown ; Markdown",
	"*.txt ; Plain Text",
	"*.rtf ; Rich Text Format",
	"*.docx ; Word Document",
	"*.pdf ; PDF",
])
static var EXPORT_MARKDOWN_FILTERS: PackedStringArray = PackedStringArray([
	"*.md ; Markdown",
])
static var EXPORT_PDF_FILTERS: PackedStringArray = PackedStringArray([
	"*.pdf ; PDF Document",
])

const SIZE_KEYS: Array[String] = [
	"font_size",
	"title_font_size",
	"h1_font_size",
	"h2_font_size",
	"h3_font_size",
	"h4_font_size",
	"h5_font_size",
	"h6_font_size",
	"max_image_width",
]

var _item: DocumentNode
var _editor: Node
var _binders: Dictionary = {}
var _suppress_signals: bool = false


func bind(item: DocumentNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	ThemeManager.apply_relative_font_sizes(self, {"Header": 1.15, "HelpLabel": 0.80, "WordCountLabel": 0.80})
	if _item == null:
		return
	_suppress_signals = true
	_title_edit.text = _item.title
	_font_size_spin.value = _item.font_size
	_title_font_size_spin.value = _item.title_font_size
	_h1_font_size_spin.value = _item.h1_font_size
	_h2_font_size_spin.value = _item.h2_font_size
	_h3_font_size_spin.value = _item.h3_font_size
	_h4_font_size_spin.value = _item.h4_font_size
	_h5_font_size_spin.value = _item.h5_font_size
	_h6_font_size_spin.value = _item.h6_font_size
	_max_image_width_spin.value = _item.max_image_width
	_bg_picker.color = _item.resolved_bg_color()
	_fg_picker.color = _item.resolved_fg_color()
	_suppress_signals = false
	_binders["title"] = PropertyBinder.new(_editor, _item, "title", _item.title)
	for size_key: String in SIZE_KEYS:
		_binders[size_key] = PropertyBinder.new(_editor, _item, size_key, int(_item.get(size_key)))
	_binders["bg_color"] = PropertyBinder.new(_editor, _item, "bg_color", ColorUtil.to_array(_item.resolved_bg_color()))
	_binders["fg_color"] = PropertyBinder.new(_editor, _item, "fg_color", ColorUtil.to_array(_item.resolved_fg_color()))
	_install_reset_button(_bg_picker, "bg_color", _item.resolved_bg_color)
	_install_reset_button(_fg_picker, "fg_color", _item.resolved_fg_color)
	_title_edit.text_changed.connect(_on_title_live)
	_title_edit.focus_exited.connect(_on_title_commit)
	_connect_size_spin(_font_size_spin, "font_size")
	_connect_size_spin(_title_font_size_spin, "title_font_size")
	_connect_size_spin(_h1_font_size_spin, "h1_font_size")
	_connect_size_spin(_h2_font_size_spin, "h2_font_size")
	_connect_size_spin(_h3_font_size_spin, "h3_font_size")
	_connect_size_spin(_h4_font_size_spin, "h4_font_size")
	_connect_size_spin(_h5_font_size_spin, "h5_font_size")
	_connect_size_spin(_h6_font_size_spin, "h6_font_size")
	_connect_size_spin(_max_image_width_spin, "max_image_width")
	_bg_picker.color_changed.connect(_on_bg_live)
	_bg_picker.popup_closed.connect(_on_bg_commit)
	_fg_picker.color_changed.connect(_on_fg_live)
	_fg_picker.popup_closed.connect(_on_fg_commit)
	_open_editor_button.pressed.connect(_on_open_editor_pressed)
	_export_markdown_button.pressed.connect(_on_export_markdown_pressed)
	_export_pdf_button.pressed.connect(_on_export_pdf_pressed)
	_replace_from_file_button.pressed.connect(_on_replace_from_file_pressed)
	_file_status_label.text = ""
	ThemeManager.theme_applied.connect(_on_theme_applied)
	ThemeManager.node_palette_changed.connect(func(_a: Dictionary, _b: Dictionary) -> void: _on_theme_applied())
	_refresh_stats()


func _find_editor() -> Node:
	return EditorLocator.find_for(_item)


func _on_title_live(new_text: String) -> void:
	if _suppress_signals:
		return
	_binders["title"].live(new_text)


func _on_title_commit() -> void:
	if _suppress_signals:
		return
	_binders["title"].commit(_title_edit.text)


func _connect_size_spin(spin: SpinBox, key: String) -> void:
	spin.value_changed.connect(func(value: float) -> void:
		if _suppress_signals:
			return
		var v: int = int(value)
		_binders[key].live(v)
		_binders[key].commit(v)
	)


func _on_bg_live(c: Color) -> void:
	if _suppress_signals:
		return
	_binders["bg_color"].live(ColorUtil.to_array(c))


func _on_bg_commit() -> void:
	if _suppress_signals:
		return
	_binders["bg_color"].commit(ColorUtil.to_array(_bg_picker.color))


func _on_fg_live(c: Color) -> void:
	if _suppress_signals:
		return
	_binders["fg_color"].live(ColorUtil.to_array(c))


func _on_fg_commit() -> void:
	if _suppress_signals:
		return
	_binders["fg_color"].commit(ColorUtil.to_array(_fg_picker.color))


func _on_open_editor_pressed() -> void:
	if _item == null:
		return
	_item.begin_edit()


func _install_reset_button(picker: ColorPickerButton, slot: String, resolver: Callable) -> void:
	var row: HBoxContainer = picker.get_parent() as HBoxContainer
	if row == null:
		return
	var btn: Button = Button.new()
	btn.text = "↺"
	btn.tooltip_text = "Reset to theme default"
	btn.custom_minimum_size = Vector2(28, 0)
	row.add_child(btn)
	btn.pressed.connect(func() -> void:
		_binders[slot].live(null)
		_binders[slot].commit(null)
		picker.color = resolver.call()
	)


func _on_theme_applied() -> void:
	if _item == null:
		return
	_suppress_signals = true
	if not _item.bg_color_custom:
		_bg_picker.color = _item.resolved_bg_color()
	if not _item.fg_color_custom:
		_fg_picker.color = _item.resolved_fg_color()
	_suppress_signals = false


func _refresh_stats() -> void:
	if _item == null:
		return
	var raw: String = _item.markdown_text
	var word_count: int = 0
	var current_word_length: int = 0
	for i in range(raw.length()):
		var ch: String = raw[i]
		if ch == " " or ch == "\n" or ch == "\t" or ch == "\r":
			if current_word_length > 0:
				word_count += 1
				current_word_length = 0
		else:
			current_word_length += 1
	if current_word_length > 0:
		word_count += 1
	_word_count_label.text = "%d words • %d characters" % [word_count, raw.length()]


func _set_file_status(text: String) -> void:
	if _file_status_label != null:
		_file_status_label.text = text


func _on_export_markdown_pressed() -> void:
	if _item == null:
		return
	var default_name: String = DocumentExporter.suggested_basename(_item) + ".md"
	_request_save_path("Export document as Markdown", default_name, "md", EXPORT_MARKDOWN_FILTERS, _on_export_markdown_path_chosen)


func _on_export_pdf_pressed() -> void:
	if _item == null:
		return
	var default_name: String = DocumentExporter.suggested_basename(_item) + ".pdf"
	_request_save_path("Export document as PDF", default_name, "pdf", EXPORT_PDF_FILTERS, _on_export_pdf_path_chosen)


func _on_replace_from_file_pressed() -> void:
	if _item == null:
		return
	_request_open_path("Replace document content", REPLACE_FILTERS, _on_replace_path_chosen)


func _on_export_markdown_path_chosen(path: String) -> void:
	if _item == null or path == "":
		return
	var ok: bool = DocumentExporter.export_markdown(_item, path)
	if ok:
		_set_file_status("Exported Markdown to %s" % path.get_file())
	else:
		_set_file_status("Failed to export Markdown.")


func _on_export_pdf_path_chosen(path: String) -> void:
	if _item == null or path == "":
		return
	_set_file_status("Rendering PDF…")
	var host: Node = self
	var ok: bool = await DocumentExporter.export_pdf(_item, host, path)
	if ok:
		_set_file_status("Exported PDF to %s" % path.get_file())
	else:
		_set_file_status("Failed to export PDF.")


func _on_replace_path_chosen(path: String) -> void:
	if _item == null or path == "":
		return
	var result: DocumentImporter.ImportResult = DocumentImporter.import_to_markdown(path)
	if not result.ok:
		_set_file_status(result.error_message)
		return
	var new_markdown: String = result.markdown
	var new_title: String = path.get_file().get_basename()
	if _editor != null:
		if new_markdown != _item.markdown_text:
			History.push(ModifyPropertyCommand.new(_editor, _item.item_id, "markdown_text", _item.markdown_text, new_markdown))
		var current_title: String = _item.title
		var should_update_title: bool = current_title == "" or current_title == DocumentNode.DEFAULT_TITLE
		if should_update_title and new_title != current_title:
			History.push(ModifyPropertyCommand.new(_editor, _item.item_id, "title", current_title, new_title))
			_suppress_signals = true
			_title_edit.text = new_title
			_suppress_signals = false
			_binders["title"] = PropertyBinder.new(_editor, _item, "title", new_title)
	else:
		_item.markdown_text = new_markdown
		if _item.title == "" or _item.title == DocumentNode.DEFAULT_TITLE:
			_item.title = new_title
			_suppress_signals = true
			_title_edit.text = new_title
			_suppress_signals = false
		_item._refresh_visuals()
	_refresh_stats()
	_set_file_status(result.notice if result.notice != "" else "Replaced content from %s" % path.get_file())


func _request_save_path(title_text: String, default_name: String, extension: String, filters: PackedStringArray, callback: Callable) -> void:
	if Bootstrap._is_mobile_runtime():
		var saver: MobileFileSaver = MobileFileSaver.new()
		add_child(saver)
		saver.save_path_chosen.connect(func(path: String) -> void:
			callback.call(path)
			saver.queue_free()
		)
		saver.save_cancelled.connect(func() -> void: saver.queue_free())
		saver.save_error.connect(func(msg: String) -> void:
			_set_file_status(msg)
			saver.queue_free()
		)
		saver.save_as(title_text, default_name, extension, filters)
		return
	var dialog: FileDialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.use_native_dialog = true
	dialog.title = title_text
	dialog.filters = filters
	dialog.current_file = default_name
	add_child(dialog)
	dialog.file_selected.connect(func(path: String) -> void:
		var normalized: String = _ensure_extension(path, extension)
		callback.call(normalized)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered_ratio(0.7)


func _request_open_path(title_text: String, filters: PackedStringArray, callback: Callable) -> void:
	if Bootstrap._is_mobile_runtime():
		var picker: MobileFilePicker = MobileFilePicker.new()
		add_child(picker)
		picker.files_chosen.connect(func(paths: PackedStringArray) -> void:
			if not paths.is_empty():
				callback.call(paths[0])
			picker.queue_free()
		)
		picker.pick_cancelled.connect(func() -> void: picker.queue_free())
		picker.pick_error.connect(func(msg: String) -> void:
			_set_file_status(msg)
			picker.queue_free()
		)
		picker.pick_single(title_text, filters)
		return
	var dialog: FileDialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.use_native_dialog = true
	dialog.title = title_text
	dialog.filters = filters
	add_child(dialog)
	dialog.file_selected.connect(func(path: String) -> void:
		callback.call(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered_ratio(0.7)


func _ensure_extension(path: String, extension: String) -> String:
	var normalized: String = path.replace("\\", "/")
	if extension == "":
		return normalized
	var dot_ext: String = "." + extension.to_lower()
	if normalized.to_lower().ends_with(dot_ext):
		return normalized
	return normalized + dot_ext
