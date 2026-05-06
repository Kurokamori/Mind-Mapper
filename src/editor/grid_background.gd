class_name GridBackground
extends Node2D

@export var camera_path: NodePath


func _process(_delta: float) -> void:
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
	var pixel_per_world: float = cam.zoom.x
	var bg: Color
	if AppState.current_board != null and AppState.current_board.has_background_color_override():
		bg = AppState.current_board.get_background_color()
	else:
		bg = ThemeManager.background_color()
	draw_grid_into_with_bg(self, Rect2(top_left, world_size), SnapService.grid_size, SnapService.enabled, pixel_per_world, bg)
	_draw_board_background_image(top_left, world_size)


func _draw_board_background_image(top_left: Vector2, world_size: Vector2) -> void:
	if AppState.current_board == null or AppState.current_project == null:
		return
	var asset: String = AppState.current_board.background_image_asset
	if asset == "":
		return
	var path: String = AppState.current_project.resolve_asset_path(asset)
	if not FileAccess.file_exists(path):
		return
	var img: Image = Image.load_from_file(path)
	if img == null or img.is_empty():
		return
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	match AppState.current_board.background_image_mode:
		1:
			draw_texture_rect(tex, Rect2(top_left, world_size), false)
		2:
			var tw: float = float(img.get_width())
			var th: float = float(img.get_height())
			var center: Vector2 = top_left + world_size * 0.5
			draw_texture_rect(tex, Rect2(center - Vector2(tw, th) * 0.5, Vector2(tw, th)), false)
		_:
			draw_texture_rect(tex, Rect2(top_left, world_size), true)


static func draw_grid_into_with_bg(canvas: CanvasItem, world_rect: Rect2, grid_size: int, snap_enabled: bool, pixel_per_world: float, bg_color: Color) -> void:
	canvas.draw_rect(world_rect, bg_color, true)
	_draw_grid_lines(canvas, world_rect, grid_size, snap_enabled, pixel_per_world, bg_color)


static func _grid_colors(bg_color: Color) -> Array:
	var palette_subtle: Color = ThemeManager.subtle_color()
	var minor: Color = bg_color.lerp(palette_subtle, 0.35)
	var major: Color = bg_color.lerp(palette_subtle, 0.65)
	return [minor, major]


static func _draw_grid_lines(canvas: CanvasItem, world_rect: Rect2, grid_size: int, snap_enabled: bool, pixel_per_world: float, bg_color: Color) -> void:
	if grid_size <= 0 or pixel_per_world <= 0.0:
		return
	var step: int = grid_size
	var pixel_step: float = step * pixel_per_world
	while pixel_step < 8.0:
		step *= 2
		pixel_step = step * pixel_per_world
	var top_left: Vector2 = world_rect.position
	var size: Vector2 = world_rect.size
	var start_x: float = floor(top_left.x / step) * step
	var end_x: float = top_left.x + size.x
	var start_y: float = floor(top_left.y / step) * step
	var end_y: float = top_left.y + size.y
	var grid_palette: Array = _grid_colors(bg_color)
	var base_minor: Color = grid_palette[0]
	var base_major: Color = grid_palette[1]
	var minor_color: Color = base_minor if snap_enabled else base_minor.lerp(bg_color, 0.4)
	var major_color: Color = base_major if snap_enabled else base_major.lerp(bg_color, 0.4)
	var line_thickness: float = 1.0 / pixel_per_world
	var x: float = start_x
	while x <= end_x:
		var color_x: Color = major_color if int(round(x / step)) % 5 == 0 else minor_color
		canvas.draw_line(Vector2(x, top_left.y), Vector2(x, end_y), color_x, line_thickness)
		x += step
	var y: float = start_y
	while y <= end_y:
		var color_y: Color = major_color if int(round(y / step)) % 5 == 0 else minor_color
		canvas.draw_line(Vector2(top_left.x, y), Vector2(end_x, y), color_y, line_thickness)
		y += step


static func draw_grid_into(canvas: CanvasItem, world_rect: Rect2, grid_size: int, snap_enabled: bool, pixel_per_world: float) -> void:
	var bg: Color = ThemeManager.background_color()
	canvas.draw_rect(world_rect, bg, true)
	_draw_grid_lines(canvas, world_rect, grid_size, snap_enabled, pixel_per_world, bg)
