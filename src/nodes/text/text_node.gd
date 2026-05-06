class_name TextNode
extends BoardItem

const PADDING: Vector2 = Vector2(10, 8)
const DEFAULT_FONT_SIZE: int = 18
const LEGACY_DEFAULT_BG: Color = Color(0.16, 0.17, 0.20, 1.0)
const LEGACY_DEFAULT_FG: Color = Color(0.95, 0.96, 0.98, 1.0)

@export var text: String = "Double-click to edit"
@export var font_size: int = DEFAULT_FONT_SIZE
@export var bg_color: Color = Color(0, 0, 0, 1)
@export var fg_color: Color = Color(1, 1, 1, 1)
@export var bg_color_custom: bool = false
@export var fg_color_custom: bool = false
@export var auto_width: bool = true
@export var auto_height: bool = true

@onready var _label: Label = %Label
@onready var _edit: TextEdit = %TextEdit

var _pre_edit_text: String = ""
var _in_auto_fit: bool = false
var _auto_fit_pending: bool = false


func _ready() -> void:
	super._ready()
	_label.clip_contents = true
	_edit.focus_exited.connect(_commit_text)
	SelectionBus.selection_changed.connect(_on_selection_changed)
	ThemeManager.theme_applied.connect(_on_theme_applied)
	ThemeManager.node_palette_changed.connect(_on_node_palette_changed)
	_layout()
	_refresh_visuals()
	_request_auto_fit()


func resolved_bg_color() -> Color:
	return bg_color if bg_color_custom else ThemeManager.node_bg_color()


func resolved_fg_color() -> Color:
	return fg_color if fg_color_custom else ThemeManager.node_fg_color()


func _on_theme_applied() -> void:
	_refresh_visuals()


func _on_node_palette_changed(_old: Dictionary, _new: Dictionary) -> void:
	_refresh_visuals()


func _on_selection_changed(selected: Array) -> void:
	if not is_editing():
		return
	if not selected.has(self):
		_commit_text()


func default_size() -> Vector2:
	return Vector2(220, 90)


func _draw_body() -> void:
	var bg: Color = resolved_bg_color()
	_draw_rounded_panel(bg, bg.darkened(0.25))


func _refresh_visuals() -> void:
	var fg: Color = resolved_fg_color()
	if _label != null:
		_label.text = text
		_label.add_theme_font_size_override("font_size", font_size)
		_label.add_theme_color_override("font_color", fg)
	if _edit != null:
		_edit.add_theme_font_size_override("font_size", font_size)
		_edit.add_theme_color_override("font_color", fg)
	queue_redraw()
	_request_auto_fit()


func _layout() -> void:
	if _label != null:
		_label.position = PADDING
		_label.size = size - PADDING * 2
	if _edit != null:
		_edit.position = PADDING
		_edit.size = size - PADDING * 2


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
		if not _in_auto_fit:
			_request_auto_fit()


func _request_auto_fit() -> void:
	if _auto_fit_pending:
		return
	if _label == null:
		return
	if not auto_width and not auto_height:
		return
	_auto_fit_pending = true
	call_deferred("_apply_auto_fit")


func _apply_auto_fit() -> void:
	_auto_fit_pending = false
	if _in_auto_fit:
		return
	if _label == null:
		return
	if not auto_width and not auto_height:
		return
	if not is_inside_tree():
		return
	_in_auto_fit = true
	var pad: Vector2 = PADDING * 2.0
	var min_size: Vector2 = minimum_item_size()
	var new_size: Vector2 = size
	if auto_width:
		_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		var natural: Vector2 = _label.get_minimum_size()
		new_size.x = max(min_size.x, ceil(natural.x + pad.x))
		if auto_height:
			new_size.y = max(min_size.y, ceil(natural.y + pad.y))
	else:
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var available_w: float = max(1.0, size.x - pad.x)
		_label.size = Vector2(available_w, _label.size.y)
		if auto_height:
			var line_count: int = max(1, _label.get_line_count())
			var line_h: int = _label.get_line_height()
			var line_sp: int = 0
			if _label.has_theme_constant("line_spacing"):
				line_sp = _label.get_theme_constant("line_spacing")
			var total_h: float = float(line_count * line_h) + float(max(0, line_count - 1) * line_sp)
			new_size.y = max(min_size.y, ceil(total_h + pad.y))
	if new_size != size:
		size = new_size
	_layout()
	_in_auto_fit = false


func _on_edit_begin() -> void:
	_pre_edit_text = text
	_edit.text = text
	_label.visible = false
	_edit.visible = true
	_edit.grab_focus()
	_edit.select_all()


func _on_edit_end() -> void:
	var new_text: String = _edit.text
	_edit.release_focus()
	_edit.visible = false
	_label.visible = true
	if new_text != _pre_edit_text:
		var editor: Node = _find_editor()
		if editor != null:
			History.push(ModifyPropertyCommand.new(editor, item_id, "text", _pre_edit_text, new_text))
		else:
			text = new_text
			_refresh_visuals()
	else:
		_refresh_visuals()


func _commit_text() -> void:
	if is_editing():
		end_edit()


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null


func _gui_input(event: InputEvent) -> void:
	if is_editing():
		return
	super._gui_input(event)


func serialize_payload() -> Dictionary:
	var out: Dictionary = {
		"text": text,
		"font_size": font_size,
		"bg_color_custom": bg_color_custom,
		"fg_color_custom": fg_color_custom,
		"auto_width": auto_width,
		"auto_height": auto_height,
	}
	if bg_color_custom:
		out["bg_color"] = [bg_color.r, bg_color.g, bg_color.b, bg_color.a]
	if fg_color_custom:
		out["fg_color"] = [fg_color.r, fg_color.g, fg_color.b, fg_color.a]
	return out


func deserialize_payload(d: Dictionary) -> void:
	text = String(d.get("text", text))
	font_size = int(d.get("font_size", font_size))
	if d.has("bg_color_custom"):
		bg_color_custom = bool(d["bg_color_custom"])
		if bg_color_custom and d.has("bg_color"):
			bg_color = _color_from(d["bg_color"], bg_color)
	elif d.has("bg_color"):
		var stored_bg: Color = _color_from(d["bg_color"], LEGACY_DEFAULT_BG)
		bg_color_custom = stored_bg != LEGACY_DEFAULT_BG
		if bg_color_custom:
			bg_color = stored_bg
	if d.has("fg_color_custom"):
		fg_color_custom = bool(d["fg_color_custom"])
		if fg_color_custom and d.has("fg_color"):
			fg_color = _color_from(d["fg_color"], fg_color)
	elif d.has("fg_color"):
		var stored_fg: Color = _color_from(d["fg_color"], LEGACY_DEFAULT_FG)
		fg_color_custom = stored_fg != LEGACY_DEFAULT_FG
		if fg_color_custom:
			fg_color = stored_fg
	auto_width = bool(d.get("auto_width", false))
	auto_height = bool(d.get("auto_height", false))
	if _label != null:
		_refresh_visuals()


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"text":
			text = String(value)
			_refresh_visuals()
		"font_size":
			font_size = int(value)
			_refresh_visuals()
		"bg_color":
			if value == null:
				bg_color_custom = false
			else:
				bg_color = _color_from(value, bg_color)
				bg_color_custom = true
			_refresh_visuals()
		"fg_color":
			if value == null:
				fg_color_custom = false
			else:
				fg_color = _color_from(value, fg_color)
				fg_color_custom = true
			_refresh_visuals()
		"auto_width":
			auto_width = bool(value)
			_refresh_visuals()
		"auto_height":
			auto_height = bool(value)
			_refresh_visuals()


func display_name() -> String:
	return "Text"


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/text/text_inspector.tscn")
	var inst: TextInspector = scene.instantiate()
	inst.bind(self)
	return inst


func bulk_shareable_properties() -> Array:
	return [
		{"key": "bg_color", "label": "Background", "kind": "color_with_reset"},
		{"key": "fg_color", "label": "Text color", "kind": "color_with_reset"},
		{"key": "font_size", "label": "Font size", "kind": "int_range", "min": 6, "max": 96},
		{"key": "auto_width", "label": "Auto width", "kind": "bool"},
		{"key": "auto_height", "label": "Auto height", "kind": "bool"},
	]


func _color_from(raw: Variant, fallback: Color) -> Color:
	if typeof(raw) == TYPE_COLOR:
		return raw
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 3:
		var arr: Array = raw
		var a: float = 1.0 if arr.size() < 4 else float(arr[3])
		return Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
	return fallback
