class_name MobileFileSaver
extends Node

signal save_path_chosen(absolute_path: String)
signal save_cancelled()
signal save_error(message: String)

var _file_dialog: FileDialog = null
var _is_native_supported: bool = false
var _pending_title: String = ""
var _pending_filters: PackedStringArray = PackedStringArray()
var _pending_default_name: String = ""
var _pending_extension: String = ""


func _ready() -> void:
	_is_native_supported = DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)


func save_as(title: String, default_name: String, extension: String, filters: PackedStringArray, initial_dir: String = "") -> void:
	_pending_title = title
	_pending_default_name = default_name
	_pending_extension = extension.to_lower()
	_pending_filters = filters
	var start_dir: String = _resolve_start_dir(initial_dir)
	if _is_native_supported and _supports_native_for_platform():
		var ok: Error = DisplayServer.file_dialog_show(
			title,
			start_dir,
			default_name,
			false,
			DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
			filters,
			_on_native_dialog_result,
		)
		if ok == OK:
			return
	_open_in_engine(start_dir)


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
		save_cancelled.emit()
		return
	save_path_chosen.emit(_ensure_extension(selected_paths[0]))


func _open_in_engine(initial_dir: String) -> void:
	_release_file_dialog()
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.use_native_dialog = false
	_file_dialog.size = Vector2i(720, 540)
	_file_dialog.title = _pending_title
	_file_dialog.filters = _pending_filters
	_file_dialog.current_file = _pending_default_name
	if DirAccess.dir_exists_absolute(initial_dir):
		_file_dialog.current_dir = initial_dir
	_file_dialog.file_selected.connect(_on_engine_file_chosen)
	_file_dialog.canceled.connect(_on_engine_dialog_cancelled)
	add_child(_file_dialog)
	_file_dialog.popup_centered()


func _on_engine_file_chosen(path: String) -> void:
	save_path_chosen.emit(_ensure_extension(path))
	_release_file_dialog()


func _on_engine_dialog_cancelled() -> void:
	save_cancelled.emit()
	_release_file_dialog()


func _ensure_extension(path: String) -> String:
	var normalized: String = path.replace("\\", "/")
	if _pending_extension == "":
		return normalized
	var dot_ext: String = "." + _pending_extension
	if normalized.to_lower().ends_with(dot_ext):
		return normalized
	return normalized + dot_ext


func _release_file_dialog() -> void:
	if _file_dialog != null:
		_file_dialog.queue_free()
		_file_dialog = null
