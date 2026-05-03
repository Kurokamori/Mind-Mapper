class_name ColorUtil
extends RefCounted


static func from_array(raw: Variant, fallback: Color) -> Color:
	if typeof(raw) == TYPE_COLOR:
		return raw
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 3:
		var arr: Array = raw
		var a: float = 1.0 if arr.size() < 4 else float(arr[3])
		return Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
	return fallback


static func to_array(c: Color) -> Array:
	return [c.r, c.g, c.b, c.a]
