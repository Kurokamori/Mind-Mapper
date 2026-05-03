class_name Editor
extends Control

signal back_to_projects_requested()

const SAVE_DEBOUNCE_SEC: float = 0.5

@onready var _world: Node2D = %World
@onready var _items_root: Control = %Items
@onready var _camera: EditorCameraController = %Camera
@onready var _grid: GridBackground = %Grid
@onready var _marquee: Marquee = %Marquee
@onready var _toolbar: EditorToolbar = %Toolbar
@onready var _inspector_panel: InspectorPanel = %InspectorPanel
@onready var _breadcrumb: BreadcrumbBar = %BreadcrumbBar
@onready var _link_picker: LinkPicker = %LinkPicker
@onready var _image_dialog: FileDialog = %ImageDialog
@onready var _embed_choice_popup: ConfirmationDialog = %EmbedChoicePopup
@onready var _sound_dialog: FileDialog = %SoundDialog
@onready var _embed_sound_popup: ConfirmationDialog = %EmbedSoundPopup
@onready var _export_dialog: FileDialog = %ExportDialog
@onready var _connection_layer: ConnectionLayer = %ConnectionLayer
@onready var _board_outliner: BoardOutliner = %BoardOutliner
@onready var _minimap: Minimap = %Minimap
@onready var _command_palette: CommandPalette = %CommandPalette

var _pending_image_path: String = ""
var _pending_sound_path: String = ""
var _pending_link_target_item: BoardItem = null
var _pending_link_callback: Callable = Callable()
var _drop_target_pinboard: PinboardNode = null
var _drag_session_active: bool = false
var _save_timer: Timer
var _items_by_id: Dictionary = {}
var _drag_batch_starts: Dictionary = {}
var _drag_batch_capturing: bool = false
var _drag_followers_starts: Dictionary = {}
var _pending_export_mode: String = EditorToolbar.EXPORT_MODE_CURRENT
var _connect_tool_active: bool = false
var _selected_connection_id: String = ""
var _port_drag_active: bool = false
var _port_drag_source_item: BoardItem = null
var _port_drag_source_anchor: String = ""
var _port_drag_target_item: BoardItem = null
var _port_drag_target_anchor: String = ""

const PORT_DRAG_SNAP_PX: float = 28.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_camera.make_current()
	_toolbar.action_requested.connect(_on_toolbar_action)
	_image_dialog.file_selected.connect(_on_image_chosen)
	_embed_choice_popup.add_cancel_button("Link")
	_embed_choice_popup.confirmed.connect(_on_embed_image_confirmed)
	_embed_choice_popup.canceled.connect(_on_link_image_chosen)
	_sound_dialog.file_selected.connect(_on_sound_chosen)
	_embed_sound_popup.add_cancel_button("Link")
	_embed_sound_popup.confirmed.connect(_on_embed_sound_confirmed)
	_embed_sound_popup.canceled.connect(_on_link_sound_chosen)
	_export_dialog.file_selected.connect(_on_export_path_chosen)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE_SEC
	_save_timer.timeout.connect(_perform_save)
	add_child(_save_timer)
	_link_picker.link_chosen.connect(_on_link_picker_chosen)
	_link_picker.link_cleared.connect(_on_link_picker_cleared)
	_connection_layer.bind_editor(self)
	_connection_layer.connection_selected.connect(_on_connection_selected)
	_connection_layer.selection_cleared.connect(_on_connection_selection_cleared)
	SelectionBus.selection_changed.connect(_on_item_selection_changed)
	AppState.before_navigation.connect(_perform_save)
	AppState.current_board_changed.connect(_on_board_changed)
	_minimap.bind_editor(self, _camera)
	_command_palette.result_chosen.connect(_on_palette_result_chosen)
	_apply_initial_panel_visibility()
	if AppState.current_board != null:
		_on_board_changed(AppState.current_board)


func _on_board_changed(board: Board) -> void:
	_cancel_port_drag()
	_set_connect_tool_active(false)
	if _connection_layer != null:
		_connection_layer.cancel_pending()
		_connection_layer.clear_selection()
	for child in _items_root.get_children():
		child.queue_free()
	_items_by_id.clear()
	SelectionBus.clear()
	for item_dict in board.items:
		_spawn_item_from_dict(item_dict)
	_load_connections_from_board(board)
	if _minimap != null:
		_minimap.notify_items_changed()


func _load_connections_from_board(board: Board) -> void:
	if _connection_layer == null:
		return
	var live: Array[Connection] = []
	for d: Variant in board.connections:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		live.append(Connection.from_dict(d))
	_connection_layer.set_connections(live)


func _spawn_item_from_dict(d: Dictionary) -> BoardItem:
	var inst: BoardItem = ItemRegistry.instantiate_from_dict(d)
	if inst == null:
		return null
	inst.board_id = AppState.current_board.id if AppState.current_board != null else ""
	_items_root.add_child(inst)
	_items_by_id[inst.item_id] = inst
	_wire_item(inst)
	_apply_group_render_order(inst)
	if _minimap != null:
		_minimap.notify_items_changed()
	return inst


func _apply_group_render_order(inst: BoardItem) -> void:
	if not (inst is GroupNode):
		return
	var target_index: int = 0
	for sibling: Node in _items_root.get_children():
		if sibling == inst:
			continue
		if sibling is GroupNode:
			target_index += 1
		else:
			break
	_items_root.move_child(inst, target_index)


func instantiate_item_from_dict(d: Dictionary) -> BoardItem:
	return _spawn_item_from_dict(d)


func remove_item_by_id(id: String) -> void:
	if not _items_by_id.has(id):
		return
	var item: BoardItem = _items_by_id[id]
	if SelectionBus.is_selected(item):
		SelectionBus.remove(item)
	_items_by_id.erase(id)
	item.queue_free()
	if _minimap != null:
		_minimap.notify_items_changed()


func find_item_by_id(id: String) -> BoardItem:
	return _items_by_id.get(id, null)


func all_items() -> Array[BoardItem]:
	var out: Array[BoardItem] = []
	for v in _items_by_id.values():
		out.append(v)
	return out


func _wire_item(item: BoardItem) -> void:
	item.selection_requested.connect(_on_item_selection_requested)
	item.moved.connect(_on_item_moved)
	item.edit_begun.connect(_on_item_edit_begun)
	item.resized_by_user.connect(_on_item_resized)
	item.link_followed.connect(_on_item_link_followed)
	item.navigate_requested.connect(_on_item_navigate_requested)
	item.dragging.connect(_on_item_dragging)
	item.item_rect_changed.connect(_on_item_rect_changed)
	item.port_drag_started.connect(_on_item_port_drag_started)


func _on_item_port_drag_started(item: BoardItem, anchor: String) -> void:
	if item == null or anchor == "":
		return
	_port_drag_active = true
	_port_drag_source_item = item
	_port_drag_source_anchor = anchor
	_port_drag_target_item = null
	_port_drag_target_anchor = ""
	item.set_force_ports_visible(true)
	item.set_highlighted_port(anchor)
	if _connection_layer != null:
		var start_world: Vector2 = item.port_world_position(anchor)
		_connection_layer.begin_pending(item.item_id, start_world, anchor)


func _input(event: InputEvent) -> void:
	if not _port_drag_active:
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_update_port_drag_hover(_camera.screen_to_world(motion.position))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_finalize_port_drag()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event as InputEventKey
		if k.keycode == KEY_ESCAPE:
			_cancel_port_drag()
			get_viewport().set_input_as_handled()


func _update_port_drag_hover(world_pos: Vector2) -> void:
	var candidate: BoardItem = _find_topmost_item_at_world(world_pos, _port_drag_source_item)
	if candidate != _port_drag_target_item:
		if _port_drag_target_item != null:
			_port_drag_target_item.set_force_ports_visible(false)
			_port_drag_target_item.set_highlighted_port("")
		_port_drag_target_item = candidate
		_port_drag_target_anchor = ""
		if candidate != null:
			candidate.set_force_ports_visible(true)
	if candidate != null:
		var anchor: String = candidate.find_closest_port_in_world(world_pos, PORT_DRAG_SNAP_PX)
		if anchor != _port_drag_target_anchor:
			_port_drag_target_anchor = anchor
			candidate.set_highlighted_port(anchor)
	if _connection_layer != null:
		var endpoint_world: Vector2 = world_pos
		if _port_drag_target_item != null and _port_drag_target_anchor != "":
			endpoint_world = _port_drag_target_item.port_world_position(_port_drag_target_anchor)
		_connection_layer.update_pending_endpoint(endpoint_world)


func _find_topmost_item_at_world(world_pos: Vector2, exclude: BoardItem) -> BoardItem:
	var hit: BoardItem = null
	for it in all_items():
		if it == exclude:
			continue
		var rect: Rect2 = Rect2(it.position, it.size).grow(BoardItem.PORT_HOVER_PROXIMITY_PX)
		if rect.has_point(world_pos):
			hit = it
	return hit


func _finalize_port_drag() -> void:
	if not _port_drag_active:
		return
	var source: BoardItem = _port_drag_source_item
	var source_anchor: String = _port_drag_source_anchor
	var target: BoardItem = _port_drag_target_item
	var target_anchor: String = _port_drag_target_anchor
	_reset_port_drag_state()
	if target == null or target_anchor == "" or target == source:
		return
	var c: Connection = Connection.make_new(source.item_id, target.item_id, source_anchor, target_anchor)
	History.push(AddConnectionsCommand.new(self, [c.to_dict()]))
	select_connection_by_id(c.id)


func _cancel_port_drag() -> void:
	if not _port_drag_active:
		return
	_reset_port_drag_state()


func _reset_port_drag_state() -> void:
	if _connection_layer != null:
		_connection_layer.cancel_pending()
	if _port_drag_source_item != null:
		_port_drag_source_item.set_force_ports_visible(false)
		_port_drag_source_item.set_highlighted_port("")
	if _port_drag_target_item != null:
		_port_drag_target_item.set_force_ports_visible(false)
		_port_drag_target_item.set_highlighted_port("")
	_port_drag_active = false
	_port_drag_source_item = null
	_port_drag_source_anchor = ""
	_port_drag_target_item = null
	_port_drag_target_anchor = ""


func _on_item_rect_changed() -> void:
	if _connection_layer != null:
		_connection_layer.notify_item_changed()
	if _minimap != null:
		_minimap.notify_items_changed()


func _on_item_dragging(item: BoardItem, world_center: Vector2) -> void:
	if _connection_layer != null:
		_connection_layer.notify_item_changed()
	if not _drag_session_active:
		_drag_session_active = true
		var others: Array = []
		for it in all_items():
			if it != item:
				others.append(Rect2(it.position, it.size))
		AlignmentGuideService.begin_drag(item, others)
	if not _drag_followers_starts.is_empty() and _drag_batch_starts.has(item.item_id):
		var primary_start: Vector2 = _drag_batch_starts[item.item_id]
		var primary_delta: Vector2 = item.position - primary_start
		for fid: String in _drag_followers_starts.keys():
			var fit: BoardItem = _items_by_id.get(fid, null)
			if fit != null:
				fit.position = (_drag_followers_starts[fid] as Vector2) + primary_delta
		if _connection_layer != null:
			_connection_layer.notify_item_changed()
	var pin: PinboardNode = _find_pinboard_under(world_center, item)
	if pin == _drop_target_pinboard:
		return
	if _drop_target_pinboard != null:
		_drop_target_pinboard.set_drop_highlighted(false)
	_drop_target_pinboard = pin
	if pin != null:
		pin.set_drop_highlighted(true)


func _end_drag_session() -> void:
	if _drag_session_active:
		_drag_session_active = false
		AlignmentGuideService.end_drag()


func _find_pinboard_under(world_pos: Vector2, exclude: BoardItem) -> PinboardNode:
	var hit: PinboardNode = null
	for it in all_items():
		if it == exclude or not (it is PinboardNode):
			continue
		var pin: PinboardNode = it
		var rect: Rect2 = Rect2(pin.position, pin.size)
		if rect.has_point(world_pos):
			hit = pin
	return hit


func _clear_drop_highlight() -> void:
	if _drop_target_pinboard != null:
		_drop_target_pinboard.set_drop_highlighted(false)
		_drop_target_pinboard = null


func _on_item_link_followed(item: BoardItem) -> void:
	follow_item_link(item)


func _on_item_navigate_requested(target_kind: String, target_id: String) -> void:
	if target_kind == BoardItem.LINK_KIND_BOARD and target_id != "":
		_perform_save()
		AppState.navigate_to_board(target_id)


func follow_item_link(item: BoardItem) -> void:
	if item == null or not item.has_link():
		return
	var kind: String = String(item.link_target.get("kind", ""))
	var id: String = String(item.link_target.get("id", ""))
	if id == "":
		return
	if kind == BoardItem.LINK_KIND_BOARD:
		_perform_save()
		AppState.navigate_to_board(id)
	elif kind == BoardItem.LINK_KIND_ITEM:
		var target: BoardItem = find_item_by_id(id)
		if target != null:
			SelectionBus.set_single(target)
			_camera.position = target.position + target.size * 0.5


func open_link_picker_for(item: BoardItem, callback: Callable) -> void:
	_pending_link_target_item = item
	_pending_link_callback = callback
	var current: Dictionary = item.link_target.duplicate(true) if item != null and item.link_target != null else {}
	_link_picker.open_for(current, all_items())


func _on_link_picker_chosen(target: Dictionary) -> void:
	if _pending_link_callback.is_valid():
		_pending_link_callback.call(target)
	_pending_link_target_item = null
	_pending_link_callback = Callable()


func _on_link_picker_cleared() -> void:
	if _pending_link_callback.is_valid():
		_pending_link_callback.call({})
	_pending_link_target_item = null
	_pending_link_callback = Callable()


func _on_item_edit_begun(item: BoardItem) -> void:
	for it in all_items():
		if it != item and it.is_editing():
			it.end_edit()


func _on_item_selection_requested(item: BoardItem, additive: bool) -> void:
	if _connect_tool_active:
		_handle_connect_tool_click(item)
		return
	if additive:
		SelectionBus.toggle(item)
	else:
		if not SelectionBus.is_selected(item):
			SelectionBus.set_single(item)
	_capture_drag_starts()


func _handle_connect_tool_click(item: BoardItem) -> void:
	if item == null or _connection_layer == null:
		return
	if not _connection_layer.is_pending_active():
		var center: Vector2 = item.position + item.size * 0.5
		_connection_layer.begin_pending(item.item_id, center)
		return
	var origin_id: String = _connection_layer.pending_from_id()
	if origin_id == "" or origin_id == item.item_id:
		_connection_layer.cancel_pending()
		return
	_connection_layer.cancel_pending()
	var c: Connection = Connection.make_new(origin_id, item.item_id)
	History.push(AddConnectionsCommand.new(self, [c.to_dict()]))
	_set_connect_tool_active(false)
	select_connection_by_id(c.id)


func _capture_drag_starts() -> void:
	_drag_batch_starts.clear()
	_drag_followers_starts.clear()
	var selected: Array = SelectionBus.current()
	for it: BoardItem in selected:
		_drag_batch_starts[it.item_id] = it.position
	for it: BoardItem in selected:
		if it is GroupNode:
			_collect_group_followers(it as GroupNode)
	_drag_batch_capturing = true


func _collect_group_followers(group: GroupNode) -> void:
	var group_rect: Rect2 = Rect2(group.position, group.size)
	for other: BoardItem in all_items():
		if other == group:
			continue
		if _drag_batch_starts.has(other.item_id):
			continue
		if _drag_followers_starts.has(other.item_id):
			continue
		var center: Vector2 = other.position + other.size * 0.5
		if group_rect.has_point(center):
			_drag_followers_starts[other.item_id] = other.position


func _items_contained_by_group(group: GroupNode, exclude_ids: Dictionary) -> Dictionary:
	var found: Dictionary = {}
	var group_rect: Rect2 = Rect2(group.position, group.size)
	for other: BoardItem in all_items():
		if other == group:
			continue
		if exclude_ids.has(other.item_id):
			continue
		var center: Vector2 = other.position + other.size * 0.5
		if group_rect.has_point(center):
			found[other.item_id] = other.position
	return found


func _on_item_moved(item: BoardItem, _from: Vector2, _to: Vector2) -> void:
	_end_drag_session()
	var pin_target: PinboardNode = _drop_target_pinboard
	_clear_drop_highlight()
	if pin_target != null and pin_target != item:
		for fid: String in _drag_followers_starts.keys():
			var follower: BoardItem = _items_by_id.get(fid, null)
			if follower != null:
				follower.position = _drag_followers_starts[fid]
		_drag_followers_starts.clear()
		_finalize_drop_into_pinboard(item, pin_target)
		return
	if not _drag_batch_capturing or _drag_batch_starts.is_empty():
		var single_entries: Array = [{
			"id": item.item_id,
			"from": [_from.x, _from.y],
			"to": [_to.x, _to.y],
		}]
		var single_delta: Vector2 = _to - _from
		for fid: String in _drag_followers_starts.keys():
			var fit: BoardItem = _items_by_id.get(fid, null)
			if fit == null:
				continue
			var f_from: Vector2 = _drag_followers_starts[fid]
			var f_to: Vector2 = f_from + single_delta
			fit.position = f_to
			single_entries.append({
				"id": fid,
				"from": [f_from.x, f_from.y],
				"to": [f_to.x, f_to.y],
			})
		_drag_followers_starts.clear()
		History.push_already_done(MoveItemsCommand.new(self, single_entries))
		request_save()
		return
	var entries: Array = []
	var primary_delta: Vector2 = item.position - _drag_batch_starts.get(item.item_id, item.position)
	for id in _drag_batch_starts.keys():
		var it: BoardItem = _items_by_id.get(id, null)
		if it == null:
			continue
		var from_pos: Vector2 = _drag_batch_starts[id]
		if id != item.item_id:
			it.position = from_pos + primary_delta
		entries.append({
			"id": id,
			"from": [from_pos.x, from_pos.y],
			"to": [it.position.x, it.position.y],
		})
	for fid: String in _drag_followers_starts.keys():
		var follower: BoardItem = _items_by_id.get(fid, null)
		if follower == null:
			continue
		var f_from: Vector2 = _drag_followers_starts[fid]
		var f_to: Vector2 = f_from + primary_delta
		follower.position = f_to
		entries.append({
			"id": fid,
			"from": [f_from.x, f_from.y],
			"to": [f_to.x, f_to.y],
		})
	_drag_batch_capturing = false
	_drag_batch_starts.clear()
	_drag_followers_starts.clear()
	History.push_already_done(MoveItemsCommand.new(self, entries))
	request_save()


func _on_item_resized(item: BoardItem, from_size: Vector2, to_size: Vector2) -> void:
	History.push_already_done(ModifyPropertyCommand.new(self, item.item_id, "size", from_size, to_size))
	request_save()


func _finalize_drop_into_pinboard(primary: BoardItem, pin: PinboardNode) -> void:
	if AppState.current_project == null or AppState.current_board == null:
		return
	var target_id: String = pin.ensure_target_board()
	if target_id == "":
		return
	var to_move: Array = []
	if SelectionBus.is_selected(primary):
		for it in SelectionBus.current():
			if it != pin and not (it is PinboardNode and (it as PinboardNode).target_board_id == target_id):
				to_move.append(it)
	else:
		to_move.append(primary)
	if to_move.is_empty():
		return
	var min_pos: Vector2 = Vector2(INF, INF)
	for it in to_move:
		min_pos.x = min(min_pos.x, it.position.x)
		min_pos.y = min(min_pos.y, it.position.y)
	var target_origin: Vector2 = Vector2(40.0, 40.0)
	var entries: Array = []
	for it in to_move:
		var dict_copy: Dictionary = (it as BoardItem).to_dict()
		var rel: Vector2 = it.position - min_pos
		var new_pos: Vector2 = target_origin + rel
		entries.append({
			"dict": dict_copy,
			"source_position": [it.position.x, it.position.y],
			"target_position": [new_pos.x, new_pos.y],
		})
	_drag_batch_capturing = false
	_drag_batch_starts.clear()
	History.push(MoveItemsBetweenBoardsCommand.new(self, AppState.current_board.id, target_id, entries))


func _gui_input(event: InputEvent) -> void:
	var consumed: bool = _camera.handle_unhandled_input(event)
	if consumed:
		accept_event()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_commit_active_edits()
				var world_pos: Vector2 = _camera.screen_to_world(mb.position)
				if _connect_tool_active and _connection_layer != null and _connection_layer.is_pending_active():
					_connection_layer.cancel_pending()
					_set_connect_tool_active(false)
					accept_event()
					return
				if _connection_layer != null:
					var hit: Connection = _connection_layer.hit_test(world_pos)
					if hit != null:
						SelectionBus.clear()
						select_connection_by_id(hit.id)
						accept_event()
						return
				if not mb.shift_pressed:
					SelectionBus.clear()
					_clear_connection_selection()
				_marquee.begin(world_pos)
				accept_event()
			else:
				if _marquee.active:
					var rect: Rect2 = _marquee.finish()
					_select_in_rect(rect, mb.shift_pressed)
					accept_event()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _marquee.active:
			_marquee.update_to(_camera.screen_to_world(motion.position))
		if _connect_tool_active and _connection_layer != null and _connection_layer.is_pending_active():
			_connection_layer.update_pending_endpoint(_camera.screen_to_world(motion.position))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event as InputEventKey
		var ctrl: bool = k.ctrl_pressed or k.meta_pressed
		if ctrl and (k.keycode == KEY_K or k.keycode == KEY_P):
			_open_command_palette()
			get_viewport().set_input_as_handled()
			return
		if ctrl and k.keycode == KEY_Z and not k.shift_pressed:
			History.undo()
			get_viewport().set_input_as_handled()
		elif ctrl and (k.keycode == KEY_Y or (k.keycode == KEY_Z and k.shift_pressed)):
			History.redo()
			get_viewport().set_input_as_handled()
		elif ctrl and k.keycode == KEY_C:
			_copy_selection()
			get_viewport().set_input_as_handled()
		elif ctrl and k.keycode == KEY_V:
			_paste_at_mouse()
			get_viewport().set_input_as_handled()
		elif ctrl and k.keycode == KEY_X:
			_copy_selection()
			_delete_selection()
			get_viewport().set_input_as_handled()
		elif ctrl and k.keycode == KEY_D:
			_duplicate_selection()
			get_viewport().set_input_as_handled()
		elif ctrl and k.keycode == KEY_S:
			_perform_save()
			get_viewport().set_input_as_handled()
		elif ctrl and k.keycode == KEY_A:
			_select_all()
			get_viewport().set_input_as_handled()
		elif ctrl and k.keycode == KEY_G:
			_group_selection()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_LEFT or k.keycode == KEY_RIGHT or k.keycode == KEY_UP or k.keycode == KEY_DOWN:
			if _has_selection_and_no_editing():
				_nudge_selection(k.keycode, k.shift_pressed)
				get_viewport().set_input_as_handled()
		elif k.keycode == KEY_DELETE or k.keycode == KEY_BACKSPACE:
			if _selected_connection_id != "":
				_delete_selected_connection()
				get_viewport().set_input_as_handled()
			elif _has_selection_and_no_editing():
				_delete_selection()
				get_viewport().set_input_as_handled()
		elif k.keycode == KEY_ESCAPE:
			if _connect_tool_active:
				_set_connect_tool_active(false)
				get_viewport().set_input_as_handled()
			elif _selected_connection_id != "":
				_clear_connection_selection()
				get_viewport().set_input_as_handled()


func _commit_active_edits() -> void:
	for it in all_items():
		if it.is_editing():
			it.end_edit()


func _has_selection_and_no_editing() -> bool:
	var any_editing: bool = false
	for it in SelectionBus.current():
		if it.is_editing():
			any_editing = true
			break
	return not any_editing and not SelectionBus.current().is_empty()


func _select_in_rect(rect: Rect2, additive: bool) -> void:
	var picks: Array = []
	for it in all_items():
		var item_rect: Rect2 = Rect2(it.position, it.size)
		if rect.intersects(item_rect):
			picks.append(it)
	if additive:
		var combined: Array = SelectionBus.current()
		for p in picks:
			if not combined.has(p):
				combined.append(p)
		SelectionBus.set_many(combined)
	else:
		SelectionBus.set_many(picks)


func _select_all() -> void:
	var picks: Array = []
	for it in all_items():
		picks.append(it)
	SelectionBus.set_many(picks)


func _copy_selection() -> void:
	var dicts: Array = []
	for it in SelectionBus.current():
		dicts.append(it.to_dict())
	if dicts.is_empty():
		return
	Clipboard.set_items(dicts)


func _paste_at_mouse() -> void:
	if Clipboard.is_empty():
		return
	var raw: Array = Clipboard.get_items_for_paste()
	if raw.is_empty():
		return
	var paste_target_world: Vector2 = _camera.screen_to_world(get_local_mouse_position())
	var min_x: float = INF
	var min_y: float = INF
	for d in raw:
		var pos: Array = d.get("position", [0, 0])
		min_x = min(min_x, float(pos[0]))
		min_y = min(min_y, float(pos[1]))
	var origin_offset: Vector2 = Vector2(min_x, min_y)
	for d in raw:
		var pos: Array = d.get("position", [0, 0])
		var rel: Vector2 = Vector2(float(pos[0]), float(pos[1])) - origin_offset
		var new_pos: Vector2 = paste_target_world + rel
		d["position"] = [new_pos.x, new_pos.y]
	History.push(AddItemsCommand.new(self, raw))
	var newly: Array = []
	for d in raw:
		var found: BoardItem = find_item_by_id(String(d.get("id", "")))
		if found != null:
			newly.append(found)
	SelectionBus.set_many(newly)


func _duplicate_selection() -> void:
	var dicts: Array = []
	for it in SelectionBus.current():
		var d: Dictionary = it.duplicate_dict()
		var pos: Array = d.get("position", [0, 0])
		d["position"] = [float(pos[0]) + 24.0, float(pos[1]) + 24.0]
		dicts.append(d)
	if dicts.is_empty():
		return
	History.push(AddItemsCommand.new(self, dicts))
	var newly: Array = []
	for d in dicts:
		var found: BoardItem = find_item_by_id(String(d.get("id", "")))
		if found != null:
			newly.append(found)
	SelectionBus.set_many(newly)


func _delete_selection() -> void:
	var current: Array = SelectionBus.current()
	if current.is_empty():
		return
	var snapshot: Array = []
	for it in current:
		snapshot.append(it)
	SelectionBus.clear()
	History.push(RemoveItemsCommand.new(self, snapshot))


func _on_toolbar_action(action: String, payload: Variant) -> void:
	match action:
		EditorToolbar.ACTION_ADD:
			_handle_add(String(payload))
		EditorToolbar.ACTION_TOGGLE_INSPECTOR:
			_inspector_panel.visible = bool(payload)
		EditorToolbar.ACTION_TOGGLE_OUTLINER:
			var visible_outliner: bool = bool(payload)
			_board_outliner.visible = visible_outliner
			UserPrefs.set_outliner_visible(visible_outliner)
		EditorToolbar.ACTION_TOGGLE_MINIMAP:
			var visible_minimap: bool = bool(payload)
			_minimap.visible = visible_minimap
			UserPrefs.set_minimap_visible(visible_minimap)
		EditorToolbar.ACTION_UNDO:
			History.undo()
		EditorToolbar.ACTION_REDO:
			History.redo()
		EditorToolbar.ACTION_SAVE:
			_perform_save()
		EditorToolbar.ACTION_BACK_TO_PROJECTS:
			_perform_save()
			emit_signal("back_to_projects_requested")
		EditorToolbar.ACTION_GROUP:
			_group_selection()
		EditorToolbar.ACTION_EXPORT_PNG:
			_open_export_dialog(String(payload))
		EditorToolbar.ACTION_TOGGLE_CONNECT:
			_set_connect_tool_active(bool(payload))


func _handle_add(type_id: String) -> void:
	match type_id:
		ItemRegistry.TYPE_TEXT:
			_add_simple(ItemRegistry.TYPE_TEXT, {"text": "New text", "font_size": TextNode.DEFAULT_FONT_SIZE})
		ItemRegistry.TYPE_LABEL:
			_add_simple(ItemRegistry.TYPE_LABEL, {"text": "Label", "font_size": LabelNode.DEFAULT_FONT_SIZE})
		ItemRegistry.TYPE_RICH_TEXT:
			_add_simple(ItemRegistry.TYPE_RICH_TEXT, {"bbcode_text": RichTextNode.DEFAULT_BBCODE, "font_size": RichTextNode.DEFAULT_FONT_SIZE})
		ItemRegistry.TYPE_PRIMITIVE:
			_add_simple(ItemRegistry.TYPE_PRIMITIVE, {"shape": PrimitiveNode.Shape.RECT})
		ItemRegistry.TYPE_GROUP:
			_add_simple(ItemRegistry.TYPE_GROUP, {"title": "Group"})
		ItemRegistry.TYPE_TIMER:
			_add_simple(ItemRegistry.TYPE_TIMER, {"initial_duration_sec": 600.0, "label_text": "Timer"})
		ItemRegistry.TYPE_PINBOARD:
			_add_pinboard()
		ItemRegistry.TYPE_SUBPAGE:
			_add_subpage()
		ItemRegistry.TYPE_TODO_LIST:
			_add_simple(ItemRegistry.TYPE_TODO_LIST, {"title": "List", "cards": []})
		ItemRegistry.TYPE_BLOCK_STACK:
			_add_simple(ItemRegistry.TYPE_BLOCK_STACK, {"title": "Blocks", "blocks": []})
		ItemRegistry.TYPE_IMAGE:
			_image_dialog.popup_centered_ratio(0.7)
		ItemRegistry.TYPE_SOUND:
			_sound_dialog.popup_centered_ratio(0.7)


func _add_pinboard() -> void:
	if AppState.current_project == null:
		return
	var parent_id: String = AppState.current_board.id if AppState.current_board != null else ""
	var child: Board = AppState.current_project.create_child_board(parent_id, "Pinboard")
	if child == null:
		return
	var d: Dictionary = {
		"id": Uuid.v4(),
		"type": ItemRegistry.TYPE_PINBOARD,
		"position": [_camera.position.x - 130, _camera.position.y - 100],
		"size": [260, 200],
		"target_board_id": child.id,
		"title": child.name,
	}
	History.push(AddItemsCommand.new(self, [d]))
	var newly: BoardItem = find_item_by_id(String(d["id"]))
	if newly != null:
		SelectionBus.set_single(newly)


func _add_subpage() -> void:
	if AppState.current_project == null:
		return
	var parent_id: String = AppState.current_board.id if AppState.current_board != null else ""
	var child: Board = AppState.current_project.create_child_board(parent_id, "Subpage")
	if child == null:
		return
	var d: Dictionary = {
		"id": Uuid.v4(),
		"type": ItemRegistry.TYPE_SUBPAGE,
		"position": [_camera.position.x - 180, _camera.position.y - 130],
		"size": [360, 260],
		"target_board_id": child.id,
		"title": child.name,
		"view_zoom": 0.5,
		"auto_fit": true,
	}
	History.push(AddItemsCommand.new(self, [d]))
	var newly: BoardItem = find_item_by_id(String(d["id"]))
	if newly != null:
		SelectionBus.set_single(newly)


func _add_simple(type_id: String, extra: Dictionary) -> void:
	var d: Dictionary = {
		"id": Uuid.v4(),
		"type": type_id,
		"position": [_camera.position.x - 110, _camera.position.y - 50],
	}
	for k in extra.keys():
		d[k] = extra[k]
	History.push(AddItemsCommand.new(self, [d]))
	var newly: BoardItem = find_item_by_id(String(d["id"]))
	if newly != null:
		SelectionBus.set_single(newly)


func _on_image_chosen(path: String) -> void:
	_pending_image_path = path
	_embed_choice_popup.popup_centered()


func _on_embed_image_confirmed() -> void:
	_finalize_image_add(true)


func _on_link_image_chosen() -> void:
	_finalize_image_add(false)


func _finalize_image_add(embed: bool) -> void:
	if _pending_image_path == "":
		return
	var path: String = _pending_image_path
	_pending_image_path = ""
	var d: Dictionary = {
		"id": Uuid.v4(),
		"type": ItemRegistry.TYPE_IMAGE,
		"position": [_camera.position.x - 120, _camera.position.y - 90],
		"size": [240, 180],
	}
	if embed and AppState.current_project != null:
		var copied: String = AppState.current_project.copy_asset_into_project(path)
		if copied != "":
			d["source_mode"] = ImageNode.SourceMode.EMBEDDED
			d["asset_name"] = copied
			d["source_path"] = ""
		else:
			d["source_mode"] = ImageNode.SourceMode.LINKED
			d["source_path"] = path
			d["asset_name"] = ""
	else:
		d["source_mode"] = ImageNode.SourceMode.LINKED
		d["source_path"] = path
		d["asset_name"] = ""
	History.push(AddItemsCommand.new(self, [d]))
	var newly: BoardItem = find_item_by_id(String(d["id"]))
	if newly != null:
		SelectionBus.set_single(newly)


func _on_sound_chosen(path: String) -> void:
	_pending_sound_path = path
	_embed_sound_popup.popup_centered()


func _on_embed_sound_confirmed() -> void:
	_finalize_sound_add(true)


func _on_link_sound_chosen() -> void:
	_finalize_sound_add(false)


func _finalize_sound_add(embed: bool) -> void:
	if _pending_sound_path == "":
		return
	var path: String = _pending_sound_path
	_pending_sound_path = ""
	var d: Dictionary = {
		"id": Uuid.v4(),
		"type": ItemRegistry.TYPE_SOUND,
		"position": [_camera.position.x - 140, _camera.position.y - 55],
		"display_label": path.get_file(),
	}
	if embed and AppState.current_project != null:
		var copied: String = AppState.current_project.copy_asset_into_project(path)
		if copied != "":
			d["source_mode"] = SoundNode.SourceMode.EMBEDDED
			d["asset_name"] = copied
			d["source_path"] = ""
		else:
			d["source_mode"] = SoundNode.SourceMode.LINKED
			d["source_path"] = path
			d["asset_name"] = ""
	else:
		d["source_mode"] = SoundNode.SourceMode.LINKED
		d["source_path"] = path
		d["asset_name"] = ""
	History.push(AddItemsCommand.new(self, [d]))
	var newly: BoardItem = find_item_by_id(String(d["id"]))
	if newly != null:
		SelectionBus.set_single(newly)


func _nudge_selection(keycode: int, shift_held: bool) -> void:
	var current: Array = SelectionBus.current()
	if current.is_empty():
		return
	var step: float = 10.0 if shift_held else 1.0
	var delta: Vector2 = Vector2.ZERO
	match keycode:
		KEY_LEFT: delta = Vector2(-step, 0)
		KEY_RIGHT: delta = Vector2(step, 0)
		KEY_UP: delta = Vector2(0, -step)
		KEY_DOWN: delta = Vector2(0, step)
	if delta == Vector2.ZERO:
		return
	var entries: Array = []
	var selected_ids: Dictionary = {}
	for it in current:
		selected_ids[(it as BoardItem).item_id] = true
	var followers: Dictionary = {}
	for it in current:
		if it is GroupNode:
			var contained: Dictionary = _items_contained_by_group(it as GroupNode, selected_ids)
			for fid: String in contained.keys():
				if not followers.has(fid):
					followers[fid] = contained[fid]
	for it in current:
		var item: BoardItem = it
		var from_pos: Vector2 = item.position
		var to_pos: Vector2 = from_pos + delta
		item.position = to_pos
		entries.append({
			"id": item.item_id,
			"from": [from_pos.x, from_pos.y],
			"to": [to_pos.x, to_pos.y],
		})
	for fid: String in followers.keys():
		var fit: BoardItem = _items_by_id.get(fid, null)
		if fit == null:
			continue
		var f_from: Vector2 = followers[fid]
		var f_to: Vector2 = f_from + delta
		fit.position = f_to
		entries.append({
			"id": fid,
			"from": [f_from.x, f_from.y],
			"to": [f_to.x, f_to.y],
		})
	History.push_already_done(MoveItemsCommand.new(self, entries))
	request_save()


func _group_selection() -> void:
	var current: Array = SelectionBus.current()
	if current.is_empty():
		return
	var min_p: Vector2 = Vector2(INF, INF)
	var max_p: Vector2 = Vector2(-INF, -INF)
	for it in current:
		var item: BoardItem = it
		min_p.x = min(min_p.x, item.position.x)
		min_p.y = min(min_p.y, item.position.y)
		max_p.x = max(max_p.x, item.position.x + item.size.x)
		max_p.y = max(max_p.y, item.position.y + item.size.y)
	var pad: float = 18.0
	var origin: Vector2 = Vector2(min_p.x - pad, min_p.y - GroupNode.TITLE_HEIGHT - pad)
	var size_v: Vector2 = (max_p - min_p) + Vector2(pad * 2.0, pad * 2.0 + GroupNode.TITLE_HEIGHT)
	var d: Dictionary = {
		"id": Uuid.v4(),
		"type": ItemRegistry.TYPE_GROUP,
		"position": [origin.x, origin.y],
		"size": [size_v.x, size_v.y],
		"title": "Group",
	}
	History.push(AddItemsCommand.new(self, [d]))
	var newly: BoardItem = find_item_by_id(String(d["id"]))
	if newly != null:
		SelectionBus.set_single(newly)


func _open_export_dialog(mode: String) -> void:
	if AppState.current_project == null or AppState.current_board == null:
		return
	_pending_export_mode = mode if mode != "" else EditorToolbar.EXPORT_MODE_CURRENT
	var suffix: String = "_unfolded" if _pending_export_mode == EditorToolbar.EXPORT_MODE_UNFOLDED else ""
	var default_name: String = "%s%s.png" % [AppState.current_board.name.replace(" ", "_"), suffix]
	_export_dialog.title = "Export unfolded as PNG" if _pending_export_mode == EditorToolbar.EXPORT_MODE_UNFOLDED else "Export current board as PNG"
	_export_dialog.current_file = default_name
	_export_dialog.popup_centered_ratio(0.7)


func _on_export_path_chosen(path: String) -> void:
	if not path.to_lower().ends_with(".png"):
		path += ".png"
	if AppState.current_board == null:
		return
	var exporter: BoardExporter = BoardExporter.new(self)
	if _pending_export_mode == EditorToolbar.EXPORT_MODE_UNFOLDED:
		await exporter.export_unfolded(AppState.current_board, AppState.current_project, path)
	else:
		await exporter.export_board(AppState.current_board, path)


func request_save() -> void:
	if _save_timer != null:
		_save_timer.start()


func _perform_save() -> void:
	if AppState.current_project == null or AppState.current_board == null:
		return
	var dicts: Array = []
	for it in all_items():
		dicts.append(it.to_dict())
	var connection_dicts: Array = []
	if _connection_layer != null:
		connection_dicts = _connection_layer.get_connection_dicts()
	AppState.save_current_board(dicts, connection_dicts)


func add_connection(c: Connection) -> void:
	if _connection_layer != null:
		_connection_layer.add_connection(c)


func remove_connection_by_id(connection_id: String) -> void:
	if _connection_layer == null:
		return
	if _selected_connection_id == connection_id:
		_clear_connection_selection()
	_connection_layer.remove_connection_by_id(connection_id)


func remove_connections_referencing_item(item_id: String) -> Array:
	if _connection_layer == null:
		return []
	var removed: Array[Connection] = _connection_layer.remove_connections_referencing_item(item_id)
	for c: Connection in removed:
		if c.id == _selected_connection_id:
			_clear_connection_selection()
	var out: Array = []
	for c: Connection in removed:
		out.append(c)
	return out


func find_connection_by_id(connection_id: String) -> Connection:
	if _connection_layer == null:
		return null
	return _connection_layer.find_connection(connection_id)


func notify_connection_updated(_c: Connection) -> void:
	if _connection_layer != null:
		_connection_layer.queue_redraw()


func select_connection_by_id(connection_id: String) -> void:
	if _connection_layer == null:
		return
	SelectionBus.clear()
	_connection_layer.select_connection(connection_id)


func _clear_connection_selection() -> void:
	if _connection_layer != null:
		_connection_layer.clear_selection()


func _on_connection_selected(c: Connection) -> void:
	_selected_connection_id = c.id
	_inspector_panel.show_connection(c, self)


func _on_connection_selection_cleared() -> void:
	_selected_connection_id = ""
	_inspector_panel.show_connection(null, self)


func _on_item_selection_changed(_selected: Array) -> void:
	if not _selected.is_empty() and _connection_layer != null and _selected_connection_id != "":
		_connection_layer.clear_selection()


func _delete_selected_connection() -> void:
	if _selected_connection_id == "" or _connection_layer == null:
		return
	var c: Connection = _connection_layer.find_connection(_selected_connection_id)
	if c == null:
		return
	History.push(RemoveConnectionsCommand.new(self, [c]))


func _apply_initial_panel_visibility() -> void:
	if _board_outliner != null:
		_board_outliner.visible = UserPrefs.outliner_visible
	if _minimap != null:
		_minimap.visible = UserPrefs.minimap_visible
	if _toolbar != null:
		_toolbar.set_outliner_pressed(UserPrefs.outliner_visible)
		_toolbar.set_minimap_pressed(UserPrefs.minimap_visible)


func _open_command_palette() -> void:
	if _command_palette == null:
		return
	_perform_save()
	_commit_active_edits()
	_command_palette.open()


func _on_palette_result_chosen(result: ProjectIndex.SearchResult) -> void:
	if result == null:
		return
	match result.kind:
		ProjectIndex.SEARCH_RESULT_KIND_BOARD:
			_jump_to_board(result.board_id, "")
		ProjectIndex.SEARCH_RESULT_KIND_ITEM, \
		ProjectIndex.SEARCH_RESULT_KIND_TODO_CARD, \
		ProjectIndex.SEARCH_RESULT_KIND_BLOCK_ROW:
			_jump_to_board(result.board_id, result.item_id)
		ProjectIndex.SEARCH_RESULT_KIND_CONNECTION:
			_jump_to_connection(result.board_id, result.connection_id, result.item_id)


func navigate_to_backlink(board_id: String, item_id: String) -> void:
	_jump_to_board(board_id, item_id)


func _jump_to_connection(board_id: String, connection_id: String, anchor_item_id: String) -> void:
	if board_id == "":
		return
	if AppState.current_board == null or AppState.current_board.id != board_id:
		_perform_save()
		var navigated: bool = AppState.navigate_to_board(board_id)
		if not navigated and (AppState.current_board == null or AppState.current_board.id != board_id):
			return
	if connection_id == "":
		return
	var anchor: BoardItem = find_item_by_id(anchor_item_id) if anchor_item_id != "" else null
	if anchor != null:
		_camera.position = anchor.position + anchor.size * 0.5
	select_connection_by_id(connection_id)


func _jump_to_board(board_id: String, item_id: String) -> void:
	if board_id == "":
		return
	if AppState.current_board == null or AppState.current_board.id != board_id:
		_perform_save()
		var navigated: bool = AppState.navigate_to_board(board_id)
		if not navigated and (AppState.current_board == null or AppState.current_board.id != board_id):
			return
	if item_id == "":
		return
	var target: BoardItem = find_item_by_id(item_id)
	if target == null:
		return
	SelectionBus.set_single(target)
	_camera.position = target.position + target.size * 0.5


func _set_connect_tool_active(active: bool) -> void:
	_connect_tool_active = active
	if _toolbar != null:
		_toolbar.set_connect_pressed(active)
	if _connection_layer != null and not active:
		_connection_layer.cancel_pending()
