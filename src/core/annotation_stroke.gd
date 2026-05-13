class_name AnnotationStroke
extends RefCounted

const FIELD_ID: String = "id"
const FIELD_AUTHOR_STABLE_ID: String = "author_stable_id"
const FIELD_AUTHOR_DISPLAY_NAME: String = "author_display_name"
const FIELD_COLOR: String = "color"
const FIELD_WIDTH: String = "width"
const FIELD_POINTS: String = "points"
const FIELD_CREATED_UNIX: String = "created_unix"

const DEFAULT_COLOR: Color = Color(0.95, 0.32, 0.32, 1.0)
const DEFAULT_WIDTH: float = 4.0
const MIN_WIDTH: float = 0.5
const MAX_WIDTH: float = 64.0


static func make_default(author_stable_id: String, author_display_name: String, color: Color, width: float) -> Dictionary:
	return {
		FIELD_ID: Uuid.v4(),
		FIELD_AUTHOR_STABLE_ID: author_stable_id,
		FIELD_AUTHOR_DISPLAY_NAME: author_display_name,
		FIELD_COLOR: serialize_color(color),
		FIELD_WIDTH: clamp_width(width),
		FIELD_POINTS: [],
		FIELD_CREATED_UNIX: int(Time.get_unix_time_from_system()),
	}


static func normalize(raw: Dictionary) -> Dictionary:
	var out: Dictionary = raw.duplicate(true)
	if String(out.get(FIELD_ID, "")) == "":
		out[FIELD_ID] = Uuid.v4()
	if not out.has(FIELD_AUTHOR_STABLE_ID):
		out[FIELD_AUTHOR_STABLE_ID] = ""
	if not out.has(FIELD_AUTHOR_DISPLAY_NAME):
		out[FIELD_AUTHOR_DISPLAY_NAME] = ""
	var color_raw: Variant = out.get(FIELD_COLOR, null)
	if typeof(color_raw) != TYPE_ARRAY or (color_raw as Array).size() < 3:
		out[FIELD_COLOR] = serialize_color(DEFAULT_COLOR)
	out[FIELD_WIDTH] = clamp_width(float(out.get(FIELD_WIDTH, DEFAULT_WIDTH)))
	var points_raw: Variant = out.get(FIELD_POINTS, null)
	var clean_points: Array = []
	if typeof(points_raw) == TYPE_ARRAY:
		for entry: Variant in (points_raw as Array):
			if typeof(entry) != TYPE_ARRAY or (entry as Array).size() < 2:
				continue
			clean_points.append([float((entry as Array)[0]), float((entry as Array)[1])])
	out[FIELD_POINTS] = clean_points
	if not out.has(FIELD_CREATED_UNIX):
		out[FIELD_CREATED_UNIX] = int(Time.get_unix_time_from_system())
	return out


static func serialize_color(color: Color) -> Array:
	return [color.r, color.g, color.b, color.a]


static func deserialize_color(raw: Variant) -> Color:
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 3:
		var arr: Array = raw
		var a: float = 1.0 if arr.size() < 4 else float(arr[3])
		return Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
	return DEFAULT_COLOR


static func color_of(stroke: Dictionary) -> Color:
	return deserialize_color(stroke.get(FIELD_COLOR, null))


static func width_of(stroke: Dictionary) -> float:
	return clamp_width(float(stroke.get(FIELD_WIDTH, DEFAULT_WIDTH)))


static func clamp_width(width: float) -> float:
	return clamp(width, MIN_WIDTH, MAX_WIDTH)


static func id_of(stroke: Dictionary) -> String:
	return String(stroke.get(FIELD_ID, ""))


static func points_as_packed(stroke: Dictionary) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var raw: Variant = stroke.get(FIELD_POINTS, null)
	if typeof(raw) != TYPE_ARRAY:
		return out
	for entry: Variant in (raw as Array):
		if typeof(entry) != TYPE_ARRAY or (entry as Array).size() < 2:
			continue
		out.append(Vector2(float((entry as Array)[0]), float((entry as Array)[1])))
	return out


static func points_from_packed(points: PackedVector2Array) -> Array:
	var out: Array = []
	for p: Vector2 in points:
		out.append([p.x, p.y])
	return out


static func find_index(strokes: Array, stroke_id: String) -> int:
	for i: int in range(strokes.size()):
		var entry: Variant = strokes[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if String((entry as Dictionary).get(FIELD_ID, "")) == stroke_id:
			return i
	return -1


static func find_stroke(strokes: Array, stroke_id: String) -> Dictionary:
	var idx: int = find_index(strokes, stroke_id)
	if idx < 0:
		return {}
	var entry: Variant = strokes[idx]
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	return (entry as Dictionary).duplicate(true)


static func hit_test(strokes: Array, world_pos: Vector2, tolerance: float) -> String:
	var best_id: String = ""
	var best_dist: float = INF
	for entry: Variant in strokes:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stroke: Dictionary = entry
		var d: float = distance_to_stroke(stroke, world_pos)
		var effective_tol: float = tolerance + width_of(stroke) * 0.5
		if d <= effective_tol and d < best_dist:
			best_dist = d
			best_id = id_of(stroke)
	return best_id


static func strokes_intersecting_circle(strokes: Array, center: Vector2, radius: float) -> Array:
	var out: Array = []
	for entry: Variant in strokes:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stroke: Dictionary = entry
		var effective: float = radius + width_of(stroke) * 0.5
		if distance_to_stroke(stroke, center) <= effective:
			out.append(id_of(stroke))
	return out


static func strokes_in_rect(strokes: Array, rect: Rect2) -> Array:
	var out: Array = []
	for entry: Variant in strokes:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stroke: Dictionary = entry
		var packed: PackedVector2Array = points_as_packed(stroke)
		for p: Vector2 in packed:
			if rect.has_point(p):
				out.append(id_of(stroke))
				break
	return out


static func distance_to_stroke(stroke: Dictionary, world_pos: Vector2) -> float:
	var packed: PackedVector2Array = points_as_packed(stroke)
	if packed.is_empty():
		return INF
	if packed.size() == 1:
		return packed[0].distance_to(world_pos)
	var best: float = INF
	for i: int in range(packed.size() - 1):
		var d: float = distance_point_to_segment(world_pos, packed[i], packed[i + 1])
		if d < best:
			best = d
	return best


static func smooth_chaikin(points: PackedVector2Array, iterations: int) -> PackedVector2Array:
	if points.size() < 3 or iterations <= 0:
		return points
	var current: PackedVector2Array = points
	for _i: int in range(iterations):
		var next: PackedVector2Array = PackedVector2Array()
		next.append(current[0])
		for j: int in range(current.size() - 1):
			var p0: Vector2 = current[j]
			var p1: Vector2 = current[j + 1]
			next.append(p0 * 0.75 + p1 * 0.25)
			next.append(p0 * 0.25 + p1 * 0.75)
		next.append(current[current.size() - 1])
		current = next
	return current


static func distance_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq <= 0.000001:
		return p.distance_to(a)
	var t: float = clamp((p - a).dot(ab) / len_sq, 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return p.distance_to(proj)
