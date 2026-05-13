class_name DockablePanel
extends PanelContainer

const MODE_FLOATING: String = "floating"
const MODE_DOCK_LEFT: String = "dock_left"
const MODE_DOCK_RIGHT: String = "dock_right"
const MODE_DOCK_BOTTOM: String = "dock_bottom"

const SIDE_RESERVED_PX: float = 0.0
const DOCK_SNAP_DISTANCE_PX: float = 32.0
const DEFAULT_DOCK_WIDTH: float = 300.0
const DEFAULT_DOCK_HEIGHT: float = 220.0
const MIN_FLOAT_SIZE: Vector2 = Vector2(220.0, 160.0)

@export var dock_id: String = ""
@export var drag_handle_path: NodePath
@export var grip_top_path: NodePath
@export var grip_bottom_path: NodePath
@export var grip_left_path: NodePath
@export var grip_right_path: NodePath
@export var default_mode: String = MODE_DOCK_RIGHT
@export var default_floating_position: Vector2 = Vector2(120.0, 140.0)
@export var default_floating_size: Vector2 = Vector2(320.0, 360.0)
@export var default_dock_size: float = 0.0

var _mode: String = MODE_FLOATING
var _floating_rect: Rect2 = Rect2(Vector2(120.0, 140.0), Vector2(320.0, 360.0))
var _dock_size: float = 300.0

var _drag_handle: Control = null
var _grip_top: ResizeGrip = null
var _grip_bottom: ResizeGrip = null
var _grip_left: ResizeGrip = null
var _grip_right: ResizeGrip = null

var _dragging_panel: bool = false
var _drag_start_global: Vector2 = Vector2.ZERO
var _drag_start_position: Vector2 = Vector2.ZERO
var _resize_start_rect: Rect2 = Rect2()
var _resize_start_dock_size: float = 0.0
var _layout_applying: bool = false


func _ready() -> void:
	if dock_id == "":
		push_warning("DockablePanel '%s' has no dock_id; layout will not persist." % name)
	_resolve_handles()
	_initialize_layout_state()
	_apply_layout()
	item_rect_changed.connect(_on_self_rect_changed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	if _has_layout_metrics():
		LayoutMetrics.top_reserved_changed.connect(_on_layout_metrics_changed)
		LayoutMetrics.bottom_reserved_changed.connect(_on_layout_metrics_changed)


func _has_layout_metrics() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return false
	return tree.root.has_node("LayoutMetrics")


func _top_reserved_px() -> float:
	if _has_layout_metrics():
		return LayoutMetrics.top_reserved
	return 140.0


func _bottom_reserved_px() -> float:
	if _has_layout_metrics():
		return LayoutMetrics.bottom_reserved
	return 8.0


func _on_layout_metrics_changed(_value: float) -> void:
	_apply_layout()


func _resolve_handles() -> void:
	if drag_handle_path != NodePath() and has_node(drag_handle_path):
		_drag_handle = get_node(drag_handle_path) as Control
		if _drag_handle != null:
			_drag_handle.mouse_filter = Control.MOUSE_FILTER_STOP
			_drag_handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
			_drag_handle.gui_input.connect(_on_drag_handle_input)
	_grip_top = _resolve_grip(grip_top_path)
	_grip_bottom = _resolve_grip(grip_bottom_path)
	_grip_left = _resolve_grip(grip_left_path)
	_grip_right = _resolve_grip(grip_right_path)


func _resolve_grip(path: NodePath) -> ResizeGrip:
	if path == NodePath() or not has_node(path):
		return null
	var grip: ResizeGrip = get_node(path) as ResizeGrip
	if grip == null:
		return null
	grip.grip_drag_started.connect(_on_grip_drag_started)
	grip.grip_drag_moved.connect(_on_grip_drag_moved)
	grip.grip_drag_ended.connect(_on_grip_drag_ended)
	return grip


func _initialize_layout_state() -> void:
	_floating_rect = Rect2(default_floating_position, default_floating_size)
	if default_dock_size > 0.0:
		_dock_size = default_dock_size
	else:
		_dock_size = DEFAULT_DOCK_WIDTH if default_mode != MODE_DOCK_BOTTOM else DEFAULT_DOCK_HEIGHT
	_mode = default_mode
	if dock_id == "" or not _has_user_prefs():
		return
	var stored: Dictionary = UserPrefs.get_panel_layout(dock_id)
	if stored.is_empty():
		return
	var stored_mode: String = String(stored.get("mode", _mode))
	if _is_valid_mode(stored_mode):
		_mode = stored_mode
	var rect_raw: Variant = stored.get("floating_rect", null)
	if typeof(rect_raw) == TYPE_ARRAY and (rect_raw as Array).size() >= 4:
		var arr: Array = rect_raw
		_floating_rect = Rect2(
			Vector2(float(arr[0]), float(arr[1])),
			Vector2(max(MIN_FLOAT_SIZE.x, float(arr[2])), max(MIN_FLOAT_SIZE.y, float(arr[3])))
		)
	var ds_raw: Variant = stored.get("dock_size", null)
	if typeof(ds_raw) == TYPE_FLOAT or typeof(ds_raw) == TYPE_INT:
		_dock_size = max(120.0, float(ds_raw))


func _is_valid_mode(value: String) -> bool:
	return value == MODE_FLOATING \
		or value == MODE_DOCK_LEFT \
		or value == MODE_DOCK_RIGHT \
		or value == MODE_DOCK_BOTTOM


func _has_user_prefs() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return false
	return tree.root.has_node("UserPrefs")


func _on_viewport_size_changed() -> void:
	_apply_layout()


func _on_self_rect_changed() -> void:
	if _mode == MODE_FLOATING and not _layout_applying:
		_floating_rect.position = global_position
		_floating_rect.size = size
	_layout_grips()


func _layout_grips() -> void:
	var rect_size: Vector2 = size
	var origin: Vector2 = global_position
	var thickness: float = 6.0
	if _grip_top != null and _grip_top.visible:
		_grip_top.global_position = origin + Vector2(0.0, -thickness * 0.5)
		_grip_top.size = Vector2(rect_size.x, thickness)
	if _grip_bottom != null and _grip_bottom.visible:
		_grip_bottom.global_position = origin + Vector2(0.0, rect_size.y - thickness * 0.5)
		_grip_bottom.size = Vector2(rect_size.x, thickness)
	if _grip_left != null and _grip_left.visible:
		_grip_left.global_position = origin + Vector2(-thickness * 0.5, 0.0)
		_grip_left.size = Vector2(thickness, rect_size.y)
	if _grip_right != null and _grip_right.visible:
		_grip_right.global_position = origin + Vector2(rect_size.x - thickness * 0.5, 0.0)
		_grip_right.size = Vector2(thickness, rect_size.y)


func _apply_layout() -> void:
	_layout_applying = true
	var min_size: Vector2 = get_combined_minimum_size()
	var min_w: float = max(MIN_FLOAT_SIZE.x, min_size.x)
	var min_h: float = max(MIN_FLOAT_SIZE.y, min_size.y)
	match _mode:
		MODE_FLOATING:
			anchor_left = 0.0
			anchor_top = 0.0
			anchor_right = 0.0
			anchor_bottom = 0.0
			grow_horizontal = Control.GROW_DIRECTION_END
			grow_vertical = Control.GROW_DIRECTION_END
			var rect: Rect2 = _clamp_floating_rect(_floating_rect, min_w, min_h)
			_floating_rect = rect
			offset_left = rect.position.x
			offset_top = rect.position.y
			offset_right = rect.position.x + rect.size.x
			offset_bottom = rect.position.y + rect.size.y
		MODE_DOCK_LEFT:
			anchor_left = 0.0
			anchor_top = 0.0
			anchor_right = 0.0
			anchor_bottom = 1.0
			grow_horizontal = Control.GROW_DIRECTION_END
			grow_vertical = Control.GROW_DIRECTION_BOTH
			var w_l: float = max(min_w, _dock_size)
			_dock_size = w_l
			offset_left = SIDE_RESERVED_PX
			offset_top = _top_reserved_px()
			offset_right = SIDE_RESERVED_PX + w_l
			offset_bottom = -_bottom_reserved_px()
		MODE_DOCK_RIGHT:
			anchor_left = 1.0
			anchor_top = 0.0
			anchor_right = 1.0
			anchor_bottom = 1.0
			grow_horizontal = Control.GROW_DIRECTION_BEGIN
			grow_vertical = Control.GROW_DIRECTION_BOTH
			var w_r: float = max(min_w, _dock_size)
			_dock_size = w_r
			offset_left = -w_r - SIDE_RESERVED_PX
			offset_top = _top_reserved_px()
			offset_right = -SIDE_RESERVED_PX
			offset_bottom = -_bottom_reserved_px()
		MODE_DOCK_BOTTOM:
			anchor_left = 0.0
			anchor_top = 1.0
			anchor_right = 1.0
			anchor_bottom = 1.0
			grow_horizontal = Control.GROW_DIRECTION_BOTH
			grow_vertical = Control.GROW_DIRECTION_BEGIN
			var h_b: float = max(min_h, _dock_size)
			_dock_size = h_b
			offset_left = SIDE_RESERVED_PX
			offset_top = -h_b - _bottom_reserved_px()
			offset_right = -SIDE_RESERVED_PX
			offset_bottom = -_bottom_reserved_px()
	_update_grip_visibility()
	_layout_applying = false
	_layout_grips()


func _update_grip_visibility() -> void:
	var allow_top: bool = _mode == MODE_FLOATING or _mode == MODE_DOCK_BOTTOM
	var allow_bottom: bool = _mode == MODE_FLOATING or _mode == MODE_DOCK_LEFT or _mode == MODE_DOCK_RIGHT
	var allow_left: bool = _mode == MODE_FLOATING or _mode == MODE_DOCK_RIGHT
	var allow_right: bool = _mode == MODE_FLOATING or _mode == MODE_DOCK_LEFT
	if _grip_top != null:
		_grip_top.visible = allow_top
		_grip_top.mouse_filter = Control.MOUSE_FILTER_STOP if allow_top else Control.MOUSE_FILTER_IGNORE
	if _grip_bottom != null:
		_grip_bottom.visible = allow_bottom
		_grip_bottom.mouse_filter = Control.MOUSE_FILTER_STOP if allow_bottom else Control.MOUSE_FILTER_IGNORE
	if _grip_left != null:
		_grip_left.visible = allow_left
		_grip_left.mouse_filter = Control.MOUSE_FILTER_STOP if allow_left else Control.MOUSE_FILTER_IGNORE
	if _grip_right != null:
		_grip_right.visible = allow_right
		_grip_right.mouse_filter = Control.MOUSE_FILTER_STOP if allow_right else Control.MOUSE_FILTER_IGNORE


func _clamp_floating_rect(rect: Rect2, min_w: float, min_h: float) -> Rect2:
	var vp: Vector2 = get_viewport_rect().size
	var w: float = clamp(rect.size.x, min_w, max(min_w, vp.x - 8.0))
	var h: float = clamp(rect.size.y, min_h, max(min_h, vp.y - 8.0))
	var max_x: float = max(0.0, vp.x - w)
	var top: float = _top_reserved_px()
	var bottom: float = _bottom_reserved_px()
	var max_y: float = max(top, vp.y - h - bottom)
	var x: float = clamp(rect.position.x, 0.0, max_x)
	var y: float = clamp(rect.position.y, top, max_y)
	return Rect2(Vector2(x, y), Vector2(w, h))


func _on_drag_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_panel_drag(mb.global_position)
				accept_event()
			else:
				if _dragging_panel:
					_end_panel_drag()
					accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_show_dock_context_menu(mb.global_position)
			accept_event()
	elif event is InputEventMouseMotion and _dragging_panel:
		var mm: InputEventMouseMotion = event
		_update_panel_drag(mm.global_position)
		accept_event()


func _begin_panel_drag(global_pos: Vector2) -> void:
	_dragging_panel = true
	_drag_start_global = global_pos
	if _mode == MODE_FLOATING:
		_drag_start_position = _floating_rect.position
	else:
		_drag_start_position = global_position
	move_to_front()


func _update_panel_drag(global_pos: Vector2) -> void:
	if _mode != MODE_FLOATING:
		var moved: float = global_pos.distance_to(_drag_start_global)
		if moved < 8.0:
			return
		_undock_into_floating_under_cursor(global_pos)
		return
	var delta: Vector2 = global_pos - _drag_start_global
	_floating_rect.position = _drag_start_position + delta
	_apply_layout()


func _undock_into_floating_under_cursor(global_pos: Vector2) -> void:
	var float_size: Vector2 = Vector2(
		max(MIN_FLOAT_SIZE.x, default_floating_size.x),
		max(MIN_FLOAT_SIZE.y, default_floating_size.y)
	)
	_mode = MODE_FLOATING
	_floating_rect = Rect2(global_pos - Vector2(float_size.x * 0.5, 18.0), float_size)
	_drag_start_global = global_pos
	_drag_start_position = _floating_rect.position
	_apply_layout()


func _end_panel_drag() -> void:
	_dragging_panel = false
	if _mode == MODE_FLOATING:
		var snap_target: String = _detect_dock_snap()
		if snap_target != "":
			_apply_dock_mode_from_floating(snap_target)
	_save_layout()


func _detect_dock_snap() -> String:
	var vp: Vector2 = get_viewport_rect().size
	var rect: Rect2 = _floating_rect
	if rect.position.x <= DOCK_SNAP_DISTANCE_PX:
		return MODE_DOCK_LEFT
	if rect.position.x + rect.size.x >= vp.x - DOCK_SNAP_DISTANCE_PX:
		return MODE_DOCK_RIGHT
	if rect.position.y + rect.size.y >= vp.y - DOCK_SNAP_DISTANCE_PX:
		return MODE_DOCK_BOTTOM
	return ""


func _apply_dock_mode_from_floating(target: String) -> void:
	_mode = target
	if target == MODE_DOCK_BOTTOM:
		_dock_size = max(MIN_FLOAT_SIZE.y, _floating_rect.size.y)
	else:
		_dock_size = max(MIN_FLOAT_SIZE.x, _floating_rect.size.x)
	_apply_layout()


func _on_grip_drag_started(_directions: int) -> void:
	_resize_start_rect = Rect2(_floating_rect.position, _floating_rect.size)
	_resize_start_dock_size = _dock_size


func _on_grip_drag_moved(directions: int, global_delta: Vector2) -> void:
	if _mode == MODE_FLOATING:
		_apply_floating_resize(directions, global_delta)
	else:
		_apply_docked_resize(directions, global_delta)
	_apply_layout()


func _on_grip_drag_ended(_directions: int) -> void:
	_save_layout()


func _apply_floating_resize(directions: int, delta: Vector2) -> void:
	var min_size: Vector2 = get_combined_minimum_size()
	var min_w: float = max(MIN_FLOAT_SIZE.x, min_size.x)
	var min_h: float = max(MIN_FLOAT_SIZE.y, min_size.y)
	var rect: Rect2 = Rect2(_floating_rect.position, _floating_rect.size)
	if (directions & ResizeGrip.DIR_LEFT) != 0:
		var new_x: float = rect.position.x + delta.x
		var max_x: float = rect.position.x + rect.size.x - min_w
		new_x = min(new_x, max_x)
		rect.size.x += rect.position.x - new_x
		rect.position.x = new_x
	if (directions & ResizeGrip.DIR_RIGHT) != 0:
		rect.size.x = max(min_w, rect.size.x + delta.x)
	if (directions & ResizeGrip.DIR_TOP) != 0:
		var new_y: float = rect.position.y + delta.y
		var max_y: float = rect.position.y + rect.size.y - min_h
		new_y = min(new_y, max_y)
		rect.size.y += rect.position.y - new_y
		rect.position.y = new_y
	if (directions & ResizeGrip.DIR_BOTTOM) != 0:
		rect.size.y = max(min_h, rect.size.y + delta.y)
	_floating_rect = rect


func _apply_docked_resize(directions: int, delta: Vector2) -> void:
	var min_size: Vector2 = get_combined_minimum_size()
	var min_w: float = max(MIN_FLOAT_SIZE.x, min_size.x)
	var min_h: float = max(MIN_FLOAT_SIZE.y, min_size.y)
	var vp: Vector2 = get_viewport_rect().size
	match _mode:
		MODE_DOCK_LEFT:
			if (directions & ResizeGrip.DIR_RIGHT) != 0:
				_dock_size = clamp(_dock_size + delta.x, min_w, vp.x - 100.0)
		MODE_DOCK_RIGHT:
			if (directions & ResizeGrip.DIR_LEFT) != 0:
				_dock_size = clamp(_dock_size - delta.x, min_w, vp.x - 100.0)
		MODE_DOCK_BOTTOM:
			if (directions & ResizeGrip.DIR_TOP) != 0:
				_dock_size = clamp(_dock_size - delta.y, min_h, vp.y - _top_reserved_px() - 60.0)


func _show_dock_context_menu(global_pos: Vector2) -> void:
	var menu: PopupMenu = PopupMenu.new()
	menu.add_item("Float", 0)
	menu.add_item("Dock Left", 1)
	menu.add_item("Dock Right", 2)
	menu.add_item("Dock Bottom", 3)
	add_child(menu)
	menu.id_pressed.connect(func(id: int) -> void:
		match id:
			0: set_dock_mode(MODE_FLOATING)
			1: set_dock_mode(MODE_DOCK_LEFT)
			2: set_dock_mode(MODE_DOCK_RIGHT)
			3: set_dock_mode(MODE_DOCK_BOTTOM)
		menu.queue_free()
	)
	menu.popup_hide.connect(func() -> void: menu.queue_free())
	menu.position = Vector2i(global_pos)
	menu.popup()


func set_dock_mode(target_mode: String) -> void:
	if not _is_valid_mode(target_mode):
		return
	if _mode == target_mode:
		return
	_mode = target_mode
	_apply_layout()
	_save_layout()


func current_dock_mode() -> String:
	return _mode


func _save_layout() -> void:
	if dock_id == "":
		return
	if not _has_user_prefs():
		return
	var data: Dictionary = {
		"mode": _mode,
		"floating_rect": [
			_floating_rect.position.x,
			_floating_rect.position.y,
			_floating_rect.size.x,
			_floating_rect.size.y,
		],
		"dock_size": _dock_size,
	}
	UserPrefs.set_panel_layout(dock_id, data)
