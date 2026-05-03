class_name UrlNode
extends BoardItem

const PADDING: Vector2 = Vector2(10, 8)
const BG_COLOR: Color = Color(0.16, 0.20, 0.27, 1.0)
const ACCENT: Color = Color(0.40, 0.78, 1.0, 1.0)

@export var url: String = "https://example.com"
@export var title: String = "Untitled link"
@export var description: String = ""

@onready var _title_label: Label = %TitleLabel
@onready var _url_label: Label = %UrlLabel
@onready var _open_button: Button = %OpenButton


func _ready() -> void:
	super._ready()
	_open_button.pressed.connect(_open_in_browser)
	_layout()
	_refresh_visuals()


func default_size() -> Vector2:
	return Vector2(260, 90)


func display_name() -> String:
	return "URL Bookmark"


func _draw_body() -> void:
	_draw_rounded_panel(BG_COLOR, ACCENT.darkened(0.4))
	var accent_strip: StyleBoxFlat = StyleBoxFlat.new()
	accent_strip.bg_color = ACCENT
	accent_strip.corner_radius_top_left = NODE_CORNER_RADIUS
	accent_strip.corner_radius_bottom_left = NODE_CORNER_RADIUS
	accent_strip.corner_radius_top_right = 0
	accent_strip.corner_radius_bottom_right = 0
	draw_style_box(accent_strip, Rect2(Vector2.ZERO, Vector2(4.0, size.y)))


func _refresh_visuals() -> void:
	if _title_label != null:
		_title_label.text = title if title != "" else url
		_title_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	if _url_label != null:
		_url_label.text = url
		_url_label.add_theme_color_override("font_color", ACCENT)
	queue_redraw()


func _layout() -> void:
	if _title_label != null:
		_title_label.position = PADDING + Vector2(8, 0)
		_title_label.size = Vector2(size.x - PADDING.x * 2 - 8 - 60, 24)
	if _url_label != null:
		_url_label.position = PADDING + Vector2(8, 28)
		_url_label.size = Vector2(size.x - PADDING.x * 2 - 8 - 60, 18)
	if _open_button != null:
		_open_button.position = Vector2(size.x - 60, PADDING.y)
		_open_button.size = Vector2(50, size.y - PADDING.y * 2)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _open_in_browser() -> void:
	if url.strip_edges() != "":
		OS.shell_open(url)


func serialize_payload() -> Dictionary:
	return {"url": url, "title": title, "description": description}


func deserialize_payload(d: Dictionary) -> void:
	url = String(d.get("url", url))
	title = String(d.get("title", title))
	description = String(d.get("description", description))
	if _title_label != null:
		_refresh_visuals()


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"url":
			url = String(value)
			_refresh_visuals()
		"title":
			title = String(value)
			_refresh_visuals()
		"description":
			description = String(value)


func build_inspector() -> Control:
	var v: VBoxContainer = VBoxContainer.new()
	var t_label: Label = Label.new(); t_label.text = "Title"; v.add_child(t_label)
	var t_edit: LineEdit = LineEdit.new(); t_edit.text = title; v.add_child(t_edit)
	var u_label: Label = Label.new(); u_label.text = "URL"; v.add_child(u_label)
	var u_edit: LineEdit = LineEdit.new(); u_edit.text = url; v.add_child(u_edit)
	var d_label: Label = Label.new(); d_label.text = "Description"; v.add_child(d_label)
	var d_edit: TextEdit = TextEdit.new(); d_edit.text = description; d_edit.custom_minimum_size = Vector2(0, 80); v.add_child(d_edit)
	var editor: Node = _find_editor()
	t_edit.focus_exited.connect(func() -> void: _commit_property(editor, "title", t_edit.text))
	u_edit.focus_exited.connect(func() -> void: _commit_property(editor, "url", u_edit.text))
	d_edit.focus_exited.connect(func() -> void: _commit_property(editor, "description", d_edit.text))
	return v


func _commit_property(editor: Node, key: String, new_value: Variant) -> void:
	if editor == null:
		apply_property(key, new_value)
		return
	var current_value: Variant = ""
	match key:
		"title": current_value = title
		"url": current_value = url
		"description": current_value = description
	if str(current_value) == str(new_value):
		return
	History.push(ModifyPropertyCommand.new(editor, item_id, key, current_value, new_value))


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null
