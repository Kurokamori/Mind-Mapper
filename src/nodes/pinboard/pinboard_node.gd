class_name PinboardNode
extends BoardItem

const TITLE_HEIGHT: float = 38.0
const PADDING: Vector2 = Vector2(8, 6)
const OPEN_BUTTON_WIDTH: float = 72.0
const OPEN_BUTTON_HEIGHT: float = 30.0
const COUNT_LABEL_HEIGHT: float = 18.0
const COUNT_LABEL_BOTTOM_MARGIN: float = 8.0
const DARK_TITLE_BG: Color = Color(0.21, 0.29, 0.42, 1.0)
const LIGHT_TITLE_BG: Color = Color(0.62, 0.78, 0.95, 1.0)
const DARK_TITLE_FG: Color = Color(0.95, 0.96, 0.99, 1.0)
const LIGHT_TITLE_FG: Color = Color(0.06, 0.13, 0.22, 1.0)
const COUNT_FG: Color = Color(0.65, 0.70, 0.78, 1.0)


func _bg_color() -> Color:
	return ThemeManager.node_bg_color()


func _title_bg() -> Color:
	return ThemeManager.heading_bg("pinboard")


func _title_fg() -> Color:
	return ThemeManager.heading_fg("pinboard")

@export var target_board_id: String = ""
@export var title: String = "Pinboard"

@onready var _title_label: Label = %TitleLabel
@onready var _title_edit: LineEdit = %TitleEdit
@onready var _count_label: Label = %CountLabel
@onready var _open_button: Button = %OpenButton
@onready var _preview_holder: Control = %PreviewHolder

const DROP_HIGHLIGHT_COLOR: Color = Color(0.95, 0.78, 0.30, 1.0)
const DROP_HIGHLIGHT_WIDTH: float = 3.0

var _preview: BoardPreview = null
var _pre_edit_title: String = ""
var _drop_highlighted: bool = false


func _ready() -> void:
	super._ready()
	ThemeManager.apply_relative_font_size(_count_label, 0.80)
	ThemeManager.theme_applied.connect(_refresh_visuals)
	ThemeManager.node_palette_changed.connect(func(_a: Dictionary, _b: Dictionary) -> void: _refresh_visuals())
	_ensure_preview()
	_layout()
	_refresh_visuals()
	if read_only:
		return
	_title_edit.focus_exited.connect(_on_edit_focus_exited)
	_title_edit.text_submitted.connect(_on_edit_submitted)
	_open_button.pressed.connect(_on_open_pressed)
	SelectionBus.selection_changed.connect(_on_selection_changed)
	AppState.current_board_changed.connect(_on_any_board_changed)
	AppState.board_modified.connect(_on_board_modified)


func _on_board_modified(board_id: String) -> void:
	if board_id == target_board_id and _preview != null:
		_preview.refresh()
	_refresh_visuals()


func default_size() -> Vector2:
	return Vector2(280, 220)


func display_name() -> String:
	return "Pinboard"


func minimum_item_size() -> Vector2:
	return Vector2(200.0, TITLE_HEIGHT + 80.0 + COUNT_LABEL_HEIGHT + COUNT_LABEL_BOTTOM_MARGIN)


func ensure_target_board() -> String:
	if target_board_id != "" and AppState.current_project != null:
		var existing: Board = AppState.current_project.read_board(target_board_id)
		if existing != null:
			return target_board_id
	if AppState.current_project == null:
		return ""
	var parent_id: String = ""
	if AppState.current_board != null:
		parent_id = AppState.current_board.id
	var new_id: String = Uuid.v4()
	var b: Board = AppState.current_project.create_child_board_with_id(parent_id, new_id, title)
	if b == null:
		return ""
	target_board_id = b.id
	_broadcast_board_create(b.id, parent_id, b.name)
	AppState.emit_signal("board_modified", b.id)
	if _preview != null:
		_preview.bind(target_board_id)
	return target_board_id


func _broadcast_board_create(board_id: String, parent_board_id: String, board_name: String) -> void:
	if board_id == "" or not OpBus.has_project() or OpBus.is_applying_remote():
		return
	OpBus.record_local_change(OpKinds.CREATE_BOARD, {
		"board_id": board_id,
		"name": board_name,
		"parent_board_id": parent_board_id,
	}, "")


func _broadcast_board_rename(board_id: String, new_name: String) -> void:
	if board_id == "" or not OpBus.has_project() or OpBus.is_applying_remote():
		return
	OpBus.record_local_change(OpKinds.RENAME_BOARD, {
		"board_id": board_id,
		"name": new_name,
	}, "")


func _ensure_preview() -> void:
	if _preview != null or _preview_holder == null:
		return
	var scene: PackedScene = preload("res://src/editor/board_preview.tscn")
	_preview = scene.instantiate()
	_preview.anchor_right = 1.0
	_preview.anchor_bottom = 1.0
	_preview_holder.add_child(_preview)
	_preview.bind(target_board_id)


func _draw_body() -> void:
	var title_bg: Color = _title_bg()
	_draw_rounded_panel(_bg_color(), title_bg.darkened(0.3), TITLE_HEIGHT, title_bg)
	if _drop_highlighted:
		_draw_rounded_outline(DROP_HIGHLIGHT_COLOR, int(DROP_HIGHLIGHT_WIDTH))


func set_drop_highlighted(value: bool) -> void:
	if _drop_highlighted == value:
		return
	_drop_highlighted = value
	queue_redraw()


func _layout() -> void:
	var open_x: float = size.x - PADDING.x - OPEN_BUTTON_WIDTH
	var open_y: float = (TITLE_HEIGHT - OPEN_BUTTON_HEIGHT) * 0.5
	var title_y: float = (TITLE_HEIGHT - 24.0) * 0.5
	var title_w: float = open_x - PADDING.x - 8.0
	if _title_label != null:
		_title_label.position = Vector2(PADDING.x, title_y)
		_title_label.size = Vector2(title_w, 24.0)
	if _title_edit != null:
		_title_edit.position = Vector2(PADDING.x, title_y)
		_title_edit.size = Vector2(title_w, 24.0)
	if _open_button != null:
		_open_button.position = Vector2(open_x, open_y)
		_open_button.size = Vector2(OPEN_BUTTON_WIDTH, OPEN_BUTTON_HEIGHT)
	if _count_label != null:
		_count_label.position = Vector2(PADDING.x, size.y - COUNT_LABEL_HEIGHT - COUNT_LABEL_BOTTOM_MARGIN)
		_count_label.size = Vector2(size.x - PADDING.x * 2, COUNT_LABEL_HEIGHT)
	if _preview_holder != null:
		var preview_top: float = TITLE_HEIGHT + 6.0
		var preview_bottom_pad: float = COUNT_LABEL_HEIGHT + COUNT_LABEL_BOTTOM_MARGIN + 6.0
		_preview_holder.position = Vector2(PADDING.x, preview_top)
		_preview_holder.size = Vector2(size.x - PADDING.x * 2, size.y - preview_top - preview_bottom_pad)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _refresh_visuals() -> void:
	var fg: Color = _title_fg()
	if _title_label != null:
		_title_label.text = title
		_title_label.add_theme_color_override("font_color", fg)
	if _title_edit != null:
		_title_edit.add_theme_color_override("font_color", fg)
	if _count_label != null:
		_count_label.add_theme_color_override("font_color", COUNT_FG)
		_count_label.text = _count_text()
	queue_redraw()


func _count_text() -> String:
	if AppState.current_project == null or target_board_id == "":
		return "Not linked"
	var b: Board = AppState.current_project.read_board(target_board_id)
	if b == null:
		return "Missing board"
	return "%d item%s" % [b.items.size(), "" if b.items.size() == 1 else "s"]


func _on_open_pressed() -> void:
	_navigate_into()


func _navigate_into() -> void:
	var id: String = ensure_target_board()
	if id == "":
		return
	emit_signal("navigate_requested", BoardItem.LINK_KIND_BOARD, id)


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
		if target_board_id != "" and AppState.current_project != null:
			AppState.current_project.rename_board(target_board_id, new_title)
			_broadcast_board_rename(target_board_id, new_title)
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


func _on_any_board_changed(_b: Board) -> void:
	_refresh_visuals()
	if _preview != null:
		_preview.refresh()


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null


func _gui_input(event: InputEvent) -> void:
	if is_editing() or read_only:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and mb.double_click:
			var local := get_local_mouse_position()
			if local.y <= TITLE_HEIGHT:
				begin_edit()
				accept_event()
				return
			_navigate_into()
			accept_event()
			return
	super._gui_input(event)


func serialize_payload() -> Dictionary:
	return {
		"target_board_id": target_board_id,
		"title": title,
	}


func deserialize_payload(d: Dictionary) -> void:
	target_board_id = String(d.get("target_board_id", ""))
	title = String(d.get("title", title))
	if _title_label != null:
		_refresh_visuals()
	if _preview != null:
		_preview.bind(target_board_id)


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"title":
			title = String(value)
			if target_board_id != "" and AppState.current_project != null:
				AppState.current_project.rename_board(target_board_id, title)
		"target_board_id":
			target_board_id = String(value)
			if _preview != null:
				_preview.bind(target_board_id)
	_refresh_visuals()


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/pinboard/pinboard_inspector.tscn")
	var inst: PinboardInspector = scene.instantiate()
	inst.bind(self)
	return inst
