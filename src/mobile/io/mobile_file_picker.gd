class_name MobileFilePicker
extends Node

signal files_chosen(absolute_paths: PackedStringArray)
signal pick_cancelled()
signal pick_error(message: String)

const MODE_SINGLE: int = 0
const MODE_MULTI: int = 1

var _file_dialog: FileDialog = null
var _is_native_supported: bool = false
var _pending_mode: int = MODE_SINGLE
var _pending_title: String = ""
var _pending_filters: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_is_native_supported = DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)


func pick_single(title: String, filters: PackedStringArray, initial_dir: String = "") -> void:
	_pending_mode = MODE_SINGLE
	_pending_title = title
	_pending_filters = filters
	_open_dialog(initial_dir)


func pick_multi(title: String, filters: PackedStringArray, initial_dir: String = "") -> void:
	_pending_mode = MODE_MULTI
	_pending_title = title
	_pending_filters = filters
	_open_dialog(initial_dir)


func _open_dialog(initial_dir: String) -> void:
	var start_dir: String = _resolve_start_dir(initial_dir)
	if _is_native_supported and _supports_native_for_platform():
		var ok: Error = DisplayServer.file_dialog_show(
			_pending_title,
			start_dir,
			"",
			false,
			_native_mode(),
			_pending_filters,
			_on_native_dialog_result,
		)
		if ok == OK:
			return
	_open_in_engine(start_dir)


func _native_mode() -> int:
	if _pending_mode == MODE_MULTI:
		return DisplayServer.FILE_DIALOG_MODE_OPEN_FILES
	return DisplayServer.FILE_DIALOG_MODE_OPEN_FILE


func _supports_native_for_platform() -> bool:
	var name: String = OS.get_name()
	return name == "Windows" or name == "macOS" or name == "Linux" or name == "Android"


func _resolve_start_dir(initial_dir: String) -> String:
	var start_dir: String = initial_dir
	if start_dir == "" or not DirAccess.dir_exists_absolute(start_dir):
		start_dir = MobileStoragePaths.sandbox_root()
		if not DirAccess.dir_exists_absolute(start_dir):
			MobileStoragePaths.ensure_dirs()
	return start_dir


func _on_native_dialog_result(status: bool, selected_paths: PackedStringArray, _selected_filter_index: int) -> void:
	if not status or selected_paths.is_empty():
		pick_cancelled.emit()
		return
	files_chosen.emit(_normalize_paths(selected_paths))


func _normalize_paths(paths: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for p: String in paths:
		out.append(p.replace("\\", "/"))
	return out


func _open_in_engine(initial_dir: String) -> void:
	_release_file_dialog()
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	if _pending_mode == MODE_MULTI:
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	else:
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.use_native_dialog = false
	_file_dialog.size = Vector2i(720, 540)
	_file_dialog.title = _pending_title
	_file_dialog.filters = _pending_filters
	if DirAccess.dir_exists_absolute(initial_dir):
		_file_dialog.current_dir = initial_dir
	_file_dialog.file_selected.connect(_on_engine_file_chosen)
	_file_dialog.files_selected.connect(_on_engine_files_chosen)
	_file_dialog.canceled.connect(_on_engine_dialog_cancelled)
	add_child(_file_dialog)
	_file_dialog.popup_centered()


func _on_engine_file_chosen(path: String) -> void:
	files_chosen.emit(_normalize_paths(PackedStringArray([path])))
	_release_file_dialog()


func _on_engine_files_chosen(paths: PackedStringArray) -> void:
	files_chosen.emit(_normalize_paths(paths))
	_release_file_dialog()


func _on_engine_dialog_cancelled() -> void:
	pick_cancelled.emit()
	_release_file_dialog()


func _release_file_dialog() -> void:
	if _file_dialog != null:
		_file_dialog.queue_free()
		_file_dialog = null
