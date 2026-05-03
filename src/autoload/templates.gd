extends Node

const TEMPLATES_PATH: String = "user://templates.json"

signal templates_changed()

var _templates: Dictionary = {}
var _loaded: bool = false


func _ready() -> void:
	_load()


func names() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var keys: Array = _templates.keys()
	keys.sort()
	for k in keys:
		out.append(String(k))
	return out


func get_template(name: String) -> Dictionary:
	var raw: Variant = _templates.get(name, null)
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return (raw as Dictionary).duplicate(true)


func save_from_dicts(name: String, item_dicts: Array, connection_dicts: Array) -> void:
	if name.strip_edges() == "":
		return
	var min_p: Vector2 = Vector2(INF, INF)
	for d in item_dicts:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var pos_raw: Variant = (d as Dictionary).get("position", [0, 0])
		if typeof(pos_raw) == TYPE_ARRAY and (pos_raw as Array).size() >= 2:
			min_p.x = min(min_p.x, float(pos_raw[0]))
			min_p.y = min(min_p.y, float(pos_raw[1]))
	if min_p.x == INF:
		min_p = Vector2.ZERO
	var normalized_items: Array = []
	for d in item_dicts:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = (d as Dictionary).duplicate(true)
		var pos_raw: Variant = copy.get("position", [0, 0])
		if typeof(pos_raw) == TYPE_ARRAY and (pos_raw as Array).size() >= 2:
			copy["position"] = [float(pos_raw[0]) - min_p.x, float(pos_raw[1]) - min_p.y]
		copy.erase("id")
		normalized_items.append(copy)
	_templates[name] = {
		"items": normalized_items,
		"connections": connection_dicts.duplicate(true),
		"created_unix": Time.get_unix_time_from_system(),
	}
	_save()
	emit_signal("templates_changed")


func delete(name: String) -> void:
	if _templates.erase(name):
		_save()
		emit_signal("templates_changed")


func instantiate_at(name: String, world_position: Vector2) -> Dictionary:
	var raw: Variant = _templates.get(name, null)
	if typeof(raw) != TYPE_DICTIONARY:
		return {"items": [], "connections": []}
	var src_items: Array = (raw as Dictionary).get("items", [])
	var src_conns: Array = (raw as Dictionary).get("connections", [])
	var id_remap: Dictionary = {}
	var new_items: Array = []
	for d in src_items:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = (d as Dictionary).duplicate(true)
		var pos_raw: Variant = copy.get("position", [0, 0])
		if typeof(pos_raw) == TYPE_ARRAY and (pos_raw as Array).size() >= 2:
			copy["position"] = [float(pos_raw[0]) + world_position.x, float(pos_raw[1]) + world_position.y]
		var new_id: String = Uuid.v4()
		copy["id"] = new_id
		new_items.append(copy)
	var new_conns: Array = []
	for d in src_conns:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = (d as Dictionary).duplicate(true)
		copy["id"] = Uuid.v4()
		var fid: String = String(copy.get("from_item_id", ""))
		var tid: String = String(copy.get("to_item_id", ""))
		if id_remap.has(fid):
			copy["from_item_id"] = id_remap[fid]
		if id_remap.has(tid):
			copy["to_item_id"] = id_remap[tid]
		new_conns.append(copy)
	return {"items": new_items, "connections": new_conns}


func _load() -> void:
	_loaded = true
	if not FileAccess.file_exists(TEMPLATES_PATH):
		return
	var f: FileAccess = FileAccess.open(TEMPLATES_PATH, FileAccess.READ)
	if f == null:
		return
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		_templates = (parsed as Dictionary).duplicate(true)


func _save() -> void:
	if not _loaded:
		return
	var f: FileAccess = FileAccess.open(TEMPLATES_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_templates, "\t"))
	f.close()
