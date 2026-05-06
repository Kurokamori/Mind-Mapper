class_name VectorClock
extends RefCounted

var _entries: Dictionary = {}


func get_value(stable_id: String) -> int:
	return int(_entries.get(stable_id, 0))


func set_value(stable_id: String, value: int) -> void:
	if stable_id == "":
		return
	if value <= 0:
		_entries.erase(stable_id)
	else:
		_entries[stable_id] = value


func increment(stable_id: String) -> int:
	if stable_id == "":
		return 0
	var current: int = int(_entries.get(stable_id, 0))
	current += 1
	_entries[stable_id] = current
	return current


func observe(stable_id: String, value: int) -> void:
	if stable_id == "":
		return
	var current: int = int(_entries.get(stable_id, 0))
	if value > current:
		_entries[stable_id] = value


func merge(other: VectorClock) -> void:
	if other == null:
		return
	for stable_id: String in other._entries.keys():
		var v: int = int(other._entries[stable_id])
		observe(stable_id, v)


func difference_to_send(remote: VectorClock) -> Dictionary:
	var out: Dictionary = {}
	for stable_id: String in _entries.keys():
		var local_v: int = int(_entries[stable_id])
		var remote_v: int = remote.get_value(stable_id) if remote != null else 0
		if local_v > remote_v:
			out[stable_id] = {"from": remote_v + 1, "to": local_v}
	return out


func is_strictly_after(other: VectorClock) -> bool:
	var saw_strictly_greater: bool = false
	for stable_id: String in _entries.keys():
		var l: int = int(_entries[stable_id])
		var r: int = other.get_value(stable_id) if other != null else 0
		if l < r:
			return false
		if l > r:
			saw_strictly_greater = true
	if other != null:
		for stable_id: String in other._entries.keys():
			if not _entries.has(stable_id) and int(other._entries[stable_id]) > 0:
				return false
	return saw_strictly_greater


func entries() -> Dictionary:
	return _entries.duplicate()


func to_dict() -> Dictionary:
	return _entries.duplicate()


static func from_dict(d: Variant) -> VectorClock:
	var vc: VectorClock = VectorClock.new()
	if typeof(d) != TYPE_DICTIONARY:
		return vc
	for k: Variant in (d as Dictionary).keys():
		vc._entries[String(k)] = int((d as Dictionary)[k])
	return vc


func clone() -> VectorClock:
	var c: VectorClock = VectorClock.new()
	c._entries = _entries.duplicate()
	return c
