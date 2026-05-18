class_name EquationNode
extends BoardItem

const HEADER_HEIGHT: float = 24.0
const PADDING: Vector2 = Vector2(10, 8)
const SOLVED_HEIGHT: float = 22.0
const DARK_HEADER_BG: Color = Color(0.32, 0.40, 0.55, 1.0)
const LIGHT_HEADER_BG: Color = Color(0.55, 0.68, 0.88, 1.0)
const DARK_HEADER_FG: Color = Color(0.95, 0.97, 1.0, 1.0)
const LIGHT_HEADER_FG: Color = Color(0.06, 0.13, 0.22, 1.0)
const PREVIEW_BG: Color = Color(0.95, 0.95, 0.97, 1.0)
const PREVIEW_FG: Color = Color(0.05, 0.05, 0.10, 1.0)
const DARK_BORDER: Color = Color(0.55, 0.60, 0.68, 1.0)
const LIGHT_BORDER: Color = Color(0.62, 0.66, 0.74, 1.0)
const SOLVED_FG: Color = Color(0.10, 0.45, 0.18, 1.0)

enum DisplayMode { FORMATTED = 0, RAW = 1 }

@export var latex: String = "E = mc^2"
@export var font_size: int = 22
@export var display_mode: int = DisplayMode.FORMATTED

@onready var _preview: RichTextLabel = %Preview
@onready var _source_label: Label = %SourceLabel
@onready var _solved_label: Label = %SolvedLabel
@onready var _edit: TextEdit = %TextEdit
@onready var _mode_button: Button = %ModeButton

var _pre_edit: String = ""


func _ready() -> void:
	super._ready()
	ThemeManager.theme_applied.connect(_refresh_visuals)
	ThemeManager.node_palette_changed.connect(func(_a: Dictionary, _b: Dictionary) -> void: _refresh_visuals())
	_layout()
	if _mode_button != null:
		_mode_button.toggled.connect(_on_mode_toggled)
		_mode_button.button_pressed = display_mode == DisplayMode.RAW
		_update_mode_button_text()
	_refresh_visuals()
	_edit.focus_exited.connect(_commit_text)
	SelectionBus.selection_changed.connect(_on_selection_changed)


func default_size() -> Vector2:
	return Vector2(320, 160)


func display_name() -> String:
	return "Equation"


func _draw_body() -> void:
	_draw_rounded_panel(
		PREVIEW_BG,
		ThemeManager.themed_color(DARK_BORDER, LIGHT_BORDER),
		HEADER_HEIGHT,
		ThemeManager.heading_bg("equation"),
	)


func _refresh_visuals() -> void:
	if _source_label != null:
		_source_label.text = " " + latex
		_source_label.add_theme_color_override("font_color", ThemeManager.heading_fg("equation"))
	if _preview != null:
		_preview.add_theme_font_size_override("normal_font_size", font_size)
		_preview.add_theme_font_size_override("bold_font_size", font_size)
		_preview.add_theme_font_size_override("italics_font_size", font_size)
		_preview.add_theme_font_size_override("bold_italics_font_size", font_size)
		_preview.add_theme_font_size_override("mono_font_size", font_size)
		_preview.add_theme_color_override("default_color", PREVIEW_FG)
		if display_mode == DisplayMode.RAW:
			_preview.bbcode_enabled = true
			_preview.text = "[code]" + latex.replace("[", "[lb]") + "[/code]"
		else:
			_preview.bbcode_enabled = true
			_preview.text = LatexRenderer.to_bbcode(latex, font_size)
	if _solved_label != null:
		_update_solved_label()
	_layout()
	queue_redraw()


func _update_solved_label() -> void:
	if display_mode == DisplayMode.RAW or _solved_label == null:
		if _solved_label != null:
			_solved_label.visible = false
		return
	var solution: Dictionary = LatexSolver.try_solve(latex)
	if bool(solution.get("ok", false)):
		_solved_label.visible = true
		_solved_label.text = "  → " + String(solution.get("formatted", ""))
		_solved_label.add_theme_color_override("font_color", SOLVED_FG)
	else:
		_solved_label.visible = false


func _on_mode_toggled(pressed: bool) -> void:
	var new_mode: int = DisplayMode.RAW if pressed else DisplayMode.FORMATTED
	if new_mode == display_mode:
		return
	var prev: int = display_mode
	var editor: Node = _find_editor()
	if editor != null:
		History.push(ModifyPropertyCommand.new(editor, item_id, "display_mode", prev, new_mode))
	else:
		display_mode = new_mode
		_update_mode_button_text()
		_refresh_visuals()


func _update_mode_button_text() -> void:
	if _mode_button == null:
		return
	_mode_button.text = "Raw" if display_mode == DisplayMode.RAW else "Fmt"
	_mode_button.tooltip_text = "Toggle raw / formatted view"


func _on_selection_changed(selected: Array) -> void:
	if is_editing() and not selected.has(self):
		end_edit()


func _layout() -> void:
	if _mode_button != null:
		_mode_button.position = Vector2(size.x - 48.0, 2.0)
		_mode_button.size = Vector2(44.0, HEADER_HEIGHT - 4.0)
	if _source_label != null:
		_source_label.position = Vector2(4, 4)
		var label_width: float = size.x - 8 - (52.0 if _mode_button != null else 0.0)
		_source_label.size = Vector2(max(0.0, label_width), HEADER_HEIGHT - 8)
	var solved_visible: bool = _solved_label != null and _solved_label.visible
	var solved_pad: float = SOLVED_HEIGHT if solved_visible else 0.0
	if _preview != null:
		_preview.position = PADDING + Vector2(0, HEADER_HEIGHT)
		_preview.size = size - Vector2(PADDING.x * 2, HEADER_HEIGHT + PADDING.y * 2 + solved_pad)
	if _solved_label != null:
		_solved_label.position = Vector2(PADDING.x, size.y - PADDING.y - SOLVED_HEIGHT)
		_solved_label.size = Vector2(size.x - PADDING.x * 2, SOLVED_HEIGHT)
	if _edit != null:
		_edit.position = PADDING + Vector2(0, HEADER_HEIGHT)
		_edit.size = size - Vector2(PADDING.x * 2, HEADER_HEIGHT + PADDING.y * 2)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _on_edit_begin() -> void:
	_pre_edit = latex
	_edit.text = latex
	_preview.visible = false
	if _solved_label != null:
		_solved_label.visible = false
	_edit.visible = true
	_edit.grab_focus()
	_edit.select_all()


func _on_edit_end() -> void:
	var new_text: String = _edit.text
	_edit.release_focus()
	_edit.visible = false
	_preview.visible = true
	if new_text != _pre_edit:
		var editor: Node = _find_editor()
		if editor != null:
			History.push(ModifyPropertyCommand.new(editor, item_id, "latex", _pre_edit, new_text))
		else:
			latex = new_text
			_refresh_visuals()
			_layout()
	else:
		_refresh_visuals()
		_layout()


func _commit_text() -> void:
	if is_editing():
		end_edit()


func _gui_input(event: InputEvent) -> void:
	if is_editing():
		return
	super._gui_input(event)


func _find_editor() -> Node:
	return EditorLocator.find_for(self)


func serialize_payload() -> Dictionary:
	return {"latex": latex, "font_size": font_size, "display_mode": display_mode}


func deserialize_payload(d: Dictionary) -> void:
	latex = String(d.get("latex", latex))
	font_size = int(d.get("font_size", font_size))
	display_mode = int(d.get("display_mode", display_mode))
	if _preview != null:
		if _mode_button != null:
			_mode_button.set_pressed_no_signal(display_mode == DisplayMode.RAW)
			_update_mode_button_text()
		_refresh_visuals()
		_layout()


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"latex":
			latex = String(value)
			_refresh_visuals()
			_layout()
		"font_size":
			font_size = int(value)
			_refresh_visuals()
		"display_mode":
			display_mode = int(value)
			if _mode_button != null:
				_mode_button.set_pressed_no_signal(display_mode == DisplayMode.RAW)
				_update_mode_button_text()
			_refresh_visuals()
			_layout()


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/equation/equation_inspector.tscn")
	var inst: EquationInspector = scene.instantiate()
	inst.bind(self)
	return inst


func bulk_shareable_properties() -> Array:
	return [
		{"key": "font_size", "label": "Font size", "kind": "int_range", "min": 8, "max": 96},
	]
