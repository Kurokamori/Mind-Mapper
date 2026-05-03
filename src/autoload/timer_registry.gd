extends Node

signal timers_changed()

var _entries: Dictionary = {}


func register(timer_item_id: String, board_id: String, label: String, seconds_remaining: float, running: bool) -> void:
	if timer_item_id == "":
		return
	_entries[timer_item_id] = {
		"item_id": timer_item_id,
		"board_id": board_id,
		"label": label,
		"seconds_remaining": seconds_remaining,
		"running": running,
		"updated_unix": Time.get_unix_time_from_system(),
	}
	emit_signal("timers_changed")


func unregister(timer_item_id: String) -> void:
	if _entries.erase(timer_item_id):
		emit_signal("timers_changed")


func clear_all() -> void:
	_entries.clear()
	emit_signal("timers_changed")


func entries() -> Array:
	var out: Array = []
	for v in _entries.values():
		out.append((v as Dictionary).duplicate())
	out.sort_custom(func(a, b) -> bool:
		var ar: bool = bool(a.get("running", false))
		var br: bool = bool(b.get("running", false))
		if ar != br:
			return ar
		return float(a.get("seconds_remaining", 0)) < float(b.get("seconds_remaining", 0))
	)
	return out


func active_count() -> int:
	var n: int = 0
	for v in _entries.values():
		if bool((v as Dictionary).get("running", false)):
			n += 1
	return n
