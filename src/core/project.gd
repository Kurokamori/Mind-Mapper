class_name Project
extends RefCounted

const MANIFEST_FILENAME := "project.json"
const BOARDS_DIR := "boards"
const ASSETS_DIR := "assets"
const FORMAT_VERSION := 1

var id: String = ""
var name: String = "Untitled Project"
var folder_path: String = ""
var created_unix: int = 0
var modified_unix: int = 0
var root_board_id: String = ""
var board_index: Dictionary = {}


static func create_new(folder_path_: String, project_name: String) -> Project:
	var p := Project.new()
	p.id = Uuid.v4()
	p.name = project_name
	p.folder_path = folder_path_
	p.created_unix = int(Time.get_unix_time_from_system())
	p.modified_unix = p.created_unix
	var root := Board.new()
	root.id = Uuid.v4()
	root.name = "Main"
	p.root_board_id = root.id
	p.board_index[root.id] = root.name
	var err := p._ensure_directories()
	if err != OK:
		return null
	if p.write_manifest() != OK:
		return null
	if p.write_board(root) != OK:
		return null
	return p


static func load_from_folder(folder_path_: String) -> Project:
	var manifest_path := folder_path_.path_join(MANIFEST_FILENAME)
	if not FileAccess.file_exists(manifest_path):
		return null
	var f := FileAccess.open(manifest_path, FileAccess.READ)
	if f == null:
		return null
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var p := Project.new()
	p.folder_path = folder_path_
	p.id = String(parsed.get("id", ""))
	p.name = String(parsed.get("name", "Untitled Project"))
	p.created_unix = int(parsed.get("created_unix", 0))
	p.modified_unix = int(parsed.get("modified_unix", 0))
	p.root_board_id = String(parsed.get("root_board_id", ""))
	var index_raw: Variant = parsed.get("board_index", {})
	if typeof(index_raw) == TYPE_DICTIONARY:
		p.board_index = index_raw.duplicate()
	return p


func _ensure_directories() -> Error:
	if not DirAccess.dir_exists_absolute(folder_path):
		var make_err := DirAccess.make_dir_recursive_absolute(folder_path)
		if make_err != OK:
			return make_err
	if not DirAccess.dir_exists_absolute(folder_path.path_join(BOARDS_DIR)):
		DirAccess.make_dir_recursive_absolute(folder_path.path_join(BOARDS_DIR))
	if not DirAccess.dir_exists_absolute(folder_path.path_join(ASSETS_DIR)):
		DirAccess.make_dir_recursive_absolute(folder_path.path_join(ASSETS_DIR))
	return OK


func write_manifest() -> Error:
	modified_unix = int(Time.get_unix_time_from_system())
	var data := {
		"format_version": FORMAT_VERSION,
		"id": id,
		"name": name,
		"created_unix": created_unix,
		"modified_unix": modified_unix,
		"root_board_id": root_board_id,
		"board_index": board_index,
	}
	var path := folder_path.path_join(MANIFEST_FILENAME)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return OK


func board_path(board_id: String) -> String:
	return folder_path.path_join(BOARDS_DIR).path_join(board_id + ".json")


func assets_path() -> String:
	return folder_path.path_join(ASSETS_DIR)


func read_board(board_id: String) -> Board:
	var path := board_path(board_id)
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return Board.from_dict(parsed)


func write_board(board: Board) -> Error:
	var path := board_path(board.id)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(board.to_dict(), "\t"))
	f.close()
	board_index[board.id] = board.name
	return write_manifest()


func copy_asset_into_project(source_path: String) -> String:
	var assets_dir := assets_path()
	if not DirAccess.dir_exists_absolute(assets_dir):
		DirAccess.make_dir_recursive_absolute(assets_dir)
	var ext := source_path.get_extension()
	var asset_id := Uuid.v4()
	var dest_name := asset_id + ("." + ext if ext != "" else "")
	var dest_path := assets_dir.path_join(dest_name)
	var src := FileAccess.open(source_path, FileAccess.READ)
	if src == null:
		return ""
	var size := src.get_length()
	var bytes := src.get_buffer(size)
	src.close()
	if bytes.size() != size:
		return ""
	var f := FileAccess.open(dest_path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_buffer(bytes)
	f.close()
	return dest_name


func resolve_asset_path(asset_name: String) -> String:
	return assets_path().path_join(asset_name)


func create_child_board(parent_board_id: String, child_name: String) -> Board:
	var b := Board.new()
	b.id = Uuid.v4()
	b.name = child_name if child_name.strip_edges() != "" else "Sub-board"
	b.parent_board_id = parent_board_id
	if write_board(b) != OK:
		return null
	return b


func delete_board(board_id: String) -> bool:
	if board_id == root_board_id:
		return false
	var path := board_path(board_id)
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		if err != OK:
			return false
	board_index.erase(board_id)
	write_manifest()
	return true


func rename_board(board_id: String, new_name: String) -> bool:
	var b := read_board(board_id)
	if b == null:
		return false
	b.name = new_name
	return write_board(b) == OK


func list_boards() -> Array:
	var out: Array = []
	for ids in board_index.keys():
		out.append({"id": ids, "name": String(board_index[ids])})
	out.sort_custom(func(a, b): return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	return out
