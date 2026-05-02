extends Node

const RECENT_PATH := "user://recent_projects.json"
const MAX_RECENT := 24

signal recent_changed()

var _recent: Array = []


func _ready() -> void:
	_load_recent()


func recent() -> Array:
	return _recent.duplicate(true)


func create_project(parent_folder: String, project_name: String) -> Project:
	var safe_name := _sanitize_folder_name(project_name)
	if safe_name == "":
		safe_name = "Untitled"
	var folder := parent_folder.path_join(safe_name)
	folder = _ensure_unique_folder(folder)
	var project := Project.create_new(folder, project_name)
	if project != null:
		_register_recent(project)
	return project


func open_project(folder_path: String) -> Project:
	var project := Project.load_from_folder(folder_path)
	if project != null:
		_register_recent(project)
	return project


func forget(folder_path: String) -> void:
	for i in range(_recent.size() - 1, -1, -1):
		if String(_recent[i].get("folder_path", "")) == folder_path:
			_recent.remove_at(i)
	_save_recent()
	emit_signal("recent_changed")


func _register_recent(project: Project) -> void:
	for i in range(_recent.size() - 1, -1, -1):
		if String(_recent[i].get("folder_path", "")) == project.folder_path:
			_recent.remove_at(i)
	_recent.insert(0, {
		"id": project.id,
		"name": project.name,
		"folder_path": project.folder_path,
		"modified_unix": project.modified_unix,
	})
	while _recent.size() > MAX_RECENT:
		_recent.pop_back()
	_save_recent()
	emit_signal("recent_changed")


func _load_recent() -> void:
	if not FileAccess.file_exists(RECENT_PATH):
		_recent = []
		return
	var f := FileAccess.open(RECENT_PATH, FileAccess.READ)
	if f == null:
		_recent = []
		return
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_ARRAY:
		_recent = parsed
	else:
		_recent = []


func _save_recent() -> void:
	var f := FileAccess.open(RECENT_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_recent, "\t"))
	f.close()


func _sanitize_folder_name(s: String) -> String:
	var bad := ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]
	var out := s.strip_edges()
	for b in bad:
		out = out.replace(b, "_")
	return out


func _ensure_unique_folder(folder: String) -> String:
	if not DirAccess.dir_exists_absolute(folder):
		return folder
	var n := 2
	while DirAccess.dir_exists_absolute("%s (%d)" % [folder, n]):
		n += 1
	return "%s (%d)" % [folder, n]
