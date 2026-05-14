class_name DocumentEditorDialog
extends Window

signal applied(title: String, markdown_text: String)

enum ImagePickerMode { INSERT, REPLACE_LINK }

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
@onready var _link_button: AutomaticButton = %LinkButton
@onready var _image_button: AutomaticButton = %ImageButton
@onready var _hr_button: Button = %HRButton
@onready var _import_button: Button = %ImportButton
@onready var _normalize_button: Button = %NormalizeButton
@onready var _ok_button: Button = %OkButton
@onready var _cancel_button: Button = %CancelButton
@onready var _import_dialog: FileDialog = %ImportDialog
@onready var _image_dialog: FileDialog = %ImageDialog
@onready var _status_label: Label = %StatusLabel
@onready var _image_size_dialog: ImageSizeDialog = %ImageSizeDialog
@onready var _image_toolbar: PanelContainer = %ImageToolbar
@onready var _image_remove_button: Button = %ImageRemoveButton
@onready var _image_edit_link_button: Button = %ImageEditLinkButton
@onready var _image_edit_size_button: Button = %ImageEditSizeButton

var _initial_title: String = ""
var _initial_markdown: String = ""
var _heading_sizes: Array[int] = MarkdownConverter.default_heading_sizes()
var _body_font_size: int = 14
var _title_font_size: int = 18
var _max_image_width: int = 0
var _image_picker_mode: ImagePickerMode = ImagePickerMode.INSERT
var _pending_image_path: String = ""
var _active_image_token: Dictionary = {}


func bind(title: String, markdown_text: String, heading_sizes: Array[int] = MarkdownConverter.default_heading_sizes(), body_font_size: int = 14, title_font_size: int = 18, max_image_width: int = 0) -> void:
	_initial_title = title
	_initial_markdown = markdown_text
	_heading_sizes = heading_sizes.duplicate()
	_body_font_size = body_font_size
	_title_font_size = title_font_size
	_max_image_width = max(0, max_image_width)


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
	_source_edit.text_changed.connect(_update_image_toolbar)
	_source_edit.caret_changed.connect(_update_image_toolbar)
	_source_edit.gui_input.connect(_on_source_gui_input)
	_source_edit.resized.connect(_update_image_toolbar)
	var v_scroll: VScrollBar = _source_edit.get_v_scroll_bar()
	if v_scroll != null:
		v_scroll.value_changed.connect(func(_v: float) -> void: _update_image_toolbar())
	var h_scroll: HScrollBar = _source_edit.get_h_scroll_bar()
	if h_scroll != null:
		h_scroll.value_changed.connect(func(_v: float) -> void: _update_image_toolbar())
	_title_edit.text_changed.connect(func(_t: String) -> void: _refresh_preview())
	_import_dialog.file_selected.connect(_on_import_file_selected)
	_image_dialog.file_selected.connect(_on_image_file_selected)
	_image_size_dialog.accepted_with_values.connect(_on_image_size_accepted)
	_image_remove_button.pressed.connect(_on_image_toolbar_remove)
	_image_edit_link_button.pressed.connect(_on_image_toolbar_edit_link)
	_image_edit_size_button.pressed.connect(_on_image_toolbar_edit_size)
	size_changed.connect(_update_image_toolbar)
	_image_toolbar.visible = false
	_refresh_preview()
	_title_edit.grab_focus()


func _refresh_preview() -> void:
	if _preview_label == null:
		return
	var source: String = _source_edit.text
	var normalized: String = MarkdownConverter.normalize_to_markdown(source)
	_preview_label.bbcode_enabled = true
	var bbcode: String = MarkdownConverter.markdown_to_bbcode(normalized, _heading_sizes)
	MarkdownImageRenderer.render_bbcode_with_images(_preview_label, bbcode, "", _max_image_width)
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
	if _image_dialog == null:
		return
	_image_picker_mode = ImagePickerMode.INSERT
	_image_dialog.popup_centered_ratio(0.7)


func _on_image_file_selected(path: String) -> void:
	var reference_path: String = _store_image_asset(path)
	if reference_path == "":
		_status_label.text = "Failed to load image: %s" % path.get_file()
		return
	match _image_picker_mode:
		ImagePickerMode.INSERT:
			_pending_image_path = reference_path
			var default_alt: String = path.get_file().get_basename()
			if _image_size_dialog != null:
				_image_size_dialog.open_for_insert(default_alt, reference_path)
		ImagePickerMode.REPLACE_LINK:
			_replace_active_image_path(reference_path)


func _store_image_asset(absolute_path: String) -> String:
	if absolute_path == "":
		return ""
	if AppState.current_project == null:
		return absolute_path
	var copied_name: String = AppState.current_project.copy_asset_into_project(absolute_path)
	if copied_name == "":
		return absolute_path
	return MarkdownImageRenderer.ASSET_SCHEME + copied_name


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


func _on_image_size_accepted(mode: int, alt_text: String, width: int, height: int) -> void:
	var size_spec: String = _size_spec_from_dims(width, height)
	var cleaned_alt: String = alt_text.replace("|", "").replace("]", "")
	match mode:
		int(ImageSizeDialog.DialogMode.INSERT):
			var path: String = _pending_image_path
			_pending_image_path = ""
			if path == "":
				return
			var markdown: String = _build_image_markdown(cleaned_alt, size_spec, path)
			var selection_text: String = _source_edit.get_selected_text()
			if selection_text == "":
				_source_edit.insert_text_at_caret(markdown)
			else:
				_replace_selection(markdown)
			_status_label.text = "Inserted %s" % path.get_file()
			_source_edit.grab_focus()
			_refresh_preview()
			_update_image_toolbar()
		int(ImageSizeDialog.DialogMode.EDIT):
			if _active_image_token.is_empty():
				return
			var existing_path: String = String(_active_image_token.get("path", ""))
			var new_markdown: String = _build_image_markdown(cleaned_alt, size_spec, existing_path)
			_replace_image_token_with(new_markdown)
			_status_label.text = "Updated image."
			_refresh_preview()
			_update_image_toolbar()


func _build_image_markdown(alt_text: String, size_spec: String, path: String) -> String:
	if size_spec != "":
		return "![%s|%s](%s)" % [alt_text, size_spec, path]
	return "![%s](%s)" % [alt_text, path]


func _size_spec_from_dims(width: int, height: int) -> String:
	if width <= 0 and height <= 0:
		return ""
	if height <= 0:
		return str(width)
	if width <= 0:
		return "0x%d" % height
	return "%dx%d" % [width, height]


func _parse_size_spec_to_dims(spec: String) -> Vector2i:
	var trimmed: String = spec.strip_edges()
	if trimmed == "":
		return Vector2i.ZERO
	var x_index: int = trimmed.find("x")
	if x_index < 0:
		if trimmed.is_valid_int():
			return Vector2i(int(trimmed), 0)
		return Vector2i.ZERO
	var width_part: String = trimmed.substr(0, x_index)
	var height_part: String = trimmed.substr(x_index + 1)
	var width_value: int = int(width_part) if width_part.is_valid_int() else 0
	var height_value: int = int(height_part) if height_part.is_valid_int() else 0
	return Vector2i(width_value, height_value)


func _find_image_token_at(line: int, column: int) -> Dictionary:
	if _source_edit == null:
		return {}
	if line < 0 or line >= _source_edit.get_line_count():
		return {}
	var line_text: String = _source_edit.get_line(line)
	var regex: RegEx = RegEx.new()
	if regex.compile("!\\[([^\\]]*)\\]\\(([^)\\s]+)\\)") != OK:
		return {}
	var matches: Array = regex.search_all(line_text)
	for raw_match: Variant in matches:
		var m: RegExMatch = raw_match
		if column >= m.get_start() and column <= m.get_end():
			var alt_full: String = m.get_string(1)
			var path: String = m.get_string(2)
			var alt_text: String = alt_full
			var size_spec: String = ""
			var pipe_index: int = alt_full.find("|")
			if pipe_index >= 0:
				alt_text = alt_full.substr(0, pipe_index)
				size_spec = alt_full.substr(pipe_index + 1)
			return {
				"line": line,
				"start_col": m.get_start(),
				"end_col": m.get_end(),
				"alt": alt_text,
				"size_spec": size_spec,
				"path": path,
				"full": m.get_string(0),
			}
	return {}


func _current_image_token() -> Dictionary:
	if _source_edit == null:
		return {}
	var line: int
	var column: int
	if _source_edit.has_selection():
		line = _source_edit.get_selection_from_line()
		column = _source_edit.get_selection_from_column()
		var token: Dictionary = _find_image_token_at(line, column)
		if not token.is_empty():
			return token
		line = _source_edit.get_selection_to_line()
		column = _source_edit.get_selection_to_column()
		return _find_image_token_at(line, column)
	line = _source_edit.get_caret_line()
	column = _source_edit.get_caret_column()
	return _find_image_token_at(line, column)


func _update_image_toolbar() -> void:
	if _image_toolbar == null or _source_edit == null:
		return
	var token: Dictionary = _current_image_token()
	if token.is_empty():
		_image_toolbar.visible = false
		_active_image_token = {}
		return
	_active_image_token = token
	_image_toolbar.size = Vector2.ZERO
	_image_toolbar.visible = true
	_image_toolbar.reset_size()
	call_deferred("_position_image_toolbar")


func _position_image_toolbar() -> void:
	if _image_toolbar == null or _source_edit == null:
		return
	if _active_image_token.is_empty() or not _image_toolbar.visible:
		return
	var line: int = int(_active_image_token.get("line", 0))
	var start_col: int = int(_active_image_token.get("start_col", 0))
	var pos_in_textedit: Vector2i = _source_edit.get_pos_at_line_column(line, start_col)
	if pos_in_textedit.x < 0 or pos_in_textedit.y < 0:
		_image_toolbar.visible = false
		return
	var line_height: int = _source_edit.get_line_height()
	var window_pos: Vector2 = _source_edit.global_position + Vector2(pos_in_textedit)
	var toolbar_size: Vector2 = _image_toolbar.size
	if toolbar_size.y <= 0:
		toolbar_size = _image_toolbar.get_combined_minimum_size()
	if toolbar_size.x <= 0:
		toolbar_size.x = 240
	if toolbar_size.y <= 0:
		toolbar_size.y = 32
	var gap: float = 6.0
	var anchor_y: float = window_pos.y - toolbar_size.y - gap
	if anchor_y < _source_edit.global_position.y:
		anchor_y = window_pos.y + float(line_height) + gap
	var anchor_x: float = window_pos.x
	var max_x: float = _source_edit.global_position.x + _source_edit.size.x - toolbar_size.x
	if anchor_x > max_x:
		anchor_x = max_x
	if anchor_x < _source_edit.global_position.x:
		anchor_x = _source_edit.global_position.x
	_image_toolbar.position = Vector2(anchor_x, anchor_y)


func _on_source_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		call_deferred("_update_image_toolbar")


func _on_image_toolbar_remove() -> void:
	if _active_image_token.is_empty():
		return
	var line: int = int(_active_image_token.get("line", -1))
	var start_col: int = int(_active_image_token.get("start_col", -1))
	var end_col: int = int(_active_image_token.get("end_col", -1))
	if line < 0 or start_col < 0 or end_col < 0:
		return
	_source_edit.begin_complex_operation()
	_source_edit.remove_text(line, start_col, line, end_col)
	_source_edit.set_caret_line(line)
	_source_edit.set_caret_column(start_col)
	_source_edit.end_complex_operation()
	_active_image_token = {}
	_image_toolbar.visible = false
	_status_label.text = "Removed image."
	_refresh_preview()


func _on_image_toolbar_edit_link() -> void:
	if _active_image_token.is_empty():
		return
	_image_picker_mode = ImagePickerMode.REPLACE_LINK
	_image_dialog.popup_centered_ratio(0.7)


func _on_image_toolbar_edit_size() -> void:
	if _active_image_token.is_empty() or _image_size_dialog == null:
		return
	var alt_text: String = String(_active_image_token.get("alt", ""))
	var size_spec: String = String(_active_image_token.get("size_spec", ""))
	var path: String = String(_active_image_token.get("path", ""))
	var dims: Vector2i = _parse_size_spec_to_dims(size_spec)
	_image_size_dialog.open_for_edit(alt_text, dims.x, dims.y, path)


func _replace_active_image_path(new_path: String) -> void:
	if _active_image_token.is_empty():
		return
	var alt_text: String = String(_active_image_token.get("alt", ""))
	var size_spec: String = String(_active_image_token.get("size_spec", ""))
	var new_markdown: String = _build_image_markdown(alt_text, size_spec, new_path)
	_replace_image_token_with(new_markdown)
	_status_label.text = "Replaced image source."
	_refresh_preview()
	_update_image_toolbar()


func _replace_image_token_with(new_markdown: String) -> void:
	if _active_image_token.is_empty():
		return
	var line: int = int(_active_image_token.get("line", -1))
	var start_col: int = int(_active_image_token.get("start_col", -1))
	var end_col: int = int(_active_image_token.get("end_col", -1))
	if line < 0 or start_col < 0 or end_col < 0:
		return
	_source_edit.begin_complex_operation()
	_source_edit.remove_text(line, start_col, line, end_col)
	_source_edit.set_caret_line(line)
	_source_edit.set_caret_column(start_col)
	_source_edit.insert_text_at_caret(new_markdown)
	_source_edit.end_complex_operation()
	_active_image_token = {
		"line": line,
		"start_col": start_col,
		"end_col": start_col + new_markdown.length(),
		"alt": _active_image_token.get("alt", ""),
		"size_spec": _active_image_token.get("size_spec", ""),
		"path": _active_image_token.get("path", ""),
		"full": new_markdown,
	}
