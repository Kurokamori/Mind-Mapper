class_name ConnectorNode
extends BoardItem

enum Style {
	LINE,
	ARROW,
}

const DEFAULT_COLOR: Color = Color(0.12, 0.14, 0.20, 1.0)
const DEFAULT_WIDTH: float = 2.5
const MIN_WIDTH: float = 0.5
const MAX_WIDTH: float = 32.0
const MIN_HEAD_SIZE: float = 6.0
const MAX_HEAD_SIZE: float = 64.0
const DEFAULT_HEAD_SIZE: float = 14.0

const HIT_PADDING_PX: float = 6.0
const ENDPOINT_HANDLE_RADIUS: float = 7.0
const ENDPOINT_HIT_RADIUS: float = 10.0
const BBOX_PADDING_PX: float = 16.0

const ENDPOINT_START: String = "start"
const ENDPOINT_END: String = "end"

@export var style: int = Style.ARROW
@export var color: Color = DEFAULT_COLOR
@export var width: float = DEFAULT_WIDTH
@export var head_size: float = DEFAULT_HEAD_SIZE

var start_local: Vector2 = Vector2(BBOX_PADDING_PX, BBOX_PADDING_PX)
var end_local: Vector2 = Vector2(160.0 + BBOX_PADDING_PX, BBOX_PADDING_PX)

var _endpoint_drag: String = ""
var _endpoint_drag_start_world_start: Vector2 = Vector2.ZERO
var _endpoint_drag_start_world_end: Vector2 = Vector2.ZERO
var _endpoint_drag_press_screen: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _resize_grip != null:
		_resize_grip.visible = false
		_resize_grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _install_resize_grip() -> void:
	pass


func _refresh_resize_grip_visibility() -> void:
	pass


func default_size() -> Vector2:
	return Vector2(160.0 + BBOX_PADDING_PX * 2.0, BBOX_PADDING_PX * 2.0 + 4.0)


func display_name() -> String:
	if style == Style.ARROW:
		return "Arrow"
	return "Line"


func minimum_item_size() -> Vector2:
	return Vector2(BBOX_PADDING_PX * 2.0, BBOX_PADDING_PX * 2.0)


func set_endpoints_world(start_world: Vector2, end_world: Vector2) -> void:
	var min_x: float = min(start_world.x, end_world.x) - BBOX_PADDING_PX
	var min_y: float = min(start_world.y, end_world.y) - BBOX_PADDING_PX
	var max_x: float = max(start_world.x, end_world.x) + BBOX_PADDING_PX
	var max_y: float = max(start_world.y, end_world.y) + BBOX_PADDING_PX
	position = Vector2(min_x, min_y)
	size = Vector2(max(max_x - min_x, BBOX_PADDING_PX * 2.0), max(max_y - min_y, BBOX_PADDING_PX * 2.0))
	start_local = start_world - position
	end_local = end_world - position
	queue_redraw()


func start_world() -> Vector2:
	return position + start_local


func end_world() -> Vector2:
	return position + end_local


func _update_port_hover(_local_pos: Vector2) -> void:
	pass


func _has_point(point: Vector2) -> bool:
	if _selected:
		if point.distance_to(start_local) <= ENDPOINT_HIT_RADIUS:
			return true
		if point.distance_to(end_local) <= ENDPOINT_HIT_RADIUS:
			return true
	return _distance_to_segment(point, start_local, end_local) <= max(HIT_PADDING_PX, width * 0.5 + 2.0)


func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq <= 0.0001:
		return p.distance_to(a)
	var t: float = clamp((p - a).dot(ab) / len_sq, 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return p.distance_to(proj)


func _hit_endpoint(local_pos: Vector2) -> String:
	if not _selected:
		return ""
	if local_pos.distance_to(start_local) <= ENDPOINT_HIT_RADIUS:
		return ENDPOINT_START
	if local_pos.distance_to(end_local) <= ENDPOINT_HIT_RADIUS:
		return ENDPOINT_END
	return ""


func _get_cursor_shape(at_position: Vector2 = Vector2.ZERO) -> int:
	if _hit_endpoint(at_position) != "":
		return Control.CURSOR_DRAG
	return Control.CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var ctrl_or_meta: bool = mb.ctrl_pressed or mb.meta_pressed
				if ctrl_or_meta and has_link():
					emit_signal("link_followed", self)
					accept_event()
					return
				var local: Vector2 = get_local_mouse_position()
				var ep: String = _hit_endpoint(local)
				if ep != "" and not locked and not read_only:
					_endpoint_drag = ep
					_endpoint_drag_press_screen = mb.global_position
					_endpoint_drag_start_world_start = start_world()
					_endpoint_drag_start_world_end = end_world()
					emit_signal("resize_started", self)
					accept_event()
					return
				super._gui_input(event)
				return
			else:
				if _endpoint_drag != "":
					var was: String = _endpoint_drag
					_endpoint_drag = ""
					emit_signal("resize_ended", self)
					var old_start: Vector2 = _endpoint_drag_start_world_start
					var old_end: Vector2 = _endpoint_drag_start_world_end
					var new_start: Vector2 = start_world()
					var new_end: Vector2 = end_world()
					if old_start != new_start or old_end != new_end:
						_record_endpoint_history(was, old_start, old_end, new_start, new_end)
					accept_event()
					return
				super._gui_input(event)
				return
	elif event is InputEventMouseMotion:
		if _endpoint_drag != "":
			var motion: InputEventMouseMotion = event as InputEventMouseMotion
			var parent_node: Control = get_parent() as Control
			var world_pos: Vector2
			if parent_node != null:
				world_pos = parent_node.get_local_mouse_position()
			else:
				world_pos = position + get_local_mouse_position()
			world_pos = SnapService.maybe_snap(world_pos)
			if _endpoint_drag == ENDPOINT_START:
				set_endpoints_world(world_pos, end_world())
			else:
				set_endpoints_world(start_world(), world_pos)
			emit_signal("resizing", self, size)
			accept_event()
			return
	super._gui_input(event)


func _record_endpoint_history(which: String, old_start: Vector2, old_end: Vector2, new_start: Vector2, new_end: Vector2) -> void:
	var editor: Node = EditorLocator.find_for(self)
	if editor == null:
		return
	if which == ENDPOINT_START:
		History.push_already_done(ModifyPropertyCommand.new(editor, item_id, "start", [old_start.x, old_start.y], [new_start.x, new_start.y]))
	else:
		History.push_already_done(ModifyPropertyCommand.new(editor, item_id, "end", [old_end.x, old_end.y], [new_end.x, new_end.y]))
	if editor.has_method("request_save"):
		editor.request_save()


func _draw_body() -> void:
	var w: float = max(width, MIN_WIDTH)
	var head: float = clamp(head_size, MIN_HEAD_SIZE, MAX_HEAD_SIZE)
	match style:
		Style.LINE:
			draw_line(start_local, end_local, color, w, true)
		Style.ARROW:
			_draw_arrow_segment(start_local, end_local, w, head)
	if _selected and not read_only and not locked:
		_draw_endpoint_handle(start_local)
		_draw_endpoint_handle(end_local)


func _draw_arrow_segment(a: Vector2, b: Vector2, line_w: float, head: float) -> void:
	var dir: Vector2 = b - a
	var length: float = dir.length()
	if length <= 0.0001:
		draw_circle(a, max(line_w, 2.0), color)
		return
	var unit: Vector2 = dir / length
	var head_h: float = min(head, length * 0.6)
	var tip: Vector2 = b
	var base: Vector2 = b - unit * head_h
	draw_line(a, base, color, line_w, true)
	var perp: Vector2 = Vector2(-unit.y, unit.x)
	var half_w: float = head_h * 0.6
	var left: Vector2 = base + perp * half_w
	var right: Vector2 = base - perp * half_w
	var pts: PackedVector2Array = PackedVector2Array([tip, left, right])
	var colors: PackedColorArray = PackedColorArray([color, color, color])
	draw_polygon(pts, colors)


func _draw_endpoint_handle(center: Vector2) -> void:
	var fill: Color = Color(0.10, 0.50, 0.95, 1.0)
	var outline: Color = Color(1.0, 1.0, 1.0, 1.0)
	draw_circle(center, ENDPOINT_HANDLE_RADIUS, outline)
	draw_circle(center, ENDPOINT_HANDLE_RADIUS - 1.5, fill)


func to_dict() -> Dictionary:
	var base: Dictionary = super.to_dict()
	var sw: Vector2 = start_world()
	var ew: Vector2 = end_world()
	base["start"] = [sw.x, sw.y]
	base["end"] = [ew.x, ew.y]
	return base


func serialize_payload() -> Dictionary:
	return {
		"style": style,
		"color": ColorUtil.to_array(color),
		"width": width,
		"head_size": head_size,
	}


func deserialize_payload(d: Dictionary) -> void:
	style = int(d.get("style", style))
	color = ColorUtil.from_array(d.get("color", null), color)
	width = clamp(float(d.get("width", width)), MIN_WIDTH, MAX_WIDTH)
	head_size = clamp(float(d.get("head_size", head_size)), MIN_HEAD_SIZE, MAX_HEAD_SIZE)
	var start_raw: Variant = d.get("start", null)
	var end_raw: Variant = d.get("end", null)
	if typeof(start_raw) == TYPE_ARRAY and (start_raw as Array).size() >= 2 \
			and typeof(end_raw) == TYPE_ARRAY and (end_raw as Array).size() >= 2:
		var sw: Vector2 = Vector2(float(start_raw[0]), float(start_raw[1]))
		var ew: Vector2 = Vector2(float(end_raw[0]), float(end_raw[1]))
		set_endpoints_world(sw, ew)
	else:
		start_local = Vector2(BBOX_PADDING_PX, size.y * 0.5)
		end_local = Vector2(size.x - BBOX_PADDING_PX, size.y * 0.5)
	queue_redraw()


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"style":
			style = int(value)
		"color":
			color = ColorUtil.from_array(value, color)
		"width":
			width = clamp(float(value), MIN_WIDTH, MAX_WIDTH)
		"head_size":
			head_size = clamp(float(value), MIN_HEAD_SIZE, MAX_HEAD_SIZE)
		"start":
			if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
				set_endpoints_world(Vector2(float(value[0]), float(value[1])), end_world())
		"end":
			if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
				set_endpoints_world(start_world(), Vector2(float(value[0]), float(value[1])))
	queue_redraw()


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/connector/connector_inspector.tscn")
	var inst: ConnectorInspector = scene.instantiate()
	inst.bind(self)
	return inst


func bulk_shareable_properties() -> Array:
	return [
		{"key": "color", "label": "Color", "kind": "color"},
		{"key": "width", "label": "Width", "kind": "float"},
	]
