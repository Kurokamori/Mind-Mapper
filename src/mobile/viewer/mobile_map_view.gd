class_name MobileMapView
extends Control

signal map_tapped()

@onready var _camera: MobileCameraController = %Camera
@onready var _world: Node2D = %World
@onready var _layers_root: Node2D = %LayersRoot
@onready var _objects_root: Control = %ObjectsRoot
@onready var _background: ColorRect = %MapBackground

var _project: Project = null
var _page: MapPage = null
var _layer_renderers: Array[TileLayerRenderer] = []
var _object_nodes: Array[BoardItem] = []
var _has_initial_frame: bool = false


func _ready() -> void:
	clip_contents = true
	_camera.user_tapped_world.connect(_on_world_tapped)


func bind_map_page(project: Project, page: MapPage) -> void:
	_project = project
	_page = page
	_has_initial_frame = false
	_rebuild_layers()
	_rebuild_objects()
	_apply_background()
	call_deferred("_frame_after_layout")


func frame_all() -> void:
	if _page == null:
		return
	var rect: Rect2 = _compute_world_bounds()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_camera.zoom = Vector2.ONE
		_camera.position = Vector2.ZERO
		return
	rect = rect.grow(64.0)
	_camera.zoom_to_fit_rect(rect)


func _frame_after_layout() -> void:
	if _has_initial_frame:
		return
	_has_initial_frame = true
	frame_all()


func _rebuild_layers() -> void:
	for node: Node in _layers_root.get_children():
		node.queue_free()
	_layer_renderers.clear()
	if _page == null or _project == null:
		return
	for layer: MapLayer in _page.layers:
		if layer.tileset_id == "":
			continue
		var tileset: TileSetResource = _project.read_tileset(layer.tileset_id)
		if tileset == null:
			continue
		var renderer: TileLayerRenderer = TileLayerRenderer.new()
		_layers_root.add_child(renderer)
		renderer.bind_layer(layer, tileset, _page.tile_size, _project.folder_path)
		_layer_renderers.append(renderer)


func _rebuild_objects() -> void:
	for node: Node in _objects_root.get_children():
		node.queue_free()
	_object_nodes.clear()
	if _page == null:
		return
	for entry_v: Variant in _page.objects:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var type_id: String = String(entry.get("type", ""))
		if type_id == "":
			continue
		var node: BoardItem = ItemRegistry.instantiate_from_dict(entry)
		if node == null:
			continue
		_objects_root.add_child(node)
		node.position = _vector_of(entry, "position", Vector2.ZERO)
		node.size = _vector_of(entry, "size", node.default_size())
		_object_nodes.append(node)


func _apply_background() -> void:
	if _page == null:
		_background.color = MapPage.DEFAULT_BG_COLOR
		return
	_background.color = _page.background_color


func _on_world_tapped(_world_pos: Vector2) -> void:
	map_tapped.emit()


func _compute_world_bounds() -> Rect2:
	var initial: bool = true
	var rect: Rect2 = Rect2()
	if _page == null:
		return rect
	for layer: MapLayer in _page.layers:
		if layer.cells.is_empty():
			continue
		var used: Rect2i = layer.used_rect()
		var pixel_pos: Vector2 = Vector2(float(used.position.x * _page.tile_size.x), float(used.position.y * _page.tile_size.y))
		var pixel_size: Vector2 = Vector2(float(used.size.x * _page.tile_size.x), float(used.size.y * _page.tile_size.y))
		var layer_rect: Rect2 = Rect2(pixel_pos, pixel_size)
		if initial:
			rect = layer_rect
			initial = false
		else:
			rect = rect.merge(layer_rect)
	for node: BoardItem in _object_nodes:
		var item_rect: Rect2 = Rect2(node.position, node.size)
		if initial:
			rect = item_rect
			initial = false
		else:
			rect = rect.merge(item_rect)
	return rect


func _vector_of(d: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var raw: Variant = d.get(key, null)
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 2:
		return Vector2(float((raw as Array)[0]), float((raw as Array)[1]))
	return fallback
