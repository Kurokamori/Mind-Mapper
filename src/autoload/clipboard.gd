extends Node

signal changed()

var _payload: Array = []


func _exit_tree() -> void:
	_payload.clear()


func is_empty() -> bool:
	return _payload.is_empty()


func clear() -> void:
	_payload.clear()
	emit_signal("changed")


func set_items(item_dicts: Array) -> void:
	_payload = item_dicts.duplicate(true)
	emit_signal("changed")


func get_items_for_paste() -> Array:
	var out: Array = []
	for d in _payload:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = (d as Dictionary).duplicate(true)
		copy["id"] = Uuid.v4()
		out.append(copy)
	return out
