extends Node

signal changed()

const ITEM_SNAP_THRESHOLD_PX: float = 8.0

var enabled: bool = false
var snap_to_grid: bool = true
var snap_to_items: bool = false
var grid_size: int = 16

var _item_targets_x: PackedFloat32Array = PackedFloat32Array()
var _item_targets_y: PackedFloat32Array = PackedFloat32Array()


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	_persist()
	emit_signal("changed")


func set_snap_to_grid(value: bool) -> void:
	if snap_to_grid == value:
		return
	snap_to_grid = value
	_persist()
	emit_signal("changed")


func set_snap_to_items(value: bool) -> void:
	if snap_to_items == value:
		return
	snap_to_items = value
	_persist()
	emit_signal("changed")


func set_grid_size(value: int) -> void:
	value = max(1, value)
	if grid_size == value:
		return
	grid_size = value
	_persist()
	emit_signal("changed")


func load_from_prefs(p_enabled: bool, p_snap_to_grid: bool, p_snap_to_items: bool, p_grid_size: int) -> void:
	enabled = p_enabled
	snap_to_grid = p_snap_to_grid
	snap_to_items = p_snap_to_items
	grid_size = max(1, p_grid_size)
	emit_signal("changed")


func set_item_snap_targets(targets_x: PackedFloat32Array, targets_y: PackedFloat32Array) -> void:
	_item_targets_x = targets_x
	_item_targets_y = targets_y


func clear_item_snap_targets() -> void:
	_item_targets_x = PackedFloat32Array()
	_item_targets_y = PackedFloat32Array()


func maybe_snap(p: Vector2) -> Vector2:
	if not enabled:
		return p
	var out: Vector2 = p
	if snap_to_grid and grid_size > 0:
		out = Vector2(
			round(out.x / grid_size) * grid_size,
			round(out.y / grid_size) * grid_size,
		)
	if snap_to_items:
		var snapped_x: float = _nearest_target(out.x, _item_targets_x, ITEM_SNAP_THRESHOLD_PX)
		if not is_nan(snapped_x):
			out.x = snapped_x
		var snapped_y: float = _nearest_target(out.y, _item_targets_y, ITEM_SNAP_THRESHOLD_PX)
		if not is_nan(snapped_y):
			out.y = snapped_y
	return out


func _nearest_target(value: float, targets: PackedFloat32Array, threshold: float) -> float:
	var best: float = NAN
	var best_distance: float = threshold
	for t: float in targets:
		var d: float = absf(value - t)
		if d <= best_distance:
			best_distance = d
			best = t
	return best


func _persist() -> void:
	if has_node("/root/UserPrefs"):
		var prefs: Node = get_node("/root/UserPrefs")
		if prefs.has_method("set_snap_state"):
			prefs.set_snap_state(enabled, snap_to_grid, snap_to_items, grid_size)
