class_name BoardPreview
extends Control

@onready var _viewport_container: SubViewportContainer = %ViewportContainer
@onready var _viewport: SubViewport = %Viewport
@onready var _world: Node2D = %PreviewWorld
@onready var _camera: Camera2D = %PreviewCamera
@onready var _items_root: Node2D = %PreviewItems
@onready var _connections_layer: ConnectionLayer = %PreviewConnections
@onready var _empty_label: Label = %EmptyLabel

var target_board_id: String = ""
var view_zoom: float = 1.0
var view_pan: Vector2 = Vector2.ZERO
var auto_fit: bool = true


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _connections_layer != null:
		_connections_layer.bind_editor(self)
	ThemeManager.theme_applied.connect(_apply_theme_colors)
	_apply_theme_colors()


func _apply_theme_colors() -> void:
	if _empty_label != null:
		_empty_label.add_theme_color_override("font_color", ThemeManager.dim_foreground_color())


func bind(board_id: String) -> void:
	target_board_id = board_id
	refresh()


func set_view(pan: Vector2, zoom: float) -> void:
	view_pan = pan
	view_zoom = max(0.05, zoom)
	auto_fit = false
	_apply_camera()


func enable_auto_fit() -> void:
	auto_fit = true
	_apply_camera()


func refresh() -> void:
	if _items_root == null:
		return
	for child in _items_root.get_children():
		child.queue_free()
	if _connections_layer != null:
		_connections_layer.set_connections([])
	if AppState.current_project == null or target_board_id == "":
		_show_empty("No target")
		return
	var board: Board = AppState.current_project.read_board(target_board_id)
	if board == null:
		_show_empty("Missing board")
		return
	if board.items.is_empty():
		_show_empty("Empty board")
		_apply_camera()
		return
	_empty_label.visible = false
	for d in board.items:
		var inst: BoardItem = ItemRegistry.instantiate(String(d.get("type", "")))
		if inst == null:
			continue
		inst.read_only = true
		inst.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inst.apply_dict(d)
		_items_root.add_child(inst)
	if _connections_layer != null:
		var conns: Array[Connection] = []
		for raw in board.connections:
			if typeof(raw) == TYPE_DICTIONARY:
				var c: Connection = Connection.from_dict(raw)
				if c != null and c.from_item_id != "" and c.to_item_id != "":
					conns.append(c)
		_connections_layer.set_connections(conns)
	_apply_camera()


func find_item_by_id(item_id: String) -> BoardItem:
	if _items_root == null or item_id == "":
		return null
	for child in _items_root.get_children():
		if child is BoardItem:
			var item: BoardItem = child
			if item.item_id == item_id:
				return item
	return null


func all_items() -> Array:
	var out: Array = []
	if _items_root == null:
		return out
	for child in _items_root.get_children():
		if child is BoardItem:
			out.append(child)
	return out


func request_save() -> void:
	pass


func _show_empty(message: String) -> void:
	_empty_label.text = message
	_empty_label.visible = true


func _apply_camera() -> void:
	if _camera == null:
		return
	if auto_fit:
		var bounds := _content_bounds()
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
			_camera.position = Vector2.ZERO
			_camera.zoom = Vector2.ONE
			return
		var viewport_size: Vector2 = _viewport.size
		var pad: float = 32.0
		var content_size: Vector2 = bounds.size + Vector2(pad, pad) * 2.0
		var z: float = min(viewport_size.x / content_size.x, viewport_size.y / content_size.y)
		z = clamp(z, 0.05, 4.0)
		_camera.zoom = Vector2(z, z)
		_camera.position = bounds.position + bounds.size * 0.5
	else:
		_camera.zoom = Vector2(view_zoom, view_zoom)
		_camera.position = view_pan


func _content_bounds() -> Rect2:
	if _items_root == null or _items_root.get_child_count() == 0:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var min_p: Vector2 = Vector2(INF, INF)
	var max_p: Vector2 = Vector2(-INF, -INF)
	for child in _items_root.get_children():
		if child is BoardItem:
			var item: BoardItem = child
			min_p.x = min(min_p.x, item.position.x)
			min_p.y = min(min_p.y, item.position.y)
			max_p.x = max(max_p.x, item.position.x + item.size.x)
			max_p.y = max(max_p.y, item.position.y + item.size.y)
	if min_p.x == INF:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return Rect2(min_p, max_p - min_p)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_camera()
