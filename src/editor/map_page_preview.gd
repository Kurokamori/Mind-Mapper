class_name MapPagePreview
extends Control

## Renders a project MapPage (background + tile layers + overlay objects)
## inside a SubViewport so it can sit inside a parent-board node like a thumbnail.
## Mirrors the responsibilities of BoardPreview but for tilemap pages.

@onready var _viewport_container: SubViewportContainer = %ViewportContainer
@onready var _viewport: SubViewport = %Viewport
@onready var _world: Node2D = %PreviewWorld
@onready var _camera: Camera2D = %PreviewCamera
@onready var _bg: ColorRect = %BackgroundRect
@onready var _layers_root: Node2D = %LayersRoot
@onready var _objects_root: Control = %ObjectsRoot
@onready var _empty_label: Label = %EmptyLabel

const OVERLAY_SCENE: PackedScene = preload("res://src/tilemap/overlay_object.tscn")

var target_map_page_id: String = ""
var view_zoom: float = 0.5
var view_pan: Vector2 = Vector2.ZERO
var auto_fit: bool = true

var _tilesets: Dictionary = {}
var _layer_renderers: Dictionary = {}
var _overlay_objects: Dictionary = {}


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ThemeManager.theme_applied.connect(_apply_theme_colors)
	_apply_theme_colors()


func _apply_theme_colors() -> void:
	if _empty_label != null:
		_empty_label.add_theme_color_override("font_color", ThemeManager.dim_foreground_color())


func bind(map_page_id: String) -> void:
	target_map_page_id = map_page_id
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
	if _layers_root == null:
		return
	_clear_layer_renderers()
	_clear_overlay_state()
	if AppState.current_project == null or target_map_page_id == "":
		_show_empty("No target")
		return
	var page: MapPage = AppState.current_project.read_map_page(target_map_page_id)
	if page == null:
		_show_empty("Missing map")
		return
	_load_tilesets_used_by(page)
	_apply_background(page)
	_rebuild_layer_renderers(page)
	_rebuild_overlay_objects(page)
	if page.layers.is_empty() and page.objects.is_empty():
		_show_empty("Empty map")
		_apply_camera()
		return
	_empty_label.visible = false
	_apply_camera()


func _load_tilesets_used_by(page: MapPage) -> void:
	_tilesets.clear()
	if AppState.current_project == null:
		return
	for ts_id: String in page.tilesets_used():
		var ts: TileSetResource = AppState.current_project.read_tileset(ts_id)
		if ts != null:
			_tilesets[ts_id] = ts


func _apply_background(page: MapPage) -> void:
	if _bg != null:
		_bg.color = page.background_color


func _clear_layer_renderers() -> void:
	for renderer_v: Variant in _layer_renderers.values():
		var renderer: TileLayerRenderer = renderer_v
		if is_instance_valid(renderer):
			renderer.queue_free()
	_layer_renderers.clear()


func _clear_overlay_state() -> void:
	if _objects_root == null:
		return
	for child in _objects_root.get_children():
		child.queue_free()
	_overlay_objects.clear()


func _rebuild_layer_renderers(page: MapPage) -> void:
	var project_root: String = AppState.current_project.folder_path if AppState.current_project != null else ""
	for layer: MapLayer in page.layers:
		var renderer: TileLayerRenderer = TileLayerRenderer.new()
		_layers_root.add_child(renderer)
		var ts: TileSetResource = _tilesets.get(layer.tileset_id, null)
		renderer.bind_layer(layer, ts, page.tile_size, project_root)
		_layer_renderers[layer.id] = renderer


func _rebuild_overlay_objects(page: MapPage) -> void:
	for obj_v: Variant in page.objects:
		if typeof(obj_v) != TYPE_DICTIONARY:
			continue
		var obj: Dictionary = obj_v
		var inst: OverlayObject = OVERLAY_SCENE.instantiate()
		_objects_root.add_child(inst)
		inst.bind_object(obj)
		_overlay_objects[String(obj.get("id", ""))] = inst


func _show_empty(message: String) -> void:
	_empty_label.text = message
	_empty_label.visible = true


func _apply_camera() -> void:
	if _camera == null:
		return
	if auto_fit:
		var bounds: Rect2 = _content_bounds()
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
			_camera.position = Vector2.ZERO
			_camera.zoom = Vector2.ONE
			return
		var viewport_size: Vector2 = _viewport.size
		var pad: float = 24.0
		var content_size: Vector2 = bounds.size + Vector2(pad, pad) * 2.0
		var z: float = min(viewport_size.x / content_size.x, viewport_size.y / content_size.y)
		z = clamp(z, 0.05, 4.0)
		_camera.zoom = Vector2(z, z)
		_camera.position = bounds.position + bounds.size * 0.5
	else:
		_camera.zoom = Vector2(view_zoom, view_zoom)
		_camera.position = view_pan


func _content_bounds() -> Rect2:
	if AppState.current_project == null or target_map_page_id == "":
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var page: MapPage = AppState.current_project.read_map_page(target_map_page_id)
	if page == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var min_p: Vector2 = Vector2(INF, INF)
	var max_p: Vector2 = Vector2(-INF, -INF)
	var seen: bool = false
	for layer: MapLayer in page.layers:
		for coord_v: Variant in layer.cells.keys():
			var coord: Vector2i = coord_v
			var cell_pos: Vector2 = TileLayerRenderer.cell_to_world(coord, page.tile_size)
			min_p.x = min(min_p.x, cell_pos.x)
			min_p.y = min(min_p.y, cell_pos.y)
			max_p.x = max(max_p.x, cell_pos.x + page.tile_size.x)
			max_p.y = max(max_p.y, cell_pos.y + page.tile_size.y)
			seen = true
	for obj_v: Variant in page.objects:
		if typeof(obj_v) != TYPE_DICTIONARY:
			continue
		var obj: Dictionary = obj_v
		var pos_raw: Variant = obj.get("position", null)
		var size_raw: Variant = obj.get("size", null)
		if typeof(pos_raw) != TYPE_ARRAY or (pos_raw as Array).size() < 2:
			continue
		var sx: float = 64.0
		var sy: float = 32.0
		if typeof(size_raw) == TYPE_ARRAY and (size_raw as Array).size() >= 2:
			sx = float((size_raw as Array)[0])
			sy = float((size_raw as Array)[1])
		var px: float = float((pos_raw as Array)[0])
		var py: float = float((pos_raw as Array)[1])
		min_p.x = min(min_p.x, px)
		min_p.y = min(min_p.y, py)
		max_p.x = max(max_p.x, px + sx)
		max_p.y = max(max_p.y, py + sy)
		seen = true
	if not seen:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return Rect2(min_p, max_p - min_p)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_camera()
