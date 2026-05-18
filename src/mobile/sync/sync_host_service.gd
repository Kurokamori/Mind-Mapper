extends Node

signal host_state_changed(active: bool)
signal client_count_changed(count: int)
signal host_log_message(severity: String, message: String)
signal incoming_offer_resolved(decision: String, applied_paths: PackedStringArray, kept_mine_paths: PackedStringArray)
signal broadcast_state_changed(folder_path: String, project_id: String, active: bool)
signal incoming_offer_pending(connection_id: int, op_kind: String, client_name: String, address: String, conflicting_paths: Array, incoming_only_paths: Array, outgoing_only_paths: Array)

const PREF_PANEL_ID: String = "lan_sync_host"
const PREF_AUTO_HOST_KEY: String = "auto_host_enabled"
const PREF_HOST_NAME_KEY: String = "host_display_name"
const OFFER_DIALOG_SCENE: PackedScene = preload("res://src/mobile/sync/lan_sync_offer_dialog.tscn")
const MOBILE_MERGE_SHEET_SCENE: PackedScene = preload("res://src/mobile/sync/mobile_merge_resolution_sheet.tscn")

const BROADCAST_ADAPTER_KIND: String = "broadcast_lan_sync"

var _host: LanSyncHost = null
var _connected_clients: Array = []
var _auto_host_enabled: bool = true
var _host_display_name: String = ""
var _open_offer_dialogs: Dictionary = {}
var _standalone_broadcast_project: Project = null
var _standalone_broadcast_folder: String = ""


func _ready() -> void:
	_load_preferences()
	if AppState != null:
		AppState.project_opened.connect(_on_project_opened)
		AppState.project_closed.connect(_on_project_closed)
	if not _is_mobile_platform() and AppState != null and AppState.current_project != null and _auto_host_enabled:
		_start_for_project(AppState.current_project)


func is_supported_on_this_platform() -> bool:
	return true


func is_mobile_platform() -> bool:
	return _is_mobile_platform()


func is_active() -> bool:
	return _host != null and _host.is_running()


func active_folder_path() -> String:
	if _host == null:
		return ""
	var bound: Project = _host.current_project()
	if bound == null:
		return ""
	return bound.folder_path


func active_project_id() -> String:
	if _host == null:
		return ""
	var bound: Project = _host.current_project()
	if bound == null:
		return ""
	return bound.id


func is_broadcasting(folder_path: String) -> bool:
	return is_active() and active_folder_path() == folder_path


func start_broadcasting(folder_path: String) -> Error:
	if folder_path == "":
		return ERR_INVALID_PARAMETER
	if AppState.current_project != null and AppState.current_project.folder_path == folder_path:
		if not is_active():
			_start_for_project(AppState.current_project)
		else:
			broadcast_state_changed.emit(folder_path, AppState.current_project.id, true)
		return OK
	if active_folder_path() == folder_path:
		broadcast_state_changed.emit(folder_path, active_project_id(), true)
		return OK
	var loaded: Project = Project.load_from_folder(folder_path)
	if loaded == null:
		host_log_message.emit("error", "Broadcast failed: cannot load project at %s" % folder_path)
		return ERR_FILE_NOT_FOUND
	if _host != null:
		_stop()
	_standalone_broadcast_project = loaded
	_standalone_broadcast_folder = folder_path
	_start_for_project(loaded)
	return OK


func stop_broadcasting(folder_path: String) -> void:
	if not is_active() or active_folder_path() != folder_path:
		return
	_stop()


func connected_client_count() -> int:
	return _connected_clients.size()


func auto_host_enabled() -> bool:
	return _auto_host_enabled


func set_auto_host_enabled(enabled: bool) -> void:
	if _auto_host_enabled == enabled:
		return
	_auto_host_enabled = enabled
	_save_preferences()
	if enabled and AppState.current_project != null and not is_active():
		_start_for_project(AppState.current_project)
	elif not enabled and is_active():
		_stop()


func host_display_name() -> String:
	if _host_display_name != "":
		return _host_display_name
	var sys: String = OS.get_environment("COMPUTERNAME")
	if sys == "":
		sys = OS.get_environment("HOSTNAME")
	if sys == "":
		sys = "Loom Desktop"
	return sys


func set_host_display_name(value: String) -> void:
	var clean: String = value.strip_edges()
	_host_display_name = clean
	_save_preferences()
	if _host != null:
		_host.set_host_display_name(host_display_name())


func _on_project_opened(project: Project) -> void:
	if project == null:
		return
	if is_active() and active_folder_path() == project.folder_path:
		_standalone_broadcast_project = null
		_standalone_broadcast_folder = ""
		return
	if _is_mobile_platform():
		return
	if not _auto_host_enabled:
		return
	_start_for_project(project)


func _on_project_closed() -> void:
	if _standalone_broadcast_folder != "":
		return
	_stop()


func _start_for_project(project: Project) -> void:
	if project == null:
		return
	if _host != null:
		_stop()
	_host = LanSyncHost.new()
	_host.name = "LanSyncHostInstance"
	_host.bind_project(project)
	_host.set_host_display_name(host_display_name())
	_host.client_connected.connect(_on_client_connected)
	_host.client_disconnected.connect(_on_client_disconnected)
	_host.file_received.connect(_on_file_received)
	_host.offer_received.connect(_on_offer_received)
	_host.offer_finalized.connect(_on_offer_finalized)
	_host.log_message.connect(_on_host_log)
	add_child(_host)
	var err: Error = _host.start()
	if err != OK:
		host_log_message.emit("error", "Failed to start LAN sync host (%d)" % err)
		_stop()
		return
	host_state_changed.emit(true)
	broadcast_state_changed.emit(project.folder_path, project.id, true)


func _stop() -> void:
	var prev_folder: String = active_folder_path()
	var prev_id: String = active_project_id()
	if _host != null:
		_host.stop()
		_host.queue_free()
		_host = null
	_standalone_broadcast_project = null
	_standalone_broadcast_folder = ""
	_connected_clients.clear()
	client_count_changed.emit(0)
	host_state_changed.emit(false)
	if prev_folder != "":
		broadcast_state_changed.emit(prev_folder, prev_id, false)


func _on_client_connected(address: String) -> void:
	if not _connected_clients.has(address):
		_connected_clients.append(address)
	client_count_changed.emit(_connected_clients.size())


func _on_client_disconnected(address: String) -> void:
	_connected_clients.erase(address)
	client_count_changed.emit(_connected_clients.size())


func _on_file_received(relative_path: String, byte_count: int) -> void:
	host_log_message.emit("info", "Received %s (%d bytes) from mobile" % [relative_path, byte_count])
	if relative_path.begins_with(Project.ASSETS_DIR + "/"):
		_notify_editor_asset_streamed(relative_path.get_file())
		return
	_reload_changed_file(relative_path)


func _notify_editor_asset_streamed(asset_name: String) -> void:
	if asset_name == "":
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var editor: Node = tree.get_first_node_in_group(EditorLocator.GROUP_ACTIVE_BOARD_EDITOR)
	if editor != null and editor.has_method("on_asset_streamed"):
		editor.call("on_asset_streamed", asset_name)


func _on_host_log(severity: String, message: String) -> void:
	host_log_message.emit(severity, message)


func _on_offer_received(connection_id: int, op_kind: String, client_name: String, address: String, conflicting_paths: Array, incoming_only_paths: Array, outgoing_only_paths: Array) -> void:
	if _host == null:
		return
	host_log_message.emit("info", "Incoming %s request from %s (%s)" % [op_kind, client_name, address])
	incoming_offer_pending.emit(connection_id, op_kind, client_name, address, conflicting_paths, incoming_only_paths, outgoing_only_paths)
	var viewport: Viewport = _ui_root_for_dialog()
	if viewport == null:
		_host.respond_to_offer(connection_id, LanSyncProtocol.DECISION_REJECT, {})
		host_log_message.emit("warning", "No viewport available to show offer dialog; auto-rejected.")
		return
	var project_name: String = _bound_project_name()
	if _is_mobile_platform():
		var sheet: MobileMergeResolutionSheet = MOBILE_MERGE_SHEET_SCENE.instantiate()
		viewport.add_child(sheet)
		sheet.configure(op_kind, client_name, conflicting_paths, incoming_only_paths, project_name)
		sheet.decision_made.connect(_on_offer_decision_made.bind(connection_id))
		sheet.dialog_dismissed.connect(_on_offer_dialog_dismissed.bind(connection_id))
		_open_offer_dialogs[connection_id] = sheet
		PopupSizer.popup_fit(sheet, {"preferred": Vector2i(680, 720)})
		return
	var dialog: LanSyncOfferDialog = OFFER_DIALOG_SCENE.instantiate()
	viewport.add_child(dialog)
	dialog.configure(op_kind, client_name, conflicting_paths, incoming_only_paths, project_name)
	dialog.decision_made.connect(_on_offer_decision_made.bind(connection_id))
	dialog.dialog_dismissed.connect(_on_offer_dialog_dismissed.bind(connection_id))
	_open_offer_dialogs[connection_id] = dialog
	PopupSizer.popup_fit(dialog, {"preferred": Vector2i(640, 520)})


func bound_project_name() -> String:
	return _bound_project_name()


func _bound_project_name() -> String:
	if _host != null:
		var bound: Project = _host.current_project()
		if bound != null:
			return bound.name
	if AppState != null and AppState.current_project != null:
		return AppState.current_project.name
	return ""


func respond_to_offer(connection_id: int, decision: String, per_file_kept_mine: Dictionary) -> void:
	if _host == null:
		return
	_host.respond_to_offer(connection_id, decision, per_file_kept_mine)


func _on_offer_decision_made(decision: String, per_file_kept_mine: Dictionary, connection_id: int) -> void:
	if _host == null:
		return
	_host.respond_to_offer(connection_id, decision, per_file_kept_mine)


func _on_offer_dialog_dismissed(connection_id: int) -> void:
	_open_offer_dialogs.erase(connection_id)


func _on_offer_finalized(connection_id: int, decision: String, applied_paths: PackedStringArray, kept_mine_paths: PackedStringArray) -> void:
	host_log_message.emit("info", "Offer #%d finalized (%s): %d applied, %d kept-mine" % [connection_id, decision, applied_paths.size(), kept_mine_paths.size()])
	incoming_offer_resolved.emit(decision, applied_paths, kept_mine_paths)


func _ui_root_for_dialog() -> Viewport:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root


func _reload_changed_file(relative_path: String) -> void:
	if AppState.current_project == null:
		return
	if not relative_path.begins_with(Project.BOARDS_DIR + "/") or not relative_path.ends_with(".json"):
		return
	var basename: String = relative_path.get_file()
	var board_id: String = basename.substr(0, basename.length() - 5)
	if board_id == "":
		return
	var board: Board = AppState.current_project.read_board(board_id)
	if board == null:
		return
	if AppState.current_board != null and AppState.current_board.id == board_id:
		AppState.apply_remote_board_snapshot(board)
	else:
		AppState.emit_signal("board_modified", board_id)


func _is_mobile_platform() -> bool:
	var platform: String = OS.get_name()
	return platform == "Android" or platform == "iOS"


func _load_preferences() -> void:
	if UserPrefs == null:
		return
	var stored: Dictionary = UserPrefs.get_panel_layout(PREF_PANEL_ID)
	if stored.has(PREF_AUTO_HOST_KEY):
		_auto_host_enabled = bool(stored[PREF_AUTO_HOST_KEY])
	if stored.has(PREF_HOST_NAME_KEY):
		_host_display_name = String(stored[PREF_HOST_NAME_KEY])


func _save_preferences() -> void:
	if UserPrefs == null:
		return
	UserPrefs.set_panel_layout(PREF_PANEL_ID, {
		PREF_AUTO_HOST_KEY: _auto_host_enabled,
		PREF_HOST_NAME_KEY: _host_display_name,
	})
