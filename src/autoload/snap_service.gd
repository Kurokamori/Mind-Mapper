extends Node

signal changed()

var enabled: bool = false
var grid_size: int = 16


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	emit_signal("changed")


func set_grid_size(value: int) -> void:
	value = max(1, value)
	if grid_size == value:
		return
	grid_size = value
	emit_signal("changed")


func maybe_snap(p: Vector2) -> Vector2:
	if not enabled:
		return p
	return Vector2(
		round(p.x / grid_size) * grid_size,
		round(p.y / grid_size) * grid_size,
	)
