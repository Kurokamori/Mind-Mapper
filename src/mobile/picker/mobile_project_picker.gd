class_name MobileProjectPicker
extends Control

signal project_opened(project: Project, source: String, remote_label: String)
signal toast_requested(severity: String, message: String)

const RECENT_ROW_SCENE: PackedScene = preload("res://src/mobile/picker/mobile_recent_row.tscn")
const LAN_ROW_SCENE: PackedScene = preload("res://src/mobile/picker/mobile_lan_host_row.tscn")
const NEW_PROJECT_DIALOG_SCENE: PackedScene = preload("res://src/mobile/picker/mobile_new_project_dialog.tscn")

@onready var _recent_scroll: ScrollContainer = %RecentScroll
@onready var _recent_list: VBoxContainer = %RecentList
@onready var _recent_empty_label: Label = %RecentEmptyLabel
@onready var _new_project_button: Button = %NewProjectButton
@onready var _open_folder_button: Button = %OpenFolderButton
@onready var _import_folder_button: Button = %ImportFolderButton
@onready var _lan_browser_button: Button = %LanBrowserButton
@onready var _lan_status_label: Label = %LanStatusLabel
@onready var _lan_log_label: RichTextLabel = %LanLogLabel
@onready var _lan_hosts_root: VBoxContainer = %LanHostsRoot
@onready var _lan_empty_label: Label = %LanHostsEmptyLabel
@onready var _manual_ip_edit: LineEdit = %ManualIpEdit
@onready var _manual_pull_button: Button = %ManualPullButton
@onready var _folder_picker: FolderPicker = %FolderPicker
@onready var _lan_client: LanSyncClient = %LanClient

var _registry_entries: Array = []
var _pending_picker_purpose: String = ""
var _pending_new_project_name: String = ""
var _pending_sync_target_folder: String = ""
var _pending_sync_host_entry: Dictionary = {}


func _ready() -> void:
	MobileStoragePaths.ensure_dirs()
	_registry_entries = MobileProjectRegistry.load_entries()
	_new_project_button.pressed.connect(_on_new_project_pressed)
	_open_folder_button.pressed.connect(_on_open_folder_pressed)
	_import_folder_button.pressed.connect(_on_import_folder_pressed)
	_lan_browser_button.toggled.connect(_on_lan_browser_toggled)
	_manual_pull_button.pressed.connect(_on_manual_pull_pressed)
	_folder_picker.folder_chosen.connect(_on_folder_chosen)
	_folder_picker.folder_pick_cancelled.connect(_on_folder_pick_cancelled)
	_folder_picker.pick_error.connect(_on_folder_pick_error)
	_lan_client.hosts_changed.connect(_on_lan_hosts_changed)
	_lan_client.sync_progress.connect(_on_sync_progress)
	_lan_client.sync_completed.connect(_on_sync_completed)
	_lan_client.sync_failed.connect(_on_sync_failed)
	_lan_client.log_message.connect(_on_lan_log)
	_lan_status_label.text = "LAN sync idle"
	_clear_log()
	_render_recent_list()
	_render_lan_hosts([])
	visibility_changed.connect(_on_visibility_changed)
	call_deferred("_auto_start_discovery_if_visible")


func _auto_start_discovery_if_visible() -> void:
	if visible and not _lan_browser_button.button_pressed:
		_lan_browser_button.button_pressed = true


func _on_visibility_changed() -> void:
	if visible:
		_auto_start_discovery_if_visible()
	else:
		if _lan_browser_button.button_pressed:
			_lan_browser_button.button_pressed = false


func refresh() -> void:
	_registry_entries = MobileProjectRegistry.load_entries()
	_render_recent_list()


func _render_recent_list() -> void:
	for child: Node in _recent_list.get_children():
		if child == _recent_empty_label:
			continue
		child.queue_free()
	_recent_empty_label.visible = _registry_entries.is_empty()
	for entry_v: Variant in _registry_entries:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var row: MobileRecentRow = RECENT_ROW_SCENE.instantiate()
		_recent_list.add_child(row)
		row.bind(entry)
		row.open_requested.connect(_on_recent_row_open)
		row.remove_requested.connect(_on_recent_row_remove)


func _on_recent_row_open(folder_path: String, source: String, remote_label: String) -> void:
	_open_project_from_folder(folder_path, source, remote_label)


func _on_recent_row_remove(folder_path: String) -> void:
	_registry_entries = MobileProjectRegistry.remove(_registry_entries, folder_path)
	MobileProjectRegistry.save_entries(_registry_entries)
	_render_recent_list()
	toast_requested.emit("info", "Removed from recent projects")


func _on_new_project_pressed() -> void:
	var dialog: MobileNewProjectDialog = NEW_PROJECT_DIALOG_SCENE.instantiate()
	add_child(dialog)
	dialog.popup_centered_clamped(Vector2i(560, 360))
	dialog.confirmed_with_name.connect(_on_new_project_named)


func _on_new_project_named(project_name: String) -> void:
	var trimmed: String = project_name.strip_edges()
	if trimmed == "":
		toast_requested.emit("warning", "Project name required")
		return
	var folder: String = MobileStoragePaths.unique_folder(MobileStoragePaths.sandbox_root(), trimmed)
	var project: Project = Project.create_new(folder, trimmed)
	if project == null:
		toast_requested.emit("error", "Failed to create project folder")
		return
	_remember_and_open(project, folder, MobileProjectRegistry.SOURCE_LOCAL, "")


func _on_open_folder_pressed() -> void:
	_pending_picker_purpose = "open"
	_folder_picker.pick_open_project()


func _on_import_folder_pressed() -> void:
	_pending_picker_purpose = "import"
	_folder_picker.pick_open_project()


func _on_folder_chosen(absolute_path: String) -> void:
	var purpose: String = _pending_picker_purpose
	_pending_picker_purpose = ""
	if purpose == "import":
		_import_project_folder(absolute_path)
	else:
		_open_external_folder(absolute_path)


func _on_folder_pick_cancelled() -> void:
	_pending_picker_purpose = ""


func _on_folder_pick_error(message: String) -> void:
	_pending_picker_purpose = ""
	toast_requested.emit("error", "Folder picker error: %s" % message)


func _open_external_folder(folder_path: String) -> void:
	var project: Project = Project.load_from_folder(folder_path)
	if project == null:
		toast_requested.emit("error", "Folder is not a Loom project")
		return
	_remember_and_open(project, folder_path, MobileProjectRegistry.SOURCE_EXTERNAL, "")


func _import_project_folder(folder_path: String) -> void:
	var source_project: Project = Project.load_from_folder(folder_path)
	if source_project == null:
		toast_requested.emit("error", "Folder is not a Loom project")
		return
	var dest_folder: String = MobileStoragePaths.unique_folder(MobileStoragePaths.imported_root(), source_project.name)
	var copy_err: Error = _copy_directory_recursive(folder_path, dest_folder)
	if copy_err != OK:
		toast_requested.emit("error", "Failed to import (%d)" % copy_err)
		return
	var copied_project: Project = Project.load_from_folder(dest_folder)
	if copied_project == null:
		toast_requested.emit("error", "Copied project could not be opened")
		return
	_remember_and_open(copied_project, dest_folder, MobileProjectRegistry.SOURCE_IMPORTED, "Imported from disk")


func _open_project_from_folder(folder_path: String, fallback_source: String, remote_label: String) -> void:
	var project: Project = Project.load_from_folder(folder_path)
	if project == null:
		toast_requested.emit("error", "Project not found at %s" % folder_path)
		_registry_entries = MobileProjectRegistry.remove(_registry_entries, folder_path)
		MobileProjectRegistry.save_entries(_registry_entries)
		_render_recent_list()
		return
	_remember_and_open(project, folder_path, fallback_source, remote_label)


func _remember_and_open(project: Project, folder: String, source: String, remote_label: String) -> void:
	var entry: Dictionary = {
		MobileProjectRegistry.FIELD_NAME: project.name,
		MobileProjectRegistry.FIELD_FOLDER: folder,
		MobileProjectRegistry.FIELD_SOURCE: source,
		MobileProjectRegistry.FIELD_PROJECT_ID: project.id,
		MobileProjectRegistry.FIELD_REMOTE_NAME: remote_label,
		MobileProjectRegistry.FIELD_LAST_OPENED_UNIX: int(Time.get_unix_time_from_system()),
	}
	if source == MobileProjectRegistry.SOURCE_SYNCED:
		entry[MobileProjectRegistry.FIELD_LAST_SYNCED_UNIX] = int(Time.get_unix_time_from_system())
	_registry_entries = MobileProjectRegistry.upsert(_registry_entries, entry)
	MobileProjectRegistry.save_entries(_registry_entries)
	_render_recent_list()
	project_opened.emit(project, source, remote_label)


func _on_lan_browser_toggled(active: bool) -> void:
	if active:
		var err: Error = _lan_client.start_discovery()
		if err == OK:
			_lan_status_label.text = "Searching for desktop hosts on UDP %d…" % LanSyncProtocol.UDP_PORT
			_append_log("info", "Listening for desktop announce packets on UDP %d." % LanSyncProtocol.UDP_PORT)
		else:
			_lan_browser_button.button_pressed = false
			_lan_status_label.text = "LAN discovery failed (%d)" % err
			_append_log("error", "UDP bind on %d failed (%d). Try the manual IP option below." % [LanSyncProtocol.UDP_PORT, err])
			toast_requested.emit("error", "Could not start LAN discovery")
		return
	_lan_client.stop_discovery()
	_lan_status_label.text = "LAN sync idle"
	_render_lan_hosts([])


func _on_lan_hosts_changed(host_list: Array) -> void:
	_render_lan_hosts(host_list)


func _render_lan_hosts(host_list: Array) -> void:
	for child: Node in _lan_hosts_root.get_children():
		if child == _lan_empty_label:
			continue
		child.queue_free()
	_lan_empty_label.visible = host_list.is_empty()
	for entry_v: Variant in host_list:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var row: MobileLanHostRow = LAN_ROW_SCENE.instantiate()
		_lan_hosts_root.add_child(row)
		row.bind(entry)
		row.pull_requested.connect(_on_lan_host_pull_requested)


func _on_lan_host_pull_requested(host_entry: Dictionary) -> void:
	var project_id: String = String(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_ID, ""))
	var project_name: String = String(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_NAME, "Synced project"))
	var host_label: String = String(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_HOST_NAME, "Desktop"))
	if project_id == "":
		toast_requested.emit("error", "Host announce missing project id")
		return
	var existing_idx: int = MobileProjectRegistry.find_index_by_project_id(_registry_entries, project_id)
	var target_folder: String = ""
	if existing_idx >= 0:
		var existing: Dictionary = _registry_entries[existing_idx]
		target_folder = String(existing.get(MobileProjectRegistry.FIELD_FOLDER, ""))
	if target_folder == "":
		target_folder = MobileStoragePaths.unique_folder(MobileStoragePaths.synced_root(), project_name)
	_pending_sync_target_folder = target_folder
	_pending_sync_host_entry = host_entry
	_lan_status_label.text = "Syncing '%s' from %s…" % [project_name, host_label]
	var err: Error = _lan_client.begin_sync(host_entry, target_folder)
	if err != OK:
		_lan_status_label.text = "Sync could not start (%d)" % err
		toast_requested.emit("error", "Could not start sync")


func _on_sync_progress(stage: String, current: int, total: int, current_path: String) -> void:
	if stage == LanSyncClient.STAGE_MANIFEST:
		_lan_status_label.text = "Receiving project manifest…"
	else:
		if total > 0:
			_lan_status_label.text = "Pulling %d/%d: %s" % [current, total, current_path]
		else:
			_lan_status_label.text = "Pulling files…"


func _on_sync_completed(project_folder: String, project_id: String) -> void:
	_lan_status_label.text = "Sync complete: %s" % project_folder
	var host_label: String = String(_pending_sync_host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_HOST_NAME, ""))
	var project: Project = Project.load_from_folder(project_folder)
	if project == null:
		toast_requested.emit("error", "Synced project failed to open")
		return
	if project_id != "" and project.id != project_id:
		toast_requested.emit("warning", "Synced project ID mismatched")
	_pending_sync_target_folder = ""
	_pending_sync_host_entry = {}
	_remember_and_open(project, project_folder, MobileProjectRegistry.SOURCE_SYNCED, host_label)


func _on_sync_failed(reason: String) -> void:
	_lan_status_label.text = "Sync failed: %s" % reason
	toast_requested.emit("error", "Sync failed (%s)" % reason)
	_pending_sync_target_folder = ""
	_pending_sync_host_entry = {}


func _on_lan_log(severity: String, message: String) -> void:
	_append_log(severity, message)
	if severity == "error":
		toast_requested.emit("error", message)


func _on_manual_pull_pressed() -> void:
	var address: String = _manual_ip_edit.text.strip_edges()
	if address == "":
		toast_requested.emit("warning", "Enter the desktop's IP address first")
		return
	var entry: Dictionary = {
		"address": address,
		LanSyncProtocol.ANNOUNCE_FIELD_TCP_PORT: LanSyncProtocol.TCP_PORT,
		LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_ID: "",
		LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_NAME: "Manual sync",
		LanSyncProtocol.ANNOUNCE_FIELD_HOST_NAME: address,
	}
	_append_log("info", "Attempting manual pull from %s:%d" % [address, LanSyncProtocol.TCP_PORT])
	_on_lan_host_pull_requested(entry)


func _clear_log() -> void:
	if _lan_log_label == null:
		return
	_lan_log_label.clear()


func _append_log(severity: String, message: String) -> void:
	if _lan_log_label == null:
		return
	var prefix: String
	match severity:
		"error": prefix = "[color=#ff8888]ERR[/color]"
		"warning": prefix = "[color=#ffcc66]WRN[/color]"
		_: prefix = "[color=#aacde5]LOG[/color]"
	_lan_log_label.append_text("%s %s\n" % [prefix, message])


func _copy_directory_recursive(source: String, dest: String) -> Error:
	if not DirAccess.dir_exists_absolute(source):
		return ERR_FILE_NOT_FOUND
	if not DirAccess.dir_exists_absolute(dest):
		var mk: Error = DirAccess.make_dir_recursive_absolute(dest)
		if mk != OK:
			return mk
	var d: DirAccess = DirAccess.open(source)
	if d == null:
		return ERR_CANT_OPEN
	d.list_dir_begin()
	var entry: String = d.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = d.get_next()
			continue
		var src_path: String = source.path_join(entry)
		var dst_path: String = dest.path_join(entry)
		if d.current_is_dir():
			var sub: Error = _copy_directory_recursive(src_path, dst_path)
			if sub != OK:
				d.list_dir_end()
				return sub
		else:
			var copy_err: Error = _copy_file(src_path, dst_path)
			if copy_err != OK:
				d.list_dir_end()
				return copy_err
		entry = d.get_next()
	d.list_dir_end()
	return OK


func _copy_file(source: String, dest: String) -> Error:
	var sf: FileAccess = FileAccess.open(source, FileAccess.READ)
	if sf == null:
		return FileAccess.get_open_error()
	var size: int = int(sf.get_length())
	var bytes: PackedByteArray = sf.get_buffer(size)
	sf.close()
	var df: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
	if df == null:
		return FileAccess.get_open_error()
	if bytes.size() > 0:
		df.store_buffer(bytes)
	df.close()
	return OK
