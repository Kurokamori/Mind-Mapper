class_name MobileBoardView
extends Control

signal item_tapped(item_id: String)
signal empty_tapped()
signal navigate_requested(target_kind: String, target_id: String)
signal comments_changed()
signal todo_payload_changed(item_id: String)
signal mode_changed(mode: String)
signal selection_changed(selected_item_ids: Array)
signal connection_tapped(connection_id: String)
signal request_item_type_picker(world_position: Vector2)
signal nodes_lock_changed(locked: bool)

const TAP_HIT_PADDING_PX: float = 8.0
const CONNECTION_TAP_TOLERANCE_PX: float = 16.0
const STROKE_HIT_TOLERANCE_PX: float = 8.0
const ERASER_RADIUS_PX: float = 18.0

const MODE_VIEW: String = "view"
const MODE_EDIT: String = "edit"
const MODE_CONNECT: String = "connect"
const MODE_PEN: String = "pen"
const MODE_ERASER: String = "eraser"

const SAVE_DEBOUNCE_SEC: float = 0.4
const DRAG_THRESHOLD_PX: float = 8.0
const LONG_PRESS_MS: int = 420
const RESIZE_HANDLE_HIT_PX: float = 28.0

@onready var _camera: MobileCameraController = %Camera
@onready var _world: Node2D = %World
@onready var _items_root: Node2D = %ItemsRoot
@onready var _connection_painter: MobileConnectionPainter = %ConnectionPainter
@onready var _annotation_painter: MobileAnnotationPainter = %AnnotationPainter
@onready var _comment_marker_layer: MobileCommentMarkerLayer = %CommentMarkerLayer
@onready var _selection_overlay: MobileSelectionOverlay = %SelectionOverlay
@onready var _port_overlay: MobilePortOverlay = %PortOverlay
@onready var _alignment_guide_layer: MobileAlignmentGuideLayer = %AlignmentGuideLayer
@onready var _background: ColorRect = %BoardBackground

var _project: Project = null
var _board: Board = null
var _items_by_id: Dictionary = {}
var _item_dicts_by_id: Dictionary = {}
var _connections_by_id: Dictionary = {}
var _has_initial_frame: bool = false
var _save_timer: Timer = null
var _save_pending: bool = false
var _pending_focus_item_id: String = ""

var _mode: String = MODE_VIEW
var _nodes_locked: bool = false
var _selected_item_ids: Array[String] = []
var _selected_connection_id: String = ""

var _touch_state: Dictionary = {}
var _active_touch_index: int = -1
var _drag_started: bool = false
var _gesture_consumed: bool = false
var _drag_item: BoardItem = null
var _drag_resize: bool = false
var _drag_start_positions: Dictionary = {}
var _drag_start_size: Vector2 = Vector2.ZERO
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_world: Vector2 = Vector2.ZERO
var _camera_pan_started: bool = false
var _camera_pan_last_screen: Vector2 = Vector2.ZERO
var _view_drag_transient_id: String = ""

var _long_press_timer: Timer = null
var _long_press_world: Vector2 = Vector2.ZERO
var _long_press_screen: Vector2 = Vector2.ZERO
var _long_press_fired: bool = false

var _pending_connect_source: String = ""
var _pending_connect_source_anchor: String = Connection.ANCHOR_AUTO
var _connection_preview_world: Vector2 = Vector2.ZERO

var _annotation_stroke_in_progress: Dictionary = {}
var _annotation_color: Color = Color(0.95, 0.32, 0.32, 1.0)
var _annotation_width: float = 4.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_to_group(EditorLocator.GROUP_ACTIVE_BOARD_EDITOR)
	_camera.user_tapped_world.connect(_on_camera_tap)
	_camera.user_long_pressed_world.connect(_on_camera_long_press)
	_camera.user_double_tapped_world.connect(_on_camera_double_tap)
	_camera.pan_should_be_allowed = Callable(self, "_camera_pan_should_be_allowed")
	_camera.single_touch_pan_enabled = false
	_connection_painter.bind_items_lookup(_lookup_item_dict)
	_comment_marker_layer.bind_items_lookup(_lookup_item_dict)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE_SEC
	_save_timer.timeout.connect(_perform_pending_save)
	add_child(_save_timer)
	_long_press_timer = Timer.new()
	_long_press_timer.one_shot = true
	_long_press_timer.wait_time = float(LONG_PRESS_MS) / 1000.0
	_long_press_timer.timeout.connect(_on_long_press_timeout)
	add_child(_long_press_timer)
	_selection_overlay.bind_board_view(self)
	_selection_overlay.set_selection([])
	_port_overlay.bind_board_view(self)
	_port_overlay.set_enabled(false)
	_alignment_guide_layer.bind_board_view(self)
	AlignmentGuideService.guides_changed.connect(_on_alignment_guides_changed)
	OpBus.bind_editor(self)
	tree_exiting.connect(_on_tree_exiting_unbind)


func _on_tree_exiting_unbind() -> void:
	OpBus.unbind_editor()


func apply_op_locally_through_editor(_op: Op) -> bool:
	return false


func apply_remote_op(op: Op) -> void:
	if op == null or _board == null or op.board_id != _board.id:
		return
	var connections_touched: bool = false
	var comments_touched: bool = false
	var annotations_touched: bool = false
	match op.kind:
		OpKinds.CREATE_ITEM:
			var item_dict_raw: Variant = op.payload.get("item_dict", null)
			if typeof(item_dict_raw) == TYPE_DICTIONARY:
				var d: Dictionary = item_dict_raw
				if not _items_by_id.has(String(d.get("id", ""))):
					instantiate_item_from_dict(d.duplicate(true))
		OpKinds.DELETE_ITEM:
			remove_item_by_id(String(op.payload.get("item_id", "")))
		OpKinds.MOVE_ITEMS:
			var entries_raw: Variant = op.payload.get("entries", [])
			if typeof(entries_raw) == TYPE_ARRAY:
				for e_v: Variant in (entries_raw as Array):
					if typeof(e_v) != TYPE_DICTIONARY:
						continue
					var entry: Dictionary = e_v
					var item: BoardItem = find_item_node(String(entry.get("id", "")))
					if item == null:
						continue
					var to_arr: Variant = entry.get("to", [])
					if typeof(to_arr) == TYPE_ARRAY and (to_arr as Array).size() >= 2:
						item.position = Vector2(float((to_arr as Array)[0]), float((to_arr as Array)[1]))
		OpKinds.SET_ITEM_PROPERTY:
			var prop_item: BoardItem = find_item_node(String(op.payload.get("item_id", "")))
			if prop_item != null:
				var key: String = String(op.payload.get("key", ""))
				var raw_value: Variant = op.payload.get("value", null)
				prop_item.apply_property(key, _deserialize_remote_property_value(key, raw_value))
		OpKinds.REORDER_ITEMS:
			_apply_remote_via_applier(op)
		OpKinds.CREATE_CONNECTION:
			var conn_raw: Variant = op.payload.get("connection_dict", null)
			if typeof(conn_raw) == TYPE_DICTIONARY:
				var c: Connection = Connection.from_dict(conn_raw)
				if c != null and c.id != "" and not _connections_by_id.has(c.id):
					_connections_by_id[c.id] = c
					connections_touched = true
		OpKinds.DELETE_CONNECTION:
			var del_id: String = String(op.payload.get("connection_id", ""))
			if del_id != "" and _connections_by_id.has(del_id):
				_connections_by_id.erase(del_id)
				connections_touched = true
		OpKinds.SET_CONNECTION_PROPERTY:
			var c_id: String = String(op.payload.get("connection_id", ""))
			var c_ref: Connection = _connections_by_id.get(c_id, null) as Connection
			if c_ref != null:
				c_ref.apply_property(String(op.payload.get("key", "")), op.payload.get("value", null))
				connections_touched = true
		OpKinds.CREATE_COMMENT, OpKinds.DELETE_COMMENT, OpKinds.SET_COMMENT_PROPERTY:
			_apply_remote_via_applier(op)
			comments_touched = true
		OpKinds.CREATE_STROKE, OpKinds.DELETE_STROKE:
			_apply_remote_via_applier(op)
			annotations_touched = true
		_:
			_apply_remote_via_applier(op)
	if connections_touched:
		_refresh_connection_painter()
	if comments_touched and _board != null:
		_comment_marker_layer.set_comments(_board.comments)
	if annotations_touched and _board != null:
		_annotation_painter.set_strokes(_board.annotations)
	request_save()


func _apply_remote_via_applier(op: Op) -> void:
	if OpBus.applier() != null:
		OpBus.applier().apply_to_project(op)


func _deserialize_remote_property_value(key: String, raw: Variant) -> Variant:
	if key == "position" or key == "size":
		if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 2:
			return Vector2(float((raw as Array)[0]), float((raw as Array)[1]))
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() == 4 and _key_is_color(key):
		var arr: Array = raw
		return Color(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
	return raw


func _key_is_color(key: String) -> bool:
	return key.ends_with("color") or key == "background_color" or key == "stroke_color" or key == "fill_color"


func bind_board(project: Project, board: Board) -> void:
	_project = project
	_board = board
	_has_initial_frame = false
	_selected_item_ids = []
	_selected_connection_id = ""
	_pending_connect_source = ""
	_annotation_stroke_in_progress = {}
	_rebuild_items()
	_rebuild_connections()
	_annotation_painter.set_strokes(board.annotations)
	_comment_marker_layer.set_comments(board.comments)
	_apply_background()
	_refresh_selection_visuals()
	if _pending_focus_item_id != "":
		var focus_id: String = _pending_focus_item_id
		_pending_focus_item_id = ""
		if find_item_node(focus_id) != null:
			call_deferred("_focus_after_layout", focus_id)
		else:
			call_deferred("_frame_after_layout")
	else:
		call_deferred("_frame_after_layout")


func set_pending_focus_item(item_id: String) -> void:
	_pending_focus_item_id = item_id


func _focus_after_layout(item_id: String) -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null or viewport.get_visible_rect().size.x < 16.0:
		call_deferred("_focus_after_layout", item_id)
		return
	_has_initial_frame = true
	if _camera.enabled:
		_camera.make_current()
	focus_item(item_id)


func current_board() -> Board:
	return _board


func current_project() -> Project:
	return _project


func current_mode() -> String:
	return _mode


func nodes_locked() -> bool:
	return _nodes_locked


func set_nodes_locked(value: bool) -> void:
	if _nodes_locked == value:
		return
	_nodes_locked = value
	if _nodes_locked:
		_finish_active_annotation_stroke()
		_pending_connect_source = ""
		_pending_connect_source_anchor = Connection.ANCHOR_AUTO
		if _drag_started:
			_cancel_drag()
			_drag_started = false
		_camera_pan_started = false
		_long_press_timer.stop()
		_selected_item_ids = []
		_selected_connection_id = ""
		_refresh_selection_visuals()
	_apply_mobile_edit_state()
	_port_overlay.set_enabled(_mode == MODE_CONNECT and not _nodes_locked)
	nodes_lock_changed.emit(_nodes_locked)
	if _nodes_locked:
		selection_changed.emit([])


func set_mode(new_mode: String) -> void:
	if _mode == new_mode:
		return
	_finish_active_annotation_stroke()
	if new_mode != MODE_CONNECT:
		_pending_connect_source = ""
		_pending_connect_source_anchor = Connection.ANCHOR_AUTO
	_mode = new_mode
	_port_overlay.set_enabled(_mode == MODE_CONNECT and not _nodes_locked)
	_port_overlay.set_pending_source(_pending_connect_source, _pending_connect_source_anchor)
	_refresh_selection_visuals()
	_apply_mobile_edit_state()
	mode_changed.emit(_mode)


func selected_item_ids() -> Array[String]:
	var dup: Array[String] = []
	for id: String in _selected_item_ids:
		dup.append(id)
	return dup


func selected_connection_id() -> String:
	return _selected_connection_id


func clear_selection() -> void:
	if _selected_item_ids.is_empty() and _selected_connection_id == "":
		return
	_selected_item_ids = []
	_selected_connection_id = ""
	_refresh_selection_visuals()
	_apply_mobile_edit_state()
	selection_changed.emit([])


func set_annotation_color(color: Color) -> void:
	_annotation_color = color


func set_annotation_width(width: float) -> void:
	_annotation_width = AnnotationStroke.clamp_width(width)


func annotation_color() -> Color:
	return _annotation_color


func annotation_width() -> float:
	return _annotation_width


func camera_node() -> MobileCameraController:
	return _camera


func find_item_dict(item_id: String) -> Dictionary:
	if not _item_dicts_by_id.has(item_id):
		return {}
	return (_item_dicts_by_id[item_id] as Dictionary).duplicate(true)


func find_item_node(item_id: String) -> BoardItem:
	if not _items_by_id.has(item_id):
		return null
	return _items_by_id[item_id]


func find_item_by_id(item_id: String) -> BoardItem:
	return find_item_node(item_id)


func all_items() -> Array:
	var out: Array = []
	for v in _items_by_id.values():
		out.append(v as BoardItem)
	return out


func update_item_payload(item_id: String, new_dict: Dictionary) -> bool:
	if _board == null or _project == null:
		return false
	var idx: int = _index_of_item_id(item_id)
	if idx < 0:
		return false
	_board.items[idx] = new_dict.duplicate(true)
	_item_dicts_by_id[item_id] = new_dict.duplicate(true)
	var node: BoardItem = find_item_node(item_id)
	if node != null:
		var was_editing: bool = node.is_editing()
		node.apply_dict(new_dict.duplicate(true))
		if was_editing and not node.is_editing() and _selected_item_ids.has(item_id) and _mode == MODE_EDIT:
			node.begin_edit()
	var err: Error = _project.write_board(_board)
	if err == OK:
		todo_payload_changed.emit(item_id)
		_refresh_overlay_state()
		return true
	return false


func update_board_comments(comments: Array) -> bool:
	if _board == null or _project == null:
		return false
	_board.comments = comments.duplicate(true)
	var err: Error = _project.write_board(_board)
	if err == OK:
		_comment_marker_layer.set_comments(_board.comments)
		comments_changed.emit()
		return true
	return false


func frame_all_items() -> void:
	if _board == null:
		return
	if _camera.enabled:
		_camera.make_current()
	var bounds: Rect2 = _compute_world_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		_camera.zoom = Vector2.ONE
		_camera.position = Vector2.ZERO
		return
	bounds = bounds.grow(64.0)
	_camera.zoom_to_fit_rect(bounds)


func request_save() -> void:
	if _board == null or _project == null:
		return
	for node_v in _items_by_id.values():
		_snapshot_item_into_board(node_v as BoardItem)
	_board.connections = []
	for c_v: Variant in _connections_by_id.values():
		_board.connections.append((c_v as Connection).to_dict())
	_save_pending = true
	_save_timer.start()


func instantiate_item_from_dict(d: Dictionary) -> BoardItem:
	if _board == null:
		return null
	var item_id: String = String(d.get("id", ""))
	if item_id == "":
		item_id = Uuid.v4()
		d["id"] = item_id
	if _items_by_id.has(item_id):
		return _items_by_id[item_id]
	var node: BoardItem = ItemRegistry.instantiate_from_dict(d)
	if node == null:
		return null
	node.board_id = _board.id
	_items_root.add_child(node)
	node.position = _vector_of(d, "position", Vector2.ZERO)
	node.size = _vector_of(d, "size", node.default_size())
	_apply_mobile_item_flags(node)
	_items_by_id[item_id] = node
	_item_dicts_by_id[item_id] = d.duplicate(true)
	_snapshot_item_into_board(node)
	_refresh_overlay_state()
	return node


func remove_item_by_id(item_id: String) -> void:
	var node: BoardItem = _items_by_id.get(item_id, null)
	if node != null:
		node.queue_free()
		_items_by_id.erase(item_id)
	_item_dicts_by_id.erase(item_id)
	var idx: int = _index_of_item_id(item_id)
	if idx >= 0 and _board != null:
		_board.items.remove_at(idx)
	if _selected_item_ids.has(item_id):
		_selected_item_ids.erase(item_id)
		_refresh_selection_visuals()
		selection_changed.emit(selected_item_ids())
	_refresh_overlay_state()


func add_connection(c: Connection) -> void:
	if c == null or _board == null:
		return
	if c.id == "":
		c.id = Uuid.v4()
	_connections_by_id[c.id] = c
	_refresh_connection_painter()


func get_connections() -> Array[Connection]:
	var out: Array[Connection] = []
	for c_v: Variant in _connections_by_id.values():
		out.append(c_v as Connection)
	return out


func get_connection_dicts() -> Array:
	var out: Array = []
	for c_v: Variant in _connections_by_id.values():
		out.append((c_v as Connection).to_dict())
	return out


func remove_connection_by_id(connection_id: String) -> void:
	if not _connections_by_id.has(connection_id):
		return
	_connections_by_id.erase(connection_id)
	if _selected_connection_id == connection_id:
		_selected_connection_id = ""
		_refresh_selection_visuals()
	_refresh_connection_painter()


func remove_connections_referencing_item(item_id: String) -> Array:
	var removed: Array = []
	var ids_to_remove: Array[String] = []
	for c_id_v: Variant in _connections_by_id.keys():
		var c: Connection = _connections_by_id[c_id_v]
		if c.references_item(item_id):
			ids_to_remove.append(String(c_id_v))
			removed.append(c)
	for id: String in ids_to_remove:
		_connections_by_id.erase(id)
	if not ids_to_remove.is_empty():
		_refresh_connection_painter()
	return removed


func apply_stroke_create_locally(stroke_dict: Dictionary) -> void:
	if _board == null:
		return
	var normalized: Dictionary = AnnotationStroke.normalize(stroke_dict.duplicate(true))
	var stroke_id: String = String(normalized.get(AnnotationStroke.FIELD_ID, ""))
	var existing_idx: int = AnnotationStroke.find_index(_board.annotations, stroke_id)
	if existing_idx >= 0:
		_board.annotations[existing_idx] = normalized
	else:
		_board.annotations.append(normalized)
	_annotation_painter.set_strokes(_board.annotations)


func apply_stroke_delete_locally(stroke_id: String) -> void:
	if _board == null or stroke_id == "":
		return
	var idx: int = AnnotationStroke.find_index(_board.annotations, stroke_id)
	if idx < 0:
		return
	_board.annotations.remove_at(idx)
	_annotation_painter.set_strokes(_board.annotations)


func create_item_at(type_id: String, world_position: Vector2) -> bool:
	if _nodes_locked:
		return false
	if not ItemRegistry.has_type(type_id) or _board == null:
		return false
	var payload: Dictionary = ItemRegistry.default_payload(type_id)
	payload["id"] = Uuid.v4()
	payload["type"] = type_id
	var probe: BoardItem = ItemRegistry.instantiate(type_id)
	var size: Vector2 = Vector2(160.0, 80.0)
	if probe != null:
		size = probe.default_size()
		probe.queue_free()
	payload["position"] = [world_position.x - size.x * 0.5, world_position.y - size.y * 0.5]
	payload["size"] = [size.x, size.y]
	History.push(AddItemsCommand.new(self, [payload]))
	var new_id: String = String(payload.get("id", ""))
	if new_id != "":
		_set_selection([new_id])
	return true


func delete_selected() -> void:
	if _nodes_locked:
		return
	if not _selected_item_ids.is_empty():
		var nodes: Array = []
		for id: String in _selected_item_ids:
			var node: BoardItem = find_item_node(id)
			if node != null:
				nodes.append(node)
		if nodes.size() > 0:
			History.push(RemoveItemsCommand.new(self, nodes))
		clear_selection()
		return
	if _selected_connection_id != "" and _connections_by_id.has(_selected_connection_id):
		var c: Connection = _connections_by_id[_selected_connection_id]
		History.push(RemoveConnectionsCommand.new(self, [c]))
		_selected_connection_id = ""
		_refresh_selection_visuals()


func duplicate_selected() -> void:
	if _nodes_locked:
		return
	if _selected_item_ids.is_empty():
		return
	var dicts: Array = []
	for id: String in _selected_item_ids:
		var node: BoardItem = find_item_node(id)
		if node == null:
			continue
		var d: Dictionary = node.duplicate_dict()
		var pos: Vector2 = _vector_of(d, "position", Vector2.ZERO) + Vector2(28.0, 28.0)
		d["position"] = [pos.x, pos.y]
		dicts.append(d)
	if dicts.is_empty():
		return
	History.push(AddItemsCommand.new(self, dicts))
	var new_ids: Array[String] = []
	for d_v: Variant in dicts:
		var d: Dictionary = d_v
		var id: String = String(d.get("id", ""))
		if id != "":
			new_ids.append(id)
	_set_selection(new_ids)


func undo() -> void:
	if _nodes_locked:
		return
	if not History.can_undo():
		return
	History.undo()
	_refresh_after_history()


func redo() -> void:
	if _nodes_locked:
		return
	if not History.can_redo():
		return
	History.redo()
	_refresh_after_history()


func toggle_lock_for_selected() -> void:
	if _nodes_locked:
		return
	for id: String in _selected_item_ids:
		var node: BoardItem = find_item_node(id)
		if node == null:
			continue
		var new_locked: bool = not node.locked
		History.push(ModifyPropertyCommand.new(self, id, "locked", node.locked, new_locked))


func group_selected() -> bool:
	if _nodes_locked:
		return false
	if _selected_item_ids.is_empty():
		return false
	var min_p: Vector2 = Vector2(INF, INF)
	var max_p: Vector2 = Vector2(-INF, -INF)
	var any: bool = false
	for id: String in _selected_item_ids:
		var node: BoardItem = find_item_node(id)
		if node == null:
			continue
		any = true
		min_p.x = min(min_p.x, node.position.x)
		min_p.y = min(min_p.y, node.position.y)
		max_p.x = max(max_p.x, node.position.x + node.size.x)
		max_p.y = max(max_p.y, node.position.y + node.size.y)
	if not any:
		return false
	var pad: float = 18.0
	var origin: Vector2 = Vector2(min_p.x - pad, min_p.y - GroupNode.TITLE_HEIGHT - pad)
	var size_v: Vector2 = (max_p - min_p) + Vector2(pad * 2.0, pad * 2.0 + GroupNode.TITLE_HEIGHT)
	var new_id: String = Uuid.v4()
	var d: Dictionary = {
		"id": new_id,
		"type": ItemRegistry.TYPE_GROUP,
		"position": [origin.x, origin.y],
		"size": [size_v.x, size_v.y],
		"title": "Group",
	}
	History.push(AddItemsCommand.new(self, [d]))
	_set_selection([new_id])
	return true


func align_selected(op: String) -> void:
	if _nodes_locked:
		return
	var movable: Array = []
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF
	for id: String in _selected_item_ids:
		var node: BoardItem = find_item_node(id)
		if node == null or node.locked:
			continue
		movable.append(node)
		min_x = min(min_x, node.position.x)
		min_y = min(min_y, node.position.y)
		max_x = max(max_x, node.position.x + node.size.x)
		max_y = max(max_y, node.position.y + node.size.y)
	if movable.size() < 2:
		return
	var entries: Array = []
	for node_v: Variant in movable:
		var node: BoardItem = node_v
		var from_pos: Vector2 = node.position
		var to_pos: Vector2 = from_pos
		match op:
			"align_left":
				to_pos.x = min_x
			"align_right":
				to_pos.x = max_x - node.size.x
			"align_top":
				to_pos.y = min_y
			"align_bottom":
				to_pos.y = max_y - node.size.y
			"align_hcenter":
				to_pos.x = (min_x + max_x) * 0.5 - node.size.x * 0.5
			"align_vcenter":
				to_pos.y = (min_y + max_y) * 0.5 - node.size.y * 0.5
		if from_pos != to_pos:
			node.position = to_pos
			entries.append({"id": node.item_id, "from": [from_pos.x, from_pos.y], "to": [to_pos.x, to_pos.y]})
	if entries.is_empty():
		return
	History.push_already_done(MoveItemsCommand.new(self, entries))
	request_save()
	_refresh_overlay_state()


func distribute_selected(horizontal: bool) -> void:
	if _nodes_locked:
		return
	var movable: Array = []
	for id: String in _selected_item_ids:
		var node: BoardItem = find_item_node(id)
		if node == null or node.locked:
			continue
		movable.append(node)
	if movable.size() < 3:
		return
	movable.sort_custom(func(a: BoardItem, b: BoardItem) -> bool:
		var av: float = a.position.x + a.size.x * 0.5 if horizontal else a.position.y + a.size.y * 0.5
		var bv: float = b.position.x + b.size.x * 0.5 if horizontal else b.position.y + b.size.y * 0.5
		return av < bv
	)
	var first: BoardItem = movable[0]
	var last: BoardItem = movable[movable.size() - 1]
	var first_center: float = (first.position.x + first.size.x * 0.5) if horizontal else (first.position.y + first.size.y * 0.5)
	var last_center: float = (last.position.x + last.size.x * 0.5) if horizontal else (last.position.y + last.size.y * 0.5)
	var span: float = last_center - first_center
	if span <= 0.0:
		return
	var step: float = span / float(movable.size() - 1)
	var entries: Array = []
	for i: int in range(1, movable.size() - 1):
		var node: BoardItem = movable[i]
		var target_center: float = first_center + step * float(i)
		var from_pos: Vector2 = node.position
		var to_pos: Vector2 = from_pos
		if horizontal:
			to_pos.x = target_center - node.size.x * 0.5
		else:
			to_pos.y = target_center - node.size.y * 0.5
		if from_pos != to_pos:
			node.position = to_pos
			entries.append({"id": node.item_id, "from": [from_pos.x, from_pos.y], "to": [to_pos.x, to_pos.y]})
	if entries.is_empty():
		return
	History.push_already_done(MoveItemsCommand.new(self, entries))
	request_save()
	_refresh_overlay_state()


func reorder_selected(direction: String) -> void:
	if _nodes_locked:
		return
	if _selected_item_ids.is_empty():
		return
	var ids: Array = []
	for id: String in _selected_item_ids:
		if find_item_node(id) != null:
			ids.append(id)
	if ids.is_empty():
		return
	History.push(ReorderItemsCommand.new(self, ids, direction))


func get_z_order_snapshot() -> Array:
	var out: Array = []
	for child: Node in _items_root.get_children():
		if child is BoardItem:
			out.append((child as BoardItem).item_id)
	return out


func apply_z_order_snapshot(order: Array) -> void:
	for i: int in range(order.size()):
		var id: String = String(order[i])
		var item: BoardItem = _items_by_id.get(id, null)
		if item != null:
			_items_root.move_child(item, i)
	_refresh_connection_painter()
	_refresh_overlay_state()


func apply_reorder(item_ids: Array, direction: String) -> void:
	var children: Array = _items_root.get_children()
	var max_idx: int = children.size() - 1
	match direction:
		ReorderItemsCommand.DIR_BRING_TO_FRONT:
			for id_v: Variant in item_ids:
				var it: BoardItem = _items_by_id.get(String(id_v), null)
				if it != null and not (it is GroupNode):
					_items_root.move_child(it, max_idx)
		ReorderItemsCommand.DIR_SEND_TO_BACK:
			var first_non_group: int = _first_non_group_index()
			for id_v: Variant in item_ids:
				var it: BoardItem = _items_by_id.get(String(id_v), null)
				if it != null:
					if it is GroupNode:
						_items_root.move_child(it, 0)
					else:
						_items_root.move_child(it, first_non_group)
		ReorderItemsCommand.DIR_BRING_FORWARD:
			for id_v: Variant in item_ids:
				var it: BoardItem = _items_by_id.get(String(id_v), null)
				if it != null:
					var nxt: int = min(it.get_index() + 1, max_idx)
					if not (it is GroupNode) and nxt > it.get_index():
						_items_root.move_child(it, nxt)
		ReorderItemsCommand.DIR_SEND_BACKWARD:
			for id_v: Variant in item_ids:
				var it: BoardItem = _items_by_id.get(String(id_v), null)
				if it != null:
					var prv: int = max(it.get_index() - 1, 0)
					if it is GroupNode or prv < it.get_index():
						_items_root.move_child(it, prv)
	_enforce_group_invariant()
	_refresh_connection_painter()
	_refresh_overlay_state()


func _first_non_group_index() -> int:
	for child: Node in _items_root.get_children():
		if not (child is GroupNode):
			return child.get_index()
	return _items_root.get_child_count()


func _enforce_group_invariant() -> void:
	var groups: Array = []
	var others: Array = []
	for child: Node in _items_root.get_children():
		if child is GroupNode:
			groups.append(child)
		else:
			others.append(child)
	var idx: int = 0
	for g: Node in groups:
		_items_root.move_child(g, idx)
		idx += 1
	for o: Node in others:
		_items_root.move_child(o, idx)
		idx += 1


func focus_item(item_id: String) -> void:
	var node: BoardItem = find_item_node(item_id)
	if node == null:
		return
	_set_selection([item_id])
	var center_world: Vector2 = node.position + node.size * 0.5
	_camera.position = center_world


func set_property_for_item(item_id: String, key: String, value: Variant) -> void:
	if _nodes_locked:
		return
	var node: BoardItem = find_item_node(item_id)
	if node == null:
		return
	var current: Variant = _read_property_value(node, key)
	if current == value:
		return
	History.push(ModifyPropertyCommand.new(self, item_id, key, current, value))


func update_connection_property(connection_id: String, key: String, value: Variant) -> void:
	if _nodes_locked:
		return
	if not _connections_by_id.has(connection_id):
		return
	var c: Connection = _connections_by_id[connection_id]
	var current: Variant = _read_connection_property(c, key)
	if current == value:
		return
	History.push(ModifyConnectionPropertyCommand.new(self, connection_id, key, current, value))


func find_connection_by_id(connection_id: String) -> Connection:
	return _connections_by_id.get(connection_id, null)


func all_connections() -> Array:
	var out: Array = []
	for v in _connections_by_id.values():
		out.append(v as Connection)
	return out


func set_selected_connection(connection_id: String) -> void:
	_selected_item_ids = []
	_selected_connection_id = connection_id
	_refresh_selection_visuals()
	selection_changed.emit([])


func _refresh_after_history() -> void:
	_refresh_overlay_state()
	if _board != null:
		_annotation_painter.set_strokes(_board.annotations)


func _read_property_value(item: BoardItem, key: String) -> Variant:
	match key:
		"position":
			return [item.position.x, item.position.y]
		"size":
			return [item.size.x, item.size.y]
		"locked":
			return item.locked
		"tags":
			var arr: Array = []
			for t: String in item.tags:
				arr.append(String(t))
			return arr
		"link_target":
			return item.link_target.duplicate(true)
		_:
			var d: Dictionary = item.to_dict()
			return d.get(key, null)


func _read_connection_property(c: Connection, key: String) -> Variant:
	match key:
		"color":
			return [c.color.r, c.color.g, c.color.b, c.color.a]
		"thickness":
			return c.thickness
		"style":
			return c.style
		"arrow_end":
			return c.arrow_end
		"arrow_start":
			return c.arrow_start
		"label":
			return c.label
		"label_font_size":
			return c.label_font_size
		_:
			return null


func _perform_pending_save() -> void:
	if not _save_pending or _board == null or _project == null:
		return
	_save_pending = false
	_project.write_board(_board)
	_refresh_overlay_state()


func _snapshot_item_into_board(item: BoardItem) -> void:
	if item == null or _board == null:
		return
	var fresh: Dictionary = item.to_dict()
	var item_id: String = String(fresh.get("id", ""))
	if item_id == "":
		return
	var found_idx: int = _index_of_item_id(item_id)
	if found_idx >= 0:
		_board.items[found_idx] = fresh.duplicate(true)
	else:
		_board.items.append(fresh.duplicate(true))
	_item_dicts_by_id[item_id] = fresh.duplicate(true)


func _index_of_item_id(item_id: String) -> int:
	if _board == null:
		return -1
	for i: int in range(_board.items.size()):
		var entry: Variant = _board.items[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if String((entry as Dictionary).get("id", "")) == item_id:
			return i
	return -1


func _rebuild_items() -> void:
	for child: Node in _items_root.get_children():
		child.queue_free()
	_items_by_id.clear()
	_item_dicts_by_id.clear()
	if _board == null:
		return
	for entry_v: Variant in _board.items:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var item_id: String = String(entry.get("id", ""))
		var type_id: String = String(entry.get("type", ""))
		if item_id == "" or type_id == "":
			continue
		var node: BoardItem = ItemRegistry.instantiate_from_dict(entry)
		if node == null:
			continue
		node.board_id = _board.id
		_items_root.add_child(node)
		node.position = _vector_of(entry, "position", Vector2.ZERO)
		node.size = _vector_of(entry, "size", node.default_size())
		_apply_mobile_item_flags(node)
		_items_by_id[item_id] = node
		_item_dicts_by_id[item_id] = entry.duplicate(true)


func _rebuild_connections() -> void:
	_connections_by_id.clear()
	if _board != null:
		for entry: Variant in _board.connections:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var c: Connection = Connection.from_dict(entry as Dictionary)
			if c.id == "":
				c.id = Uuid.v4()
			_connections_by_id[c.id] = c
	_refresh_connection_painter()


func _refresh_connection_painter() -> void:
	var arr: Array = []
	for v in _connections_by_id.values():
		arr.append(v as Connection)
	_connection_painter.set_connections(arr)
	_connection_painter.set_selected_id(_selected_connection_id)


func _refresh_overlay_state() -> void:
	_connection_painter.refresh()
	_connection_painter.set_selected_id(_selected_connection_id)
	_comment_marker_layer.queue_redraw()
	_selection_overlay.refresh()


func _apply_background() -> void:
	if _board == null:
		_background.color = Color(0.05, 0.05, 0.08)
		return
	_background.color = _board.get_background_color()


func _lookup_item_dict(item_id: String) -> Variant:
	if _item_dicts_by_id.has(item_id):
		return _item_dicts_by_id[item_id]
	return {}


func _frame_after_layout() -> void:
	if _has_initial_frame:
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		call_deferred("_frame_after_layout")
		return
	var size_vp: Vector2 = viewport.get_visible_rect().size
	if size_vp.x < 16.0 or size_vp.y < 16.0:
		call_deferred("_frame_after_layout")
		return
	_has_initial_frame = true
	frame_all_items()


func _on_camera_tap(world_pos: Vector2) -> void:
	if _gesture_consumed:
		_gesture_consumed = false
		return
	_handle_tap_world(world_pos)


func _on_camera_long_press(world_pos: Vector2) -> void:
	if _gesture_consumed:
		_gesture_consumed = false
		return
	if _nodes_locked:
		var hit_locked: BoardItem = _hit_test_item(world_pos)
		if hit_locked == null:
			empty_tapped.emit()
			return
		item_tapped.emit(hit_locked.item_id)
		return
	if _mode == MODE_VIEW:
		var hit: BoardItem = _hit_test_item(world_pos)
		if hit == null:
			empty_tapped.emit()
			return
		item_tapped.emit(hit.item_id)
		return
	if _mode == MODE_EDIT:
		var hit2: BoardItem = _hit_test_item(world_pos)
		if hit2 == null:
			request_item_type_picker.emit(world_pos)
			return
		item_tapped.emit(hit2.item_id)


func _on_camera_double_tap(world_pos: Vector2) -> void:
	if _gesture_consumed:
		_gesture_consumed = false
		return
	if _nodes_locked:
		var hit_locked: BoardItem = _hit_test_item(world_pos)
		if hit_locked != null:
			item_tapped.emit(hit_locked.item_id)
		return
	if _mode == MODE_PEN or _mode == MODE_ERASER:
		return
	if _mode == MODE_CONNECT:
		return
	var hit: BoardItem = _hit_test_item(world_pos)
	if hit == null:
		return
	if _mode == MODE_EDIT:
		_set_selection([hit.item_id])
	item_tapped.emit(hit.item_id)


func _handle_tap_world(world_pos: Vector2) -> void:
	if _nodes_locked:
		var hit_locked: BoardItem = _hit_test_item(world_pos)
		if hit_locked == null:
			empty_tapped.emit()
			return
		item_tapped.emit(hit_locked.item_id)
		return
	match _mode:
		MODE_VIEW:
			var hit: BoardItem = _hit_test_item(world_pos)
			if hit == null:
				empty_tapped.emit()
				return
			item_tapped.emit(hit.item_id)
		MODE_EDIT:
			var hit_e: BoardItem = _hit_test_item(world_pos)
			if hit_e != null:
				_set_selection([hit_e.item_id])
				return
			var conn_id: String = _hit_test_connection(world_pos)
			if conn_id != "":
				_select_connection(conn_id)
				return
			clear_selection()
			empty_tapped.emit()
		MODE_CONNECT:
			var port_hit: Dictionary = _port_overlay.hit_test(world_pos)
			if port_hit.is_empty():
				port_hit = _closest_port_on_item_under(world_pos)
			if port_hit.is_empty():
				if _pending_connect_source != "":
					_pending_connect_source = ""
					_pending_connect_source_anchor = Connection.ANCHOR_AUTO
					_refresh_pending_connect_highlight()
				return
			var hit_id: String = String(port_hit.get("item_id", ""))
			var hit_anchor: String = String(port_hit.get("anchor", Connection.ANCHOR_AUTO))
			if _pending_connect_source == "":
				_pending_connect_source = hit_id
				_pending_connect_source_anchor = hit_anchor
				_refresh_pending_connect_highlight()
				return
			if hit_id == _pending_connect_source and hit_anchor == _pending_connect_source_anchor:
				_pending_connect_source = ""
				_pending_connect_source_anchor = Connection.ANCHOR_AUTO
				_refresh_pending_connect_highlight()
				return
			_finish_connect_to(hit_id, hit_anchor)
		MODE_PEN:
			var stroke_dict: Dictionary = AnnotationStroke.make_default("", "mobile", _annotation_color, _annotation_width)
			stroke_dict[AnnotationStroke.FIELD_POINTS] = [[world_pos.x, world_pos.y]]
			History.push(AddStrokesCommand.new(self, [stroke_dict]))
		MODE_ERASER:
			_erase_at(world_pos)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
		return
	if event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
		return
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
		return


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_state[event.index] = event.position
		if _touch_state.size() > 1:
			_cancel_pending_one_finger_gesture()
			return
		if _active_touch_index != -1:
			return
		_active_touch_index = event.index
		_begin_one_finger(event.position)
		return
	if event.index == _active_touch_index:
		_end_one_finger(event.position)
		_active_touch_index = -1
	_touch_state.erase(event.index)
	if _touch_state.is_empty():
		_drag_started = false


func _handle_drag(event: InputEventScreenDrag) -> void:
	if _touch_state.has(event.index):
		_touch_state[event.index] = event.position
	if _touch_state.size() != 1 or event.index != _active_touch_index:
		return
	_continue_one_finger(event.position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if _active_touch_index != -1:
			return
		_active_touch_index = -2
		_touch_state[-2] = event.position
		_begin_one_finger(event.position)
	else:
		if _active_touch_index == -2:
			_end_one_finger(event.position)
		_active_touch_index = -1
		_touch_state.erase(-2)
		_drag_started = false


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _active_touch_index != -2:
		return
	_touch_state[-2] = event.position
	_continue_one_finger(event.position)


func _begin_one_finger(screen_pos: Vector2) -> void:
	_drag_started = false
	_gesture_consumed = false
	_drag_item = null
	_drag_resize = false
	_drag_start_positions.clear()
	_camera_pan_started = false
	_camera_pan_last_screen = screen_pos
	_long_press_screen = screen_pos
	_long_press_world = _camera.screen_to_world(screen_pos)
	_long_press_fired = false
	if _can_claim_gesture(screen_pos):
		_long_press_timer.stop()
	else:
		_long_press_timer.start()


func _continue_one_finger(screen_pos: Vector2) -> void:
	var world_pos: Vector2 = _camera.screen_to_world(screen_pos)
	if not _drag_started:
		if _long_press_fired:
			return
		if screen_pos.distance_to(_long_press_screen) < DRAG_THRESHOLD_PX:
			return
		if _try_start_drag(_long_press_world):
			_drag_started = true
			_gesture_consumed = true
			_long_press_timer.stop()
		elif _can_pan_camera_for_current_gesture():
			_camera_pan_started = true
			_gesture_consumed = true
			_long_press_timer.stop()
		else:
			return
	if _drag_started:
		_continue_drag(world_pos)
		get_viewport().set_input_as_handled()
		return
	if _camera_pan_started:
		_continue_camera_pan(screen_pos)


func _end_one_finger(screen_pos: Vector2) -> void:
	_long_press_timer.stop()
	var world_pos: Vector2 = _camera.screen_to_world(screen_pos)
	if _drag_started:
		_finish_drag(world_pos)
		_drag_started = false
		get_viewport().set_input_as_handled()
		return
	if _camera_pan_started:
		_camera_pan_started = false
		return
	if _long_press_fired:
		_long_press_fired = false
		return
	if _mode == MODE_PEN and _annotation_stroke_in_progress.size() > 0:
		_finish_active_annotation_stroke()


func _cancel_pending_one_finger_gesture() -> void:
	_long_press_timer.stop()
	if _drag_started:
		_cancel_drag()
		_drag_started = false
	_camera_pan_started = false
	_finish_active_annotation_stroke()


func _on_long_press_timeout() -> void:
	if _drag_started:
		return
	_long_press_fired = true
	_handle_long_press_world(_long_press_world)


func _handle_long_press_world(world_pos: Vector2) -> void:
	if _nodes_locked:
		var hit_locked: BoardItem = _hit_test_item(world_pos)
		if hit_locked != null:
			item_tapped.emit(hit_locked.item_id)
		else:
			empty_tapped.emit()
		return
	match _mode:
		MODE_VIEW:
			var hit: BoardItem = _hit_test_item(world_pos)
			if hit != null:
				item_tapped.emit(hit.item_id)
			else:
				empty_tapped.emit()
		MODE_EDIT:
			var hit_e: BoardItem = _hit_test_item(world_pos)
			if hit_e != null:
				_toggle_selection(hit_e.item_id)
				_gesture_consumed = true
			else:
				request_item_type_picker.emit(world_pos)
				_gesture_consumed = true
		MODE_CONNECT:
			pass
		MODE_PEN, MODE_ERASER:
			pass


func _try_start_drag(world_pos: Vector2) -> bool:
	if _nodes_locked:
		return false
	match _mode:
		MODE_VIEW:
			var hit_v: BoardItem = _hit_test_item(world_pos)
			if hit_v == null or hit_v.locked:
				return false
			_view_drag_transient_id = hit_v.item_id
			_selected_item_ids = [hit_v.item_id]
			return _begin_move_drag(world_pos)
		MODE_EDIT:
			if _is_world_over_resize_handle(world_pos):
				return _begin_resize_drag(world_pos)
			var hit: BoardItem = _hit_test_item(world_pos)
			if hit == null:
				return false
			if not _selected_item_ids.has(hit.item_id):
				_set_selection([hit.item_id])
			return _begin_move_drag(world_pos)
		MODE_PEN:
			_begin_annotation_stroke(world_pos)
			return true
		MODE_ERASER:
			_erase_at(world_pos)
			return true
		_:
			return false


func _continue_drag(world_pos: Vector2) -> void:
	if _drag_resize:
		_continue_resize_drag(world_pos)
		return
	if _drag_item != null:
		_continue_move_drag(world_pos)
		return
	if _mode == MODE_PEN:
		_append_annotation_point(world_pos)
		return
	if _mode == MODE_ERASER:
		_erase_at(world_pos)
		return


func _finish_drag(world_pos: Vector2) -> void:
	if _drag_resize:
		_finish_resize_drag(world_pos)
		return
	if _drag_item != null:
		_finish_move_drag(world_pos)
		return
	if _mode == MODE_PEN:
		_finish_active_annotation_stroke()
		return
	if _mode == MODE_ERASER:
		_erase_at(world_pos)
		return


func _cancel_drag() -> void:
	if _drag_item != null:
		for id: String in _drag_start_positions.keys():
			var node: BoardItem = find_item_node(id)
			if node != null:
				node.position = _drag_start_positions[id]
		_drag_item = null
		_drag_start_positions.clear()
	if _drag_resize:
		var node2: BoardItem = find_item_node(_selected_item_ids[0]) if _selected_item_ids.size() > 0 else null
		if node2 != null:
			node2.size = _drag_start_size
			node2.position = _drag_start_pos
		_drag_resize = false
	if _view_drag_transient_id != "":
		_view_drag_transient_id = ""
		_selected_item_ids = []
	_finish_active_annotation_stroke()
	_refresh_overlay_state()


func _begin_move_drag(world_pos: Vector2) -> bool:
	_drag_start_positions.clear()
	for id: String in _selected_item_ids:
		var node: BoardItem = find_item_node(id)
		if node == null:
			continue
		if node.locked:
			continue
		_drag_start_positions[id] = node.position
	if _drag_start_positions.is_empty():
		return false
	_drag_item = find_item_node(_selected_item_ids[0])
	_drag_start_world = world_pos
	_refresh_item_snap_targets()
	AlignmentGuideService.begin_drag(_drag_item, _other_rects_excluding(_drag_start_positions))
	return true


func _continue_move_drag(world_pos: Vector2) -> void:
	var delta: Vector2 = world_pos - _drag_start_world
	var primary_intended: Vector2 = (_drag_start_positions[_drag_item.item_id] as Vector2) + delta
	primary_intended = SnapService.maybe_snap(primary_intended)
	primary_intended = AlignmentGuideService.maybe_align(_drag_item, primary_intended)
	var effective_delta: Vector2 = primary_intended - (_drag_start_positions[_drag_item.item_id] as Vector2)
	for id: String in _drag_start_positions.keys():
		var node: BoardItem = find_item_node(id)
		if node == null:
			continue
		node.position = (_drag_start_positions[id] as Vector2) + effective_delta
	_refresh_overlay_state()


func _finish_move_drag(world_pos: Vector2) -> void:
	var entries: Array = []
	var delta: Vector2 = world_pos - _drag_start_world
	var primary_intended: Vector2 = (_drag_start_positions[_drag_item.item_id] as Vector2) + delta
	primary_intended = SnapService.maybe_snap(primary_intended)
	primary_intended = AlignmentGuideService.maybe_align(_drag_item, primary_intended)
	var effective_delta: Vector2 = primary_intended - (_drag_start_positions[_drag_item.item_id] as Vector2)
	for id: String in _drag_start_positions.keys():
		var node: BoardItem = find_item_node(id)
		if node == null:
			continue
		var from_pos: Vector2 = _drag_start_positions[id]
		var to_pos: Vector2 = from_pos + effective_delta
		if from_pos != to_pos:
			entries.append({"id": id, "from": [from_pos.x, from_pos.y], "to": [to_pos.x, to_pos.y]})
		node.position = to_pos
	_drag_item = null
	_drag_start_positions.clear()
	AlignmentGuideService.end_drag()
	SnapService.clear_item_snap_targets()
	if not entries.is_empty():
		History.push_already_done(MoveItemsCommand.new(self, entries))
		request_save()
	if _view_drag_transient_id != "":
		_view_drag_transient_id = ""
		_selected_item_ids = []
	_refresh_overlay_state()


func _begin_resize_drag(world_pos: Vector2) -> bool:
	if _selected_item_ids.size() != 1:
		return false
	var node: BoardItem = find_item_node(_selected_item_ids[0])
	if node == null or node.locked:
		return false
	_drag_resize = true
	_drag_start_size = node.size
	_drag_start_pos = node.position
	_drag_start_world = world_pos
	var excluded: Dictionary = {node.item_id: true}
	AlignmentGuideService.begin_resize(node, _other_rects_excluding(excluded))
	return true


func _continue_resize_drag(world_pos: Vector2) -> void:
	if _selected_item_ids.size() != 1:
		return
	var node: BoardItem = find_item_node(_selected_item_ids[0])
	if node == null:
		return
	var min_s: Vector2 = node.minimum_item_size()
	var intended: Vector2 = Vector2(max(min_s.x, world_pos.x - node.position.x), max(min_s.y, world_pos.y - node.position.y))
	var aligned: Vector2 = AlignmentGuideService.maybe_align_resize(node, intended)
	node.size = aligned
	_refresh_overlay_state()


func _finish_resize_drag(_world_pos: Vector2) -> void:
	if not _drag_resize:
		return
	_drag_resize = false
	AlignmentGuideService.end_resize()
	if _selected_item_ids.size() != 1:
		return
	var node: BoardItem = find_item_node(_selected_item_ids[0])
	if node == null:
		return
	if node.size != _drag_start_size:
		History.push(ModifyPropertyCommand.new(self, node.item_id, "size", [_drag_start_size.x, _drag_start_size.y], [node.size.x, node.size.y]))
	_refresh_overlay_state()


func _is_world_over_resize_handle(world_pos: Vector2) -> bool:
	if _selected_item_ids.size() != 1:
		return false
	var node: BoardItem = find_item_node(_selected_item_ids[0])
	if node == null or node.locked:
		return false
	var corner: Vector2 = node.position + node.size
	var hit_radius: float = RESIZE_HANDLE_HIT_PX / max(_camera.zoom.x, 0.05)
	return world_pos.distance_to(corner) <= hit_radius


func _hit_test_item(world_pos: Vector2) -> BoardItem:
	var best: BoardItem = null
	var best_z: int = -2147483648
	for node_v in _items_by_id.values():
		var node: BoardItem = node_v
		var rect: Rect2 = Rect2(node.position, node.size).grow(TAP_HIT_PADDING_PX)
		if not rect.has_point(world_pos):
			continue
		var z: int = _z_index_for_type(node.type_id)
		if z >= best_z:
			best_z = z
			best = node
	return best


func _closest_port_on_item_under(world_pos: Vector2) -> Dictionary:
	var item: BoardItem = _hit_test_item(world_pos)
	if item == null:
		return {}
	var best_anchor: String = ""
	var best_distance: float = INF
	for anchor: String in BoardItem.PORT_ANCHORS:
		var port_world: Vector2 = item.port_world_position(anchor)
		var dist: float = world_pos.distance_to(port_world)
		if dist < best_distance:
			best_distance = dist
			best_anchor = anchor
	if best_anchor == "":
		return {}
	return {"item_id": item.item_id, "anchor": best_anchor}


func _hit_test_connection(world_pos: Vector2) -> String:
	var best_id: String = ""
	var best_dist: float = INF
	for v in _connections_by_id.values():
		var c: Connection = v
		var dist: float = _distance_to_connection(c, world_pos)
		if dist < best_dist and dist <= CONNECTION_TAP_TOLERANCE_PX / max(_camera.zoom.x, 0.05):
			best_dist = dist
			best_id = c.id
	return best_id


func _distance_to_connection(c: Connection, world_pos: Vector2) -> float:
	var from_d: Dictionary = _lookup_item_dict(c.from_item_id)
	var to_d: Dictionary = _lookup_item_dict(c.to_item_id)
	if from_d.is_empty() or to_d.is_empty():
		return INF
	var from_center: Vector2 = _center_of(from_d)
	var to_center: Vector2 = _center_of(to_d)
	return _distance_point_to_segment(world_pos, from_center, to_center)


func _center_of(d: Dictionary) -> Vector2:
	var pos: Vector2 = _vector_of(d, "position", Vector2.ZERO)
	var size_v: Vector2 = _vector_of(d, "size", Vector2(160, 80))
	return pos + size_v * 0.5


func _distance_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq <= 0.000001:
		return p.distance_to(a)
	var t: float = clamp((p - a).dot(ab) / len_sq, 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return p.distance_to(proj)


func _z_index_for_type(type_id: String) -> int:
	match type_id:
		ItemRegistry.TYPE_GROUP:
			return 0
		ItemRegistry.TYPE_PINBOARD:
			return 1
		ItemRegistry.TYPE_DOCUMENT:
			return 2
		_:
			return 3


func _set_selection(item_ids: Array[String]) -> void:
	_selected_item_ids = []
	for id: String in item_ids:
		if find_item_node(id) != null:
			_selected_item_ids.append(id)
	_selected_connection_id = ""
	_refresh_selection_visuals()
	_apply_mobile_edit_state()
	selection_changed.emit(selected_item_ids())


func _toggle_selection(item_id: String) -> void:
	if _selected_item_ids.has(item_id):
		_selected_item_ids.erase(item_id)
	else:
		_selected_item_ids.append(item_id)
	_selected_connection_id = ""
	_refresh_selection_visuals()
	_apply_mobile_edit_state()
	selection_changed.emit(selected_item_ids())


func _select_connection(connection_id: String) -> void:
	_selected_item_ids = []
	_selected_connection_id = connection_id
	_refresh_selection_visuals()
	selection_changed.emit([])
	connection_tapped.emit(connection_id)


func _refresh_selection_visuals() -> void:
	for v in _items_by_id.values():
		var node: BoardItem = v
		node.set_selected(_selected_item_ids.has(node.item_id))
	_selection_overlay.set_selection(_selected_item_ids)
	_selection_overlay.set_resize_handle_visible(_mode == MODE_EDIT and _selected_item_ids.size() == 1)
	_connection_painter.set_selected_id(_selected_connection_id)


func _camera_pan_should_be_allowed(screen_pos: Vector2) -> bool:
	return not _can_claim_gesture(screen_pos)


func _can_pan_camera_for_current_gesture() -> bool:
	if _nodes_locked:
		return true
	return _mode == MODE_VIEW or _mode == MODE_EDIT or _mode == MODE_CONNECT


func _continue_camera_pan(screen_pos: Vector2) -> void:
	var previous_world: Vector2 = _camera.screen_to_world(_camera_pan_last_screen)
	var current_world: Vector2 = _camera.screen_to_world(screen_pos)
	_camera_pan_last_screen = screen_pos
	_camera.position += previous_world - current_world


func _can_claim_gesture(screen_pos: Vector2) -> bool:
	if _nodes_locked:
		return false
	var world_pos: Vector2 = _camera.screen_to_world(screen_pos)
	match _mode:
		MODE_VIEW:
			var hit_v: BoardItem = _hit_test_item(world_pos)
			if hit_v != null and not hit_v.locked:
				return true
			return false
		MODE_EDIT:
			if _is_world_over_resize_handle(world_pos):
				return true
			var hit: BoardItem = _hit_test_item(world_pos)
			if hit != null and not hit.locked:
				return true
			return false
		MODE_PEN, MODE_ERASER:
			return true
		_:
			return false


func _begin_annotation_stroke(world_pos: Vector2) -> void:
	_annotation_stroke_in_progress = AnnotationStroke.make_default("", "mobile", _annotation_color, _annotation_width)
	_annotation_stroke_in_progress[AnnotationStroke.FIELD_POINTS] = [[world_pos.x, world_pos.y]]
	_annotation_painter.set_in_progress(_annotation_stroke_in_progress)


func _append_annotation_point(world_pos: Vector2) -> void:
	if _annotation_stroke_in_progress.is_empty():
		_begin_annotation_stroke(world_pos)
		return
	var points: Array = _annotation_stroke_in_progress.get(AnnotationStroke.FIELD_POINTS, [])
	if points.size() > 0:
		var last: Array = points[points.size() - 1]
		if Vector2(float(last[0]), float(last[1])).distance_to(world_pos) < 1.5:
			return
	points.append([world_pos.x, world_pos.y])
	_annotation_stroke_in_progress[AnnotationStroke.FIELD_POINTS] = points
	_annotation_painter.set_in_progress(_annotation_stroke_in_progress)


func _finish_active_annotation_stroke() -> void:
	if _annotation_stroke_in_progress.is_empty():
		return
	var stroke: Dictionary = _annotation_stroke_in_progress
	_annotation_stroke_in_progress = {}
	_annotation_painter.set_in_progress({})
	var points: Array = stroke.get(AnnotationStroke.FIELD_POINTS, [])
	if points.size() < 1:
		return
	History.push(AddStrokesCommand.new(self, [stroke]))


func _erase_at(world_pos: Vector2) -> void:
	if _board == null:
		return
	var radius_world: float = ERASER_RADIUS_PX / max(_camera.zoom.x, 0.05)
	var ids: Array = AnnotationStroke.strokes_intersecting_circle(_board.annotations, world_pos, radius_world)
	if ids.is_empty():
		return
	var dicts: Array = []
	for stroke_id_v: Variant in ids:
		var stroke_id: String = String(stroke_id_v)
		var idx: int = AnnotationStroke.find_index(_board.annotations, stroke_id)
		if idx < 0:
			continue
		dicts.append((_board.annotations[idx] as Dictionary).duplicate(true))
	if dicts.is_empty():
		return
	History.push(RemoveStrokesCommand.new(self, dicts))


func _finish_connect_to(target_item_id: String, target_anchor: String) -> void:
	if _pending_connect_source == "" or target_item_id == "":
		return
	if _pending_connect_source == target_item_id:
		return
	var c: Connection = Connection.make_new(_pending_connect_source, target_item_id, _pending_connect_source_anchor, target_anchor)
	History.push(AddConnectionsCommand.new(self, [c.to_dict()]))
	_pending_connect_source = ""
	_pending_connect_source_anchor = Connection.ANCHOR_AUTO
	_refresh_pending_connect_highlight()


func _refresh_pending_connect_highlight() -> void:
	if _pending_connect_source == "":
		_selected_item_ids = []
	else:
		_selected_item_ids = [_pending_connect_source]
	_selected_connection_id = ""
	_refresh_selection_visuals()
	_port_overlay.set_pending_source(_pending_connect_source, _pending_connect_source_anchor)


func _compute_world_bounds() -> Rect2:
	var initial: bool = true
	var rect: Rect2 = Rect2()
	for entry_v: Variant in _item_dicts_by_id.values():
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var pos: Vector2 = _vector_of(entry, "position", Vector2.ZERO)
		var size_v: Vector2 = _vector_of(entry, "size", Vector2(160, 80))
		var item_rect: Rect2 = Rect2(pos, size_v)
		if initial:
			rect = item_rect
			initial = false
		else:
			rect = rect.merge(item_rect)
	return rect


func _vector_of(d: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var raw: Variant = d.get(key, null)
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 2:
		return Vector2(float((raw as Array)[0]), float((raw as Array)[1]))
	return fallback


func notify_connection_updated(_c: Connection) -> void:
	_refresh_connection_painter()


func _on_alignment_guides_changed(guides: Array) -> void:
	if _alignment_guide_layer != null:
		_alignment_guide_layer.set_guides(guides)


func _other_rects_excluding(excluded_ids: Dictionary) -> Array:
	var rects: Array = []
	for v in _items_by_id.values():
		var node: BoardItem = v
		if excluded_ids.has(node.item_id):
			continue
		rects.append(Rect2(node.position, node.size))
	return rects


func _refresh_item_snap_targets() -> void:
	if not SnapService.snap_to_items:
		SnapService.clear_item_snap_targets()
		return
	var xs: PackedFloat32Array = PackedFloat32Array()
	var ys: PackedFloat32Array = PackedFloat32Array()
	for v in _items_by_id.values():
		var node: BoardItem = v
		var pos: Vector2 = node.position
		var size_v: Vector2 = node.size
		xs.append(pos.x)
		xs.append(pos.x + size_v.x)
		xs.append(pos.x + size_v.x * 0.5)
		ys.append(pos.y)
		ys.append(pos.y + size_v.y)
		ys.append(pos.y + size_v.y * 0.5)
	SnapService.set_item_snap_targets(xs, ys)


func _apply_mobile_item_flags(node: BoardItem) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_desktop_resize_grip_suppressed(true)


func _apply_mobile_edit_state() -> void:
	var allow_inline_edit: bool = _mode == MODE_EDIT and _selected_item_ids.size() == 1 and not _nodes_locked
	var editable_id: String = _selected_item_ids[0] if allow_inline_edit else ""
	for v in _items_by_id.values():
		var node: BoardItem = v
		if node == null:
			continue
		var should_edit: bool = node.item_id == editable_id and not node.locked
		if should_edit:
			if not node.is_editing():
				node.begin_edit()
		else:
			if node.is_editing():
				node.end_edit()


func refresh_background() -> void:
	_apply_background()
