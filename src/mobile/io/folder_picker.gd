class_name FolderPicker
extends Node

signal folder_chosen(absolute_path: String)
signal folder_pick_cancelled()
signal pick_error(message: String)

const MODE_OPEN_PROJECT: int = 0
const MODE_CHOOSE_PARENT_FOR_NEW: int = 1

var _file_dialog: FileDialog = null
var _is_native_supported: bool = false
var _pending_mode: int = MODE_OPEN_PROJECT


func _ready() -> void:
	_is_native_supported = DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)


func has_native() -> bool:
	return _is_native_supported


func pick_open_project(initial_dir: String = "") -> void:
	_pending_mode = MODE_OPEN_PROJECT
	_open_dialog(initial_dir, "Open project folder")


func pick_parent_folder(initial_dir: String = "") -> void:
	_pending_mode = MODE_CHOOSE_PARENT_FOR_NEW
	_open_dialog(initial_dir, "Choose where the new project will live")


func _open_dialog(initial_dir: String, title: String) -> void:
	var start_dir: String = initial_dir
	if start_dir == "" or not DirAccess.dir_exists_absolute(start_dir):
		start_dir = MobileStoragePaths.sandbox_root()
		if not DirAccess.dir_exists_absolute(start_dir):
			MobileStoragePaths.ensure_dirs()
	if _is_native_supported and _supports_native_for_platform():
		_open_native(start_dir, title)
		return
	_open_in_engine(start_dir, title)


func _supports_native_for_platform() -> bool:
	var name: String = OS.get_name()
	if name == "Windows" or name == "macOS" or name == "Linux" or name == "Android":
		return true
	return false


func _open_native(initial_dir: String, title: String) -> void:
	var filters: PackedStringArray = PackedStringArray()
	var ok: Error = DisplayServer.file_dialog_show(
		title,
		initial_dir,
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_DIR,
		filters,
		_on_native_dialog_result,
	)
	if ok != OK:
		_open_in_engine(initial_dir, title)


func _on_native_dialog_result(status: bool, selected_paths: PackedStringArray, _selected_filter_index: int) -> void:
	if not status or selected_paths.is_empty():
		folder_pick_cancelled.emit()
		return
	folder_chosen.emit(selected_paths[0])


func _open_in_engine(initial_dir: String, title: String) -> void:
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_file_dialog.use_native_dialog = false
		_file_dialog.size = Vector2i(720, 540)
		_file_dialog.dir_selected.connect(_on_engine_dir_chosen)
		_file_dialog.canceled.connect(_on_engine_dialog_cancelled)
		add_child(_file_dialog)
	_file_dialog.title = title
	if DirAccess.dir_exists_absolute(initial_dir):
		_file_dialog.current_dir = initial_dir
	_file_dialog.popup_centered()


func _on_engine_dir_chosen(dir_path: String) -> void:
	folder_chosen.emit(dir_path)


func _on_engine_dialog_cancelled() -> void:
	folder_pick_cancelled.emit()


func current_mode() -> int:
	return _pending_mode
