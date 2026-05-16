class_name MobileCommentMarkerLayer
extends Node2D

const BADGE_RADIUS: float = 11.0
const BADGE_OFFSET: Vector2 = Vector2(-6.0, -6.0)
const BADGE_FG: Color = Color(0.06, 0.07, 0.10, 1.0)

var _comments: Array = []
var _item_lookup: Callable = Callable()


func bind_items_lookup(lookup: Callable) -> void:
	_item_lookup = lookup


func set_comments(comments: Array) -> void:
	_comments.clear()
	for entry: Variant in comments:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		_comments.append(CommentData.normalize((entry as Dictionary).duplicate(true)))
	queue_redraw()


func _draw() -> void:
	if not _item_lookup.is_valid():
		return
	var counts: Dictionary = {}
	var colors: Dictionary = {}
	for c: Dictionary in _comments:
		var target: String = CommentData.target_item_id(c)
		if target == "":
			continue
		counts[target] = int(counts.get(target, 0)) + 1
		if not colors.has(target):
			colors[target] = CommentData.color_of(c)
	for item_id: String in counts.keys():
		var item_dict: Dictionary = _item_lookup.call(item_id)
		if item_dict.is_empty():
			continue
		var pos: Vector2 = _position_of(item_dict)
		var center: Vector2 = pos + BADGE_OFFSET
		var color: Color = colors.get(item_id, Color(0.95, 0.78, 0.30, 1.0))
		draw_circle(center, BADGE_RADIUS, color)
		var count: int = int(counts[item_id])
		var text: String = "%d" % count if count < 10 else "9+"
		var font: Font = ThemeDB.fallback_font
		if font == null:
			continue
		var size_pt: int = 12
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_pt)
		var baseline: Vector2 = center + Vector2(-text_size.x * 0.5, font.get_ascent(size_pt) * 0.5 - 1.0)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_pt, BADGE_FG)


func _position_of(item: Dictionary) -> Vector2:
	var raw: Variant = item.get("position", [0, 0])
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO
