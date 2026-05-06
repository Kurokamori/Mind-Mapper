class_name PresenceState
extends RefCounted

const HEARTBEAT_TIMEOUT_MS: int = 8000
const CURSOR_UPDATE_HZ: float = 20.0

var stable_id: String = ""
var network_id: int = 0
var display_name: String = ""
var avatar_color: Color = Color(0.55, 0.78, 1.0, 1.0)
var role: String = ""
var hosting: bool = false
var board_id: String = ""
var cursor_world: Vector2 = Vector2.ZERO
var has_cursor: bool = false
var selection_world_rect: Rect2 = Rect2()
var has_selection_rect: bool = false
var viewport_world_rect: Rect2 = Rect2()
var has_viewport_rect: bool = false
var last_heartbeat_ms: int = 0
var editing_lock_item_ids: PackedStringArray = PackedStringArray()


func to_dict() -> Dictionary:
	return {
		"stable_id": stable_id,
		"network_id": network_id,
		"display_name": display_name,
		"avatar_color": [avatar_color.r, avatar_color.g, avatar_color.b, avatar_color.a],
		"role": role,
		"hosting": hosting,
		"board_id": board_id,
		"cursor_world": [cursor_world.x, cursor_world.y] if has_cursor else null,
		"selection_world_rect": _rect_to_array(selection_world_rect) if has_selection_rect else null,
		"viewport_world_rect": _rect_to_array(viewport_world_rect) if has_viewport_rect else null,
		"editing_lock_item_ids": _packed_to_array(editing_lock_item_ids),
	}


func merge_from_dict(d: Dictionary) -> void:
	if d.has("display_name"):
		display_name = String(d.get("display_name", display_name))
	if d.has("avatar_color"):
		var c_raw: Variant = d.get("avatar_color", null)
		if typeof(c_raw) == TYPE_ARRAY and (c_raw as Array).size() >= 3:
			var arr: Array = c_raw
			var a: float = 1.0 if arr.size() < 4 else float(arr[3])
			avatar_color = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
	if d.has("role"):
		role = String(d.get("role", role))
	if d.has("hosting"):
		hosting = bool(d.get("hosting", hosting))
	if d.has("board_id"):
		board_id = String(d.get("board_id", board_id))
	if d.has("cursor_world"):
		var cw_raw: Variant = d.get("cursor_world", null)
		if typeof(cw_raw) == TYPE_ARRAY and (cw_raw as Array).size() >= 2:
			cursor_world = Vector2(float(cw_raw[0]), float(cw_raw[1]))
			has_cursor = true
		else:
			has_cursor = false
	if d.has("selection_world_rect"):
		var sr_raw: Variant = d.get("selection_world_rect", null)
		if typeof(sr_raw) == TYPE_ARRAY and (sr_raw as Array).size() >= 4:
			selection_world_rect = Rect2(float(sr_raw[0]), float(sr_raw[1]), float(sr_raw[2]), float(sr_raw[3]))
			has_selection_rect = true
		else:
			has_selection_rect = false
	if d.has("viewport_world_rect"):
		var vr_raw: Variant = d.get("viewport_world_rect", null)
		if typeof(vr_raw) == TYPE_ARRAY and (vr_raw as Array).size() >= 4:
			viewport_world_rect = Rect2(float(vr_raw[0]), float(vr_raw[1]), float(vr_raw[2]), float(vr_raw[3]))
			has_viewport_rect = true
		else:
			has_viewport_rect = false
	if d.has("editing_lock_item_ids"):
		var locks_raw: Variant = d.get("editing_lock_item_ids", [])
		editing_lock_item_ids = PackedStringArray()
		if typeof(locks_raw) == TYPE_ARRAY:
			for v: Variant in (locks_raw as Array):
				editing_lock_item_ids.append(String(v))
	last_heartbeat_ms = Time.get_ticks_msec()


func is_stale() -> bool:
	if last_heartbeat_ms == 0:
		return false
	return Time.get_ticks_msec() - last_heartbeat_ms > HEARTBEAT_TIMEOUT_MS


func _rect_to_array(r: Rect2) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]


func _packed_to_array(p: PackedStringArray) -> Array:
	var out: Array = []
	for s: String in p:
		out.append(s)
	return out
