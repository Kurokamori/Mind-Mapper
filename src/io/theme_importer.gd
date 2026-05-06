class_name ThemeImporter
extends RefCounted

const IMPORT_ROOT: String = "user://themes"
const ACTIVE_DIR: String = "user://themes/current"
const ACTIVE_THEME_FILE: String = "user://themes/current/theme.tres"

const ALLOWED_SUB_TYPES: PackedStringArray = [
	"StyleBox",
	"StyleBoxFlat",
	"StyleBoxLine",
	"StyleBoxEmpty",
	"StyleBoxTexture",
	"Texture",
	"Texture2D",
	"CompressedTexture2D",
	"ImageTexture",
	"AtlasTexture",
	"PortableCompressedTexture2D",
	"PlaceholderTexture2D",
	"Gradient",
	"GradientTexture1D",
	"GradientTexture2D",
	"Curve",
	"CurveTexture",
	"Image",
]

const ALLOWED_EXT_TYPES: PackedStringArray = [
	"Texture",
	"Texture2D",
	"CompressedTexture2D",
	"ImageTexture",
	"AtlasTexture",
	"PortableCompressedTexture2D",
]

const ALLOWED_EXT_FILE_EXTENSIONS: PackedStringArray = [
	"png",
	"jpg",
	"jpeg",
]

const FORBIDDEN_TYPE_TOKENS: PackedStringArray = [
	"GDScript",
	"CSharpScript",
	"PackedScene",
	"NativeScript",
	"VisualScript",
	"PluginScript",
	"Script",
]

const MAX_FILE_BYTES: int = 4 * 1024 * 1024
const MAX_TEXTURE_BYTES: int = 8 * 1024 * 1024


static func make_result(p_ok: bool, p_error: String = "", p_path: String = "", p_label: String = "") -> Dictionary:
	return {
		"ok": p_ok,
		"error": p_error,
		"path": p_path,
		"label": p_label,
	}


static func import_file(source_path: String) -> Dictionary:
	if source_path == "":
		return make_result(false, "No file selected.")
	if not FileAccess.file_exists(source_path):
		return make_result(false, "File not found: %s" % source_path)
	var size: int = _file_size(source_path)
	if size <= 0:
		return make_result(false, "File is empty or unreadable.")
	if size > MAX_FILE_BYTES:
		return make_result(false, "Theme file is too large (%d bytes). Limit is %d." % [size, MAX_FILE_BYTES])
	var ext: String = source_path.get_extension().to_lower()
	if ext != "tres":
		return make_result(false, "Only text-format .tres themes are supported.")
	var f: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if f == null:
		return make_result(false, "Cannot open file for reading.")
	var text: String = f.get_as_text()
	f.close()
	var validation: Dictionary = validate_text(text)
	if not bool(validation.get("ok", false)):
		return make_result(false, String(validation.get("error", "Validation failed.")))
	var ext_resources: Array = validation.get("ext_resources", []) as Array
	var prepared: Dictionary = _prepare_active_dir()
	if not bool(prepared.get("ok", false)):
		return make_result(false, String(prepared.get("error", "Could not prepare theme directory.")))
	var source_dir: String = source_path.get_base_dir()
	var rewritten: Dictionary = _copy_and_rewrite(text, ext_resources, source_dir)
	if not bool(rewritten.get("ok", false)):
		_purge_active_dir()
		return make_result(false, String(rewritten.get("error", "Failed to copy referenced images.")))
	var rewritten_text: String = String(rewritten.get("text", ""))
	var write_err: String = _write_text_file(ACTIVE_THEME_FILE, rewritten_text)
	if write_err != "":
		_purge_active_dir()
		return make_result(false, write_err)
	var loaded: Resource = ResourceLoader.load(ACTIVE_THEME_FILE, "Theme", ResourceLoader.CACHE_MODE_IGNORE)
	if not (loaded is Theme):
		_purge_active_dir()
		return make_result(false, "Imported file did not load as a Godot Theme.")
	var label: String = source_path.get_file().get_basename()
	return make_result(true, "", ACTIVE_THEME_FILE, label)


static func clear_active_theme() -> void:
	_purge_active_dir()


static func active_theme_path() -> String:
	if FileAccess.file_exists(ACTIVE_THEME_FILE):
		return ACTIVE_THEME_FILE
	return ""


static func validate_text(text: String) -> Dictionary:
	if text == "":
		return _err("File is empty.")
	var saw_header: bool = false
	var ext_resources: Array = []
	var lines: PackedStringArray = text.split("\n", true)
	for raw_line: String in lines:
		var line: String = raw_line.strip_edges()
		if line == "" or line.begins_with(";"):
			continue
		if line.begins_with("["):
			if line.begins_with("[gd_resource"):
				if saw_header:
					return _err("Multiple gd_resource headers.")
				saw_header = true
				var root_type: String = _attr(line, "type")
				if root_type != "Theme":
					return _err("Root resource type must be Theme (got '%s')." % root_type)
				if _attr(line, "script_class") != "":
					return _err("Resource declares script_class; not allowed.")
				continue
			if line.begins_with("[ext_resource"):
				var ext_type: String = _attr(line, "type")
				var ext_path: String = _attr(line, "path")
				var ext_id: String = _attr(line, "id")
				if not (ext_type in ALLOWED_EXT_TYPES):
					return _err("External resource type '%s' is not allowed; only image textures (png/jpg/jpeg) may be referenced." % ext_type)
				if ext_path == "":
					return _err("External resource is missing a path attribute.")
				if ext_path.begins_with("res://") or ext_path.begins_with("uid://"):
					return _err("External resource path '%s' references a foreign Godot project; only local file paths are supported." % ext_path)
				var path_ext: String = ext_path.get_extension().to_lower()
				if not (path_ext in ALLOWED_EXT_FILE_EXTENSIONS):
					return _err("External resource '%s' has unsupported extension; only png/jpg/jpeg are allowed." % ext_path)
				ext_resources.append({
					"line": line,
					"type": ext_type,
					"path": ext_path,
					"id": ext_id,
				})
				continue
			if line.begins_with("[sub_resource"):
				var sub_type: String = _attr(line, "type")
				if not (sub_type in ALLOWED_SUB_TYPES):
					return _err("Sub-resource type '%s' is not allowed." % sub_type)
				if _attr(line, "script_class") != "":
					return _err("Sub-resource declares script_class; not allowed.")
				continue
			if line.begins_with("[resource"):
				continue
			if line.begins_with("[node") or line.begins_with("[connection") or line.begins_with("[editable"):
				return _err("Scene sections are not allowed in a theme file.")
			return _err("Unknown section header: %s" % line)
		var lower: String = line.to_lower()
		if lower.begins_with("script ") or lower.begins_with("script=") or lower.begins_with("script\t"):
			return _err("Theme attaches a script; not allowed.")
		for token: String in FORBIDDEN_TYPE_TOKENS:
			if line.contains(token):
				return _err("Theme references forbidden type '%s'." % token)
	if not saw_header:
		return _err("Missing gd_resource header; not a Godot resource file.")
	return {
		"ok": true,
		"error": "",
		"ext_resources": ext_resources,
	}


static func _err(msg: String) -> Dictionary:
	return {
		"ok": false,
		"error": msg,
		"ext_resources": [],
	}


static func _attr(line: String, key: String) -> String:
	var needle: String = key + "=\""
	var start: int = line.find(needle)
	if start < 0:
		return ""
	var value_start: int = start + needle.length()
	var end: int = line.find("\"", value_start)
	if end < 0:
		return ""
	return line.substr(value_start, end - value_start)


static func _file_size(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var n: int = int(f.get_length())
	f.close()
	return n


static func _prepare_active_dir() -> Dictionary:
	var root: DirAccess = DirAccess.open("user://")
	if root == null:
		return {"ok": false, "error": "Cannot access user:// directory."}
	if not root.dir_exists("themes"):
		var mk: int = root.make_dir_recursive("themes")
		if mk != OK:
			return {"ok": false, "error": "Cannot create user://themes directory."}
	_purge_active_dir()
	var themes: DirAccess = DirAccess.open(IMPORT_ROOT)
	if themes == null:
		return {"ok": false, "error": "Cannot open user://themes directory."}
	var mk2: int = themes.make_dir_recursive("current")
	if mk2 != OK and not themes.dir_exists("current"):
		return {"ok": false, "error": "Cannot create user://themes/current directory."}
	return {"ok": true, "error": ""}


static func _purge_active_dir() -> void:
	var d: DirAccess = DirAccess.open(ACTIVE_DIR)
	if d == null:
		return
	d.list_dir_begin()
	var entry: String = d.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			if d.current_is_dir():
				_purge_subdir(ACTIVE_DIR.path_join(entry))
			else:
				d.remove(entry)
		entry = d.get_next()
	d.list_dir_end()
	var parent: DirAccess = DirAccess.open(IMPORT_ROOT)
	if parent != null:
		parent.remove("current")


static func _purge_subdir(path: String) -> void:
	var d: DirAccess = DirAccess.open(path)
	if d == null:
		return
	d.list_dir_begin()
	var entry: String = d.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			if d.current_is_dir():
				_purge_subdir(path.path_join(entry))
			else:
				d.remove(entry)
		entry = d.get_next()
	d.list_dir_end()
	var parent_path: String = path.get_base_dir()
	var parent: DirAccess = DirAccess.open(parent_path)
	if parent != null:
		parent.remove(path.get_file())


static func _copy_and_rewrite(text: String, ext_resources: Array, source_dir: String) -> Dictionary:
	var path_remap: Dictionary = {}
	var used_names: Dictionary = {}
	for entry_v: Variant in ext_resources:
		var entry: Dictionary = entry_v
		var original: String = String(entry.get("path", ""))
		if path_remap.has(original):
			continue
		var resolved: String = _resolve_external_path(original, source_dir)
		if resolved == "":
			return {"ok": false, "error": "Cannot resolve referenced image '%s' relative to the theme file." % original}
		var size: int = _file_size(resolved)
		if size <= 0:
			return {"ok": false, "error": "Referenced image '%s' is empty or unreadable." % original}
		if size > MAX_TEXTURE_BYTES:
			return {"ok": false, "error": "Referenced image '%s' is too large (%d bytes; limit %d)." % [original, size, MAX_TEXTURE_BYTES]}
		if not _looks_like_image(resolved):
			return {"ok": false, "error": "Referenced file '%s' does not look like a PNG/JPEG image." % original}
		var dest_name: String = _unique_name_for(original.get_file(), used_names)
		var dest_path: String = ACTIVE_DIR.path_join(dest_name)
		var copy_err: String = _copy_binary(resolved, dest_path)
		if copy_err != "":
			return {"ok": false, "error": copy_err}
		used_names[dest_name] = true
		path_remap[original] = dest_path
	var rewritten_text: String = _rewrite_ext_resource_lines(text, path_remap)
	return {
		"ok": true,
		"error": "",
		"text": rewritten_text,
	}


static func _resolve_external_path(raw: String, source_dir: String) -> String:
	if raw == "":
		return ""
	if raw.begins_with("res://") or raw.begins_with("uid://") or raw.begins_with("user://"):
		return ""
	if FileAccess.file_exists(raw):
		return raw
	if source_dir != "":
		var joined: String = source_dir.path_join(raw)
		if FileAccess.file_exists(joined):
			return joined
	return ""


static func _looks_like_image(path: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var header: PackedByteArray = f.get_buffer(8)
	f.close()
	if header.size() < 4:
		return false
	if header[0] == 0x89 and header[1] == 0x50 and header[2] == 0x4E and header[3] == 0x47:
		return true
	if header[0] == 0xFF and header[1] == 0xD8 and header[2] == 0xFF:
		return true
	return false


static func _unique_name_for(file_name: String, used: Dictionary) -> String:
	var base: String = file_name.get_basename()
	var ext: String = file_name.get_extension().to_lower()
	var safe_base: String = _sanitize_basename(base)
	if safe_base == "":
		safe_base = "image"
	var safe_ext: String = ext if ext in ALLOWED_EXT_FILE_EXTENSIONS else "png"
	var candidate: String = "%s.%s" % [safe_base, safe_ext]
	var counter: int = 1
	while used.has(candidate):
		candidate = "%s_%d.%s" % [safe_base, counter, safe_ext]
		counter += 1
	return candidate


static func _sanitize_basename(value: String) -> String:
	var out: String = ""
	for i: int in range(value.length()):
		var ch: String = value.substr(i, 1)
		var cu: int = ch.unicode_at(0)
		var is_alpha: bool = (cu >= 0x41 and cu <= 0x5A) or (cu >= 0x61 and cu <= 0x7A)
		var is_digit: bool = (cu >= 0x30 and cu <= 0x39)
		if is_alpha or is_digit or ch == "_" or ch == "-":
			out += ch
		else:
			out += "_"
	return out


static func _copy_binary(source_path: String, dest_path: String) -> String:
	var src_f: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if src_f == null:
		return "Cannot read '%s'." % source_path
	var bytes: PackedByteArray = src_f.get_buffer(int(src_f.get_length()))
	src_f.close()
	var dst_f: FileAccess = FileAccess.open(dest_path, FileAccess.WRITE)
	if dst_f == null:
		return "Cannot write '%s'." % dest_path
	dst_f.store_buffer(bytes)
	dst_f.close()
	return ""


static func _write_text_file(dest_path: String, content: String) -> String:
	var f: FileAccess = FileAccess.open(dest_path, FileAccess.WRITE)
	if f == null:
		return "Cannot write '%s'." % dest_path
	f.store_string(content)
	f.close()
	return ""


static func _rewrite_ext_resource_lines(text: String, path_remap: Dictionary) -> String:
	if path_remap.is_empty():
		return text
	var lines: PackedStringArray = text.split("\n", true)
	var out: PackedStringArray = PackedStringArray()
	for raw_line: String in lines:
		var stripped: String = raw_line.strip_edges()
		if stripped.begins_with("[ext_resource"):
			out.append(_rewrite_single_ext_line(raw_line, path_remap))
		else:
			out.append(raw_line)
	return "\n".join(out)


static func _rewrite_single_ext_line(line: String, path_remap: Dictionary) -> String:
	var original_path: String = _attr(line, "path")
	if original_path == "" or not path_remap.has(original_path):
		return line
	var new_path: String = String(path_remap[original_path])
	var replaced: String = line.replace(
		"path=\"%s\"" % original_path,
		"path=\"%s\"" % new_path,
	)
	replaced = _strip_attribute(replaced, "uid")
	return replaced


static func _strip_attribute(line: String, key: String) -> String:
	var needle: String = " " + key + "=\""
	var start: int = line.find(needle)
	if start < 0:
		return line
	var value_start: int = start + needle.length()
	var end: int = line.find("\"", value_start)
	if end < 0:
		return line
	return line.substr(0, start) + line.substr(end + 1, line.length() - end - 1)
