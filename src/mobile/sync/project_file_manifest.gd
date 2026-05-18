class_name ProjectFileManifest
extends RefCounted

const FIELD_PATH: String = "path"
const FIELD_SIZE: String = "size"
const FIELD_MTIME: String = "mtime"
const FIELD_HASH: String = "hash"

const PROJECT_FILE_EXTENSIONS_TEXT: Array[String] = ["json"]
const PROJECT_FILE_EXTENSIONS_BINARY: Array[String] = ["png", "jpg", "jpeg", "webp", "bmp", "svg", "ogg", "wav", "mp3", "tres"]


static func build_for_project(project: Project) -> Array:
	var out: Array = []
	if project == null or project.folder_path == "":
		return out
	_walk(project.folder_path, "", out)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get(FIELD_PATH, "")) < String(b.get(FIELD_PATH, ""))
	)
	return out


static func project_summary(project: Project) -> Dictionary:
	if project == null:
		return {}
	return {
		"project_id": project.id,
		"project_name": project.name,
		"root_board_id": project.root_board_id,
		"format_version": Project.FORMAT_VERSION,
		"modified_unix": project.modified_unix,
	}


static func is_safe_relative_path(rel: String) -> bool:
	if rel == "":
		return false
	if rel.begins_with("/") or rel.begins_with("\\"):
		return false
	if rel.contains(".."):
		return false
	if rel.contains(":"):
		return false
	if rel.length() > 1024:
		return false
	return true


static func is_writable_from_client(rel: String) -> bool:
	if not is_safe_relative_path(rel):
		return false
	if rel == Project.MANIFEST_FILENAME:
		return false
	if rel.begins_with(Project.BOARDS_DIR + "/"):
		return rel.ends_with(".json")
	if rel.begins_with(Project.ASSETS_DIR + "/"):
		var ext: String = rel.get_extension().to_lower()
		if ext == "":
			return false
		return PROJECT_FILE_EXTENSIONS_BINARY.has(ext) or PROJECT_FILE_EXTENSIONS_TEXT.has(ext)
	return false


static func _walk(root: String, prefix: String, into: Array) -> void:
	var abs_dir: String = root.path_join(prefix) if prefix != "" else root
	var dir: DirAccess = DirAccess.open(abs_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var relative: String = entry if prefix == "" else prefix.path_join(entry)
		var absolute: String = root.path_join(relative)
		if dir.current_is_dir():
			_walk(root, relative, into)
			entry = dir.get_next()
			continue
		var entry_dict: Dictionary = _build_entry(absolute, relative)
		if not entry_dict.is_empty():
			into.append(entry_dict)
		entry = dir.get_next()
	dir.list_dir_end()


static func _build_entry(absolute: String, relative: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(absolute, FileAccess.READ)
	if f == null:
		return {}
	var size: int = int(f.get_length())
	var bytes: PackedByteArray = f.get_buffer(size)
	f.close()
	var modified: int = int(FileAccess.get_modified_time(absolute))
	return {
		FIELD_PATH: relative.replace("\\", "/"),
		FIELD_SIZE: size,
		FIELD_MTIME: modified,
		FIELD_HASH: LanSyncProtocol.sha256_hex(bytes),
	}


static func read_file_bytes(project_root: String, relative_path: String) -> PackedByteArray:
	if not is_safe_relative_path(relative_path):
		return PackedByteArray()
	var absolute: String = project_root.path_join(relative_path)
	if not FileAccess.file_exists(absolute):
		return PackedByteArray()
	var f: FileAccess = FileAccess.open(absolute, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var size: int = int(f.get_length())
	var bytes: PackedByteArray = f.get_buffer(size)
	f.close()
	return bytes


static func write_file_bytes(project_root: String, relative_path: String, bytes: PackedByteArray) -> Error:
	if not is_safe_relative_path(relative_path):
		return ERR_INVALID_PARAMETER
	var absolute: String = project_root.path_join(relative_path)
	var parent: String = absolute.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		var mk_err: Error = DirAccess.make_dir_recursive_absolute(parent)
		if mk_err != OK:
			return mk_err
	var f: FileAccess = FileAccess.open(absolute, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	if bytes.size() > 0:
		f.store_buffer(bytes)
	f.close()
	return OK
