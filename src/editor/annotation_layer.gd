class_name AnnotationLayer
extends Node2D

const SELECTION_OUTLINE_COLOR: Color = Color(1.0, 0.85, 0.2, 0.9)
const SELECTION_OUTLINE_EXTRA_WIDTH: float = 4.0
const LIVE_STROKE_ALPHA: float = 0.85
const MIN_DRAW_WIDTH: float = 0.5
const SMOOTHING_ITERATIONS: int = 2

var _strokes: Array = []
var _selected_ids: Array[String] = []
var _live_strokes: Dictionary = {}
var _local_in_progress: Dictionary = {}


func set_strokes(strokes: Array) -> void:
	_strokes.clear()
	for entry: Variant in strokes:
		if typeof(entry) == TYPE_DICTIONARY:
			_strokes.append(AnnotationStroke.normalize((entry as Dictionary).duplicate(true)))
	_selected_ids = _selected_ids.filter(func(id: String) -> bool: return AnnotationStroke.find_index(_strokes, id) >= 0)
	queue_redraw()


func get_strokes() -> Array:
	return _strokes.duplicate(true)


func get_stroke(stroke_id: String) -> Dictionary:
	return AnnotationStroke.find_stroke(_strokes, stroke_id)


func add_stroke(stroke_dict: Dictionary) -> void:
	var normalized: Dictionary = AnnotationStroke.normalize(stroke_dict.duplicate(true))
	var stroke_id: String = String(normalized.get(AnnotationStroke.FIELD_ID, ""))
	if stroke_id == "":
		return
	var idx: int = AnnotationStroke.find_index(_strokes, stroke_id)
	if idx < 0:
		_strokes.append(normalized)
	else:
		_strokes[idx] = normalized
	_live_strokes.erase(stroke_id)
	queue_redraw()


func remove_stroke(stroke_id: String) -> void:
	if stroke_id == "":
		return
	var idx: int = AnnotationStroke.find_index(_strokes, stroke_id)
	if idx >= 0:
		_strokes.remove_at(idx)
	_selected_ids.erase(stroke_id)
	_live_strokes.erase(stroke_id)
	queue_redraw()


func clear_selection() -> void:
	if _selected_ids.is_empty():
		return
	_selected_ids.clear()
	queue_redraw()


func set_selected_ids(ids: Array) -> void:
	_selected_ids.clear()
	for id: Variant in ids:
		var id_str: String = String(id)
		if AnnotationStroke.find_index(_strokes, id_str) >= 0 and not _selected_ids.has(id_str):
			_selected_ids.append(id_str)
	queue_redraw()


func toggle_selected(stroke_id: String, additive: bool) -> void:
	if stroke_id == "":
		return
	if AnnotationStroke.find_index(_strokes, stroke_id) < 0:
		return
	if additive:
		if _selected_ids.has(stroke_id):
			_selected_ids.erase(stroke_id)
		else:
			_selected_ids.append(stroke_id)
	else:
		_selected_ids = [stroke_id]
	queue_redraw()


func selected_ids() -> Array[String]:
	return _selected_ids.duplicate()


func selected_snapshots() -> Array:
	var out: Array = []
	for id: String in _selected_ids:
		var snap: Dictionary = AnnotationStroke.find_stroke(_strokes, id)
		if not snap.is_empty():
			out.append(snap)
	return out


func hit_test(world_pos: Vector2, tolerance_px: float) -> String:
	return AnnotationStroke.hit_test(_strokes, world_pos, tolerance_px)


func strokes_intersecting_circle(world_pos: Vector2, radius_px: float) -> Array:
	return AnnotationStroke.strokes_intersecting_circle(_strokes, world_pos, radius_px)


func strokes_in_rect(rect: Rect2) -> Array:
	return AnnotationStroke.strokes_in_rect(_strokes, rect)


func update_live_stroke(stable_id: String, payload: Dictionary) -> void:
	if stable_id == "":
		return
	var finished: bool = bool(payload.get("finished", false))
	if finished:
		_live_strokes.erase(stable_id)
	else:
		_live_strokes[stable_id] = AnnotationStroke.normalize(payload.duplicate(true))
	queue_redraw()


func clear_live_stroke(stable_id: String) -> void:
	if _live_strokes.has(stable_id):
		_live_strokes.erase(stable_id)
		queue_redraw()


func clear_all_live_strokes() -> void:
	if _live_strokes.is_empty():
		return
	_live_strokes.clear()
	queue_redraw()


func set_local_in_progress(stroke_dict: Variant) -> void:
	if typeof(stroke_dict) != TYPE_DICTIONARY:
		_local_in_progress.clear()
	else:
		_local_in_progress = AnnotationStroke.normalize((stroke_dict as Dictionary).duplicate(true))
	queue_redraw()


func clear_local_in_progress() -> void:
	if _local_in_progress.is_empty():
		return
	_local_in_progress.clear()
	queue_redraw()


func _draw() -> void:
	for entry: Variant in _strokes:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		_draw_stroke(entry as Dictionary, 1.0)
	for stroke_v: Variant in _live_strokes.values():
		if typeof(stroke_v) != TYPE_DICTIONARY:
			continue
		_draw_stroke(stroke_v as Dictionary, LIVE_STROKE_ALPHA)
	if not _local_in_progress.is_empty():
		_draw_stroke(_local_in_progress, 1.0)
	for stroke_id: String in _selected_ids:
		var snap: Dictionary = AnnotationStroke.find_stroke(_strokes, stroke_id)
		if snap.is_empty():
			continue
		_draw_selection_outline(snap)


func _draw_stroke(stroke: Dictionary, alpha_scale: float) -> void:
	var raw_points: PackedVector2Array = AnnotationStroke.points_as_packed(stroke)
	if raw_points.is_empty():
		return
	var color: Color = AnnotationStroke.color_of(stroke)
	color.a *= alpha_scale
	var width: float = max(AnnotationStroke.width_of(stroke), MIN_DRAW_WIDTH)
	if raw_points.size() == 1:
		draw_circle(raw_points[0], width * 0.5, color)
		return
	var points: PackedVector2Array = AnnotationStroke.smooth_chaikin(raw_points, SMOOTHING_ITERATIONS)
	draw_polyline(points, color, width, true)
	draw_circle(points[0], width * 0.5, color)
	draw_circle(points[points.size() - 1], width * 0.5, color)


func _draw_selection_outline(stroke: Dictionary) -> void:
	var raw_points: PackedVector2Array = AnnotationStroke.points_as_packed(stroke)
	if raw_points.is_empty():
		return
	var width: float = max(AnnotationStroke.width_of(stroke), MIN_DRAW_WIDTH) + SELECTION_OUTLINE_EXTRA_WIDTH
	if raw_points.size() == 1:
		draw_arc(raw_points[0], width * 0.5, 0.0, TAU, 32, SELECTION_OUTLINE_COLOR, 1.5, true)
		return
	var points: PackedVector2Array = AnnotationStroke.smooth_chaikin(raw_points, SMOOTHING_ITERATIONS)
	draw_polyline(points, SELECTION_OUTLINE_COLOR, 1.5, true)
	for p: Vector2 in [points[0], points[points.size() - 1]]:
		draw_arc(p, width * 0.5, 0.0, TAU, 24, SELECTION_OUTLINE_COLOR, 1.5, true)
