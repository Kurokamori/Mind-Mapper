class_name CommentData
extends RefCounted

const DEFAULT_COLOR_AUTHOR_FALLBACK: Color = Color(0.95, 0.78, 0.30, 1.0)
const RESOLVED_DIM_FACTOR: float = 0.32

const FIELD_ID: String = "id"
const FIELD_TARGET_ITEM_ID: String = "target_item_id"
const FIELD_TARGET_CARD_ID: String = "target_card_id"
const FIELD_TITLE: String = "title"
const FIELD_BODY_BBCODE: String = "body_bbcode"
const FIELD_COLOR: String = "color"
const FIELD_RESOLVED: String = "resolved"
const FIELD_AUTHOR_STABLE_ID: String = "author_stable_id"
const FIELD_AUTHOR_DISPLAY_NAME: String = "author_display_name"
const FIELD_CREATED_UNIX: String = "created_unix"
const FIELD_LAST_EDITED_UNIX: String = "last_edited_unix"

const SETTABLE_KEYS: Array[String] = [
	FIELD_TITLE,
	FIELD_BODY_BBCODE,
	FIELD_COLOR,
	FIELD_RESOLVED,
	FIELD_TARGET_CARD_ID,
]


static func default_color_for_author(stable_id: String) -> Color:
	if stable_id == "":
		return DEFAULT_COLOR_AUTHOR_FALLBACK
	var hash_value: int = abs(stable_id.hash())
	var hue: float = float(hash_value % 360) / 360.0
	return Color.from_hsv(hue, 0.55, 0.92, 1.0)


static func make_default(target_item_id: String, target_card_id: String, author_stable_id: String, author_display_name: String) -> Dictionary:
	var color: Color = default_color_for_author(author_stable_id)
	return {
		FIELD_ID: Uuid.v4(),
		FIELD_TARGET_ITEM_ID: target_item_id,
		FIELD_TARGET_CARD_ID: target_card_id,
		FIELD_TITLE: "",
		FIELD_BODY_BBCODE: "",
		FIELD_COLOR: [color.r, color.g, color.b, color.a],
		FIELD_RESOLVED: false,
		FIELD_AUTHOR_STABLE_ID: author_stable_id,
		FIELD_AUTHOR_DISPLAY_NAME: author_display_name,
		FIELD_CREATED_UNIX: int(Time.get_unix_time_from_system()),
		FIELD_LAST_EDITED_UNIX: int(Time.get_unix_time_from_system()),
	}


static func normalize(raw: Dictionary) -> Dictionary:
	var out: Dictionary = raw.duplicate(true)
	if String(out.get(FIELD_ID, "")) == "":
		out[FIELD_ID] = Uuid.v4()
	if not out.has(FIELD_TARGET_ITEM_ID):
		out[FIELD_TARGET_ITEM_ID] = ""
	if not out.has(FIELD_TARGET_CARD_ID):
		out[FIELD_TARGET_CARD_ID] = ""
	if not out.has(FIELD_TITLE):
		out[FIELD_TITLE] = ""
	if not out.has(FIELD_BODY_BBCODE):
		out[FIELD_BODY_BBCODE] = ""
	if not out.has(FIELD_RESOLVED):
		out[FIELD_RESOLVED] = false
	if not out.has(FIELD_AUTHOR_STABLE_ID):
		out[FIELD_AUTHOR_STABLE_ID] = ""
	if not out.has(FIELD_AUTHOR_DISPLAY_NAME):
		out[FIELD_AUTHOR_DISPLAY_NAME] = ""
	if not out.has(FIELD_CREATED_UNIX):
		out[FIELD_CREATED_UNIX] = int(Time.get_unix_time_from_system())
	if not out.has(FIELD_LAST_EDITED_UNIX):
		out[FIELD_LAST_EDITED_UNIX] = int(out[FIELD_CREATED_UNIX])
	var color_value: Variant = out.get(FIELD_COLOR, null)
	if typeof(color_value) != TYPE_ARRAY or (color_value as Array).size() < 3:
		var fallback: Color = default_color_for_author(String(out[FIELD_AUTHOR_STABLE_ID]))
		out[FIELD_COLOR] = [fallback.r, fallback.g, fallback.b, fallback.a]
	return out


static func color_of(comment: Dictionary) -> Color:
	var raw: Variant = comment.get(FIELD_COLOR, null)
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 3:
		var arr: Array = raw
		var a: float = 1.0 if arr.size() < 4 else float(arr[3])
		return Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
	return default_color_for_author(String(comment.get(FIELD_AUTHOR_STABLE_ID, "")))


static func is_resolved(comment: Dictionary) -> bool:
	return bool(comment.get(FIELD_RESOLVED, false))


static func target_item_id(comment: Dictionary) -> String:
	return String(comment.get(FIELD_TARGET_ITEM_ID, ""))


static func target_card_id(comment: Dictionary) -> String:
	return String(comment.get(FIELD_TARGET_CARD_ID, ""))


static func find_index(comments: Array, comment_id: String) -> int:
	for i in range(comments.size()):
		var entry: Variant = comments[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if String((entry as Dictionary).get(FIELD_ID, "")) == comment_id:
			return i
	return -1


static func find_comment(comments: Array, comment_id: String) -> Dictionary:
	var idx: int = find_index(comments, comment_id)
	if idx < 0:
		return {}
	var entry: Variant = comments[idx]
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	return (entry as Dictionary).duplicate(true)


static func filter_for_item(comments: Array, item_id: String) -> Array:
	var out: Array = []
	for entry: Variant in comments:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if target_item_id(entry as Dictionary) == item_id:
			out.append((entry as Dictionary).duplicate(true))
	return out


static func filter_for_card(comments: Array, item_id: String, card_id: String) -> Array:
	var out: Array = []
	for entry: Variant in comments:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry
		if target_item_id(d) != item_id:
			continue
		if target_card_id(d) != card_id:
			continue
		out.append(d.duplicate(true))
	return out


static func serialize_color_value(color: Color) -> Array:
	return [color.r, color.g, color.b, color.a]


static func deserialize_color_value(raw: Variant) -> Color:
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 3:
		var arr: Array = raw
		var a: float = 1.0 if arr.size() < 4 else float(arr[3])
		return Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
	return DEFAULT_COLOR_AUTHOR_FALLBACK


static func is_settable_key(key: String) -> bool:
	return SETTABLE_KEYS.has(key)
