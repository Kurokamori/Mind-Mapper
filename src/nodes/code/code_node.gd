class_name CodeNode
extends BoardItem

const PADDING: Vector2 = Vector2(8, 28)
const HEADER_HEIGHT: float = 24.0
const LANGUAGES: Array[String] = ["plaintext", "gdscript", "python", "javascript", "typescript", "rust", "go", "c", "cpp", "json", "html", "css", "markdown"]

const DARK_HEADER_BG: Color = Color(0.16, 0.18, 0.22, 1.0)
const LIGHT_HEADER_BG: Color = Color(0.78, 0.82, 0.88, 1.0)
const DARK_HEADER_FG: Color = Color(0.78, 0.85, 0.95, 1.0)
const LIGHT_HEADER_FG: Color = Color(0.10, 0.13, 0.20, 1.0)
const DARK_BORDER: Color = Color(0.30, 0.34, 0.40, 1.0)
const LIGHT_BORDER: Color = Color(0.62, 0.66, 0.74, 1.0)

@export var code: String = ""
@export var language: String = "plaintext"
@export var font_size: int = 13

@onready var _lang_label: Label = %LangLabel
@onready var _code_edit: CodeEdit = %CodeEdit


func _ready() -> void:
	super._ready()
	ThemeManager.theme_applied.connect(_refresh_visuals)
	ThemeManager.node_palette_changed.connect(func(_a: Dictionary, _b: Dictionary) -> void: _refresh_visuals())
	_layout()
	_refresh_visuals()
	_code_edit.text_changed.connect(_on_text_changed)
	_code_edit.focus_exited.connect(_commit_text)
	SelectionBus.selection_changed.connect(_on_selection_changed)


func default_size() -> Vector2:
	return Vector2(360, 200)


func display_name() -> String:
	return "Code"


func _on_selection_changed(selected: Array) -> void:
	if is_editing() and not selected.has(self):
		end_edit()


func _draw_body() -> void:
	_draw_rounded_panel(
		ThemeManager.node_bg_color(),
		ThemeManager.themed_color(DARK_BORDER, LIGHT_BORDER),
		HEADER_HEIGHT,
		ThemeManager.heading_bg("code"),
	)


func _refresh_visuals() -> void:
	if _lang_label != null:
		_lang_label.text = " " + language
		_lang_label.add_theme_color_override("font_color", ThemeManager.heading_fg("code"))
	if _code_edit != null:
		_code_edit.text = code
		_code_edit.add_theme_font_size_override("font_size", font_size)
	queue_redraw()


func _layout() -> void:
	if _lang_label != null:
		_lang_label.position = Vector2(6, 4)
		_lang_label.size = Vector2(size.x - 12, HEADER_HEIGHT - 8)
	if _code_edit != null:
		_code_edit.position = Vector2(PADDING.x, HEADER_HEIGHT)
		_code_edit.size = size - Vector2(PADDING.x * 2, HEADER_HEIGHT + 4)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _on_edit_begin() -> void:
	_code_edit.editable = true
	_code_edit.grab_focus()


func _on_edit_end() -> void:
	_code_edit.release_focus()
	_commit_text()


func _on_text_changed() -> void:
	pass


func _commit_text() -> void:
	if _code_edit == null:
		return
	var new_code: String = _code_edit.text
	if new_code == code:
		return
	var editor: Node = _find_editor()
	if editor != null:
		History.push_already_done(ModifyPropertyCommand.new(editor, item_id, "code", code, new_code))
	code = new_code


func _gui_input(event: InputEvent) -> void:
	if is_editing():
		return
	super._gui_input(event)


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null


func serialize_payload() -> Dictionary:
	return {"code": code, "language": language, "font_size": font_size}


func deserialize_payload(d: Dictionary) -> void:
	code = String(d.get("code", code))
	language = String(d.get("language", language))
	font_size = int(d.get("font_size", font_size))
	if _lang_label != null:
		_refresh_visuals()


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"code":
			code = String(value)
			if _code_edit != null and _code_edit.text != code:
				_code_edit.text = code
		"language":
			language = String(value)
			_refresh_visuals()
		"font_size":
			font_size = int(value)
			_refresh_visuals()


func build_inspector() -> Control:
	var v: VBoxContainer = VBoxContainer.new()
	var lang_row: HBoxContainer = HBoxContainer.new()
	var lang_label: Label = Label.new(); lang_label.text = "Language"; lang_row.add_child(lang_label)
	var lang_opt: OptionButton = OptionButton.new()
	for i in range(LANGUAGES.size()):
		lang_opt.add_item(LANGUAGES[i], i)
		if LANGUAGES[i] == language:
			lang_opt.select(i)
	lang_row.add_child(lang_opt)
	v.add_child(lang_row)
	var size_row: HBoxContainer = HBoxContainer.new()
	var size_label: Label = Label.new(); size_label.text = "Font size"; size_row.add_child(size_label)
	var spin: SpinBox = SpinBox.new(); spin.min_value = 8; spin.max_value = 48; spin.value = font_size
	size_row.add_child(spin)
	v.add_child(size_row)
	var editor: Node = _find_editor()
	lang_opt.item_selected.connect(func(i: int) -> void:
		var new_lang: String = LANGUAGES[i]
		if new_lang == language: return
		if editor == null:
			language = new_lang
			_refresh_visuals()
			return
		History.push(ModifyPropertyCommand.new(editor, item_id, "language", language, new_lang))
	)
	spin.value_changed.connect(func(val: float) -> void:
		var v_int: int = int(val)
		if v_int == font_size: return
		if editor == null:
			font_size = v_int
			_refresh_visuals()
			return
		History.push(ModifyPropertyCommand.new(editor, item_id, "font_size", font_size, v_int))
	)
	return v
