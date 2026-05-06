class_name ConnectionLayer
extends Node2D

signal connection_selected(connection: Connection)
signal connections_selected(connections: Array)
signal selection_cleared()

const HIT_TOLERANCE_PX: float = 8.0
const ARROW_HEAD_LENGTH: float = 12.0
const ARROW_HEAD_WIDTH: float = 8.0
const PENDING_LINE_COLOR: Color = Color(0.6, 0.85, 1.0, 0.85)
const PENDING_LINE_DASH: float = 8.0
const SELECTION_OUTLINE_COLOR: Color = Color(0.35, 0.7, 1.0, 0.9)
const SELECTION_OUTLINE_PADDING: float = 2.5
const ENDPOINT_DOT_RADIUS: float = 4.0
const BEZIER_SAMPLES: int = 24
const WAYPOINT_RADIUS: float = 5.0
const WAYPOINT_HIT_RADIUS: float = 9.0
const ROUTING_GRID: float = 24.0
const ROUTING_PADDING: float = 16.0

var _editor: Node = null
var _connections: Array[Connection] = []
var _selected_ids: Array[String] = []
var _pending_from_id: String = ""
var _pending_from_anchor: String = Connection.ANCHOR_AUTO
var _pending_endpoint_world: Vector2 = Vector2.ZERO
var _pending_active: bool = false
var _waypoint_drag_conn_id: String = ""
var _waypoint_drag_index: int = -1


func bind_editor(editor: Node) -> void:
	_editor = editor


func set_connections(list: Array) -> void:
	_connections.clear()
	for c in list:
		if c is Connection:
			_connections.append(c)
	queue_redraw()


func get_connections() -> Array[Connection]:
	return _connections.duplicate()


func get_connection_dicts() -> Array:
	var out: Array = []
	for c: Connection in _connections:
		out.append(c.to_dict())
	return out


func find_connection(connection_id: String) -> Connection:
	for c: Connection in _connections:
		if c.id == connection_id:
			return c
	return null


func add_connection(c: Connection) -> void:
	if c == null:
		return
	if find_connection(c.id) != null:
		return
	_connections.append(c)
	queue_redraw()


func remove_connection_by_id(connection_id: String) -> Connection:
	for i: int in range(_connections.size()):
		var c: Connection = _connections[i]
		if c.id == connection_id:
			_connections.remove_at(i)
			_selected_ids.erase(connection_id)
			queue_redraw()
			return c
	return null


func remove_connections_referencing_item(item_id: String) -> Array[Connection]:
	var removed: Array[Connection] = []
	var i: int = _connections.size() - 1
	while i >= 0:
		var c: Connection = _connections[i]
		if c.references_item(item_id):
			removed.append(c)
			_connections.remove_at(i)
			_selected_ids.erase(c.id)
		i -= 1
	if removed.size() > 0:
		queue_redraw()
	return removed


func selected_connection() -> Connection:
	if _selected_ids.is_empty():
		return null
	return find_connection(_selected_ids[0])


func selected_connections() -> Array:
	var out: Array = []
	for id in _selected_ids:
		var c: Connection = find_connection(id)
		if c != null:
			out.append(c)
	return out


func select_connection(connection_id: String, additive: bool = false) -> void:
	if connection_id == "":
		clear_selection()
		return
	var c: Connection = find_connection(connection_id)
	if c == null:
		return
	if not additive:
		_selected_ids.clear()
	if not _selected_ids.has(connection_id):
		_selected_ids.append(connection_id)
	queue_redraw()
	if _selected_ids.size() == 1:
		emit_signal("connection_selected", c)
	else:
		emit_signal("connections_selected", selected_connections())


func clear_selection() -> void:
	if _selected_ids.is_empty():
		return
	_selected_ids.clear()
	queue_redraw()
	emit_signal("selection_cleared")


func notify_item_changed() -> void:
	queue_redraw()


func begin_pending(from_item_id: String, world_pos: Vector2, from_anchor_value: String = Connection.ANCHOR_AUTO) -> void:
	_pending_active = true
	_pending_from_id = from_item_id
	_pending_from_anchor = from_anchor_value
	_pending_endpoint_world = world_pos
	queue_redraw()


func update_pending_endpoint(world_pos: Vector2) -> void:
	if not _pending_active:
		return
	_pending_endpoint_world = world_pos
	queue_redraw()


func cancel_pending() -> void:
	if not _pending_active:
		return
	_pending_active = false
	_pending_from_id = ""
	_pending_from_anchor = Connection.ANCHOR_AUTO
	queue_redraw()


func is_pending_active() -> bool:
	return _pending_active


func pending_from_id() -> String:
	return _pending_from_id


func hit_test(world_pos: Vector2) -> Connection:
	var best: Connection = null
	var best_distance: float = HIT_TOLERANCE_PX
	for c: Connection in _connections:
		var endpoints: Array = _compute_endpoints(c)
		if endpoints.is_empty():
			continue
		var distance: float = _distance_to_path(c, endpoints[0], endpoints[1], world_pos)
		if distance <= best_distance:
			best_distance = distance
			best = c
	return best


func hit_test_in_rect(rect: Rect2) -> Array:
	var out: Array = []
	for c: Connection in _connections:
		var endpoints: Array = _compute_endpoints(c)
		if endpoints.is_empty():
			continue
		var path: PackedVector2Array = _build_path(c, endpoints[0], endpoints[1])
		for p in path:
			if rect.has_point(p):
				out.append(c)
				break
	return out


func hit_test_waypoint(world_pos: Vector2) -> Dictionary:
	for id in _selected_ids:
		var c: Connection = find_connection(id)
		if c == null:
			continue
		for i in range(c.waypoints.size()):
			if (c.waypoints[i] as Vector2).distance_to(world_pos) <= WAYPOINT_HIT_RADIUS:
				return {"connection_id": c.id, "index": i}
	return {}


func add_waypoint_at(world_pos: Vector2) -> bool:
	var c: Connection = hit_test(world_pos)
	if c == null:
		return false
	if not _selected_ids.has(c.id):
		select_connection(c.id, false)
	var endpoints: Array = _compute_endpoints(c)
	if endpoints.is_empty():
		return false
	var path: PackedVector2Array = _build_path(c, endpoints[0], endpoints[1])
	var insert_idx: int = c.waypoints.size()
	var best_seg: int = -1
	var best_d: float = INF
	for i in range(path.size() - 1):
		var d: float = _distance_to_segment(path[i], path[i + 1], world_pos)
		if d < best_d:
			best_d = d
			best_seg = i
	if best_seg >= 0:
		insert_idx = clampi(best_seg, 0, c.waypoints.size())
	if _editor != null:
		var before_arr: Array = []
		for w in c.waypoints:
			before_arr.append([float((w as Vector2).x), float((w as Vector2).y)])
		var after_arr: Array = before_arr.duplicate(true)
		after_arr.insert(insert_idx, [world_pos.x, world_pos.y])
		History.push(ModifyConnectionPropertyCommand.new(_editor, c.id, "waypoints", before_arr, after_arr))
	queue_redraw()
	return true


func begin_waypoint_drag(connection_id: String, index: int) -> void:
	_waypoint_drag_conn_id = connection_id
	_waypoint_drag_index = index


func is_dragging_waypoint() -> bool:
	return _waypoint_drag_conn_id != ""


func update_waypoint_drag(world_pos: Vector2) -> void:
	if _waypoint_drag_conn_id == "":
		return
	var c: Connection = find_connection(_waypoint_drag_conn_id)
	if c == null or _waypoint_drag_index < 0 or _waypoint_drag_index >= c.waypoints.size():
		return
	c.waypoints[_waypoint_drag_index] = world_pos
	queue_redraw()


func end_waypoint_drag() -> void:
	if _waypoint_drag_conn_id == "":
		return
	if _editor != null:
		var c: Connection = find_connection(_waypoint_drag_conn_id)
		if c != null:
			var arr: Array = []
			for w in c.waypoints:
				arr.append([float((w as Vector2).x), float((w as Vector2).y)])
			if _editor.has_method("request_save"):
				_editor.request_save()
	_waypoint_drag_conn_id = ""
	_waypoint_drag_index = -1


func remove_selected_waypoint(world_pos: Vector2) -> bool:
	var hit: Dictionary = hit_test_waypoint(world_pos)
	if hit.is_empty():
		return false
	var c: Connection = find_connection(String(hit.connection_id))
	if c == null:
		return false
	var idx: int = int(hit.index)
	if _editor != null:
		var before_arr: Array = []
		var after_arr: Array = []
		for i in range(c.waypoints.size()):
			var w: Vector2 = c.waypoints[i]
			before_arr.append([w.x, w.y])
			if i != idx:
				after_arr.append([w.x, w.y])
		History.push(ModifyConnectionPropertyCommand.new(_editor, c.id, "waypoints", before_arr, after_arr))
	queue_redraw()
	return true


func _draw() -> void:
	for c: Connection in _connections:
		_draw_connection(c)
	if _pending_active:
		_draw_pending()


func _draw_connection(c: Connection) -> void:
	var endpoints: Array = _compute_endpoints(c)
	if endpoints.is_empty():
		return
	var start_point: Vector2 = endpoints[0]
	var end_point: Vector2 = endpoints[1]
	var path: PackedVector2Array = _build_path(c, start_point, end_point)
	if path.size() < 2:
		return
	var is_selected: bool = _selected_ids.has(c.id)
	if is_selected:
		_draw_polyline(path, SELECTION_OUTLINE_COLOR, c.thickness + SELECTION_OUTLINE_PADDING * 2.0)
	_draw_polyline(path, c.color, c.thickness)
	if c.arrow_end:
		_draw_arrow_head(path[path.size() - 2], path[path.size() - 1], c.color, c.thickness)
	if c.arrow_start:
		_draw_arrow_head(path[1], path[0], c.color, c.thickness)
	if c.label != "":
		_draw_label(c, path)
	if is_selected:
		for w in c.waypoints:
			draw_circle(w, WAYPOINT_RADIUS + 1.5, Color(0.96, 0.97, 1.0, 1.0))
			draw_circle(w, WAYPOINT_RADIUS, SELECTION_OUTLINE_COLOR)


func _draw_polyline(path: PackedVector2Array, color: Color, width: float) -> void:
	if path.size() < 2:
		return
	draw_polyline(path, color, max(1.0, width), true)


func _draw_arrow_head(prev_point: Vector2, tip: Vector2, color: Color, width: float) -> void:
	var direction: Vector2 = (tip - prev_point)
	if direction.length_squared() <= 0.0001:
		return
	direction = direction.normalized()
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	var base: Vector2 = tip - direction * ARROW_HEAD_LENGTH
	var left: Vector2 = base + perpendicular * (ARROW_HEAD_WIDTH * 0.5)
	var right: Vector2 = base - perpendicular * (ARROW_HEAD_WIDTH * 0.5)
	var poly: PackedVector2Array = PackedVector2Array([tip, left, right])
	draw_colored_polygon(poly, color)
	draw_line(tip, left, color, max(1.0, width * 0.6), true)
	draw_line(tip, right, color, max(1.0, width * 0.6), true)


func _draw_label(c: Connection, path: PackedVector2Array) -> void:
	var midpoint: Vector2 = _path_midpoint(path)
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var label_size: int = max(8, c.label_font_size)
	var text_width: float = font.get_string_size(c.label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size).x
	var pad: float = 4.0
	var rect: Rect2 = Rect2(
		midpoint - Vector2(text_width * 0.5 + pad, label_size * 0.5 + pad),
		Vector2(text_width + pad * 2.0, label_size + pad * 2.0),
	)
	draw_rect(rect, Color(0.10, 0.12, 0.16, 0.85), true)
	draw_rect(rect, c.color, false, 1.0)
	draw_string(font, Vector2(rect.position.x + pad, rect.position.y + pad + font.get_ascent(label_size)), c.label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size, Color(0.96, 0.97, 0.99, 1.0))


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


func _draw_pending() -> void:
	var from_item: BoardItem = _resolve_item(_pending_from_id)
	if from_item == null:
		return
	var start_point: Vector2 = _resolve_anchor_position(from_item, _pending_from_anchor, _pending_endpoint_world)
	_draw_dashed_line(start_point, _pending_endpoint_world, PENDING_LINE_COLOR, 2.0, PENDING_LINE_DASH)
	draw_circle(start_point, ENDPOINT_DOT_RADIUS, PENDING_LINE_COLOR)
	draw_circle(_pending_endpoint_world, ENDPOINT_DOT_RADIUS, PENDING_LINE_COLOR)


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_length: float) -> void:
	var direction: Vector2 = to - from
	var total: float = direction.length()
	if total <= 0.0:
		return
	var step: Vector2 = direction.normalized() * dash_length
	var travelled: float = 0.0
	var draw_segment: bool = true
	var cursor: Vector2 = from
	while travelled < total:
		var remaining: float = min(dash_length, total - travelled)
		var segment_end: Vector2 = cursor + step.normalized() * remaining
		if draw_segment:
			draw_line(cursor, segment_end, color, max(1.0, width), true)
		cursor = segment_end
		travelled += remaining
		draw_segment = not draw_segment


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
			return _build_orthogonal_routed_path(c, start_point, end_point)
		_:
			return _build_bezier_path(start_point, end_point)


func _smooth_through_points(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 2:
		return pts
	var out: PackedVector2Array = PackedVector2Array()
	out.append(pts[0])
	for i in range(pts.size() - 1):
		var p0: Vector2 = pts[max(0, i - 1)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[min(pts.size() - 1, i + 2)]
		for s in range(1, 13):
			var t: float = float(s) / 12.0
			out.append(_catmull(p0, p1, p2, p3, t))
	return out


func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _build_bezier_path(start_point: Vector2, end_point: Vector2) -> PackedVector2Array:
	var distance: float = start_point.distance_to(end_point)
	var handle_offset: float = clamp(distance * 0.4, 30.0, 220.0)
	var direction: Vector2 = end_point - start_point
	var horizontal_dominant: bool = abs(direction.x) >= abs(direction.y)
	var control1: Vector2
	var control2: Vector2
	if horizontal_dominant:
		control1 = start_point + Vector2(handle_offset * sign_or_one(direction.x), 0.0)
		control2 = end_point - Vector2(handle_offset * sign_or_one(direction.x), 0.0)
	else:
		control1 = start_point + Vector2(0.0, handle_offset * sign_or_one(direction.y))
		control2 = end_point - Vector2(0.0, handle_offset * sign_or_one(direction.y))
	var path: PackedVector2Array = PackedVector2Array()
	path.resize(BEZIER_SAMPLES + 1)
	for i: int in range(BEZIER_SAMPLES + 1):
		var t: float = float(i) / float(BEZIER_SAMPLES)
		path[i] = _cubic_bezier(start_point, control1, control2, end_point, t)
	return path


func _build_orthogonal_routed_path(c: Connection, start_point: Vector2, end_point: Vector2) -> PackedVector2Array:
	var obstacles: Array = _collect_obstacles(c)
	var routed: PackedVector2Array = _route_orthogonal(start_point, end_point, obstacles)
	if routed.size() >= 2:
		return routed
	var midpoint_x: float = (start_point.x + end_point.x) * 0.5
	return PackedVector2Array([start_point, Vector2(midpoint_x, start_point.y), Vector2(midpoint_x, end_point.y), end_point])


func _collect_obstacles(c: Connection) -> Array:
	var obs: Array = []
	if _editor == null or not _editor.has_method("all_items"):
		return obs
	for it in _editor.all_items():
		var item: BoardItem = it
		if item == null:
			continue
		if item.item_id == c.from_item_id or item.item_id == c.to_item_id:
			continue
		obs.append(Rect2(item.position - Vector2(ROUTING_PADDING, ROUTING_PADDING), item.size + Vector2(ROUTING_PADDING * 2.0, ROUTING_PADDING * 2.0)))
	return obs


func _route_orthogonal(start_point: Vector2, end_point: Vector2, obstacles: Array) -> PackedVector2Array:
	var bounds_min: Vector2 = Vector2(min(start_point.x, end_point.x), min(start_point.y, end_point.y))
	var bounds_max: Vector2 = Vector2(max(start_point.x, end_point.x), max(start_point.y, end_point.y))
	for o in obstacles:
		var r: Rect2 = o
		bounds_min.x = min(bounds_min.x, r.position.x)
		bounds_min.y = min(bounds_min.y, r.position.y)
		bounds_max.x = max(bounds_max.x, r.position.x + r.size.x)
		bounds_max.y = max(bounds_max.y, r.position.y + r.size.y)
	bounds_min -= Vector2(ROUTING_GRID, ROUTING_GRID) * 2.0
	bounds_max += Vector2(ROUTING_GRID, ROUTING_GRID) * 2.0
	var cols: int = max(2, int((bounds_max.x - bounds_min.x) / ROUTING_GRID) + 1)
	var rows: int = max(2, int((bounds_max.y - bounds_min.y) / ROUTING_GRID) + 1)
	if cols * rows > 6000:
		var midpoint_x: float = (start_point.x + end_point.x) * 0.5
		return PackedVector2Array([start_point, Vector2(midpoint_x, start_point.y), Vector2(midpoint_x, end_point.y), end_point])
	var grid: Array = []
	for y in range(rows):
		var row: Array = []
		row.resize(cols)
		for x in range(cols):
			var wp: Vector2 = bounds_min + Vector2(float(x) * ROUTING_GRID, float(y) * ROUTING_GRID)
			var blocked: bool = false
			for o in obstacles:
				if (o as Rect2).has_point(wp):
					blocked = true
					break
			row[x] = blocked
		grid.append(row)
	var start_cell: Vector2i = Vector2i(int(round((start_point.x - bounds_min.x) / ROUTING_GRID)), int(round((start_point.y - bounds_min.y) / ROUTING_GRID)))
	var end_cell: Vector2i = Vector2i(int(round((end_point.x - bounds_min.x) / ROUTING_GRID)), int(round((end_point.y - bounds_min.y) / ROUTING_GRID)))
	start_cell.x = clampi(start_cell.x, 0, cols - 1)
	start_cell.y = clampi(start_cell.y, 0, rows - 1)
	end_cell.x = clampi(end_cell.x, 0, cols - 1)
	end_cell.y = clampi(end_cell.y, 0, rows - 1)
	(grid[start_cell.y] as Array)[start_cell.x] = false
	(grid[end_cell.y] as Array)[end_cell.x] = false
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start_cell: 0.0}
	var open: Array = [{"cell": start_cell, "f": start_cell.distance_to(end_cell)}]
	while not open.is_empty():
		open.sort_custom(func(a, b) -> bool: return float(a.f) < float(b.f))
		var current_entry: Dictionary = open.pop_front()
		var current: Vector2i = current_entry.cell
		if current == end_cell:
			break
		var neighbors: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for n_off in neighbors:
			var n: Vector2i = current + n_off
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
				continue
			if (grid[n.y] as Array)[n.x]:
				continue
			var prev: Vector2i = came_from.get(current, current - Vector2i(0, 0))
			var turn_penalty: float = 0.0
			if came_from.has(current):
				var dir_in: Vector2i = current - (came_from[current] as Vector2i)
				if dir_in != n_off:
					turn_penalty = 1.5
			var tentative: float = float(g_score.get(current, INF)) + 1.0 + turn_penalty
			if tentative < float(g_score.get(n, INF)):
				came_from[n] = current
				g_score[n] = tentative
				open.append({"cell": n, "f": tentative + n.distance_to(end_cell)})
	if not came_from.has(end_cell):
		return PackedVector2Array()
	var path_cells: Array = [end_cell]
	var cur: Vector2i = end_cell
	while came_from.has(cur):
		cur = came_from[cur]
		path_cells.push_front(cur)
	var raw: PackedVector2Array = PackedVector2Array()
	for cell in path_cells:
		var v: Vector2i = cell
		raw.append(bounds_min + Vector2(float(v.x) * ROUTING_GRID, float(v.y) * ROUTING_GRID))
	var simplified: PackedVector2Array = PackedVector2Array()
	simplified.append(start_point)
	if raw.size() > 0:
		simplified.append(raw[0])
	for i in range(1, raw.size() - 1):
		var prev: Vector2 = raw[i - 1]
		var here: Vector2 = raw[i]
		var nxt: Vector2 = raw[i + 1]
		var d1: Vector2 = (here - prev)
		var d2: Vector2 = (nxt - here)
		if (d1.x != 0.0 and d2.x == 0.0) or (d1.y != 0.0 and d2.y == 0.0) or (d1.x == 0.0 and d2.y == 0.0) or (d1.y == 0.0 and d2.x == 0.0):
			simplified.append(here)
	if raw.size() > 0:
		simplified.append(raw[raw.size() - 1])
	simplified.append(end_point)
	return simplified


func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return (u * u * u) * p0 + (3.0 * u * u * t) * p1 + (3.0 * u * t * t) * p2 + (t * t * t) * p3


static func sign_or_one(value: float) -> float:
	if value < 0.0:
		return -1.0
	return 1.0


func _compute_endpoints(c: Connection) -> Array:
	var from_item: BoardItem = _resolve_item(c.from_item_id)
	var to_item: BoardItem = _resolve_item(c.to_item_id)
	if from_item == null or to_item == null:
		return []
	var to_reference: Vector2 = _anchor_world_position(to_item, c.to_anchor) if c.to_anchor != Connection.ANCHOR_AUTO else _item_center(to_item)
	var from_reference: Vector2 = _anchor_world_position(from_item, c.from_anchor) if c.from_anchor != Connection.ANCHOR_AUTO else _item_center(from_item)
	var start_point: Vector2 = _resolve_anchor_position(from_item, c.from_anchor, to_reference)
	var end_point: Vector2 = _resolve_anchor_position(to_item, c.to_anchor, from_reference)
	return [start_point, end_point]


func _resolve_anchor_position(item: BoardItem, anchor: String, target_reference: Vector2) -> Vector2:
	if anchor == "" or anchor == Connection.ANCHOR_AUTO:
		var center: Vector2 = _item_center(item)
		return _intersect_rect_edge(_item_rect(item), center, target_reference)
	return _anchor_world_position(item, anchor)


func _anchor_world_position(item: BoardItem, anchor: String) -> Vector2:
	if item == null:
		return Vector2.ZERO
	if item.has_method("port_world_position"):
		return item.port_world_position(anchor)
	return item.position + item.size * 0.5


func _resolve_item(item_id: String) -> BoardItem:
	if _editor == null or item_id == "":
		return null
	if _editor.has_method("find_item_by_id"):
		return _editor.find_item_by_id(item_id)
	return null


func _item_rect(item: BoardItem) -> Rect2:
	return Rect2(item.position, item.size)


func _item_center(item: BoardItem) -> Vector2:
	return item.position + item.size * 0.5


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


func _distance_to_path(c: Connection, start_point: Vector2, end_point: Vector2, world_pos: Vector2) -> float:
	var path: PackedVector2Array = _build_path(c, start_point, end_point)
	var min_distance: float = INF
	for i: int in range(path.size() - 1):
		var d: float = _distance_to_segment(path[i], path[i + 1], world_pos)
		if d < min_distance:
			min_distance = d
	return min_distance


static func _distance_to_segment(a: Vector2, b: Vector2, point: Vector2) -> float:
	var ab: Vector2 = b - a
	var length_squared: float = ab.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(a)
	var t: float = clamp((point - a).dot(ab) / length_squared, 0.0, 1.0)
	var projection: Vector2 = a + ab * t
	return point.distance_to(projection)
