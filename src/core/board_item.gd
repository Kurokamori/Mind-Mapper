class_name BoardItem
extends Control

signal moved(item: BoardItem, from_position: Vector2, to_position: Vector2)
signal resized_by_user(item: BoardItem, from_size: Vector2, to_size: Vector2)
signal selection_requested(item: BoardItem, additive: bool)
signal edit_begun(item: BoardItem)
signal link_followed(item: BoardItem)
signal navigate_requested(target_kind: String, target_id: String)
signal dragging(item: BoardItem, world_center: Vector2)
signal port_drag_started(item: BoardItem, anchor: String)

const SELECTION_OUTLINE_COLOR := Color(0.35, 0.7, 1.0, 1.0)
const SELECTION_OUTLINE_WIDTH := 2.0
const RESIZE_GRIP_SIZE := 14.0
const MIN_ITEM_WIDTH := 48.0
const MIN_ITEM_HEIGHT := 32.0
const LINK_BADGE_SIZE := 18.0
const LINK_BADGE_PADDING := 4.0
const LINK_BADGE_COLOR := Color(0.95, 0.78, 0.30, 1.0)
const LINK_BADGE_FG := Color(0.10, 0.08, 0.05, 1.0)

const PORT_RADIUS: float = 6.0
const PORT_HIT_RADIUS: float = 9.0
const PORT_HOVER_PROXIMITY_PX: float = 22.0
const PORT_FILL_COLOR: Color = Color(0.13, 0.15, 0.21, 0.95)
const PORT_OUTLINE_COLOR: Color = Color(0.55, 0.78, 1.0, 1.0)
const PORT_HOVER_FILL_COLOR: Color = Color(0.45, 0.78, 1.0, 1.0)
const PORT_HOVER_OUTLINE_COLOR: Color = Color(0.95, 0.97, 1.0, 1.0)
const PORT_OUTLINE_WIDTH: float = 1.5
const PORT_ANCHORS: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

const NODE_CORNER_RADIUS: int = 6
const NODE_BORDER_WIDTH: int = 2

const LINK_KIND_NONE := ""
const LINK_KIND_ITEM := "item"
const LINK_KIND_BOARD := "board"

var item_id: String = ""
var type_id: String = ""
var board_id: String = ""
var link_target: Dictionary = {}
var read_only: bool = false
var locked: bool = false
var tags: PackedStringArray = PackedStringArray()
var dimmed_by_filter: bool = false

var _selected: bool = false
var _drag_active: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_start_position: Vector2 = Vector2.ZERO
var _press_screen_position: Vector2 = Vector2.ZERO
var _moved_during_press: bool = false
var _editing: bool = false
var _resize_active: bool = false
var _resize_start_size: Vector2 = Vector2.ZERO
var _ports_visible: bool = false
var _hovered_port: String = ""
var _force_ports_visible: bool = false
var _highlighted_port: String = ""


func _ready() -> void:
	if item_id == "":
		item_id = Uuid.v4()
	mouse_filter = Control.MOUSE_FILTER_IGNORE if read_only else Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	_apply_initial_minimum_size()
	mouse_exited.connect(_on_mouse_exited_item)


func _on_mouse_exited_item() -> void:
	if _ports_visible or _hovered_port != "":
		_ports_visible = false
		_hovered_port = ""
		queue_redraw()


func _apply_initial_minimum_size() -> void:
	if size == Vector2.ZERO:
		size = default_size()


func default_size() -> Vector2:
	return Vector2(160, 80)


func minimum_item_size() -> Vector2:
	return Vector2(MIN_ITEM_WIDTH, MIN_ITEM_HEIGHT)


func is_selected() -> bool:
	return _selected


func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	queue_redraw()


func is_editing() -> bool:
	return _editing


func end_edit() -> void:
	if not _editing:
		return
	_editing = false
	_on_edit_end()


func _on_edit_begin() -> void:
	pass


func _on_edit_end() -> void:
	pass


func _is_in_resize_grip(local: Vector2) -> bool:
	return local.x >= size.x - RESIZE_GRIP_SIZE and local.y >= size.y - RESIZE_GRIP_SIZE


func port_local_position(anchor: String) -> Vector2:
	match anchor:
		"N":
			return Vector2(size.x * 0.5, 0.0)
		"NE":
			return Vector2(size.x, 0.0)
		"E":
			return Vector2(size.x, size.y * 0.5)
		"SE":
			return Vector2(size.x, size.y)
		"S":
			return Vector2(size.x * 0.5, size.y)
		"SW":
			return Vector2(0.0, size.y)
		"W":
			return Vector2(0.0, size.y * 0.5)
		"NW":
			return Vector2(0.0, 0.0)
		_:
			return size * 0.5


func port_world_position(anchor: String) -> Vector2:
	return position + port_local_position(anchor)


func port_at_local(local_pos: Vector2) -> String:
	for anchor: String in PORT_ANCHORS:
		var port_pos: Vector2 = port_local_position(anchor)
		if local_pos.distance_to(port_pos) <= PORT_HIT_RADIUS:
			return anchor
	return ""


func find_closest_port_in_world(world_pos: Vector2, max_distance_px: float) -> String:
	var best: String = ""
	var best_distance: float = max_distance_px
	for anchor: String in PORT_ANCHORS:
		var port_pos: Vector2 = port_world_position(anchor)
		var distance: float = world_pos.distance_to(port_pos)
		if distance <= best_distance:
			best_distance = distance
			best = anchor
	return best


func set_force_ports_visible(force: bool) -> void:
	if _force_ports_visible == force:
		return
	_force_ports_visible = force
	if not force:
		_highlighted_port = ""
	queue_redraw()


func set_highlighted_port(anchor: String) -> void:
	if _highlighted_port == anchor:
		return
	_highlighted_port = anchor
	queue_redraw()


func ports_currently_visible() -> bool:
	return _force_ports_visible or _ports_visible


func _is_near_edges(local: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(local):
		return false
	var dist_left: float = local.x
	var dist_right: float = size.x - local.x
	var dist_top: float = local.y
	var dist_bottom: float = size.y - local.y
	var min_edge_distance: float = min(min(dist_left, dist_right), min(dist_top, dist_bottom))
	return min_edge_distance <= PORT_HOVER_PROXIMITY_PX


func _get_cursor_shape(at_position: Vector2 = Vector2.ZERO) -> int:
	if _selected and _is_in_resize_grip(at_position):
		return Control.CURSOR_FDIAGSIZE
	return Control.CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
	if read_only:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var ctrl_or_meta: bool = mb.ctrl_pressed or mb.meta_pressed
				if ctrl_or_meta and has_link():
					emit_signal("link_followed", self)
					accept_event()
					return
				if mb.double_click and not locked:
					begin_edit()
					accept_event()
					return
				var local := get_local_mouse_position()
				var port_anchor: String = port_at_local(local)
				if port_anchor != "" and ports_currently_visible() and not locked:
					emit_signal("port_drag_started", self, port_anchor)
					accept_event()
					return
				if _selected and _is_in_resize_grip(local) and not locked:
					_resize_active = true
					_resize_start_size = size
					accept_event()
					return
				_press_screen_position = mb.global_position
				_moved_during_press = false
				var additive := mb.shift_pressed
				emit_signal("selection_requested", self, additive)
				if not _editing and not locked:
					_drag_active = true
					_drag_offset = get_local_mouse_position()
					_drag_start_position = position
				accept_event()
			else:
				if _resize_active:
					_resize_active = false
					if size != _resize_start_size:
						emit_signal("resized_by_user", self, _resize_start_size, size)
					accept_event()
					return
				if _drag_active:
					_drag_active = false
					if _moved_during_press and position != _drag_start_position:
						emit_signal("moved", self, _drag_start_position, position)
				accept_event()
	elif event is InputEventMouseMotion:
		_update_port_hover(get_local_mouse_position())
		if _resize_active:
			var local := get_local_mouse_position()
			var min_s := minimum_item_size()
			var new_w = max(min_s.x, local.x)
			var new_h = max(min_s.y, local.y)
			size = Vector2(new_w, new_h)
			accept_event()
			return
		if _drag_active:
			var motion := event as InputEventMouseMotion
			if (motion.global_position - _press_screen_position).length() > 2.0:
				_moved_during_press = true
			var parent_node := get_parent() as Control
			var target_local: Vector2
			if parent_node != null:
				target_local = parent_node.get_local_mouse_position() - _drag_offset
			else:
				target_local = position + motion.relative
			target_local = SnapService.maybe_snap(target_local)
			target_local = AlignmentGuideService.maybe_align(self, target_local)
			position = target_local
			emit_signal("dragging", self, position + size * 0.5)
			accept_event()


func _draw() -> void:
	_draw_body()
	if dimmed_by_filter:
		var dim_box: StyleBoxFlat = StyleBoxFlat.new()
		dim_box.bg_color = Color(0.05, 0.05, 0.07, 0.55)
		dim_box.set_corner_radius_all(NODE_CORNER_RADIUS)
		draw_style_box(dim_box, Rect2(Vector2.ZERO, size))
	if has_link():
		_draw_link_badge()
	if locked:
		_draw_lock_badge()
	if tags.size() > 0:
		_draw_tag_strip()
	if _selected and not read_only:
		_draw_rounded_outline(SELECTION_OUTLINE_COLOR, int(SELECTION_OUTLINE_WIDTH))
		var grip_rect := Rect2(
			Vector2(size.x - RESIZE_GRIP_SIZE, size.y - RESIZE_GRIP_SIZE),
			Vector2(RESIZE_GRIP_SIZE, RESIZE_GRIP_SIZE),
		)
		draw_rect(grip_rect, SELECTION_OUTLINE_COLOR.darkened(0.15), true)
		draw_line(
			Vector2(size.x - 2.0, size.y - RESIZE_GRIP_SIZE + 2.0),
			Vector2(size.x - RESIZE_GRIP_SIZE + 2.0, size.y - 2.0),
			Color(1, 1, 1, 0.7),
			1.0,
		)
	if not read_only and ports_currently_visible():
		_draw_ports()


func _draw_ports() -> void:
	for anchor: String in PORT_ANCHORS:
		var port_pos: Vector2 = port_local_position(anchor)
		var is_hot: bool = (anchor == _hovered_port) or (anchor == _highlighted_port)
		var fill: Color = PORT_HOVER_FILL_COLOR if is_hot else PORT_FILL_COLOR
		var outline: Color = PORT_HOVER_OUTLINE_COLOR if is_hot else PORT_OUTLINE_COLOR
		var radius: float = PORT_RADIUS + (1.5 if is_hot else 0.0)
		draw_circle(port_pos, radius, fill)
		draw_arc(port_pos, radius, 0.0, TAU, 24, outline, PORT_OUTLINE_WIDTH, true)


func _update_port_hover(local_pos: Vector2) -> void:
	if read_only:
		return
	var was_visible: bool = _ports_visible
	var prior_hover: String = _hovered_port
	if _force_ports_visible:
		_ports_visible = true
	else:
		_ports_visible = _is_near_edges(local_pos)
	if not _ports_visible:
		_hovered_port = ""
	else:
		_hovered_port = port_at_local(local_pos)
	if was_visible != _ports_visible or prior_hover != _hovered_port:
		queue_redraw()


func _draw_lock_badge() -> void:
	var pad: float = LINK_BADGE_PADDING
	var off_x: float = LINK_BADGE_SIZE + pad * 2.0 if has_link() else 0.0
	var center: Vector2 = Vector2(size.x - pad - LINK_BADGE_SIZE * 0.5 - off_x, pad + LINK_BADGE_SIZE * 0.5)
	draw_circle(center, LINK_BADGE_SIZE * 0.5, Color(0.50, 0.50, 0.55, 1.0))
	var body: Rect2 = Rect2(center + Vector2(-4, -1), Vector2(8, 6))
	draw_rect(body, Color(0.10, 0.08, 0.05, 1.0), true)
	draw_arc(center + Vector2(0, -3), 3.0, deg_to_rad(180), deg_to_rad(360), 12, Color(0.10, 0.08, 0.05, 1.0), 1.4, true)


func _draw_tag_strip() -> void:
	var x: float = 4.0
	var y: float = size.y - 6.0
	for tag: String in tags:
		var color: Color = Tags.color_for(tag)
		var w: float = 14.0
		draw_rect(Rect2(Vector2(x, y - 4.0), Vector2(w, 4.0)), color, true)
		x += w + 2.0


func _draw_link_badge() -> void:
	var center: Vector2 = Vector2(size.x - LINK_BADGE_PADDING - LINK_BADGE_SIZE * 0.5, LINK_BADGE_PADDING + LINK_BADGE_SIZE * 0.5)
	draw_circle(center, LINK_BADGE_SIZE * 0.5, LINK_BADGE_COLOR)
	var arrow_start: Vector2 = center + Vector2(-4, 2)
	var arrow_end: Vector2 = center + Vector2(4, -3)
	draw_line(arrow_start, arrow_end, LINK_BADGE_FG, 1.5)
	draw_line(arrow_end, arrow_end + Vector2(-4, 0), LINK_BADGE_FG, 1.5)
	draw_line(arrow_end, arrow_end + Vector2(0, 4), LINK_BADGE_FG, 1.5)


func has_link() -> bool:
	if link_target.is_empty():
		return false
	return String(link_target.get("kind", "")) != "" and String(link_target.get("id", "")) != ""


func _draw_body() -> void:
	pass


func _draw_rounded_panel(
	bg: Color,
	border: Color,
	header_height: float = 0.0,
	header_bg: Color = Color(0, 0, 0, 0),
	border_width: int = NODE_BORDER_WIDTH,
	radius: int = NODE_CORNER_RADIUS,
) -> void:
	var body_fill: StyleBoxFlat = StyleBoxFlat.new()
	body_fill.bg_color = bg
	body_fill.set_corner_radius_all(radius)
	body_fill.border_width_left = 0
	body_fill.border_width_top = 0
	body_fill.border_width_right = 0
	body_fill.border_width_bottom = 0
	draw_style_box(body_fill, Rect2(Vector2.ZERO, size))
	if header_height > 0.0 and header_bg.a > 0.0:
		var header_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(size.x, header_height))
		var header_box: StyleBoxFlat = StyleBoxFlat.new()
		header_box.bg_color = header_bg
		header_box.corner_radius_top_left = radius
		header_box.corner_radius_top_right = radius
		header_box.corner_radius_bottom_left = 0
		header_box.corner_radius_bottom_right = 0
		header_box.border_width_left = 0
		header_box.border_width_top = 0
		header_box.border_width_right = 0
		header_box.border_width_bottom = 0
		draw_style_box(header_box, header_rect)
	var outline: StyleBoxFlat = StyleBoxFlat.new()
	outline.draw_center = false
	outline.border_color = border
	outline.set_border_width_all(border_width)
	outline.set_corner_radius_all(radius)
	draw_style_box(outline, Rect2(Vector2.ZERO, size))


func _draw_rounded_outline(
	border: Color,
	border_width: int = NODE_BORDER_WIDTH,
	radius: int = NODE_CORNER_RADIUS,
) -> void:
	var outline: StyleBoxFlat = StyleBoxFlat.new()
	outline.draw_center = false
	outline.border_color = border
	outline.set_border_width_all(border_width)
	outline.set_corner_radius_all(radius)
	draw_style_box(outline, Rect2(Vector2.ZERO, size))


func to_dict() -> Dictionary:
	var base := {
		"id": item_id,
		"type": type_id,
		"position": [position.x, position.y],
		"size": [size.x, size.y],
	}
	if has_link():
		base["link_target"] = link_target.duplicate(true)
	if locked:
		base["locked"] = true
	if tags.size() > 0:
		var tag_arr: Array = []
		for t in tags:
			tag_arr.append(String(t))
		base["tags"] = tag_arr
	var extra := serialize_payload()
	for k in extra.keys():
		base[k] = extra[k]
	return base


func apply_dict(d: Dictionary) -> void:
	item_id = String(d.get("id", item_id if item_id != "" else Uuid.v4()))
	type_id = String(d.get("type", type_id))
	var pos_raw: Variant = d.get("position", [0, 0])
	if typeof(pos_raw) == TYPE_ARRAY and pos_raw.size() >= 2:
		position = Vector2(float(pos_raw[0]), float(pos_raw[1]))
	var size_raw: Variant = d.get("size", null)
	if typeof(size_raw) == TYPE_ARRAY and size_raw.size() >= 2:
		size = Vector2(float(size_raw[0]), float(size_raw[1]))
	var lt: Variant = d.get("link_target", {})
	if typeof(lt) == TYPE_DICTIONARY:
		link_target = (lt as Dictionary).duplicate(true)
	locked = bool(d.get("locked", false))
	var tag_raw: Variant = d.get("tags", null)
	tags = PackedStringArray()
	if typeof(tag_raw) == TYPE_ARRAY:
		for t in (tag_raw as Array):
			tags.append(String(t))
	deserialize_payload(d)


func serialize_payload() -> Dictionary:
	return {}


func deserialize_payload(_d: Dictionary) -> void:
	pass


func duplicate_dict() -> Dictionary:
	var d := to_dict()
	d["id"] = Uuid.v4()
	return d


func apply_property(key: String, value: Variant) -> void:
	match key:
		"position":
			if typeof(value) == TYPE_VECTOR2:
				position = value
			elif typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
				position = Vector2(float(value[0]), float(value[1]))
		"size":
			if typeof(value) == TYPE_VECTOR2:
				size = value
			elif typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
				size = Vector2(float(value[0]), float(value[1]))
		"link_target":
			if typeof(value) == TYPE_DICTIONARY:
				link_target = (value as Dictionary).duplicate(true)
			else:
				link_target = {}
			queue_redraw()
		"locked":
			locked = bool(value)
			queue_redraw()
		"tags":
			tags = PackedStringArray()
			if typeof(value) == TYPE_ARRAY:
				for t in (value as Array):
					tags.append(String(t))
			elif typeof(value) == TYPE_PACKED_STRING_ARRAY:
				tags = (value as PackedStringArray).duplicate()
			queue_redraw()
		_:
			apply_typed_property(key, value)


func set_dimmed(dim: bool) -> void:
	if dimmed_by_filter == dim:
		return
	dimmed_by_filter = dim
	queue_redraw()


func has_tag(tag: String) -> bool:
	if tag == "":
		return true
	for t: String in tags:
		if String(t) == tag:
			return true
	return false


func begin_edit() -> void:
	if locked:
		return
	if _editing:
		return
	_editing = true
	emit_signal("edit_begun", self)
	_on_edit_begin()


func apply_typed_property(_key: String, _value: Variant) -> void:
	pass


func build_inspector() -> Control:
	return null


func display_name() -> String:
	return type_id.capitalize() if type_id != "" else "Item"
