class_name GroupNode
extends BoardItem

const TITLE_HEIGHT: float = 28.0
const TITLE_PADDING: Vector2 = Vector2(10, 4)
const LEGACY_DEFAULT_BG: Color = Color(0.32, 0.18, 0.42, 0.55)
const LEGACY_DEFAULT_TITLE_BG: Color = Color(0.32, 0.18, 0.42, 1.0)
const LEGACY_DEFAULT_TITLE_FG: Color = Color(0.97, 0.97, 0.99, 1.0)
const BODY_ALPHA: float = 0.55

@export var title: String = "Group"
@export var bg_color: Color = Color(0, 0, 0, 0)
@export var title_bg_color: Color = Color(0, 0, 0, 1)
@export var title_fg_color: Color = Color(1, 1, 1, 1)
@export var bg_color_custom: bool = false
@export var title_bg_color_custom: bool = false
@export var title_fg_color_custom: bool = false

@onready var _title_label: Label = %TitleLabel
@onready var _title_edit: LineEdit = %TitleEdit

var _pre_edit_title: String = ""


func _ready() -> void:
	super._ready()
	_title_edit.focus_exited.connect(_on_edit_focus_exited)
	_title_edit.text_submitted.connect(_on_edit_submitted)
	SelectionBus.selection_changed.connect(_on_selection_changed)
	ThemeManager.theme_applied.connect(_refresh_visuals)
	ThemeManager.node_palette_changed.connect(_on_node_palette_changed)
	_layout()
	_refresh_visuals()


func resolved_title_bg_color() -> Color:
	return title_bg_color if title_bg_color_custom else ThemeManager.heading_bg("group")


func resolved_title_fg_color() -> Color:
	return title_fg_color if title_fg_color_custom else ThemeManager.heading_fg("group")


func resolved_bg_color() -> Color:
	if bg_color_custom:
		return bg_color
	var body: Color = ThemeManager.node_bg_color()
	body.a = BODY_ALPHA
	return body


func _on_node_palette_changed(_old: Dictionary, _new: Dictionary) -> void:
	_refresh_visuals()


func default_size() -> Vector2:
	return Vector2(360, 240)


func display_name() -> String:
	return "Group"


func minimum_item_size() -> Vector2:
	return Vector2(120.0, TITLE_HEIGHT + 32.0)


func _draw_body() -> void:
	var body_bg: Color = resolved_bg_color()
	var heading_bg: Color = resolved_title_bg_color()
	_draw_rounded_panel(body_bg, heading_bg.darkened(0.2), TITLE_HEIGHT, heading_bg)


func _refresh_visuals() -> void:
	var fg: Color = resolved_title_fg_color()
	if _title_label != null:
		_title_label.text = title
		_title_label.add_theme_color_override("font_color", fg)
	if _title_edit != null:
		_title_edit.add_theme_color_override("font_color", fg)
	queue_redraw()


func _layout() -> void:
	if _title_label != null:
		_title_label.position = TITLE_PADDING
		_title_label.size = Vector2(size.x - TITLE_PADDING.x * 2, TITLE_HEIGHT - TITLE_PADDING.y * 2)
	if _title_edit != null:
		_title_edit.position = TITLE_PADDING
		_title_edit.size = Vector2(size.x - TITLE_PADDING.x * 2, TITLE_HEIGHT - TITLE_PADDING.y * 2)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _on_edit_begin() -> void:
	_pre_edit_title = title
	_title_edit.text = title
	_title_label.visible = false
	_title_edit.visible = true
	_title_edit.grab_focus()
	_title_edit.select_all()


func _on_edit_end() -> void:
	var new_title: String = _title_edit.text
	_title_edit.release_focus()
	_title_edit.visible = false
	_title_label.visible = true
	if new_title != _pre_edit_title:
		var editor: Node = _find_editor()
		if editor != null:
			History.push(ModifyPropertyCommand.new(editor, item_id, "title", _pre_edit_title, new_title))
		else:
			title = new_title
			_refresh_visuals()
	else:
		_refresh_visuals()


func _on_edit_focus_exited() -> void:
	if is_editing():
		end_edit()


func _on_edit_submitted(_t: String) -> void:
	if is_editing():
		end_edit()


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
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and mb.double_click:
			var local := get_local_mouse_position()
			if local.y <= TITLE_HEIGHT:
				begin_edit()
				accept_event()
				return
	super._gui_input(event)


func serialize_payload() -> Dictionary:
	var out: Dictionary = {
		"title": title,
		"bg_color_custom": bg_color_custom,
		"title_bg_color_custom": title_bg_color_custom,
		"title_fg_color_custom": title_fg_color_custom,
	}
	if bg_color_custom:
		out["bg_color"] = ColorUtil.to_array(bg_color)
	if title_bg_color_custom:
		out["title_bg_color"] = ColorUtil.to_array(title_bg_color)
	if title_fg_color_custom:
		out["title_fg_color"] = ColorUtil.to_array(title_fg_color)
	return out


func deserialize_payload(d: Dictionary) -> void:
	title = String(d.get("title", title))
	_load_color_field(d, "bg_color", "bg_color_custom", LEGACY_DEFAULT_BG, _set_bg)
	_load_color_field(d, "title_bg_color", "title_bg_color_custom", LEGACY_DEFAULT_TITLE_BG, _set_title_bg)
	_load_color_field(d, "title_fg_color", "title_fg_color_custom", LEGACY_DEFAULT_TITLE_FG, _set_title_fg)
	if _title_label != null:
		_refresh_visuals()


func _set_bg(c: Color) -> void:
	bg_color = c


func _set_title_bg(c: Color) -> void:
	title_bg_color = c


func _set_title_fg(c: Color) -> void:
	title_fg_color = c


func _load_color_field(d: Dictionary, color_key: String, custom_key: String, legacy: Color, setter: Callable) -> void:
	if d.has(custom_key):
		var is_custom: bool = bool(d[custom_key])
		set(custom_key, is_custom)
		if is_custom and d.has(color_key):
			setter.call(ColorUtil.from_array(d[color_key], legacy))
		return
	if not d.has(color_key):
		return
	var stored: Color = ColorUtil.from_array(d[color_key], legacy)
	var is_legacy: bool = stored == legacy
	set(custom_key, not is_legacy)
	if not is_legacy:
		setter.call(stored)


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"title":
			title = String(value)
		"bg_color":
			if value == null:
				bg_color_custom = false
			else:
				bg_color = ColorUtil.from_array(value, bg_color)
				bg_color_custom = true
		"title_bg_color":
			if value == null:
				title_bg_color_custom = false
			else:
				title_bg_color = ColorUtil.from_array(value, title_bg_color)
				title_bg_color_custom = true
		"title_fg_color":
			if value == null:
				title_fg_color_custom = false
			else:
				title_fg_color = ColorUtil.from_array(value, title_fg_color)
				title_fg_color_custom = true
	_refresh_visuals()


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/group/group_inspector.tscn")
	var inst: GroupInspector = scene.instantiate()
	inst.bind(self)
	return inst
