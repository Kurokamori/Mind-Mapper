extends Node

signal guides_changed(guides: Array)
signal changed()

const SNAP_THRESHOLD: float = 6.0
const DISTANCE_REPEAT_THRESHOLD: float = 8.0
const MIN_GAP: float = 1.0
const GAP_DEDUP_TOLERANCE: float = 0.5
const RESIZE_EDGE_THRESHOLD: float = 6.0
const DIMENSION_MATCH_THRESHOLD: float = 6.0

const MODE_NONE: int = 0
const MODE_DRAG: int = 1
const MODE_RESIZE: int = 2

var enabled: bool = true
var _active_item: BoardItem = null
var _other_rects: Array = []
var _x_gaps: Array = []
var _y_gaps: Array = []
var _mode: int = MODE_NONE


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	emit_signal("changed")
	if not enabled:
		emit_signal("guides_changed", [])


func begin_drag(active: BoardItem, other_rects: Array) -> void:
	_active_item = active
	_other_rects = other_rects.duplicate()
	_mode = MODE_DRAG
	_recompute_gap_catalog()


func end_drag() -> void:
	_active_item = null
	_other_rects.clear()
	_x_gaps.clear()
	_y_gaps.clear()
	_mode = MODE_NONE
	emit_signal("guides_changed", [])


func begin_resize(active: BoardItem, other_rects: Array) -> void:
	_active_item = active
	_other_rects = other_rects.duplicate()
	_mode = MODE_RESIZE


func end_resize() -> void:
	_active_item = null
	_other_rects.clear()
	_mode = MODE_NONE
	emit_signal("guides_changed", [])


func maybe_align(item: BoardItem, intended_pos: Vector2) -> Vector2:
	if not enabled or _mode != MODE_DRAG or item != _active_item or _other_rects.is_empty():
		return intended_pos
	var size: Vector2 = item.size
	var adjusted: Vector2 = intended_pos
	var guides: Array = []

	var rx: Dictionary = _find_best_axis_snap(intended_pos.x, size.x, true)
	if rx.has("delta"):
		adjusted.x += rx.delta
		guides.append({"type": "edge", "axis": "x", "value": rx.value})
	else:
		var dx: Dictionary = _find_best_repeat_snap(intended_pos, size, 0, _x_gaps)
		if dx.has("delta"):
			adjusted.x += dx.delta
			guides.append(_make_gap_guide("x", dx, adjusted, size))

	var ry: Dictionary = _find_best_axis_snap(intended_pos.y, size.y, false)
	if ry.has("delta"):
		adjusted.y += ry.delta
		guides.append({"type": "edge", "axis": "y", "value": ry.value})
	else:
		var dy: Dictionary = _find_best_repeat_snap(intended_pos, size, 1, _y_gaps)
		if dy.has("delta"):
			adjusted.y += dy.delta
			guides.append(_make_gap_guide("y", dy, adjusted, size))

	emit_signal("guides_changed", guides)
	return adjusted


func _find_best_axis_snap(start: float, length: float, is_x: bool) -> Dictionary:
	var item_edges: Array = [start, start + length * 0.5, start + length]
	var best_delta: float = INF
	var best_value: float = 0.0
	for r in _other_rects:
		var rect: Rect2 = r
		var other_edges: Array
		if is_x:
			other_edges = [rect.position.x, rect.position.x + rect.size.x * 0.5, rect.position.x + rect.size.x]
		else:
			other_edges = [rect.position.y, rect.position.y + rect.size.y * 0.5, rect.position.y + rect.size.y]
		for ie in item_edges:
			for oe in other_edges:
				var d: float = oe - ie
				if abs(d) < abs(best_delta):
					best_delta = d
					best_value = oe
	if abs(best_delta) <= SNAP_THRESHOLD:
		return {"delta": best_delta, "value": best_value}
	return {}


func _recompute_gap_catalog() -> void:
	var x_raw: Array = []
	var y_raw: Array = []
	var n: int = _other_rects.size()
	for i in range(n):
		var a: Rect2 = _other_rects[i]
		for j in range(n):
			if i == j:
				continue
			var b: Rect2 = _other_rects[j]
			if _ranges_overlap(a.position.y, a.position.y + a.size.y, b.position.y, b.position.y + b.size.y):
				var gx: float = b.position.x - (a.position.x + a.size.x)
				if gx >= MIN_GAP:
					x_raw.append(gx)
			if _ranges_overlap(a.position.x, a.position.x + a.size.x, b.position.x, b.position.x + b.size.x):
				var gy: float = b.position.y - (a.position.y + a.size.y)
				if gy >= MIN_GAP:
					y_raw.append(gy)
	_x_gaps = _dedup_sorted(x_raw)
	_y_gaps = _dedup_sorted(y_raw)


func _ranges_overlap(a0: float, a1: float, b0: float, b1: float) -> bool:
	return min(a1, b1) > max(a0, b0)


func _dedup_sorted(arr: Array) -> Array:
	var sorted: Array = arr.duplicate()
	sorted.sort()
	var out: Array = []
	for v in sorted:
		var f: float = float(v)
		if out.is_empty() or absf(float(out[out.size() - 1]) - f) > GAP_DEDUP_TOLERANCE:
			out.append(f)
	return out


func _find_best_repeat_snap(item_pos: Vector2, item_size: Vector2, axis: int, gaps: Array) -> Dictionary:
	if gaps.is_empty():
		return {}
	var perp: int = 1 - axis
	var item_start: float = item_pos[axis]
	var item_perp_start: float = item_pos[perp]
	var item_perp_end: float = item_pos[perp] + item_size[perp]
	var item_axis_size: float = item_size[axis]

	var best_delta: float = INF
	var best_anchor: float = 0.0
	var best_gap: float = 0.0
	var best_dir: int = 0
	var best_rect_perp_start: float = 0.0
	var best_rect_perp_end: float = 0.0

	for r in _other_rects:
		var rect: Rect2 = r
		var rect_perp_start: float = rect.position[perp]
		var rect_perp_end: float = rect.position[perp] + rect.size[perp]
		if not _ranges_overlap(item_perp_start, item_perp_end, rect_perp_start, rect_perp_end):
			continue
		var rect_start: float = rect.position[axis]
		var rect_end: float = rect.position[axis] + rect.size[axis]
		for g in gaps:
			var gap: float = float(g)
			var d_after: float = (rect_end + gap) - item_start
			if absf(d_after) < absf(best_delta):
				best_delta = d_after
				best_anchor = rect_end
				best_gap = gap
				best_dir = 1
				best_rect_perp_start = rect_perp_start
				best_rect_perp_end = rect_perp_end
			var d_before: float = (rect_start - gap - item_axis_size) - item_start
			if absf(d_before) < absf(best_delta):
				best_delta = d_before
				best_anchor = rect_start
				best_gap = gap
				best_dir = -1
				best_rect_perp_start = rect_perp_start
				best_rect_perp_end = rect_perp_end

	if absf(best_delta) <= DISTANCE_REPEAT_THRESHOLD:
		return {
			"delta": best_delta,
			"anchor": best_anchor,
			"gap": best_gap,
			"dir": best_dir,
			"rect_perp_start": best_rect_perp_start,
			"rect_perp_end": best_rect_perp_end,
		}
	return {}


func _make_gap_guide(axis: String, snap: Dictionary, adjusted_pos: Vector2, size: Vector2) -> Dictionary:
	var dir: int = int(snap.get("dir", 1))
	var anchor: float = float(snap.get("anchor", 0.0))
	var gap: float = float(snap.get("gap", 0.0))
	var rect_perp_start: float = float(snap.get("rect_perp_start", 0.0))
	var rect_perp_end: float = float(snap.get("rect_perp_end", 0.0))
	var from_v: float
	var to_v: float
	if dir == 1:
		from_v = anchor
		to_v = anchor + gap
	else:
		from_v = anchor - gap
		to_v = anchor
	var item_perp_start: float
	var item_perp_end: float
	if axis == "x":
		item_perp_start = adjusted_pos.y
		item_perp_end = adjusted_pos.y + size.y
	else:
		item_perp_start = adjusted_pos.x
		item_perp_end = adjusted_pos.x + size.x
	var perp_low: float = maxf(rect_perp_start, item_perp_start)
	var perp_high: float = minf(rect_perp_end, item_perp_end)
	if perp_high <= perp_low:
		perp_low = (rect_perp_start + item_perp_start) * 0.5
		perp_high = (rect_perp_end + item_perp_end) * 0.5
	var perp_center: float = (perp_low + perp_high) * 0.5
	return {
		"type": "gap",
		"axis": axis,
		"from": from_v,
		"to": to_v,
		"perp": perp_center,
		"gap": gap,
	}


func maybe_align_resize(item: BoardItem, intended_size: Vector2) -> Vector2:
	if not enabled or _mode != MODE_RESIZE or item != _active_item or _other_rects.is_empty():
		return intended_size
	var pos: Vector2 = item.position
	var min_s: Vector2 = item.minimum_item_size()
	var x_result: Dictionary = _resolve_resize_axis(pos.x, intended_size.x, min_s.x, true)
	var y_result: Dictionary = _resolve_resize_axis(pos.y, intended_size.y, min_s.y, false)
	var adjusted: Vector2 = Vector2(float(x_result.get("size", intended_size.x)), float(y_result.get("size", intended_size.y)))
	var guides: Array = []
	if x_result.has("guide"):
		guides.append(_finalize_resize_guide(x_result["guide"], pos, adjusted))
	if y_result.has("guide"):
		guides.append(_finalize_resize_guide(y_result["guide"], pos, adjusted))
	emit_signal("guides_changed", guides)
	return adjusted


func _resolve_resize_axis(start: float, intended: float, min_size: float, is_x: bool) -> Dictionary:
	var moving_edge: float = start + intended
	var edge_snap: Dictionary = _find_best_resize_edge(moving_edge, is_x)
	if edge_snap.has("delta"):
		var snapped_size: float = maxf(min_size, intended + float(edge_snap["delta"]))
		var axis_label: String = "x" if is_x else "y"
		return {
			"size": snapped_size,
			"guide": {"type": "edge", "axis": axis_label, "value": float(edge_snap["value"])},
		}
	var dim_snap: Dictionary = _find_best_dim_match(intended, is_x)
	if dim_snap.has("delta"):
		var snapped_size_dim: float = maxf(min_size, intended + float(dim_snap["delta"]))
		var axis_label_dim: String = "x" if is_x else "y"
		return {
			"size": snapped_size_dim,
			"guide": {
				"type": "dim",
				"axis": axis_label_dim,
				"source_rect": dim_snap["source_rect"],
			},
		}
	return {"size": intended}


func _find_best_resize_edge(moving_edge: float, is_x: bool) -> Dictionary:
	var best_delta: float = INF
	var best_value: float = 0.0
	for r in _other_rects:
		var rect: Rect2 = r
		var candidates: Array
		if is_x:
			candidates = [rect.position.x, rect.position.x + rect.size.x * 0.5, rect.position.x + rect.size.x]
		else:
			candidates = [rect.position.y, rect.position.y + rect.size.y * 0.5, rect.position.y + rect.size.y]
		for c in candidates:
			var cv: float = float(c)
			var d: float = cv - moving_edge
			if absf(d) < absf(best_delta):
				best_delta = d
				best_value = cv
	if absf(best_delta) <= RESIZE_EDGE_THRESHOLD:
		return {"delta": best_delta, "value": best_value}
	return {}


func _find_best_dim_match(intended: float, is_x: bool) -> Dictionary:
	var best_delta: float = INF
	var best_rect: Rect2 = Rect2()
	var found: bool = false
	for r in _other_rects:
		var rect: Rect2 = r
		var candidate: float = rect.size.x if is_x else rect.size.y
		var d: float = candidate - intended
		if absf(d) < absf(best_delta):
			best_delta = d
			best_rect = rect
			found = true
	if found and absf(best_delta) <= DIMENSION_MATCH_THRESHOLD:
		return {"delta": best_delta, "source_rect": best_rect}
	return {}


func _finalize_resize_guide(guide: Dictionary, pos: Vector2, size: Vector2) -> Dictionary:
	if String(guide.get("type", "")) != "dim":
		return guide
	guide["active_rect"] = Rect2(pos, size)
	return guide
