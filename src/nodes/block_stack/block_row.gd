class_name BlockRow
extends PanelContainer

signal text_changed(block_id: String, new_text: String)
signal indent_requested(block_id: String, delta: int)
signal delete_requested(block_id: String)
signal image_requested(block_id: String)
signal link_requested(block_id: String)
signal follow_link_requested(block_id: String)
signal block_selected(block_id: String)

const INDENT_PIXELS_PER_LEVEL: float = 20.0
const ROW_BG_BASE: Color = Color(0.18, 0.20, 0.24, 1.0)
const INDENT_BAR_COLORS: Array = [
	Color(0.95, 0.78, 0.30, 1.0),
	Color(0.30, 0.78, 0.95, 1.0),
	Color(0.40, 0.85, 0.55, 1.0),
	Color(0.85, 0.55, 0.85, 1.0),
	Color(0.95, 0.55, 0.45, 1.0),
	Color(0.65, 0.65, 0.95, 1.0),
]

@onready var _indent_spacer: Control = %IndentSpacer
@onready var _indent_bar: ColorRect = %IndentBar
@onready var _text_edit: LineEdit = %TextEdit
@onready var _outdent_btn: Button = %OutdentButton
@onready var _indent_btn: Button = %IndentButton
@onready var _image_btn: Button = %ImageButton
@onready var _image_thumb: TextureRect = %ImageThumb
@onready var _link_btn: Button = %LinkButton
@onready var _delete_btn: Button = %DeleteButton

const HIGHLIGHT_BORDER: Color = Color(0.95, 0.78, 0.30, 1.0)

var block_id: String = ""
var owner_stack_id: String = ""
var block_data: Dictionary = {}
var highlighted: bool = false
var palette_bg: Color = ROW_BG_BASE
var palette_fg: Color = Color(0.95, 0.96, 0.98, 1.0)
var _suppress: bool = false


func set_palette(bg: Color, fg: Color) -> void:
	palette_bg = bg
	palette_fg = fg
	if not is_inside_tree():
		return
	_apply_highlight_style()
	if _text_edit != null:
		_text_edit.add_theme_color_override("font_color", fg)


func bind(stack_item_id: String, data: Dictionary) -> void:
	owner_stack_id = stack_item_id
	block_data = data.duplicate(true)
	block_id = String(block_data.get("id", ""))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 30)
	_text_edit.text_changed.connect(_on_text_changed)
	_text_edit.text_submitted.connect(_on_text_submitted)
	_text_edit.focus_entered.connect(_on_text_focus_entered)
	_text_edit.focus_exited.connect(_on_text_focus_exited)
	_text_edit.gui_input.connect(_on_text_gui_input)
	_outdent_btn.pressed.connect(func() -> void: emit_signal("indent_requested", block_id, -1))
	_indent_btn.pressed.connect(func() -> void: emit_signal("indent_requested", block_id, 1))
	_image_btn.pressed.connect(func() -> void: emit_signal("image_requested", block_id))
	_link_btn.pressed.connect(_on_link_pressed)
	_delete_btn.pressed.connect(func() -> void: emit_signal("delete_requested", block_id))
	_apply_block_data()


func update_data(data: Dictionary) -> void:
	block_data = data.duplicate(true)
	block_id = String(block_data.get("id", ""))
	_apply_block_data()


func _apply_block_data() -> void:
	if _text_edit == null:
		return
	_suppress = true
	_text_edit.text = String(block_data.get("text", ""))
	var indent: int = int(block_data.get("indent_level", 0))
	indent = clamp(indent, 0, 6)
	_indent_spacer.custom_minimum_size = Vector2(indent * INDENT_PIXELS_PER_LEVEL, 0)
	_indent_bar.color = INDENT_BAR_COLORS[indent % INDENT_BAR_COLORS.size()]
	_apply_image_visual()
	_apply_link_visual()
	_apply_highlight_style()
	_apply_selection_state()
	_suppress = false


func set_highlighted(value: bool) -> void:
	if highlighted == value:
		return
	highlighted = value
	_apply_highlight_style()
	_apply_selection_state()


func _apply_selection_state() -> void:
	if _outdent_btn == null:
		return
	var show_tools: bool = highlighted
	_outdent_btn.visible = show_tools
	_indent_btn.visible = show_tools
	_link_btn.visible = show_tools
	_delete_btn.visible = show_tools
	var has_image: bool = _image_thumb != null and _image_thumb.texture != null
	_image_btn.visible = show_tools or has_image
	if _image_btn.visible:
		_image_btn.disabled = not show_tools
		_image_btn.focus_mode = Control.FOCUS_NONE
		_image_btn.mouse_filter = Control.MOUSE_FILTER_STOP if show_tools else Control.MOUSE_FILTER_IGNORE
	if not show_tools and _text_edit != null:
		if _text_edit.has_focus():
			_text_edit.release_focus()
		_text_edit.deselect()
		_text_edit.caret_column = 0


func _apply_highlight_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = palette_bg
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(4)
	if highlighted:
		sb.border_color = HIGHLIGHT_BORDER
		sb.set_border_width_all(2)
	add_theme_stylebox_override("panel", sb)
	if _text_edit != null:
		_text_edit.add_theme_color_override("font_color", palette_fg)


func _apply_image_visual() -> void:
	var asset_name: String = String(block_data.get("asset_name", ""))
	var source_path: String = String(block_data.get("source_path", ""))
	var path: String = ""
	if asset_name != "" and AppState.current_project != null:
		path = AppState.current_project.resolve_asset_path(asset_name)
	elif source_path != "":
		path = source_path
	if path != "" and FileAccess.file_exists(path):
		var img: Image = _load_image_bytes(path)
		if img != null:
			_image_thumb.texture = ImageTexture.create_from_image(img)
			_image_thumb.visible = true
			_image_btn.text = ""
			return
	_image_thumb.texture = null
	_image_thumb.visible = false
	_image_btn.text = "+"


func _load_image_bytes(path: String) -> Image:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() == 0:
		return null
	var ext: String = path.get_extension().to_lower()
	var img: Image = Image.new()
	var err: int = ERR_FILE_UNRECOGNIZED
	match ext:
		"png":
			err = img.load_png_from_buffer(bytes)
		"jpg", "jpeg":
			err = img.load_jpg_from_buffer(bytes)
		"webp":
			err = img.load_webp_from_buffer(bytes)
		"bmp":
			err = img.load_bmp_from_buffer(bytes)
		_:
			err = img.load_png_from_buffer(bytes)
			if err != OK:
				err = img.load_jpg_from_buffer(bytes)
	if err != OK:
		return null
	return img


func _apply_link_visual() -> void:
	var lt: Variant = block_data.get("link_target", null)
	var has_link: bool = false
	if typeof(lt) == TYPE_DICTIONARY and not (lt as Dictionary).is_empty():
		has_link = String((lt as Dictionary).get("kind", "")) != "" and String((lt as Dictionary).get("id", "")) != ""
	_link_btn.modulate = Color(0.95, 0.78, 0.30, 1.0) if has_link else Color(0.7, 0.7, 0.75, 1.0)


func _on_text_changed(new_text: String) -> void:
	if _suppress:
		return
	emit_signal("text_changed", block_id, new_text)


func _on_text_submitted(_t: String) -> void:
	if _suppress:
		return
	emit_signal("text_changed", block_id, _text_edit.text)
	_text_edit.release_focus()


func _on_text_focus_entered() -> void:
	emit_signal("block_selected", block_id)


func _on_text_focus_exited() -> void:
	if _suppress:
		return
	emit_signal("text_changed", block_id, _text_edit.text)


func _on_text_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var k: InputEventKey = event as InputEventKey
		if k.keycode == KEY_TAB:
			emit_signal("indent_requested", block_id, -1 if k.shift_pressed else 1)
			get_viewport().set_input_as_handled()
		elif (k.ctrl_pressed or k.meta_pressed) and k.keycode == KEY_BRACKETRIGHT:
			emit_signal("indent_requested", block_id, 1)
			get_viewport().set_input_as_handled()
		elif (k.ctrl_pressed or k.meta_pressed) and k.keycode == KEY_BRACKETLEFT:
			emit_signal("indent_requested", block_id, -1)
			get_viewport().set_input_as_handled()


func _on_link_pressed() -> void:
	var lt: Variant = block_data.get("link_target", null)
	var has_link: bool = typeof(lt) == TYPE_DICTIONARY and String((lt as Dictionary).get("id", "")) != ""
	if has_link and Input.is_key_pressed(KEY_CTRL):
		emit_signal("follow_link_requested", block_id)
		return
	emit_signal("link_requested", block_id)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			emit_signal("block_selected", block_id)


func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = String(block_data.get("text", "(empty)"))
	preview.add_theme_color_override("font_color", Color.WHITE)
	preview.modulate.a = 0.85
	set_drag_preview(preview)
	return {
		"kind": "block_row",
		"source_stack_id": owner_stack_id,
		"block_id": block_id,
		"block_data": block_data.duplicate(true),
	}
