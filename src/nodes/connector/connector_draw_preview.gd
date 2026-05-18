class_name ConnectorDrawPreview
extends Node2D

const PREVIEW_COLOR: Color = Color(0.10, 0.50, 0.95, 0.85)
const PREVIEW_HEAD_SIZE: float = 14.0
const ENDPOINT_RADIUS: float = 5.0

var _active: bool = false
var _style: int = ConnectorNode.Style.ARROW
var _start_world: Vector2 = Vector2.ZERO
var _end_world: Vector2 = Vector2.ZERO
var _color: Color = PREVIEW_COLOR
var _width: float = ConnectorNode.DEFAULT_WIDTH


func begin(style: int, color: Color, width: float, start_world: Vector2) -> void:
	_active = true
	_style = style
	_color = color
	_color.a = max(_color.a, 0.85)
	_width = width
	_start_world = start_world
	_end_world = start_world
	queue_redraw()


func update_end(end_world: Vector2) -> void:
	if not _active:
		return
	_end_world = end_world
	queue_redraw()


func clear_preview() -> void:
	_active = false
	queue_redraw()


func is_active() -> bool:
	return _active


func start_world() -> Vector2:
	return _start_world


func _draw() -> void:
	if not _active:
		return
	var w: float = max(_width, ConnectorNode.MIN_WIDTH)
	var head: float = PREVIEW_HEAD_SIZE
	match _style:
		ConnectorNode.Style.LINE:
			draw_line(_start_world, _end_world, _color, w, true)
		ConnectorNode.Style.ARROW:
			_draw_arrow_segment(_start_world, _end_world, w, head)
	draw_circle(_start_world, ENDPOINT_RADIUS, _color)


func _draw_arrow_segment(a: Vector2, b: Vector2, line_w: float, head: float) -> void:
	var dir: Vector2 = b - a
	var length: float = dir.length()
	if length <= 0.0001:
		draw_circle(a, max(line_w, 2.0), _color)
		return
	var unit: Vector2 = dir / length
	var head_h: float = min(head, length * 0.6)
	var tip: Vector2 = b
	var base: Vector2 = b - unit * head_h
	draw_line(a, base, _color, line_w, true)
	var perp: Vector2 = Vector2(-unit.y, unit.x)
	var half_w: float = head_h * 0.6
	var left: Vector2 = base + perp * half_w
	var right: Vector2 = base - perp * half_w
	var pts: PackedVector2Array = PackedVector2Array([tip, left, right])
	var colors: PackedColorArray = PackedColorArray([_color, _color, _color])
	draw_polygon(pts, colors)
