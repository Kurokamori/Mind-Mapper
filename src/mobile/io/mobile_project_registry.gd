class_name MobileProjectRegistry
extends RefCounted

const SOURCE_LOCAL: String = "local"
const SOURCE_SYNCED: String = "synced"
const SOURCE_IMPORTED: String = "imported"
const SOURCE_EXTERNAL: String = "external"

const MAX_ENTRIES: int = 64

const FIELD_ID: String = "id"
const FIELD_NAME: String = "name"
const FIELD_FOLDER: String = "folder"
const FIELD_SOURCE: String = "source"
const FIELD_REMOTE_HOST: String = "remote_host"
const FIELD_REMOTE_NAME: String = "remote_name"
const FIELD_LAST_OPENED_UNIX: String = "last_opened_unix"
const FIELD_LAST_SYNCED_UNIX: String = "last_synced_unix"
const FIELD_PROJECT_ID: String = "project_id"


static func load_entries() -> Array:
	var path: String = MobileStoragePaths.registry_path()
	if not FileAccess.file_exists(path):
		return []
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_ARRAY:
		return []
	var out: Array = []
	for entry_v: Variant in (parsed as Array):
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		out.append(normalize(entry_v as Dictionary))
	return out


static func save_entries(entries: Array) -> Error:
	MobileStoragePaths.ensure_dirs()
	var path: String = MobileStoragePaths.registry_path()
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(entries, "\t"))
	f.close()
	return OK


static func normalize(raw: Dictionary) -> Dictionary:
	var out: Dictionary = raw.duplicate(true)
	if String(out.get(FIELD_ID, "")) == "":
		out[FIELD_ID] = Uuid.v4()
	out[FIELD_NAME] = String(out.get(FIELD_NAME, "Project"))
	out[FIELD_FOLDER] = String(out.get(FIELD_FOLDER, ""))
	out[FIELD_SOURCE] = String(out.get(FIELD_SOURCE, SOURCE_LOCAL))
	out[FIELD_REMOTE_HOST] = String(out.get(FIELD_REMOTE_HOST, ""))
	out[FIELD_REMOTE_NAME] = String(out.get(FIELD_REMOTE_NAME, ""))
	out[FIELD_LAST_OPENED_UNIX] = int(out.get(FIELD_LAST_OPENED_UNIX, 0))
	out[FIELD_LAST_SYNCED_UNIX] = int(out.get(FIELD_LAST_SYNCED_UNIX, 0))
	out[FIELD_PROJECT_ID] = String(out.get(FIELD_PROJECT_ID, ""))
	return out


static func find_index(entries: Array, folder_path: String) -> int:
	for i: int in range(entries.size()):
		var entry: Variant = entries[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if String((entry as Dictionary).get(FIELD_FOLDER, "")) == folder_path:
			return i
	return -1


static func find_index_by_project_id(entries: Array, project_id: String) -> int:
	if project_id == "":
		return -1
	for i: int in range(entries.size()):
		var entry: Variant = entries[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if String((entry as Dictionary).get(FIELD_PROJECT_ID, "")) == project_id:
			return i
	return -1


static func upsert(entries: Array, candidate: Dictionary) -> Array:
	var out: Array = entries.duplicate(true)
	var normalized: Dictionary = normalize(candidate)
	var idx: int = find_index(out, String(normalized[FIELD_FOLDER]))
	if idx >= 0:
		var existing: Dictionary = out[idx]
		for k: Variant in normalized.keys():
			existing[k] = normalized[k]
		out[idx] = existing
		return _bring_to_front(out, idx)
	out.push_front(normalized)
	while out.size() > MAX_ENTRIES:
		out.pop_back()
	return out


static func remove(entries: Array, folder_path: String) -> Array:
	var out: Array = entries.duplicate(true)
	var idx: int = find_index(out, folder_path)
	if idx < 0:
		return out
	out.remove_at(idx)
	return out


static func touch_last_opened(entries: Array, folder_path: String) -> Array:
	var out: Array = entries.duplicate(true)
	var idx: int = find_index(out, folder_path)
	if idx < 0:
		return out
	var entry: Dictionary = out[idx]
	entry[FIELD_LAST_OPENED_UNIX] = int(Time.get_unix_time_from_system())
	out[idx] = entry
	return _bring_to_front(out, idx)


static func touch_last_synced(entries: Array, folder_path: String) -> Array:
	var out: Array = entries.duplicate(true)
	var idx: int = find_index(out, folder_path)
	if idx < 0:
		return out
	var entry: Dictionary = out[idx]
	entry[FIELD_LAST_SYNCED_UNIX] = int(Time.get_unix_time_from_system())
	out[idx] = entry
	return _bring_to_front(out, idx)


static func _bring_to_front(entries: Array, idx: int) -> Array:
	if idx <= 0 or idx >= entries.size():
		return entries
	var pulled: Variant = entries[idx]
	entries.remove_at(idx)
	entries.push_front(pulled)
	return entries
