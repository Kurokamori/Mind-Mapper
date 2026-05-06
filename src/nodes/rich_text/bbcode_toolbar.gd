class_name BBCodeToolbar
extends HBoxContainer

signal text_changed()

@onready var _bold_button: Button = %BoldButton
@onready var _italic_button: Button = %ItalicButton
@onready var _underline_button: Button = %UnderlineButton
@onready var _strike_button: Button = %StrikeButton
@onready var _code_button: Button = %CodeButton
@onready var _h1_button: Button = %H1Button
@onready var _h2_button: Button = %H2Button
@onready var _h3_button: Button = %H3Button
@onready var _list_button: Button = %ListButton
@onready var _link_button: Button = %LinkButton
@onready var _internal_link_button: Button = %InternalLinkButton
@onready var _color_picker: ColorPickerButton = %ColorPicker
@onready var _color_apply_button: Button = %ColorApplyButton
@onready var _size_spin: SpinBox = %SizeSpin
@onready var _size_apply_button: Button = %SizeApplyButton
@onready var _clear_button: Button = %ClearButton

var _target: TextEdit = null


func bind(target: TextEdit) -> void:
	_target = target


func _ready() -> void:
	_bold_button.pressed.connect(func() -> void: _wrap("b"))
	_italic_button.pressed.connect(func() -> void: _wrap("i"))
	_underline_button.pressed.connect(func() -> void: _wrap("u"))
	_strike_button.pressed.connect(func() -> void: _wrap("s"))
	_code_button.pressed.connect(func() -> void: _wrap("code"))
	_h1_button.pressed.connect(func() -> void: _wrap_with_size(28))
	_h2_button.pressed.connect(func() -> void: _wrap_with_size(22))
	_h3_button.pressed.connect(func() -> void: _wrap_with_size(18))
	_list_button.pressed.connect(_apply_list)
	_link_button.pressed.connect(_apply_link)
	_internal_link_button.pressed.connect(_apply_internal_link)
	_color_apply_button.pressed.connect(_apply_color)
	_size_apply_button.pressed.connect(_apply_size_spin)
	_clear_button.pressed.connect(_clear_formatting)


func _wrap(tag: String) -> void:
	_wrap_with(tag, "[%s]" % tag, "[/%s]" % tag)


func _wrap_with_size(size_value: int) -> void:
	_wrap_with("size", "[font_size=%d]" % size_value, "[/font_size]")


func _apply_color() -> void:
	if _color_picker == null:
		return
	var color: Color = _color_picker.color
	var hex: String = "#%02x%02x%02x" % [
		int(round(color.r * 255.0)),
		int(round(color.g * 255.0)),
		int(round(color.b * 255.0)),
	]
	_wrap_with("color", "[color=%s]" % hex, "[/color]")


func _apply_size_spin() -> void:
	if _size_spin == null:
		return
	_wrap_with_size(int(_size_spin.value))


func _apply_internal_link() -> void:
	if _target == null:
		return
	var picker_scene: PackedScene = preload("res://src/editor/link_picker.tscn")
	var picker: LinkPicker = picker_scene.instantiate()
	get_tree().root.add_child(picker)
	var items_for_picker: Array = []
	var editor: Node = _find_editor_node()
	if editor != null and editor.has_method("all_items"):
		items_for_picker = editor.all_items()
	picker.link_chosen.connect(func(target: Dictionary) -> void:
		var kind: String = String(target.get("kind", ""))
		var id_v: String = String(target.get("id", ""))
		if kind == "" or id_v == "":
			picker.queue_free()
			return
		var spec: String = "%s:%s" % [kind, id_v]
		var sel_text: String = _target.get_selected_text()
		if sel_text == "":
			sel_text = String(target.get("display_label", id_v))
		_replace_selection_or_insert("[url=%s]%s[/url]" % [spec, sel_text])
		picker.queue_free()
	)
	picker.link_cleared.connect(func() -> void: picker.queue_free())
	picker.open_for({}, items_for_picker)


func _find_editor_node() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null


func _apply_link() -> void:
	if _target == null:
		return
	var selection_text: String = _target.get_selected_text()
	if selection_text == "":
		_insert_paired("[url=https://example.com]", "[/url]")
	else:
		_wrap_with("url", "[url=%s]" % selection_text, "[/url]")


func _apply_list() -> void:
	if _target == null:
		return
	var selection_text: String = _target.get_selected_text()
	var lines: PackedStringArray = (selection_text if selection_text != "" else "Item 1\nItem 2").split("\n")
	var list_block: String = "[ul]\n"
	for line: String in lines:
		var trimmed: String = line.strip_edges()
		if trimmed == "":
			continue
		list_block += "  " + trimmed + "\n"
	list_block += "[/ul]"
	_replace_selection_or_insert(list_block)


func _clear_formatting() -> void:
	if _target == null:
		return
	var selection_text: String = _target.get_selected_text()
	if selection_text == "":
		return
	var stripped: String = _strip_bbcode_tags(selection_text)
	_replace_selection_or_insert(stripped)


func _wrap_with(_tag: String, opening: String, closing: String) -> void:
	if _target == null:
		return
	var selection_text: String = _target.get_selected_text()
	if selection_text == "":
		_insert_paired(opening, closing)
		return
	_replace_selection_or_insert(opening + selection_text + closing)


func _insert_paired(opening: String, closing: String) -> void:
	if _target == null:
		return
	_target.insert_text_at_caret(opening + closing)
	var line: int = _target.get_caret_line()
	var col: int = _target.get_caret_column()
	_target.set_caret_column(col - closing.length(), false)
	_target.set_caret_line(line, false)
	_emit_change()


func _insert_at_caret(text_to_insert: String) -> void:
	if _target == null:
		return
	_target.insert_text_at_caret(text_to_insert)
	_emit_change()


func _replace_selection_or_insert(text_to_insert: String) -> void:
	if _target == null:
		return
	if _target.has_selection():
		var from_line: int = _target.get_selection_from_line()
		var from_col: int = _target.get_selection_from_column()
		var to_line: int = _target.get_selection_to_line()
		var to_col: int = _target.get_selection_to_column()
		_target.begin_complex_operation()
		_target.remove_text(from_line, from_col, to_line, to_col)
		_target.set_caret_line(from_line)
		_target.set_caret_column(from_col)
		_target.insert_text_at_caret(text_to_insert)
		_target.end_complex_operation()
	else:
		_target.insert_text_at_caret(text_to_insert)
	_emit_change()


func _emit_change() -> void:
	if _target != null:
		_target.grab_focus()
	emit_signal("text_changed")


static func _strip_bbcode_tags(input_text: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("\\[/?[a-zA-Z0-9_]+(=[^\\]]*)?\\]")
	return regex.sub(input_text, "", true)
