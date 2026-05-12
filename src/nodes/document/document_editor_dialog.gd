class_name DocumentEditorDialog
extends Window

signal applied(title: String, markdown_text: String)

@onready var _heading_label: Label = %HeadingLabel
@onready var _title_edit: LineEdit = %TitleEdit
@onready var _source_edit: TextEdit = %SourceEdit
@onready var _preview_label: RichTextLabel = %PreviewLabel
@onready var _bold_button: Button = %BoldButton
@onready var _italic_button: Button = %ItalicButton
@onready var _strike_button: Button = %StrikeButton
@onready var _inline_code_button: Button = %InlineCodeButton
@onready var _h1_button: Button = %H1Button
@onready var _h2_button: Button = %H2Button
@onready var _h3_button: Button = %H3Button
@onready var _ul_button: Button = %ULButton
@onready var _ol_button: Button = %OLButton
@onready var _quote_button: Button = %QuoteButton
@onready var _code_block_button: Button = %CodeBlockButton
@onready var _link_button: Button = %LinkButton
@onready var _image_button: Button = %ImageButton
@onready var _hr_button: Button = %HRButton
@onready var _import_button: Button = %ImportButton
@onready var _normalize_button: Button = %NormalizeButton
@onready var _ok_button: Button = %OkButton
@onready var _cancel_button: Button = %CancelButton
@onready var _import_dialog: FileDialog = %ImportDialog
@onready var _status_label: Label = %StatusLabel

var _initial_title: String = ""
var _initial_markdown: String = ""
var _heading_sizes: Array[int] = MarkdownConverter.default_heading_sizes()
var _body_font_size: int = 14
var _title_font_size: int = 18


func bind(title: String, markdown_text: String, heading_sizes: Array[int] = MarkdownConverter.default_heading_sizes(), body_font_size: int = 14, title_font_size: int = 18) -> void:
	_initial_title = title
	_initial_markdown = markdown_text
	_heading_sizes = heading_sizes.duplicate()
	_body_font_size = body_font_size
	_title_font_size = title_font_size


func _ready() -> void:
	close_requested.connect(_on_cancel)
	ThemeManager.apply_relative_font_size(_heading_label, 1.20)
	ThemeManager.apply_relative_font_size(_status_label, 0.85)
	_heading_label.text = "Document Editor"
	_title_edit.text = _initial_title
	_source_edit.text = _initial_markdown
	_status_label.text = ""
	_bold_button.pressed.connect(func() -> void: _wrap_selection("**", "**"))
	_italic_button.pressed.connect(func() -> void: _wrap_selection("*", "*"))
	_strike_button.pressed.connect(func() -> void: _wrap_selection("~~", "~~"))
	_inline_code_button.pressed.connect(func() -> void: _wrap_selection("`", "`"))
	_h1_button.pressed.connect(func() -> void: _prepend_line("# "))
	_h2_button.pressed.connect(func() -> void: _prepend_line("## "))
	_h3_button.pressed.connect(func() -> void: _prepend_line("### "))
	_ul_button.pressed.connect(func() -> void: _prepend_each_line("- "))
	_ol_button.pressed.connect(_apply_ordered_list)
	_quote_button.pressed.connect(func() -> void: _prepend_each_line("> "))
	_code_block_button.pressed.connect(_apply_code_block)
	_link_button.pressed.connect(_apply_link)
	_image_button.pressed.connect(_apply_image)
	_hr_button.pressed.connect(_apply_hr)
	_import_button.pressed.connect(_on_import_pressed)
	_normalize_button.pressed.connect(_on_normalize_pressed)
	_ok_button.pressed.connect(_on_apply)
	_cancel_button.pressed.connect(_on_cancel)
	_source_edit.text_changed.connect(_refresh_preview)
	_title_edit.text_changed.connect(func(_t: String) -> void: _refresh_preview())
	_import_dialog.file_selected.connect(_on_import_file_selected)
	_refresh_preview()
	_title_edit.grab_focus()


func _refresh_preview() -> void:
	if _preview_label == null:
		return
	var source: String = _source_edit.text
	var normalized: String = MarkdownConverter.normalize_to_markdown(source)
	_preview_label.bbcode_enabled = true
	_preview_label.text = MarkdownConverter.markdown_to_bbcode(normalized, _heading_sizes)
	_preview_label.add_theme_font_size_override("normal_font_size", _body_font_size)
	_preview_label.add_theme_font_size_override("bold_font_size", _body_font_size)
	_preview_label.add_theme_font_size_override("italics_font_size", _body_font_size)
	_preview_label.add_theme_font_size_override("mono_font_size", _body_font_size)
	if _title_edit != null:
		_title_edit.add_theme_font_size_override("font_size", _title_font_size)


func _wrap_selection(opening: String, closing: String) -> void:
	if _source_edit == null:
		return
	var selection_text: String = _source_edit.get_selected_text()
	if selection_text == "":
		_source_edit.insert_text_at_caret(opening + closing)
		var line: int = _source_edit.get_caret_line()
		var col: int = _source_edit.get_caret_column()
		_source_edit.set_caret_column(col - closing.length(), false)
		_source_edit.set_caret_line(line, false)
	else:
		_replace_selection(opening + selection_text + closing)
	_source_edit.grab_focus()
	_refresh_preview()


func _replace_selection(text_to_insert: String) -> void:
	if not _source_edit.has_selection():
		_source_edit.insert_text_at_caret(text_to_insert)
		return
	var from_line: int = _source_edit.get_selection_from_line()
	var from_col: int = _source_edit.get_selection_from_column()
	var to_line: int = _source_edit.get_selection_to_line()
	var to_col: int = _source_edit.get_selection_to_column()
	_source_edit.begin_complex_operation()
	_source_edit.remove_text(from_line, from_col, to_line, to_col)
	_source_edit.set_caret_line(from_line)
	_source_edit.set_caret_column(from_col)
	_source_edit.insert_text_at_caret(text_to_insert)
	_source_edit.end_complex_operation()


func _prepend_line(prefix: String) -> void:
	if _source_edit == null:
		return
	var line: int = _source_edit.get_caret_line()
	var current: String = _source_edit.get_line(line)
	_source_edit.set_line(line, prefix + current)
	_source_edit.set_caret_line(line)
	_source_edit.set_caret_column(prefix.length() + current.length())
	_source_edit.grab_focus()
	_refresh_preview()


func _prepend_each_line(prefix: String) -> void:
	if _source_edit == null:
		return
	if not _source_edit.has_selection():
		_prepend_line(prefix)
		return
	var from_line: int = _source_edit.get_selection_from_line()
	var to_line: int = _source_edit.get_selection_to_line()
	_source_edit.begin_complex_operation()
	for line_idx: int in range(from_line, to_line + 1):
		var current: String = _source_edit.get_line(line_idx)
		_source_edit.set_line(line_idx, prefix + current)
	_source_edit.end_complex_operation()
	_source_edit.grab_focus()
	_refresh_preview()


func _apply_ordered_list() -> void:
	if _source_edit == null:
		return
	if not _source_edit.has_selection():
		_prepend_line("1. ")
		return
	var from_line: int = _source_edit.get_selection_from_line()
	var to_line: int = _source_edit.get_selection_to_line()
	_source_edit.begin_complex_operation()
	var counter: int = 1
	for line_idx: int in range(from_line, to_line + 1):
		var current: String = _source_edit.get_line(line_idx)
		_source_edit.set_line(line_idx, "%d. %s" % [counter, current])
		counter += 1
	_source_edit.end_complex_operation()
	_source_edit.grab_focus()
	_refresh_preview()


func _apply_code_block() -> void:
	var selection_text: String = _source_edit.get_selected_text()
	if selection_text == "":
		_source_edit.insert_text_at_caret("\n```\n\n```\n")
	else:
		_replace_selection("\n```\n" + selection_text + "\n```\n")
	_source_edit.grab_focus()
	_refresh_preview()


func _apply_link() -> void:
	var selection_text: String = _source_edit.get_selected_text()
	if selection_text == "":
		_source_edit.insert_text_at_caret("[text](https://example.com)")
	else:
		_replace_selection("[" + selection_text + "](https://example.com)")
	_source_edit.grab_focus()
	_refresh_preview()


func _apply_image() -> void:
	var selection_text: String = _source_edit.get_selected_text()
	if selection_text == "":
		_source_edit.insert_text_at_caret("![alt](https://example.com/image.png)")
	else:
		_replace_selection("![" + selection_text + "](https://example.com/image.png)")
	_source_edit.grab_focus()
	_refresh_preview()


func _apply_hr() -> void:
	_source_edit.insert_text_at_caret("\n\n---\n\n")
	_source_edit.grab_focus()
	_refresh_preview()


func _on_normalize_pressed() -> void:
	var current: String = _source_edit.text
	var normalized: String = MarkdownConverter.normalize_to_markdown(current)
	if normalized == current:
		_status_label.text = "Already markdown."
		return
	_source_edit.text = normalized
	_status_label.text = "Converted BBCode to Markdown."
	_refresh_preview()


func _on_import_pressed() -> void:
	if _import_dialog == null:
		return
	_import_dialog.popup_centered_ratio(0.7)


func _on_import_file_selected(path: String) -> void:
	var result: DocumentImporter.ImportResult = DocumentImporter.import_to_markdown(path)
	if not result.ok:
		_status_label.text = result.error_message
		return
	_source_edit.text = result.markdown
	if _title_edit.text == "" or _title_edit.text == DocumentNode.DEFAULT_TITLE:
		_title_edit.text = path.get_file().get_basename()
	_status_label.text = result.notice if result.notice != "" else "Imported %s" % path.get_file()
	_refresh_preview()


func _on_apply() -> void:
	var final_title: String = _title_edit.text.strip_edges()
	if final_title == "":
		final_title = DocumentNode.DEFAULT_TITLE
	var final_markdown: String = MarkdownConverter.normalize_to_markdown(_source_edit.text)
	emit_signal("applied", final_title, final_markdown)
	queue_free()


func _on_cancel() -> void:
	queue_free()
