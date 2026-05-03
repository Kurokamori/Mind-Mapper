class_name GridBackground
extends Node2D

const MAJOR_COLOR := Color(0.18, 0.19, 0.22, 1.0)
const MINOR_COLOR := Color(0.13, 0.14, 0.16, 1.0)
const BG_COLOR := Color(0.09, 0.10, 0.12, 1.0)

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
	draw_grid_into(self, Rect2(top_left, world_size), SnapService.grid_size, SnapService.enabled, pixel_per_world)


static func draw_grid_into(canvas: CanvasItem, world_rect: Rect2, grid_size: int, snap_enabled: bool, pixel_per_world: float) -> void:
	canvas.draw_rect(world_rect, BG_COLOR, true)
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
	var minor_color: Color = MINOR_COLOR if snap_enabled else MINOR_COLOR.darkened(0.4)
	var major_color: Color = MAJOR_COLOR if snap_enabled else MAJOR_COLOR.darkened(0.4)
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
