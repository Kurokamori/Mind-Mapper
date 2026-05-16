class_name MobileAnnotationPainter
extends Node2D

const MIN_DRAW_WIDTH: float = 0.5
const SMOOTHING_ITERATIONS: int = 2

var _strokes: Array = []
var _in_progress: Dictionary = {}


func set_strokes(strokes: Array) -> void:
	_strokes.clear()
	for entry: Variant in strokes:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		_strokes.append(AnnotationStroke.normalize((entry as Dictionary).duplicate(true)))
	queue_redraw()


func set_in_progress(stroke: Dictionary) -> void:
	_in_progress = stroke.duplicate(true) if not stroke.is_empty() else {}
	queue_redraw()


func _draw() -> void:
	for entry: Dictionary in _strokes:
		_draw_stroke(entry)
	if not _in_progress.is_empty():
		_draw_stroke(_in_progress)


func _draw_stroke(stroke: Dictionary) -> void:
	var color: Color = AnnotationStroke.color_of(stroke)
	var width: float = max(MIN_DRAW_WIDTH, AnnotationStroke.width_of(stroke))
	var packed: PackedVector2Array = AnnotationStroke.points_as_packed(stroke)
	if packed.is_empty():
		return
	if packed.size() == 1:
		draw_circle(packed[0], width * 0.5, color)
		return
	var smoothed: PackedVector2Array = AnnotationStroke.smooth_chaikin(packed, SMOOTHING_ITERATIONS)
	draw_polyline(smoothed, color, width, true)
