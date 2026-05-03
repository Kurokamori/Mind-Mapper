class_name Minimap
extends PanelContainer

signal close_requested

const PADDING_PX: float = 8.0
const ZOOM_STEP: float = 1.1
const MIN_BOUNDS_SIZE: Vector2 = Vector2(800.0, 600.0)

@onready var _canvas: Control = %Canvas
@onready var _close_button: Button = %CloseButton
@onready var _header: Control = %Header

var _editor: Node = null
var _camera: Camera2D = null
var _items_dirty: bool = true
var _last_camera_position: Vector2 = Vector2.INF
var _last_camera_zoom: Vector2 = Vector2.ZERO
var _last_viewport_size: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _panel_dragging: bool = false
var _panel_drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	ThemeManager.theme_applied.connect(_on_theme_applied)
	_apply_translucent_panel()
	_canvas.draw.connect(_on_canvas_draw)
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.resized.connect(_on_canvas_resized)
	_close_button.pressed.connect(_on_close_pressed)
	_header.gui_input.connect(_on_header_gui_input)
	SelectionBus.selection_changed.connect(_on_selection_changed)
	AppState.current_board_changed.connect(_on_current_board_changed)
	get_viewport().size_changed.connect(_clamp_panel_to_viewport)
	if UserPrefs.minimap_position_set:
		call_deferred("_apply_floating_position", UserPrefs.minimap_position)
	set_process(true)


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_panel_dragging = true
			_panel_drag_offset = _header.get_global_mouse_position() - global_position
			_detach_anchors()
			_header.accept_event()
		else:
			if _panel_dragging:
				_panel_dragging = false
				UserPrefs.set_minimap_position(position)
				_header.accept_event()
	elif event is InputEventMouseMotion and _panel_dragging:
		var target: Vector2 = get_global_mouse_position() - _panel_drag_offset
		_apply_floating_position(target)
		_header.accept_event()


func _detach_anchors() -> void:
	var current_pos: Vector2 = position
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	position = current_pos


func _apply_floating_position(target: Vector2) -> void:
	_detach_anchors()
	position = _clamp_to_viewport(target)


func _clamp_to_viewport(target: Vector2) -> Vector2:
	var vp: Vector2 = Vector2(get_viewport_rect().size)
	var max_x: float = max(0.0, vp.x - size.x)
	var max_y: float = max(0.0, vp.y - size.y)
	return Vector2(clampf(target.x, 0.0, max_x), clampf(target.y, 0.0, max_y))


func _clamp_panel_to_viewport() -> void:
	if not UserPrefs.minimap_position_set:
		return
	position = _clamp_to_viewport(position)


func _on_close_pressed() -> void:
	emit_signal("close_requested")


func bind_editor(editor: Node, camera: Camera2D) -> void:
	_editor = editor
	_camera = camera
	notify_items_changed()


func notify_items_changed() -> void:
	_items_dirty = true
	if _canvas != null:
		_canvas.queue_redraw()


func _on_selection_changed(_selected: Array) -> void:
	if _canvas != null:
		_canvas.queue_redraw()


func _on_current_board_changed(_b: Board) -> void:
	notify_items_changed()


func _on_canvas_resized() -> void:
	if _canvas != null:
		_canvas.queue_redraw()


func _process(_delta: float) -> void:
	if _camera == null or _canvas == null:
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var vp_size: Vector2 = viewport.get_visible_rect().size
	if _camera.position == _last_camera_position \
			and _camera.zoom == _last_camera_zoom \
			and vp_size == _last_viewport_size:
		return
	_last_camera_position = _camera.position
	_last_camera_zoom = _camera.zoom
	_last_viewport_size = vp_size
	_canvas.queue_redraw()


func _content_bounds() -> Rect2:
	if _editor == null or not _editor.has_method("all_items"):
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var items: Array = _editor.all_items()
	if items.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var min_p: Vector2 = Vector2(INF, INF)
	var max_p: Vector2 = Vector2(-INF, -INF)
	for v: Variant in items:
		if not (v is BoardItem):
			continue
		var item: BoardItem = v
		min_p.x = min(min_p.x, item.position.x)
		min_p.y = min(min_p.y, item.position.y)
		max_p.x = max(max_p.x, item.position.x + item.size.x)
		max_p.y = max(max_p.y, item.position.y + item.size.y)
	if min_p.x == INF:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return Rect2(min_p, max_p - min_p)


func _world_bounds() -> Rect2:
	var content: Rect2 = _content_bounds()
	var viewport_world_rect: Rect2 = _viewport_world_rect()
	var combined: Rect2 = content
	if combined.size == Vector2.ZERO:
		combined = viewport_world_rect
	else:
		combined = combined.merge(viewport_world_rect)
	if combined.size.x < MIN_BOUNDS_SIZE.x:
		var center_x: float = combined.position.x + combined.size.x * 0.5
		combined.position.x = center_x - MIN_BOUNDS_SIZE.x * 0.5
		combined.size.x = MIN_BOUNDS_SIZE.x
	if combined.size.y < MIN_BOUNDS_SIZE.y:
		var center_y: float = combined.position.y + combined.size.y * 0.5
		combined.position.y = center_y - MIN_BOUNDS_SIZE.y * 0.5
		combined.size.y = MIN_BOUNDS_SIZE.y
	return combined


func _viewport_world_rect() -> Rect2:
	var viewport: Viewport = get_viewport()
	if _camera == null or viewport == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var vp_size: Vector2 = viewport.get_visible_rect().size
	var z: float = max(_camera.zoom.x, 0.0001)
	var size_world: Vector2 = vp_size / z
	return Rect2(_camera.position - size_world * 0.5, size_world)


func _world_to_canvas_transform() -> Dictionary:
	var canvas_size: Vector2 = _canvas.size
	var bounds: Rect2 = _world_bounds()
	var inner: Vector2 = canvas_size - Vector2(PADDING_PX, PADDING_PX) * 2.0
	if inner.x <= 0.0 or inner.y <= 0.0 or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return {"scale": 0.0, "offset": Vector2.ZERO, "bounds": bounds}
	var scale: float = min(inner.x / bounds.size.x, inner.y / bounds.size.y)
	var scaled_size: Vector2 = bounds.size * scale
	var offset: Vector2 = Vector2(PADDING_PX, PADDING_PX) + (inner - scaled_size) * 0.5
	return {"scale": scale, "offset": offset, "bounds": bounds}


func _world_to_canvas_point(p: Vector2, transform: Dictionary) -> Vector2:
	var bounds: Rect2 = transform.get("bounds", Rect2())
	var scale: float = float(transform.get("scale", 0.0))
	var offset: Vector2 = transform.get("offset", Vector2.ZERO)
	return offset + (p - bounds.position) * scale


func _canvas_to_world_point(p: Vector2, transform: Dictionary) -> Vector2:
	var bounds: Rect2 = transform.get("bounds", Rect2())
	var scale: float = float(transform.get("scale", 0.0))
	var offset: Vector2 = transform.get("offset", Vector2.ZERO)
	if scale <= 0.0:
		return Vector2.ZERO
	return bounds.position + (p - offset) / scale


func _on_canvas_draw() -> void:
	var canvas_size: Vector2 = _canvas.size
	var bg_color: Color = ThemeManager.background_color()
	var frame_base: Color = ThemeManager.accent_color()
	var frame_color: Color = Color(frame_base.r, frame_base.g, frame_base.b, 0.85)
	var frame_fill_color: Color = Color(frame_base.r, frame_base.g, frame_base.b, 0.10)
	var fallback_item_color: Color = ThemeManager.subtle_color()
	var selected_item_color: Color = ThemeManager.selection_highlight_color()
	_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), bg_color, true)
	if _editor == null or not _editor.has_method("all_items"):
		return
	var items: Array = _editor.all_items()
	var transform: Dictionary = _world_to_canvas_transform()
	if float(transform.get("scale", 0.0)) <= 0.0:
		_draw_empty_message(canvas_size, ThemeManager.dim_foreground_color())
		return
	for v: Variant in items:
		if not (v is BoardItem):
			continue
		var item: BoardItem = v
		var top_left: Vector2 = _world_to_canvas_point(item.position, transform)
		var bottom_right: Vector2 = _world_to_canvas_point(item.position + item.size, transform)
		var rect: Rect2 = Rect2(top_left, bottom_right - top_left).abs()
		if rect.size.x < 1.5:
			rect.size.x = 1.5
		if rect.size.y < 1.5:
			rect.size.y = 1.5
		var fill: Color = _color_for_item(item, fallback_item_color)
		_canvas.draw_rect(rect, fill, true)
		if item.is_selected():
			_canvas.draw_rect(rect, selected_item_color, false, 1.0)
	var vp_rect_world: Rect2 = _viewport_world_rect()
	if vp_rect_world.size.x > 0.0 and vp_rect_world.size.y > 0.0:
		var top_left: Vector2 = _world_to_canvas_point(vp_rect_world.position, transform)
		var bottom_right: Vector2 = _world_to_canvas_point(vp_rect_world.position + vp_rect_world.size, transform)
		var rect: Rect2 = Rect2(top_left, bottom_right - top_left).abs()
		_canvas.draw_rect(rect, frame_fill_color, true)
		_canvas.draw_rect(rect, frame_color, false, 1.5)


func _draw_empty_message(canvas_size: Vector2, fg: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var font_size: int = 12
	var msg: String = "Empty"
	var text_size: Vector2 = font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos: Vector2 = (canvas_size - text_size) * 0.5 + Vector2(0.0, font.get_ascent(font_size) * 0.5)
	_canvas.draw_string(font, pos, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fg)


func _color_for_item(item: BoardItem, fallback: Color) -> Color:
	for property_name: String in ["accent_color", "bg_color", "title_bg_color"]:
		if not (property_name in item):
			continue
		var raw: Variant = item.get(property_name)
		if typeof(raw) == TYPE_COLOR:
			var c: Color = raw
			return Color(c.r, c.g, c.b, 1.0)
	return fallback


func _on_canvas_input(event: InputEvent) -> void:
	if _editor == null or _camera == null:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_pan_to_canvas_position(mb.position)
			else:
				_dragging = false
			_canvas.accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_camera(ZOOM_STEP)
			_canvas.accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_camera(1.0 / ZOOM_STEP)
			_canvas.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_pan_to_canvas_position(motion.position)
		_canvas.accept_event()


func _pan_to_canvas_position(canvas_pos: Vector2) -> void:
	var transform: Dictionary = _world_to_canvas_transform()
	if float(transform.get("scale", 0.0)) <= 0.0:
		return
	var world_pos: Vector2 = _canvas_to_world_point(canvas_pos, transform)
	_camera.position = world_pos
	_canvas.queue_redraw()


func _zoom_camera(factor: float) -> void:
	var current_z: float = _camera.zoom.x
	var new_z: float = clamp(current_z * factor, EditorCameraController.MIN_ZOOM, EditorCameraController.MAX_ZOOM)
	_camera.zoom = Vector2(new_z, new_z)
	_canvas.queue_redraw()


func _apply_translucent_panel() -> void:
	ThemeManager.apply_translucent_panel(self)


func _on_theme_applied() -> void:
	_apply_translucent_panel()
	if _canvas != null:
		_canvas.queue_redraw()
