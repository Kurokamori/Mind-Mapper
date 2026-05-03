extends Node

const PREFS_PATH: String = "user://ui_prefs.json"
const FORMAT_VERSION: int = 1

signal changed()

var outliner_visible: bool = true
var minimap_visible: bool = true
var _outliner_collapsed_by_project: Dictionary = {}


func _ready() -> void:
	_load()


func is_board_collapsed(project_id: String, board_id: String) -> bool:
	if project_id == "" or board_id == "":
		return false
	var entry: Variant = _outliner_collapsed_by_project.get(project_id, null)
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	return bool((entry as Dictionary).get(board_id, false))


func set_board_collapsed(project_id: String, board_id: String, collapsed: bool) -> void:
	if project_id == "" or board_id == "":
		return
	var entry: Dictionary = _outliner_collapsed_by_project.get(project_id, {})
	if collapsed:
		entry[board_id] = true
	else:
		entry.erase(board_id)
	if entry.is_empty():
		_outliner_collapsed_by_project.erase(project_id)
	else:
		_outliner_collapsed_by_project[project_id] = entry
	_save()


func set_outliner_visible(value: bool) -> void:
	if outliner_visible == value:
		return
	outliner_visible = value
	_save()
	emit_signal("changed")


func set_minimap_visible(value: bool) -> void:
	if minimap_visible == value:
		return
	minimap_visible = value
	_save()
	emit_signal("changed")


func _load() -> void:
	if not FileAccess.file_exists(PREFS_PATH):
		return
	var f: FileAccess = FileAccess.open(PREFS_PATH, FileAccess.READ)
	if f == null:
		return
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	outliner_visible = bool(data.get("outliner_visible", outliner_visible))
	minimap_visible = bool(data.get("minimap_visible", minimap_visible))
	var collapsed_raw: Variant = data.get("outliner_collapsed_by_project", {})
	if typeof(collapsed_raw) == TYPE_DICTIONARY:
		_outliner_collapsed_by_project.clear()
		for project_id_v: Variant in (collapsed_raw as Dictionary).keys():
			var project_id: String = String(project_id_v)
			var inner_raw: Variant = (collapsed_raw as Dictionary)[project_id_v]
			if typeof(inner_raw) != TYPE_DICTIONARY:
				continue
			var inner_clean: Dictionary = {}
			for board_id_v: Variant in (inner_raw as Dictionary).keys():
				if bool((inner_raw as Dictionary)[board_id_v]):
					inner_clean[String(board_id_v)] = true
			if not inner_clean.is_empty():
				_outliner_collapsed_by_project[project_id] = inner_clean


func _save() -> void:
	var data: Dictionary = {
		"format_version": FORMAT_VERSION,
		"outliner_visible": outliner_visible,
		"minimap_visible": minimap_visible,
		"outliner_collapsed_by_project": _outliner_collapsed_by_project,
	}
	var f: FileAccess = FileAccess.open(PREFS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
