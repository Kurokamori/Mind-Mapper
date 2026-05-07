class_name MapPageNode
extends BoardItem

const HEADER_HEIGHT: float = 38.0
const FOOTER_HEIGHT: float = 40.0
const PADDING: Vector2 = Vector2(8, 6)
const OPEN_BUTTON_WIDTH: float = 72.0
const OPEN_BUTTON_HEIGHT: float = 30.0
const FIT_BUTTON_WIDTH: float = 60.0
const FIT_BUTTON_HEIGHT: float = 30.0
const ZOOM_VALUE_WIDTH: float = 56.0
const SLIDER_HEIGHT: float = 18.0


func _bg_color() -> Color:
	return ThemeManager.node_bg_color()


func _header_bg() -> Color:
	return ThemeManager.heading_bg("map_page")


func _header_fg() -> Color:
	return ThemeManager.heading_fg("map_page")


@export var target_map_page_id: String = ""
@export var title: String = "Map Page"
@export var view_zoom: float = 0.5
@export var view_pan: Vector2 = Vector2.ZERO
@export var auto_fit: bool = true

@onready var _title_label: Label = %TitleLabel
@onready var _title_edit: LineEdit = %TitleEdit
@onready var _open_button: Button = %OpenButton
@onready var _preview_holder: Control = %PreviewHolder
@onready var _zoom_slider: HSlider = %ZoomSlider
@onready var _zoom_value_label: Label = %ZoomValueLabel
@onready var _fit_button: Button = %FitButton

var _preview: MapPagePreview = null
var _pre_edit_title: String = ""


func _ready() -> void:
	super._ready()
	ThemeManager.apply_relative_font_size(_zoom_value_label, 0.80)
	ThemeManager.theme_applied.connect(_refresh_visuals)
	ThemeManager.node_palette_changed.connect(func(_a: Dictionary, _b: Dictionary) -> void: _refresh_visuals())
	_ensure_preview()
	_layout()
	_apply_view_to_preview()
	_refresh_visuals()
	if read_only:
		return
	_title_edit.focus_exited.connect(_on_edit_focus_exited)
	_title_edit.text_submitted.connect(_on_edit_submitted)
	_open_button.pressed.connect(_on_open_pressed)
	_zoom_slider.value_changed.connect(_on_zoom_changed)
	_fit_button.pressed.connect(_on_fit_pressed)
	SelectionBus.selection_changed.connect(_on_selection_changed)
	AppState.map_page_modified.connect(_on_map_page_modified)


func _on_map_page_modified(map_id: String) -> void:
	if map_id != target_map_page_id:
		return
	_sync_title_from_project()
	if _preview != null:
		_preview.refresh()
		_apply_view_to_preview()


func default_size() -> Vector2:
	return Vector2(380, 300)


func display_name() -> String:
	return "Map Page"


func minimum_item_size() -> Vector2:
	return Vector2(260.0, HEADER_HEIGHT + FOOTER_HEIGHT + 100.0)


func ensure_target_map_page() -> String:
	if target_map_page_id != "" and AppState.current_project != null:
		var existing: MapPage = AppState.current_project.read_map_page(target_map_page_id)
		if existing != null:
			return target_map_page_id
	if AppState.current_project == null:
		return ""
	var safe_title: String = title if title.strip_edges() != "" else "Map Page"
	var page: MapPage = AppState.current_project.create_map_page(safe_title, MapPage.DEFAULT_TILE_SIZE)
	if page == null:
		return ""
	target_map_page_id = page.id
	if _preview != null:
		_preview.bind(target_map_page_id)
		_apply_view_to_preview()
	AppState.emit_signal("map_page_modified", page.id)
	return target_map_page_id


func _ensure_preview() -> void:
	if _preview != null or _preview_holder == null:
		return
	var scene: PackedScene = preload("res://src/editor/map_page_preview.tscn")
	_preview = scene.instantiate()
	_preview.anchor_right = 1.0
	_preview.anchor_bottom = 1.0
	_preview_holder.add_child(_preview)
	_preview.bind(target_map_page_id)


func _draw_body() -> void:
	var header: Color = _header_bg()
	_draw_rounded_panel(_bg_color(), header.darkened(0.3), HEADER_HEIGHT, header)


func _layout() -> void:
	var open_x: float = size.x - PADDING.x - OPEN_BUTTON_WIDTH
	var open_y: float = (HEADER_HEIGHT - OPEN_BUTTON_HEIGHT) * 0.5
	var title_y: float = (HEADER_HEIGHT - 24.0) * 0.5
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
	if _preview_holder != null:
		_preview_holder.position = Vector2(PADDING.x, HEADER_HEIGHT + 6.0)
		_preview_holder.size = Vector2(size.x - PADDING.x * 2, size.y - HEADER_HEIGHT - FOOTER_HEIGHT - 8.0)
	var footer_y: float = size.y - FOOTER_HEIGHT
	var fit_x: float = size.x - PADDING.x - FIT_BUTTON_WIDTH
	var fit_y: float = footer_y + (FOOTER_HEIGHT - FIT_BUTTON_HEIGHT) * 0.5
	var zoom_value_x: float = fit_x - 8.0 - ZOOM_VALUE_WIDTH
	var slider_w: float = zoom_value_x - PADDING.x - 8.0
	if _zoom_slider != null:
		_zoom_slider.position = Vector2(PADDING.x, footer_y + (FOOTER_HEIGHT - SLIDER_HEIGHT) * 0.5)
		_zoom_slider.size = Vector2(slider_w, SLIDER_HEIGHT)
	if _zoom_value_label != null:
		_zoom_value_label.position = Vector2(zoom_value_x, footer_y + (FOOTER_HEIGHT - 18.0) * 0.5)
		_zoom_value_label.size = Vector2(ZOOM_VALUE_WIDTH, 18.0)
	if _fit_button != null:
		_fit_button.position = Vector2(fit_x, fit_y)
		_fit_button.size = Vector2(FIT_BUTTON_WIDTH, FIT_BUTTON_HEIGHT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _refresh_visuals() -> void:
	var fg: Color = _header_fg()
	if _title_label != null:
		_title_label.text = title
		_title_label.add_theme_color_override("font_color", fg)
	if _title_edit != null:
		_title_edit.add_theme_color_override("font_color", fg)
	if _zoom_slider != null:
		_zoom_slider.set_value_no_signal(view_zoom)
	if _zoom_value_label != null:
		_zoom_value_label.text = "%d%%" % int(round(view_zoom * 100.0))
	queue_redraw()


func _apply_view_to_preview() -> void:
	if _preview == null:
		return
	if auto_fit:
		_preview.enable_auto_fit()
	else:
		_preview.set_view(view_pan, view_zoom)


func _on_zoom_changed(value: float) -> void:
	view_zoom = value
	auto_fit = false
	_apply_view_to_preview()
	_refresh_visuals()


func _on_fit_pressed() -> void:
	auto_fit = true
	_apply_view_to_preview()


func _on_open_pressed() -> void:
	_navigate_into()


func _navigate_into() -> void:
	var id: String = ensure_target_map_page()
	if id == "":
		return
	emit_signal("navigate_requested", BoardItem.LINK_KIND_MAP_PAGE, id)


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
		if target_map_page_id != "" and AppState.current_project != null:
			AppState.current_project.rename_map_page(target_map_page_id, new_title)
			AppState.emit_signal("map_page_modified", target_map_page_id)
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


func _sync_title_from_project() -> void:
	if AppState.current_project == null or target_map_page_id == "":
		return
	if not AppState.current_project.map_page_index.has(target_map_page_id):
		return
	var current: String = String(AppState.current_project.map_page_index[target_map_page_id])
	if current != "" and current != title:
		title = current
		_refresh_visuals()


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
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and mb.double_click:
			var local: Vector2 = get_local_mouse_position()
			if local.y <= HEADER_HEIGHT:
				begin_edit()
				accept_event()
				return
			_navigate_into()
			accept_event()
			return
	super._gui_input(event)


func serialize_payload() -> Dictionary:
	return {
		"target_map_page_id": target_map_page_id,
		"title": title,
		"view_zoom": view_zoom,
		"view_pan": [view_pan.x, view_pan.y],
		"auto_fit": auto_fit,
	}


func deserialize_payload(d: Dictionary) -> void:
	target_map_page_id = String(d.get("target_map_page_id", ""))
	title = String(d.get("title", title))
	view_zoom = float(d.get("view_zoom", view_zoom))
	var pan_raw: Variant = d.get("view_pan", null)
	if typeof(pan_raw) == TYPE_ARRAY and (pan_raw as Array).size() >= 2:
		view_pan = Vector2(float(pan_raw[0]), float(pan_raw[1]))
	auto_fit = bool(d.get("auto_fit", auto_fit))
	if _title_label != null:
		_refresh_visuals()
	if _preview != null:
		_preview.bind(target_map_page_id)
		_apply_view_to_preview()


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"title":
			title = String(value)
			if target_map_page_id != "" and AppState.current_project != null:
				AppState.current_project.rename_map_page(target_map_page_id, title)
				AppState.emit_signal("map_page_modified", target_map_page_id)
		"target_map_page_id":
			target_map_page_id = String(value)
			if _preview != null:
				_preview.bind(target_map_page_id)
				_apply_view_to_preview()
		"view_zoom":
			view_zoom = float(value)
			auto_fit = false
			_apply_view_to_preview()
		"auto_fit":
			auto_fit = bool(value)
			_apply_view_to_preview()
	_refresh_visuals()


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/map_page/map_page_inspector.tscn")
	var inst: MapPageInspector = scene.instantiate()
	inst.bind(self)
	return inst
