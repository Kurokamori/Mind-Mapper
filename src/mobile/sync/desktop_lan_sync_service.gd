extends Node

signal hosts_changed(hosts: Array)
signal status_changed(message: String)
signal flow_started(flow: String, host_entry: Dictionary)
signal flow_progress(stage: String, current: int, total: int, current_path: String)
signal flow_completed(folder_path: String, project_id: String, flow: String, host_entry: Dictionary)
signal flow_failed(reason: String, flow: String, host_entry: Dictionary)
signal review_requested(conflicting_paths: Array, host_name: String, project_name: String)
signal log_message(severity: String, message: String)

const REVIEW_DIALOG_SCENE: PackedScene = preload("res://src/mobile/sync/lan_sync_offer_dialog.tscn")
const PREF_PANEL_ID: String = "desktop_lan_sync_client"
const PREF_DISPLAY_NAME_KEY: String = "client_display_name"
const PULL_ROOT_USER_PATH: String = "user://lan_pulled_projects"

var _client: LanSyncClient = null
var _client_display_name: String = ""
var _active_host_entry: Dictionary = {}
var _active_flow: String = ""
var _last_status: String = ""
var _review_dialog: LanSyncOfferDialog = null


func _ready() -> void:
	if _is_mobile_platform():
		set_process(false)
		return
	_load_preferences()
	_client = LanSyncClient.new()
	_client.name = "DesktopLanSyncClient"
	add_child(_client)
	_client.set_display_name(effective_display_name())
	_client.hosts_changed.connect(_on_hosts_changed)
	_client.sync_progress.connect(_on_sync_progress)
	_client.sync_completed.connect(_on_sync_completed)
	_client.sync_failed.connect(_on_sync_failed)
	_client.connection_state_changed.connect(_on_client_state_changed)
	_client.offer_decision_received.connect(_on_offer_decision_received)
	_client.offer_review_result.connect(_on_offer_review_result)
	_client.defer_review_requested.connect(_on_defer_review_requested)
	_client.log_message.connect(_on_client_log)
	var err: Error = _client.start_discovery()
	if err != OK:
		_emit_status("LAN discovery unavailable (%d)" % err)
	else:
		_emit_status("Scanning LAN for project broadcasts…")


func is_supported_on_this_platform() -> bool:
	return not _is_mobile_platform()


func discovered_hosts() -> Array:
	if _client == null:
		return []
	return _client.known_hosts()


func last_status() -> String:
	return _last_status


func effective_display_name() -> String:
	if _client_display_name != "":
		return _client_display_name
	var sys: String = OS.get_environment("COMPUTERNAME")
	if sys == "":
		sys = OS.get_environment("HOSTNAME")
	if sys == "":
		sys = "Loom Desktop"
	return sys


func set_display_name(value: String) -> void:
	_client_display_name = value.strip_edges()
	_save_preferences()
	if _client != null:
		_client.set_display_name(effective_display_name())


func begin_pull(host_entry: Dictionary, target_folder: String = "") -> Error:
	var folder: String = _resolve_target_folder(host_entry, target_folder, true)
	if folder == "":
		return ERR_INVALID_PARAMETER
	_active_host_entry = host_entry.duplicate(true)
	_active_flow = LanSyncClient.FLOW_PULL
	flow_started.emit(_active_flow, _active_host_entry)
	_emit_status("Pulling '%s'…" % _project_name_for(host_entry))
	return _client.begin_sync(host_entry, folder)


func begin_push(host_entry: Dictionary, source_folder: String) -> Error:
	if source_folder == "":
		return ERR_INVALID_PARAMETER
	_active_host_entry = host_entry.duplicate(true)
	_active_flow = LanSyncClient.FLOW_PUSH
	flow_started.emit(_active_flow, _active_host_entry)
	_emit_status("Offering push of '%s'…" % _project_name_for(host_entry))
	return _client.begin_push(host_entry, source_folder)


func begin_two_way_sync(host_entry: Dictionary, project_folder: String) -> Error:
	if project_folder == "":
		return ERR_INVALID_PARAMETER
	_active_host_entry = host_entry.duplicate(true)
	_active_flow = LanSyncClient.FLOW_SYNC
	flow_started.emit(_active_flow, _active_host_entry)
	_emit_status("Two-way syncing '%s'…" % _project_name_for(host_entry))
	return _client.begin_two_way_sync(host_entry, project_folder)


func find_local_folder_for_host(host_entry: Dictionary) -> String:
	var project_id: String = String(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_ID, ""))
	if project_id == "" or ProjectStore == null:
		return ""
	for entry_v: Variant in ProjectStore.recent():
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		if String(entry.get("id", "")) == project_id:
			var folder: String = String(entry.get("folder_path", ""))
			if folder != "" and DirAccess.dir_exists_absolute(folder):
				return folder
	return ""


func _resolve_target_folder(host_entry: Dictionary, target_folder: String, allow_new: bool) -> String:
	if target_folder != "":
		return target_folder
	var match: String = find_local_folder_for_host(host_entry)
	if match != "":
		return match
	if not allow_new:
		return ""
	var pulled_root: String = ProjectSettings.globalize_path(PULL_ROOT_USER_PATH)
	if pulled_root == "":
		pulled_root = OS.get_user_data_dir().path_join("lan_pulled_projects")
	pulled_root = pulled_root.replace("\\", "/")
	if not DirAccess.dir_exists_absolute(pulled_root):
		DirAccess.make_dir_recursive_absolute(pulled_root)
	var base_name: String = String(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_NAME, "synced_project")).strip_edges()
	if base_name == "":
		base_name = "synced_project"
	var safe: String = base_name.replace(" ", "_")
	var candidate: String = pulled_root.path_join(safe)
	var counter: int = 1
	while DirAccess.dir_exists_absolute(candidate):
		candidate = pulled_root.path_join("%s_%d" % [safe, counter])
		counter += 1
	DirAccess.make_dir_recursive_absolute(candidate)
	return candidate


func _on_hosts_changed(host_list: Array) -> void:
	hosts_changed.emit(host_list)


func _on_sync_progress(stage: String, current: int, total: int, current_path: String) -> void:
	flow_progress.emit(stage, current, total, current_path)
	match stage:
		LanSyncClient.STAGE_MANIFEST:
			_emit_status("Receiving manifest…")
		LanSyncClient.STAGE_OFFER:
			_emit_status("Waiting for host to respond to the offer…")
		LanSyncClient.STAGE_PUSH:
			if total > 0:
				_emit_status("Pushing %d/%d: %s" % [current, total, current_path])
			else:
				_emit_status("Pushing files…")
		LanSyncClient.STAGE_REVIEW:
			_emit_status("Host is finalizing the merge…")
		LanSyncClient.STAGE_FILES:
			if total > 0:
				_emit_status("Pulling %d/%d: %s" % [current, total, current_path])
			else:
				_emit_status("Pulling files…")


func _on_sync_completed(project_folder: String, project_id: String) -> void:
	_emit_status("Sync complete: %s" % project_folder)
	var host_copy: Dictionary = _active_host_entry.duplicate(true)
	var flow: String = _active_flow
	_active_host_entry = {}
	_active_flow = ""
	flow_completed.emit(project_folder, project_id, flow, host_copy)


func _on_sync_failed(reason: String) -> void:
	_emit_status("Sync failed: %s" % reason)
	var host_copy: Dictionary = _active_host_entry.duplicate(true)
	var flow: String = _active_flow
	_active_host_entry = {}
	_active_flow = ""
	flow_failed.emit(reason, flow, host_copy)


func _on_client_state_changed(state: int) -> void:
	if state == LanSyncClient.STATE_ERROR and _active_flow != "":
		# error path already drained via sync_failed
		pass


func _on_offer_decision_received(decision: String, op_kind: String) -> void:
	match decision:
		LanSyncProtocol.DECISION_REJECT:
			_emit_status("Host rejected the offer.")
		LanSyncProtocol.DECISION_REJECT_AND_BLOCK:
			_emit_status("Host rejected and blocked this desktop.")
		LanSyncProtocol.DECISION_ACCEPT_ALL:
			_emit_status("Host accepted: newest-wins merge in progress…")
		LanSyncProtocol.DECISION_ACCEPT_REVIEW:
			_emit_status("Host is reviewing %s conflicts…" % op_kind)
		LanSyncProtocol.DECISION_DEFER_TO_REQUESTER:
			_emit_status("Host asked you to resolve the merge here.")


func _on_offer_review_result(resolutions: Array) -> void:
	var kept_mine: int = 0
	var kept_theirs: int = 0
	for entry_v: Variant in resolutions:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		if bool((entry_v as Dictionary).get(LanSyncProtocol.OFFER_FIELD_KEPT_MINE, false)):
			kept_mine += 1
		else:
			kept_theirs += 1
	if resolutions.is_empty():
		return
	_emit_status("Host merge done: %d accepted, %d kept by host." % [kept_theirs, kept_mine])


func _on_defer_review_requested(conflicting_paths: Array, _incoming_only_paths: Array, host_name: String, project_name: String, op_kind: String) -> void:
	review_requested.emit(conflicting_paths.duplicate(), host_name, project_name)
	var viewport: Viewport = _ui_root_for_dialog()
	if viewport == null:
		_client.cancel_offer_resolution()
		_emit_status("No viewport available for desktop merge review; cancelled.")
		return
	if _review_dialog != null and is_instance_valid(_review_dialog):
		_review_dialog.queue_free()
	_review_dialog = REVIEW_DIALOG_SCENE.instantiate()
	viewport.add_child(_review_dialog)
	_review_dialog.configure_review_only(host_name, project_name, conflicting_paths, op_kind)
	_review_dialog.decision_made.connect(_on_review_decision_made)
	_review_dialog.dialog_dismissed.connect(_on_review_dialog_dismissed)
	PopupSizer.popup_fit(_review_dialog, {"preferred": Vector2i(640, 600)})


func _on_review_decision_made(decision: String, per_file_kept_mine: Dictionary) -> void:
	if _client == null:
		return
	if decision == LanSyncProtocol.DECISION_ACCEPT_REVIEW:
		var err: Error = _client.submit_offer_resolution(per_file_kept_mine)
		if err != OK:
			_emit_status("Could not submit merge resolution (%d)" % err)
	else:
		_client.cancel_offer_resolution()
		_emit_status("Merge cancelled by user.")


func _on_review_dialog_dismissed() -> void:
	_review_dialog = null


func _on_client_log(severity: String, message: String) -> void:
	log_message.emit(severity, message)


func _project_name_for(host_entry: Dictionary) -> String:
	return String(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_NAME, "project"))


func _emit_status(message: String) -> void:
	_last_status = message
	status_changed.emit(message)


func _ui_root_for_dialog() -> Viewport:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root


func _is_mobile_platform() -> bool:
	var platform: String = OS.get_name()
	return platform == "Android" or platform == "iOS"


func _load_preferences() -> void:
	if UserPrefs == null:
		return
	var stored: Dictionary = UserPrefs.get_panel_layout(PREF_PANEL_ID)
	if stored.has(PREF_DISPLAY_NAME_KEY):
		_client_display_name = String(stored[PREF_DISPLAY_NAME_KEY])


func _save_preferences() -> void:
	if UserPrefs == null:
		return
	UserPrefs.set_panel_layout(PREF_PANEL_ID, {
		PREF_DISPLAY_NAME_KEY: _client_display_name,
	})
