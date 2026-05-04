class_name RichTextNode
extends BoardItem

const PADDING: Vector2 = Vector2(10, 8)
const TOOLBAR_GAP: float = 6.0
const DEFAULT_FONT_SIZE: int = 16
const LEGACY_DEFAULT_BG: Color = Color(0.13, 0.14, 0.18, 1.0)
const LEGACY_DEFAULT_FG: Color = Color(0.95, 0.96, 0.98, 1.0)
const DEFAULT_BBCODE: String = "[b]Heading[/b]\nDouble-click to edit. Use [color=#7cf]BBCode[/color] like [i]italics[/i] and [b]bold[/b]."

@export var bbcode_text: String = DEFAULT_BBCODE
@export var font_size: int = DEFAULT_FONT_SIZE
@export var bg_color: Color = Color(0, 0, 0, 1)
@export var fg_color: Color = Color(1, 1, 1, 1)
@export var bg_color_custom: bool = false
@export var fg_color_custom: bool = false

@onready var _rich: RichTextLabel = %RichTextLabel
@onready var _edit: TextEdit = %TextEdit
@onready var _toolbar_host: PanelContainer = %ToolbarHost
@onready var _toolbar: BBCodeToolbar = %FormatToolbar

var _pre_edit_text: String = ""


func _ready() -> void:
	super._ready()
	_toolbar.bind(_edit)
	_edit.gui_input.connect(_on_edit_gui_input)
	SelectionBus.selection_changed.connect(_on_selection_changed)
	_toolbar_host.minimum_size_changed.connect(_position_toolbar)
	_rich.meta_clicked.connect(_on_meta_clicked)
	_rich.meta_underlined = true
	ThemeManager.theme_applied.connect(_refresh_visuals)
	ThemeManager.node_palette_changed.connect(_on_node_palette_changed)
	_layout()
	_refresh_visuals()


func resolved_bg_color() -> Color:
	return bg_color if bg_color_custom else ThemeManager.node_bg_color()


func resolved_fg_color() -> Color:
	return fg_color if fg_color_custom else ThemeManager.node_fg_color()


func _on_node_palette_changed(_old: Dictionary, _new: Dictionary) -> void:
	_refresh_visuals()


func _on_meta_clicked(meta: Variant) -> void:
	var spec: String = String(meta)
	if spec == "":
		return
	if spec.begins_with("board:"):
		var board_id: String = spec.substr(6)
		if AppState.current_project != null:
			AppState.navigate_to_board(board_id)
		return
	if spec.begins_with("item:"):
		var item_id_v: String = spec.substr(5)
		var editor: Node = _find_editor()
		if editor != null and editor.has_method("navigate_to_backlink") and AppState.current_board != null:
			editor.navigate_to_backlink(AppState.current_board.id, item_id_v)
		return
	if spec.begins_with("http://") or spec.begins_with("https://") or spec.begins_with("mailto:"):
		OS.shell_open(spec)
		return
	OS.shell_open(spec)


func default_size() -> Vector2:
	return Vector2(300, 160)


func display_name() -> String:
	return "Rich Text"


func _draw_body() -> void:
	var bg: Color = resolved_bg_color()
	var border_color: Color = SELECTION_OUTLINE_COLOR if is_editing() else bg.darkened(0.25)
	var border_width: int = 2 if is_editing() else NODE_BORDER_WIDTH
	_draw_rounded_panel(bg, border_color, 0.0, Color(0, 0, 0, 0), border_width)


func _refresh_visuals() -> void:
	var fg: Color = resolved_fg_color()
	if _rich != null:
		_rich.bbcode_enabled = true
		_rich.text = bbcode_text
		_rich.add_theme_color_override("default_color", fg)
		_rich.add_theme_font_size_override("normal_font_size", font_size)
		_rich.add_theme_font_size_override("bold_font_size", font_size)
		_rich.add_theme_font_size_override("italics_font_size", font_size)
		_rich.add_theme_font_size_override("mono_font_size", font_size)
	if _edit != null:
		_edit.add_theme_font_size_override("font_size", font_size)
		_edit.add_theme_color_override("font_color", fg)
	queue_redraw()


func _layout() -> void:
	if _rich != null:
		_rich.position = PADDING
		_rich.size = size - PADDING * 2
	if _edit != null:
		_edit.position = PADDING
		_edit.size = size - PADDING * 2
	_position_toolbar()


func _position_toolbar() -> void:
	if _toolbar_host == null:
		return
	var minsize: Vector2 = _toolbar_host.get_combined_minimum_size()
	if minsize.x <= 0.0:
		minsize.x = 480.0
	if minsize.y <= 0.0:
		minsize.y = 36.0
	_toolbar_host.size = minsize
	_toolbar_host.position = Vector2(0.0, -minsize.y - TOOLBAR_GAP)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _on_edit_begin() -> void:
	_pre_edit_text = bbcode_text
	_edit.text = bbcode_text
	_edit.visible = true
	_rich.visible = false
	_toolbar_host.visible = true
	_position_toolbar()
	_edit.grab_focus()
	_edit.select_all()
	queue_redraw()


func _on_edit_end() -> void:
	var new_text: String = _edit.text
	_edit.release_focus()
	_edit.visible = false
	_toolbar_host.visible = false
	_rich.visible = true
	_commit_text_change(new_text)
	queue_redraw()


func _commit_text_change(new_text: String) -> void:
	if new_text == _pre_edit_text:
		_refresh_visuals()
		return
	var editor: Node = _find_editor()
	if editor != null:
		History.push(ModifyPropertyCommand.new(editor, item_id, "bbcode_text", _pre_edit_text, new_text))
	else:
		bbcode_text = new_text
		_refresh_visuals()


func _cancel_edit() -> void:
	if not is_editing():
		return
	_edit.text = _pre_edit_text
	end_edit()


func _on_edit_gui_input(event: InputEvent) -> void:
	if not is_editing():
		return
	if event is InputEventKey:
		var ke: InputEventKey = event
		if not ke.pressed or ke.echo:
			return
		if ke.keycode == KEY_ESCAPE:
			_cancel_edit()
			get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_ENTER and ke.ctrl_pressed:
			end_edit()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not is_editing():
		return
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed:
		return
	var click_global: Vector2 = mb.global_position
	if _is_global_point_inside_editor(click_global):
		return
	end_edit()


func _is_global_point_inside_editor(global_point: Vector2) -> bool:
	if get_global_rect().has_point(global_point):
		return true
	if _toolbar_host != null and _toolbar_host.visible and _toolbar_host.get_global_rect().has_point(global_point):
		return true
	return false


func _on_selection_changed(selected: Array) -> void:
	if is_editing() and not selected.has(self):
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
		"bbcode_text": bbcode_text,
		"font_size": font_size,
		"bg_color_custom": bg_color_custom,
		"fg_color_custom": fg_color_custom,
	}
	if bg_color_custom:
		out["bg_color"] = ColorUtil.to_array(bg_color)
	if fg_color_custom:
		out["fg_color"] = ColorUtil.to_array(fg_color)
	return out


func deserialize_payload(d: Dictionary) -> void:
	bbcode_text = String(d.get("bbcode_text", bbcode_text))
	font_size = int(d.get("font_size", font_size))
	if d.has("bg_color_custom"):
		bg_color_custom = bool(d["bg_color_custom"])
		if bg_color_custom and d.has("bg_color"):
			bg_color = ColorUtil.from_array(d["bg_color"], bg_color)
	elif d.has("bg_color"):
		var stored_bg: Color = ColorUtil.from_array(d["bg_color"], LEGACY_DEFAULT_BG)
		bg_color_custom = stored_bg != LEGACY_DEFAULT_BG
		if bg_color_custom:
			bg_color = stored_bg
	if d.has("fg_color_custom"):
		fg_color_custom = bool(d["fg_color_custom"])
		if fg_color_custom and d.has("fg_color"):
			fg_color = ColorUtil.from_array(d["fg_color"], fg_color)
	elif d.has("fg_color"):
		var stored_fg: Color = ColorUtil.from_array(d["fg_color"], LEGACY_DEFAULT_FG)
		fg_color_custom = stored_fg != LEGACY_DEFAULT_FG
		if fg_color_custom:
			fg_color = stored_fg
	if _rich != null:
		_refresh_visuals()


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"bbcode_text":
			bbcode_text = String(value)
		"font_size":
			font_size = int(value)
		"bg_color":
			if value == null:
				bg_color_custom = false
			else:
				bg_color = ColorUtil.from_array(value, bg_color)
				bg_color_custom = true
		"fg_color":
			if value == null:
				fg_color_custom = false
			else:
				fg_color = ColorUtil.from_array(value, fg_color)
				fg_color_custom = true
	_refresh_visuals()


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/rich_text/rich_text_inspector.tscn")
	var inst: RichTextInspector = scene.instantiate()
	inst.bind(self)
	return inst
