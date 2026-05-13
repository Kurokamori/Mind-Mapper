extends Node

signal top_reserved_changed(value: float)
signal bottom_reserved_changed(value: float)

const DEFAULT_TOP_RESERVED: float = 140.0
const DEFAULT_BOTTOM_RESERVED: float = 8.0
const MIN_TOP_RESERVED: float = 48.0
const MIN_BOTTOM_RESERVED: float = 0.0

var top_reserved: float = DEFAULT_TOP_RESERVED:
	set = _set_top_reserved
var bottom_reserved: float = DEFAULT_BOTTOM_RESERVED:
	set = _set_bottom_reserved


func _set_top_reserved(value: float) -> void:
	var clamped: float = max(MIN_TOP_RESERVED, value)
	if is_equal_approx(clamped, top_reserved):
		return
	top_reserved = clamped
	emit_signal("top_reserved_changed", top_reserved)


func _set_bottom_reserved(value: float) -> void:
	var clamped: float = max(MIN_BOTTOM_RESERVED, value)
	if is_equal_approx(clamped, bottom_reserved):
		return
	bottom_reserved = clamped
	emit_signal("bottom_reserved_changed", bottom_reserved)


func reset_to_defaults() -> void:
	_set_top_reserved(DEFAULT_TOP_RESERVED)
	_set_bottom_reserved(DEFAULT_BOTTOM_RESERVED)
