class_name TileGridOverlay
extends Node2D

## Draws the cell grid lines and the brush preview overlay above all layers.

@export var camera_path: NodePath
@export var grid_color: Color = Color(1, 1, 1, 0.06)
@export var grid_color_major: Color = Color(1, 1, 1, 0.12)
@export var preview_fill_color: Color = Color(0.5, 0.85, 1.0, 0.35)
@export var preview_outline_color: Color = Color(0.95, 0.97, 1.0, 0.85)
@export var rect_outline_color: Color = Color(0.95, 0.97, 1.0, 0.65)

var tile_size: Vector2i = Vector2i(16, 16)
var preview_cells: Array = []
var preview_rect: Rect2i = Rect2i(0, 0, 0, 0)
var preview_rect_active: bool = false
var preview_atlas_coord: Vector2i = Vector2i(-1, -1)
var preview_tileset: TileSetResource = null
var preview_project_root: String = ""


func _process(_delta: float) -> void:
	queue_redraw()


func set_tile_size(size: Vector2i) -> void:
	if tile_size == size:
		return
	tile_size = size
	queue_redraw()


func clear_preview() -> void:
	preview_cells = []
	preview_rect_active = false
	preview_atlas_coord = Vector2i(-1, -1)
	preview_tileset = null
	queue_redraw()


func set_brush_preview(cells: Array, atlas_coord: Vector2i, tileset: TileSetResource, project_root: String) -> void:
	preview_cells = cells.duplicate()
	preview_rect_active = false
	preview_atlas_coord = atlas_coord
	preview_tileset = tileset
	preview_project_root = project_root
	queue_redraw()


func set_rect_preview(rect: Rect2i) -> void:
	preview_rect = rect
	preview_rect_active = true
	queue_redraw()


func _draw() -> void:
	var cam: Camera2D = get_node_or_null(camera_path) as Camera2D
	if cam == null:
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var vp_size: Vector2 = viewport.get_visible_rect().size
	var world_size: Vector2 = vp_size / cam.zoom
	var top_left: Vector2 = cam.position - world_size * 0.5
	_draw_grid(top_left, world_size, cam.zoom.x)
	_draw_preview_cells()
	_draw_preview_rect()


func _draw_grid(top_left: Vector2, world_size: Vector2, pixel_per_world: float) -> void:
	if tile_size.x <= 0 or tile_size.y <= 0 or pixel_per_world <= 0.0:
		return
	var pixel_step_x: float = float(tile_size.x) * pixel_per_world
	var pixel_step_y: float = float(tile_size.y) * pixel_per_world
	if pixel_step_x < 4.0 or pixel_step_y < 4.0:
		return
	var line_thickness: float = 1.0 / pixel_per_world
	var start_x: float = floor(top_left.x / float(tile_size.x)) * float(tile_size.x)
	var end_x: float = top_left.x + world_size.x
	var start_y: float = floor(top_left.y / float(tile_size.y)) * float(tile_size.y)
	var end_y: float = top_left.y + world_size.y
	var x: float = start_x
	while x <= end_x:
		var col: Color = grid_color_major if int(round(x / float(tile_size.x))) % 8 == 0 else grid_color
		draw_line(Vector2(x, top_left.y), Vector2(x, end_y), col, line_thickness)
		x += float(tile_size.x)
	var y: float = start_y
	while y <= end_y:
		var col: Color = grid_color_major if int(round(y / float(tile_size.y))) % 8 == 0 else grid_color
		draw_line(Vector2(top_left.x, y), Vector2(end_x, y), col, line_thickness)
		y += float(tile_size.y)


func _draw_preview_cells() -> void:
	for cell_v: Variant in preview_cells:
		var cell: Vector2i = cell_v
		var origin: Vector2 = TileLayerRenderer.cell_to_world(cell, tile_size)
		var rect: Rect2 = Rect2(origin, Vector2(tile_size.x, tile_size.y))
		if preview_tileset != null and preview_tileset.has_tile(preview_atlas_coord):
			var tex: ImageTexture = preview_tileset.texture_for_project(preview_project_root)
			if tex != null:
				var src_rect: Rect2 = preview_tileset.texture_pixel_size_for(preview_atlas_coord)
				draw_texture_rect_region(tex, rect, src_rect, Color(1, 1, 1, 0.55))
		draw_rect(rect, preview_fill_color, true)
		draw_rect(rect, preview_outline_color, false, 1.0)


func _draw_preview_rect() -> void:
	if not preview_rect_active:
		return
	if preview_rect.size.x == 0 or preview_rect.size.y == 0:
		return
	var origin: Vector2 = Vector2(
		float(preview_rect.position.x * tile_size.x),
		float(preview_rect.position.y * tile_size.y),
	)
	var size: Vector2 = Vector2(
		float(preview_rect.size.x * tile_size.x),
		float(preview_rect.size.y * tile_size.y),
	)
	draw_rect(Rect2(origin, size), Color(0.5, 0.85, 1.0, 0.18), true)
	draw_rect(Rect2(origin, size), rect_outline_color, false, 2.0)
