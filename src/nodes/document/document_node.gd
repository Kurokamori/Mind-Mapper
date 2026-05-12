class_name DocumentNode
extends BoardItem

const PADDING: Vector2 = Vector2(10, 8)
const TITLE_HEIGHT: float = 26.0
const TITLE_GAP: float = 4.0
const DEFAULT_TITLE: String = "Untitled Document"
const DEFAULT_MARKDOWN: String = "# Document\n\nDouble-click to open the editor.\n\nWrite **Markdown** or [b]BBCode[/b]. Imports: txt, md, rtf, docx, pdf."
const DEFAULT_FONT_SIZE: int = 14
const DEFAULT_TITLE_FONT_SIZE: int = 18
const DEFAULT_H1_FONT_SIZE: int = 28
const DEFAULT_H2_FONT_SIZE: int = 24
const DEFAULT_H3_FONT_SIZE: int = 20
const DEFAULT_H4_FONT_SIZE: int = 18
const DEFAULT_H5_FONT_SIZE: int = 16
const DEFAULT_H6_FONT_SIZE: int = 15
const PREVIEW_DARK_HEADER: Color = Color(0.18, 0.20, 0.26, 1.0)
const PREVIEW_LIGHT_HEADER: Color = Color(0.84, 0.87, 0.92, 1.0)

@export var title: String = DEFAULT_TITLE
@export var markdown_text: String = DEFAULT_MARKDOWN
@export var font_size: int = DEFAULT_FONT_SIZE
@export var title_font_size: int = DEFAULT_TITLE_FONT_SIZE
@export var h1_font_size: int = DEFAULT_H1_FONT_SIZE
@export var h2_font_size: int = DEFAULT_H2_FONT_SIZE
@export var h3_font_size: int = DEFAULT_H3_FONT_SIZE
@export var h4_font_size: int = DEFAULT_H4_FONT_SIZE
@export var h5_font_size: int = DEFAULT_H5_FONT_SIZE
@export var h6_font_size: int = DEFAULT_H6_FONT_SIZE
@export var bg_color: Color = Color(0, 0, 0, 1)
@export var fg_color: Color = Color(1, 1, 1, 1)
@export var bg_color_custom: bool = false
@export var fg_color_custom: bool = false

@onready var _title_label: Label = %TitleLabel
@onready var _preview: RichTextLabel = %Preview


func _ready() -> void:
	super._ready()
	ThemeManager.theme_applied.connect(_refresh_visuals)
	ThemeManager.node_palette_changed.connect(_on_node_palette_changed)
	_preview.meta_clicked.connect(_on_meta_clicked)
	_preview.meta_underlined = true
	_layout()
	_refresh_visuals()


func default_size() -> Vector2:
	return Vector2(320, 260)


func display_name() -> String:
	return "Document"


func resolved_bg_color() -> Color:
	return bg_color if bg_color_custom else ThemeManager.node_bg_color()


func resolved_fg_color() -> Color:
	return fg_color if fg_color_custom else ThemeManager.node_fg_color()


func _on_node_palette_changed(_old: Dictionary, _new: Dictionary) -> void:
	_refresh_visuals()


func _draw_body() -> void:
	var bg: Color = resolved_bg_color()
	var border_color: Color = SELECTION_OUTLINE_COLOR if is_editing() else bg.darkened(0.25)
	var border_width: int = 2 if is_editing() else NODE_BORDER_WIDTH
	var header_bg: Color = ThemeManager.themed_color(PREVIEW_DARK_HEADER, PREVIEW_LIGHT_HEADER)
	_draw_rounded_panel(bg, border_color, _title_band_height(), header_bg, border_width)


func heading_sizes() -> Array[int]:
	return [h1_font_size, h2_font_size, h3_font_size, h4_font_size, h5_font_size, h6_font_size]


func _refresh_visuals() -> void:
	var fg: Color = resolved_fg_color()
	if _title_label != null:
		_title_label.text = title if title != "" else DEFAULT_TITLE
		_title_label.add_theme_color_override("font_color", fg)
		_title_label.add_theme_font_size_override("font_size", title_font_size)
	if _preview != null:
		_preview.bbcode_enabled = true
		_preview.text = MarkdownConverter.markdown_to_bbcode(markdown_text, heading_sizes())
		_preview.add_theme_color_override("default_color", fg)
		_preview.add_theme_font_size_override("normal_font_size", font_size)
		_preview.add_theme_font_size_override("bold_font_size", font_size)
		_preview.add_theme_font_size_override("italics_font_size", font_size)
		_preview.add_theme_font_size_override("mono_font_size", font_size)
	_layout()
	queue_redraw()


func _title_band_height() -> float:
	return max(TITLE_HEIGHT, float(title_font_size) + 10.0)


func _layout() -> void:
	var band: float = _title_band_height()
	if _title_label != null:
		_title_label.position = Vector2(PADDING.x, 4)
		_title_label.size = Vector2(max(0.0, size.x - PADDING.x * 2.0), band - 6.0)
	if _preview != null:
		var top: float = band + TITLE_GAP
		_preview.position = Vector2(PADDING.x, top)
		_preview.size = Vector2(max(0.0, size.x - PADDING.x * 2.0), max(0.0, size.y - top - PADDING.y))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _on_edit_begin() -> void:
	_open_editor_dialog()
	end_edit()


func _open_editor_dialog() -> void:
	var scene: PackedScene = preload("res://src/nodes/document/document_editor_dialog.tscn")
	var dlg: DocumentEditorDialog = scene.instantiate()
	dlg.bind(title, markdown_text, heading_sizes(), font_size, title_font_size)
	get_tree().root.add_child(dlg)
	dlg.applied.connect(_on_editor_applied)
	dlg.popup_centered()


func _on_editor_applied(new_title: String, new_markdown: String) -> void:
	var changed_title: bool = new_title != title
	var changed_markdown: bool = new_markdown != markdown_text
	if not changed_title and not changed_markdown:
		return
	var editor: Node = _find_editor()
	if editor == null:
		title = new_title
		markdown_text = new_markdown
		_refresh_visuals()
		return
	if changed_title:
		History.push(ModifyPropertyCommand.new(editor, item_id, "title", title, new_title))
	if changed_markdown:
		History.push(ModifyPropertyCommand.new(editor, item_id, "markdown_text", markdown_text, new_markdown))


func _on_meta_clicked(meta: Variant) -> void:
	var spec: String = String(meta)
	if spec == "":
		return
	if spec.begins_with("board:"):
		var board_id_v: String = spec.substr(6)
		if AppState.current_project != null:
			AppState.navigate_to_board(board_id_v)
		return
	if spec.begins_with("item:"):
		var item_id_v: String = spec.substr(5)
		var editor: Node = _find_editor()
		if editor != null and editor.has_method("navigate_to_backlink") and AppState.current_board != null:
			editor.navigate_to_backlink(AppState.current_board.id, item_id_v)
		return
	OS.shell_open(spec)


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
		"title": title,
		"markdown_text": markdown_text,
		"font_size": font_size,
		"title_font_size": title_font_size,
		"h1_font_size": h1_font_size,
		"h2_font_size": h2_font_size,
		"h3_font_size": h3_font_size,
		"h4_font_size": h4_font_size,
		"h5_font_size": h5_font_size,
		"h6_font_size": h6_font_size,
		"bg_color_custom": bg_color_custom,
		"fg_color_custom": fg_color_custom,
	}
	if bg_color_custom:
		out["bg_color"] = ColorUtil.to_array(bg_color)
	if fg_color_custom:
		out["fg_color"] = ColorUtil.to_array(fg_color)
	return out


func deserialize_payload(d: Dictionary) -> void:
	title = String(d.get("title", title))
	markdown_text = String(d.get("markdown_text", markdown_text))
	font_size = int(d.get("font_size", font_size))
	title_font_size = int(d.get("title_font_size", title_font_size))
	h1_font_size = int(d.get("h1_font_size", h1_font_size))
	h2_font_size = int(d.get("h2_font_size", h2_font_size))
	h3_font_size = int(d.get("h3_font_size", h3_font_size))
	h4_font_size = int(d.get("h4_font_size", h4_font_size))
	h5_font_size = int(d.get("h5_font_size", h5_font_size))
	h6_font_size = int(d.get("h6_font_size", h6_font_size))
	if d.has("bg_color_custom"):
		bg_color_custom = bool(d["bg_color_custom"])
		if bg_color_custom and d.has("bg_color"):
			bg_color = ColorUtil.from_array(d["bg_color"], bg_color)
	if d.has("fg_color_custom"):
		fg_color_custom = bool(d["fg_color_custom"])
		if fg_color_custom and d.has("fg_color"):
			fg_color = ColorUtil.from_array(d["fg_color"], fg_color)
	if _preview != null:
		_refresh_visuals()


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"title":
			title = String(value)
		"markdown_text":
			markdown_text = String(value)
		"font_size":
			font_size = int(value)
		"title_font_size":
			title_font_size = int(value)
		"h1_font_size":
			h1_font_size = int(value)
		"h2_font_size":
			h2_font_size = int(value)
		"h3_font_size":
			h3_font_size = int(value)
		"h4_font_size":
			h4_font_size = int(value)
		"h5_font_size":
			h5_font_size = int(value)
		"h6_font_size":
			h6_font_size = int(value)
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
	var scene: PackedScene = preload("res://src/nodes/document/document_inspector.tscn")
	var inst: DocumentInspector = scene.instantiate()
	inst.bind(self)
	return inst


func bulk_shareable_properties() -> Array:
	return [
		{"key": "bg_color", "label": "Background", "kind": "color_with_reset"},
		{"key": "fg_color", "label": "Text color", "kind": "color_with_reset"},
		{"key": "font_size", "label": "Body font", "kind": "int_range", "min": 8, "max": 48},
		{"key": "title_font_size", "label": "Title font", "kind": "int_range", "min": 8, "max": 64},
		{"key": "h1_font_size", "label": "H1 font", "kind": "int_range", "min": 8, "max": 96},
		{"key": "h2_font_size", "label": "H2 font", "kind": "int_range", "min": 8, "max": 96},
		{"key": "h3_font_size", "label": "H3 font", "kind": "int_range", "min": 8, "max": 96},
		{"key": "h4_font_size", "label": "H4 font", "kind": "int_range", "min": 8, "max": 96},
		{"key": "h5_font_size", "label": "H5 font", "kind": "int_range", "min": 8, "max": 96},
		{"key": "h6_font_size", "label": "H6 font", "kind": "int_range", "min": 8, "max": 96},
	]
