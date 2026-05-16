extends Node

signal host_state_changed(active: bool)
signal client_count_changed(count: int)
signal host_log_message(severity: String, message: String)

const PREF_PANEL_ID: String = "lan_sync_host"
const PREF_AUTO_HOST_KEY: String = "auto_host_enabled"
const PREF_HOST_NAME_KEY: String = "host_display_name"

var _host: LanSyncHost = null
var _connected_clients: Array = []
var _auto_host_enabled: bool = true
var _host_display_name: String = ""


func _ready() -> void:
	if _is_mobile_platform():
		set_process(false)
		return
	_load_preferences()
	AppState.project_opened.connect(_on_project_opened)
	AppState.project_closed.connect(_on_project_closed)
	if AppState.current_project != null and _auto_host_enabled:
		_start_for_project(AppState.current_project)


func is_supported_on_this_platform() -> bool:
	return not _is_mobile_platform()


func is_active() -> bool:
	return _host != null and _host.is_running()


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
	if not _auto_host_enabled:
		return
	_start_for_project(project)


func _on_project_closed() -> void:
	_stop()


func _start_for_project(project: Project) -> void:
	if project == null or _is_mobile_platform():
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
	_host.log_message.connect(_on_host_log)
	add_child(_host)
	var err: Error = _host.start()
	if err != OK:
		host_log_message.emit("error", "Failed to start LAN sync host (%d)" % err)
		_stop()
		return
	host_state_changed.emit(true)


func _stop() -> void:
	if _host != null:
		_host.stop()
		_host.queue_free()
		_host = null
	_connected_clients.clear()
	client_count_changed.emit(0)
	host_state_changed.emit(false)


func _on_client_connected(address: String) -> void:
	if not _connected_clients.has(address):
		_connected_clients.append(address)
	client_count_changed.emit(_connected_clients.size())


func _on_client_disconnected(address: String) -> void:
	_connected_clients.erase(address)
	client_count_changed.emit(_connected_clients.size())


func _on_file_received(relative_path: String, byte_count: int) -> void:
	host_log_message.emit("info", "Received %s (%d bytes) from mobile" % [relative_path, byte_count])
	_reload_changed_file(relative_path)


func _on_host_log(severity: String, message: String) -> void:
	host_log_message.emit(severity, message)


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
