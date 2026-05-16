class_name MobileStoragePaths
extends RefCounted

const SANDBOX_DIRNAME: String = "projects"
const SYNCED_DIRNAME: String = "synced"
const IMPORTED_DIRNAME: String = "imported"
const REGISTRY_FILENAME: String = "mobile_projects.json"


static func sandbox_root() -> String:
	return _user_dir(SANDBOX_DIRNAME)


static func synced_root() -> String:
	return _user_dir(SANDBOX_DIRNAME).path_join(SYNCED_DIRNAME)


static func imported_root() -> String:
	return _user_dir(SANDBOX_DIRNAME).path_join(IMPORTED_DIRNAME)


static func registry_path() -> String:
	return _user_dir(SANDBOX_DIRNAME).path_join(REGISTRY_FILENAME)


static func ensure_dirs() -> Error:
	var dirs: PackedStringArray = PackedStringArray([
		sandbox_root(),
		synced_root(),
		imported_root(),
	])
	for d: String in dirs:
		if not DirAccess.dir_exists_absolute(d):
			var err: Error = DirAccess.make_dir_recursive_absolute(d)
			if err != OK:
				return err
	return OK


static func slugify_folder_name(raw: String) -> String:
	var bad: PackedStringArray = PackedStringArray(["<", ">", ":", "\"", "/", "\\", "|", "?", "*"])
	var out: String = raw.strip_edges()
	for b: String in bad:
		out = out.replace(b, "_")
	if out == "":
		out = "Project"
	return out


static func unique_folder(parent: String, raw_name: String) -> String:
	var safe: String = slugify_folder_name(raw_name)
	var candidate: String = parent.path_join(safe)
	if not DirAccess.dir_exists_absolute(candidate):
		return candidate
	var n: int = 2
	while DirAccess.dir_exists_absolute("%s (%d)" % [candidate, n]):
		n += 1
	return "%s (%d)" % [candidate, n]


static func _user_dir(sub: String) -> String:
	var base: String = ProjectSettings.globalize_path("user://")
	if base == "":
		return OS.get_user_data_dir().path_join(sub)
	return base.path_join(sub)
