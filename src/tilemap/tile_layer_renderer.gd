class_name TileLayerRenderer
extends Node2D

## Renders one MapLayer's painted cells using its TileSetResource texture.
## Operates entirely in world space — same coordinate system the camera uses.

var layer: MapLayer = null
var tileset: TileSetResource = null
var tile_size: Vector2i = Vector2i(16, 16)
var project_root: String = ""


func _ready() -> void:
	z_as_relative = false


func bind_layer(map_layer: MapLayer, ts: TileSetResource, tile_dim: Vector2i, project: String) -> void:
	layer = map_layer
	tileset = ts
	tile_size = tile_dim
	project_root = project
	_apply_layer_visuals()
	queue_redraw()


func refresh() -> void:
	_apply_layer_visuals()
	queue_redraw()


func _apply_layer_visuals() -> void:
	if layer == null:
		visible = true
		modulate = Color(1, 1, 1, 1)
		return
	visible = layer.visible
	var mod: Color = Color(
		layer.modulate_color.r,
		layer.modulate_color.g,
		layer.modulate_color.b,
		layer.modulate_color.a * clamp(layer.opacity, 0.0, 1.0),
	)
	modulate = mod
	z_index = layer.z_index


func _draw() -> void:
	if layer == null or tileset == null:
		return
	var tex: ImageTexture = tileset.texture_for_project(project_root)
	if tex == null:
		return
	for coord_v: Variant in layer.cells.keys():
		var coord: Vector2i = coord_v
		var data: Vector3i = layer.cells[coord]
		var atlas_coord: Vector2i = Vector2i(data.x, data.y)
		if not tileset.has_tile(atlas_coord):
			continue
		var src_rect: Rect2 = tileset.texture_pixel_size_for(atlas_coord)
		var dest_pos: Vector2 = Vector2(float(coord.x * tile_size.x), float(coord.y * tile_size.y))
		var dest_rect: Rect2 = Rect2(dest_pos, Vector2(tile_size.x, tile_size.y))
		draw_texture_rect_region(tex, dest_rect, src_rect)


static func world_to_cell(world_pos: Vector2, tile_dim: Vector2i) -> Vector2i:
	if tile_dim.x <= 0 or tile_dim.y <= 0:
		return Vector2i.ZERO
	return Vector2i(
		int(floor(world_pos.x / float(tile_dim.x))),
		int(floor(world_pos.y / float(tile_dim.y))),
	)


static func cell_to_world(cell: Vector2i, tile_dim: Vector2i) -> Vector2:
	return Vector2(float(cell.x * tile_dim.x), float(cell.y * tile_dim.y))
