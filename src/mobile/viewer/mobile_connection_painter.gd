class_name MobileConnectionPainter
extends Node2D

const ARROW_HEAD_LENGTH: float = 12.0
const ARROW_HEAD_WIDTH: float = 8.0
const BEZIER_SAMPLES: int = 24
const SMOOTH_SAMPLES_PER_SEGMENT: int = 14
const SMOOTH_CENTRIPETAL_ALPHA: float = 0.5

const SELECTION_OUTLINE_COLOR: Color = Color(0.35, 0.7, 1.0, 1.0)
const SELECTION_OUTLINE_EXTRA_WIDTH: float = 4.0

var _connections: Array = []
var _item_lookup: Callable = Callable()
var _selected_id: String = ""


func bind_items_lookup(lookup: Callable) -> void:
	_item_lookup = lookup


func set_connections(list: Array) -> void:
	_connections.clear()
	for c: Variant in list:
		if c is Connection:
			_connections.append(c)
	queue_redraw()


func set_selected_id(id: String) -> void:
	if _selected_id == id:
		return
	_selected_id = id
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	for connection_v: Variant in _connections:
		var c: Connection = connection_v
		_draw_connection(c)


func _draw_connection(c: Connection) -> void:
	var endpoints: Array = _compute_endpoints(c)
	if endpoints.is_empty():
		return
	var start_point: Vector2 = endpoints[0]
	var end_point: Vector2 = endpoints[1]
	var path: PackedVector2Array = _build_path(c, start_point, end_point)
	if path.size() < 2:
		return
	if c.id == _selected_id:
		draw_polyline(path, SELECTION_OUTLINE_COLOR, max(1.0, c.thickness) + SELECTION_OUTLINE_EXTRA_WIDTH, true)
	draw_polyline(path, c.color, max(1.0, c.thickness), true)
	if c.arrow_end:
		_draw_arrow(path[path.size() - 2], path[path.size() - 1], c.color, c.thickness)
	if c.arrow_start:
		_draw_arrow(path[1], path[0], c.color, c.thickness)
	if c.label != "":
		_draw_label(c, path)


func _draw_arrow(prev_point: Vector2, tip: Vector2, color: Color, width: float) -> void:
	var direction: Vector2 = (tip - prev_point)
	if direction.length_squared() <= 0.0001:
		return
	direction = direction.normalized()
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	var base: Vector2 = tip - direction * ARROW_HEAD_LENGTH
	var left: Vector2 = base + perpendicular * (ARROW_HEAD_WIDTH * 0.5)
	var right: Vector2 = base - perpendicular * (ARROW_HEAD_WIDTH * 0.5)
	draw_colored_polygon(PackedVector2Array([tip, left, right]), color)
	draw_line(tip, left, color, max(1.0, width * 0.6), true)
	draw_line(tip, right, color, max(1.0, width * 0.6), true)


func _draw_label(c: Connection, path: PackedVector2Array) -> void:
	var midpoint: Vector2 = _path_midpoint(path)
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var label_size: int = max(10, c.label_font_size)
	var text_width: float = font.get_string_size(c.label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size).x
	var pad: float = 4.0
	var rect: Rect2 = Rect2(
		midpoint - Vector2(text_width * 0.5 + pad, label_size * 0.5 + pad),
		Vector2(text_width + pad * 2.0, label_size + pad * 2.0),
	)
	draw_rect(rect, Color(0.10, 0.12, 0.16, 0.88), true)
	draw_rect(rect, c.color, false, 1.0)
	draw_string(
		font,
		Vector2(rect.position.x + pad, rect.position.y + pad + font.get_ascent(label_size)),
		c.label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		label_size,
		Color(0.96, 0.97, 0.99, 1.0),
	)


func _path_midpoint(path: PackedVector2Array) -> Vector2:
	if path.size() == 0:
		return Vector2.ZERO
	if path.size() == 1:
		return path[0]
	var total_length: float = 0.0
	for i: int in range(path.size() - 1):
		total_length += path[i].distance_to(path[i + 1])
	if total_length <= 0.0:
		return path[0]
	var target_length: float = total_length * 0.5
	var traveled: float = 0.0
	for i: int in range(path.size() - 1):
		var seg: float = path[i].distance_to(path[i + 1])
		if traveled + seg >= target_length:
			var remainder: float = target_length - traveled
			var t: float = 0.0 if seg == 0.0 else remainder / seg
			return path[i].lerp(path[i + 1], t)
		traveled += seg
	return path[path.size() - 1]


func _compute_endpoints(c: Connection) -> Array:
	var from_dict: Dictionary = _lookup_item(c.from_item_id)
	var to_dict: Dictionary = _lookup_item(c.to_item_id)
	if from_dict.is_empty() or to_dict.is_empty():
		return []
	var from_center: Vector2 = _center_of(from_dict)
	var to_center: Vector2 = _center_of(to_dict)
	var to_reference: Vector2 = _anchor_position(to_dict, c.to_anchor) if c.to_anchor != Connection.ANCHOR_AUTO else to_center
	var from_reference: Vector2 = _anchor_position(from_dict, c.from_anchor) if c.from_anchor != Connection.ANCHOR_AUTO else from_center
	var start_point: Vector2 = _resolve_anchor(from_dict, c.from_anchor, to_reference)
	var end_point: Vector2 = _resolve_anchor(to_dict, c.to_anchor, from_reference)
	return [start_point, end_point]


func _lookup_item(item_id: String) -> Dictionary:
	if not _item_lookup.is_valid() or item_id == "":
		return {}
	var result: Variant = _item_lookup.call(item_id)
	if typeof(result) != TYPE_DICTIONARY:
		return {}
	return result


func _rect_of(item: Dictionary) -> Rect2:
	return Rect2(_position_of(item), _size_of(item))


func _position_of(item: Dictionary) -> Vector2:
	var raw: Variant = item.get("position", [0, 0])
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO


func _size_of(item: Dictionary) -> Vector2:
	var raw: Variant = item.get("size", [160, 80])
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2(160, 80)


func _center_of(item: Dictionary) -> Vector2:
	return _position_of(item) + _size_of(item) * 0.5


func _anchor_position(item: Dictionary, anchor: String) -> Vector2:
	var pos: Vector2 = _position_of(item)
	var size_v: Vector2 = _size_of(item)
	match anchor:
		Connection.ANCHOR_N:
			return pos + Vector2(size_v.x * 0.5, 0.0)
		Connection.ANCHOR_NE:
			return pos + Vector2(size_v.x, 0.0)
		Connection.ANCHOR_E:
			return pos + Vector2(size_v.x, size_v.y * 0.5)
		Connection.ANCHOR_SE:
			return pos + Vector2(size_v.x, size_v.y)
		Connection.ANCHOR_S:
			return pos + Vector2(size_v.x * 0.5, size_v.y)
		Connection.ANCHOR_SW:
			return pos + Vector2(0.0, size_v.y)
		Connection.ANCHOR_W:
			return pos + Vector2(0.0, size_v.y * 0.5)
		Connection.ANCHOR_NW:
			return pos
		_:
			return _center_of(item)


func _resolve_anchor(item: Dictionary, anchor: String, target_reference: Vector2) -> Vector2:
	if anchor == "" or anchor == Connection.ANCHOR_AUTO:
		return _intersect_rect_edge(_rect_of(item), _center_of(item), target_reference)
	return _anchor_position(item, anchor)


func _intersect_rect_edge(rect: Rect2, center: Vector2, target: Vector2) -> Vector2:
	var direction: Vector2 = target - center
	if direction.length_squared() <= 0.0001:
		return center
	var half: Vector2 = rect.size * 0.5
	if half.x <= 0.0 or half.y <= 0.0:
		return center
	var scale_x: float = INF
	if abs(direction.x) > 0.0001:
		scale_x = half.x / abs(direction.x)
	var scale_y: float = INF
	if abs(direction.y) > 0.0001:
		scale_y = half.y / abs(direction.y)
	var s: float = min(scale_x, scale_y)
	return center + direction * s


func _build_path(c: Connection, start_point: Vector2, end_point: Vector2) -> PackedVector2Array:
	if c.waypoints.size() > 0:
		var pts: PackedVector2Array = PackedVector2Array()
		pts.append(start_point)
		for w in c.waypoints:
			pts.append(w)
		pts.append(end_point)
		if c.style == Connection.STYLE_BEZIER:
			return _smooth_through_points(pts)
		return pts
	match c.style:
		Connection.STYLE_STRAIGHT:
			return PackedVector2Array([start_point, end_point])
		Connection.STYLE_ORTHOGONAL:
			return _build_simple_orthogonal_path(start_point, end_point)
		_:
			return _build_bezier_path(start_point, end_point)


func _smooth_through_points(pts: PackedVector2Array) -> PackedVector2Array:
	var count: int = pts.size()
	if count < 2:
		return pts
	if count == 2:
		return pts
	var out: PackedVector2Array = PackedVector2Array()
	out.append(pts[0])
	var last: int = count - 1
	for i: int in range(last):
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p0: Vector2 = pts[i - 1] if i > 0 else p1 + (p1 - p2)
		var p3: Vector2 = pts[i + 2] if i + 2 <= last else p2 + (p2 - p1)
		for s: int in range(1, SMOOTH_SAMPLES_PER_SEGMENT + 1):
			var t: float = float(s) / float(SMOOTH_SAMPLES_PER_SEGMENT)
			out.append(_centripetal_catmull_rom(p0, p1, p2, p3, t))
	return out


func _centripetal_catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t0: float = 0.0
	var t1: float = t0 + pow(maxf(p0.distance_to(p1), 0.0001), SMOOTH_CENTRIPETAL_ALPHA)
	var t2: float = t1 + pow(maxf(p1.distance_to(p2), 0.0001), SMOOTH_CENTRIPETAL_ALPHA)
	var t3: float = t2 + pow(maxf(p2.distance_to(p3), 0.0001), SMOOTH_CENTRIPETAL_ALPHA)
	var u: float = lerp(t1, t2, t)
	var a1: Vector2 = ((t1 - u) / (t1 - t0)) * p0 + ((u - t0) / (t1 - t0)) * p1
	var a2: Vector2 = ((t2 - u) / (t2 - t1)) * p1 + ((u - t1) / (t2 - t1)) * p2
	var a3: Vector2 = ((t3 - u) / (t3 - t2)) * p2 + ((u - t2) / (t3 - t2)) * p3
	var b1: Vector2 = ((t2 - u) / (t2 - t0)) * a1 + ((u - t0) / (t2 - t0)) * a2
	var b2: Vector2 = ((t3 - u) / (t3 - t1)) * a2 + ((u - t1) / (t3 - t1)) * a3
	return ((t2 - u) / (t2 - t1)) * b1 + ((u - t1) / (t2 - t1)) * b2


func _build_bezier_path(start_point: Vector2, end_point: Vector2) -> PackedVector2Array:
	var distance: float = start_point.distance_to(end_point)
	var handle_offset: float = clamp(distance * 0.4, 30.0, 220.0)
	var direction: Vector2 = end_point - start_point
	var horizontal_dominant: bool = abs(direction.x) >= abs(direction.y)
	var control1: Vector2
	var control2: Vector2
	if horizontal_dominant:
		control1 = start_point + Vector2(handle_offset * _sign_or_one(direction.x), 0.0)
		control2 = end_point - Vector2(handle_offset * _sign_or_one(direction.x), 0.0)
	else:
		control1 = start_point + Vector2(0.0, handle_offset * _sign_or_one(direction.y))
		control2 = end_point - Vector2(0.0, handle_offset * _sign_or_one(direction.y))
	var path: PackedVector2Array = PackedVector2Array()
	path.resize(BEZIER_SAMPLES + 1)
	for i: int in range(BEZIER_SAMPLES + 1):
		var t: float = float(i) / float(BEZIER_SAMPLES)
		path[i] = _cubic_bezier(start_point, control1, control2, end_point, t)
	return path


func _build_simple_orthogonal_path(start_point: Vector2, end_point: Vector2) -> PackedVector2Array:
	var midpoint_x: float = (start_point.x + end_point.x) * 0.5
	return PackedVector2Array([
		start_point,
		Vector2(midpoint_x, start_point.y),
		Vector2(midpoint_x, end_point.y),
		end_point,
	])


func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return (u * u * u) * p0 + (3.0 * u * u * t) * p1 + (3.0 * u * t * t) * p2 + (t * t * t) * p3


func _sign_or_one(value: float) -> float:
	if value < 0.0:
		return -1.0
	return 1.0
