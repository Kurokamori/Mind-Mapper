extends Node

signal timers_changed()

const SECONDS_PER_MINUTE: int = 60
const SECONDS_PER_HOUR: int = 3600
const SECONDS_PER_DAY: int = 86400
const SECONDS_PER_WEEK: int = 604800
const SECONDS_PER_YEAR: int = 31556952

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


func format_duration(seconds: float, compact: bool = false) -> String:
	var safe_seconds: float = seconds
	if safe_seconds < 0.0 or is_nan(safe_seconds):
		safe_seconds = 0.0
	var total: int = int(ceil(safe_seconds))
	@warning_ignore("integer_division")
	var years: int = total / SECONDS_PER_YEAR
	var rem: int = total % SECONDS_PER_YEAR
	@warning_ignore("integer_division")
	var weeks: int = rem / SECONDS_PER_WEEK
	rem = rem % SECONDS_PER_WEEK
	@warning_ignore("integer_division")
	var days: int = rem / SECONDS_PER_DAY
	rem = rem % SECONDS_PER_DAY
	@warning_ignore("integer_division")
	var hours: int = rem / SECONDS_PER_HOUR
	rem = rem % SECONDS_PER_HOUR
	@warning_ignore("integer_division")
	var minutes: int = rem / SECONDS_PER_MINUTE
	var secs: int = rem % SECONDS_PER_MINUTE
	var has_big: bool = years > 0 or weeks > 0 or days > 0
	var big_parts: Array[String] = []
	if years > 0:
		big_parts.append("%dy" % years)
	if weeks > 0:
		big_parts.append("%dw" % weeks)
	if days > 0:
		big_parts.append("%dd" % days)
	var clock: String
	if has_big or hours > 0:
		clock = "%d:%02d:%02d" % [hours, minutes, secs]
	else:
		clock = "%d:%02d" % [minutes, secs]
	if compact and has_big:
		return " ".join(big_parts)
	if big_parts.is_empty():
		return clock
	return "%s %s" % [" ".join(big_parts), clock]
