class_name MobileProjectPicker
extends Control

signal project_opened(project: Project, source: String, remote_label: String)
signal toast_requested(severity: String, message: String)
signal loading_requested(title: String, subtitle: String)
signal loading_progress(subtitle: String)
signal loading_dismissed()

const RECENT_ROW_SCENE: PackedScene = preload("res://src/mobile/picker/mobile_recent_row.tscn")
const LAN_ROW_SCENE: PackedScene = preload("res://src/mobile/picker/mobile_lan_host_row.tscn")
const NEW_PROJECT_DIALOG_SCENE: PackedScene = preload("res://src/mobile/picker/mobile_new_project_dialog.tscn")
const THEME_DIALOG_SCENE: PackedScene = preload("res://src/editor/dialogs/theme_dialog.tscn")
const KEYBINDINGS_DIALOG_SCENE: PackedScene = preload("res://src/editor/dialogs/keybindings_dialog.tscn")
const JOIN_SESSION_DIALOG_SCENE: PackedScene = preload("res://src/multiplayer/dialogs/join_session_dialog.tscn")

const SETTINGS_THEME_ID: int = 0
const SETTINGS_KEYBINDINGS_ID: int = 1

@onready var _recent_scroll: ScrollContainer = %RecentScroll
@onready var _recent_list: VBoxContainer = %RecentList
@onready var _recent_empty_label: Label = %RecentEmptyLabel
@onready var _new_project_button: Button = %NewProjectButton
@onready var _open_folder_button: Button = %OpenFolderButton
@onready var _import_folder_button: Button = %ImportFolderButton
@onready var _settings_button: MenuButton = %SettingsButton
@onready var _join_multiplayer_button: Button = %JoinMultiplayerButton
@onready var _lan_browser_button: Button = %LanBrowserButton
@onready var _lan_status_label: Label = %LanStatusLabel
@onready var _lan_log_label: RichTextLabel = %LanLogLabel
@onready var _lan_hosts_root: VBoxContainer = %LanHostsRoot
@onready var _lan_empty_label: Label = %LanHostsEmptyLabel
@onready var _folder_picker: FolderPicker = %FolderPicker
@onready var _lan_client: LanSyncClient = %LanClient


func lan_sync_client() -> LanSyncClient:
	return _lan_client

var _registry_entries: Array = []
var _pending_picker_purpose: String = ""
var _pending_new_project_name: String = ""
var _pending_sync_target_folder: String = ""
var _pending_sync_host_entry: Dictionary = {}
var _pending_flow_kind: String = LanSyncClient.FLOW_PULL


func _ready() -> void:
	MobileStoragePaths.ensure_dirs()
	_registry_entries = MobileProjectRegistry.load_entries()
	_new_project_button.pressed.connect(_on_new_project_pressed)
	_open_folder_button.pressed.connect(_on_open_folder_pressed)
	_import_folder_button.pressed.connect(_on_import_folder_pressed)
	_setup_settings_menu()
	_join_multiplayer_button.pressed.connect(_on_join_multiplayer_pressed)
	_lan_browser_button.toggled.connect(_on_lan_browser_toggled)
	_folder_picker.folder_chosen.connect(_on_folder_chosen)
	_folder_picker.folder_pick_cancelled.connect(_on_folder_pick_cancelled)
	_folder_picker.pick_error.connect(_on_folder_pick_error)
	_lan_client.hosts_changed.connect(_on_lan_hosts_changed)
	_lan_client.sync_progress.connect(_on_sync_progress)
	_lan_client.sync_completed.connect(_on_sync_completed)
	_lan_client.sync_failed.connect(_on_sync_failed)
	_lan_client.offer_decision_received.connect(_on_offer_decision_received)
	_lan_client.offer_review_result.connect(_on_offer_review_result)
	_lan_client.log_message.connect(_on_lan_log)
	var resolved_name: String = MobileLanIdentity.resolve_display_name()
	_lan_client.set_display_name(resolved_name)
	MobileLanIdentity.set_display_name(resolved_name)
	_lan_status_label.text = "LAN sync idle"
	_clear_log()
	_render_recent_list()
	_render_lan_hosts([])
	visibility_changed.connect(_on_visibility_changed)
	if SyncHostService != null and not SyncHostService.broadcast_state_changed.is_connected(_on_broadcast_state_changed):
		SyncHostService.broadcast_state_changed.connect(_on_broadcast_state_changed)
	call_deferred("_auto_start_discovery_if_visible")


func _auto_start_discovery_if_visible() -> void:
	if visible and not _lan_browser_button.button_pressed:
		_lan_browser_button.button_pressed = true


func _setup_settings_menu() -> void:
	var popup: PopupMenu = _settings_button.get_popup()
	popup.clear()
	popup.add_item("Theme & Fonts", SETTINGS_THEME_ID)
	popup.add_item("Keybindings", SETTINGS_KEYBINDINGS_ID)
	if not popup.id_pressed.is_connected(_on_settings_menu_id_pressed):
		popup.id_pressed.connect(_on_settings_menu_id_pressed)


func _on_settings_menu_id_pressed(id: int) -> void:
	match id:
		SETTINGS_THEME_ID:
			_open_theme_dialog()
		SETTINGS_KEYBINDINGS_ID:
			_open_keybindings_dialog()


func _open_theme_dialog() -> void:
	var dlg: Window = THEME_DIALOG_SCENE.instantiate()
	add_child(dlg)
	PopupSizer.popup_fit(dlg, {"preferred": Vector2i(880, 680)})


func _open_keybindings_dialog() -> void:
	var dlg: Window = KEYBINDINGS_DIALOG_SCENE.instantiate()
	add_child(dlg)
	PopupSizer.popup_fit(dlg, {"preferred": Vector2i(880, 680)})


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
		row.broadcast_toggle_requested.connect(_on_recent_row_broadcast_toggle)
		var folder_path: String = String(entry.get(MobileProjectRegistry.FIELD_FOLDER, ""))
		if folder_path != "" and SyncHostService != null and SyncHostService.is_broadcasting(folder_path):
			row.set_broadcast_active(true)


func _on_recent_row_open(folder_path: String, source: String, remote_label: String) -> void:
	_open_project_from_folder(folder_path, source, remote_label)


func _on_recent_row_broadcast_toggle(folder_path: String, want_active: bool) -> void:
	if SyncHostService == null:
		toast_requested.emit("warning", "LAN broadcast unavailable on this build")
		_refresh_broadcast_rows()
		return
	if want_active:
		var err: Error = SyncHostService.start_broadcasting(folder_path)
		if err != OK:
			toast_requested.emit("error", "Could not start broadcast (%d)" % err)
			_refresh_broadcast_rows()
	else:
		SyncHostService.stop_broadcasting(folder_path)


func _on_broadcast_state_changed(_folder_path: String, _project_id: String, _active: bool) -> void:
	_refresh_broadcast_rows()


func _refresh_broadcast_rows() -> void:
	for child: Node in _recent_list.get_children():
		var row: MobileRecentRow = child as MobileRecentRow
		if row == null:
			continue
		var folder_path: String = row.folder_path()
		var is_broadcasting: bool = false
		if folder_path != "" and SyncHostService != null:
			is_broadcasting = SyncHostService.is_broadcasting(folder_path)
		row.set_broadcast_active(is_broadcasting)


func _on_recent_row_remove(folder_path: String) -> void:
	_registry_entries = MobileProjectRegistry.remove(_registry_entries, folder_path)
	MobileProjectRegistry.save_entries(_registry_entries)
	_render_recent_list()
	toast_requested.emit("info", "Removed from recent projects")


func _on_new_project_pressed() -> void:
	var dialog: MobileNewProjectDialog = NEW_PROJECT_DIALOG_SCENE.instantiate()
	add_child(dialog)
	PopupSizer.popup_fit(dialog, {"preferred": Vector2i(560, 360)})
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


func _on_join_multiplayer_pressed() -> void:
	var dialog: JoinSessionDialog = JOIN_SESSION_DIALOG_SCENE.instantiate()
	add_child(dialog)
	dialog.join_confirmed.connect(_on_join_session_confirmed)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	PopupSizer.popup_fit(dialog, {"preferred": Vector2i(680, 520)})


func _on_join_session_confirmed(adapter_kind: String, connect_info: Dictionary) -> void:
	if MultiplayerService.is_in_session():
		MultiplayerService.leave_session()
	var lobby_payload: Dictionary = connect_info.duplicate(true)
	if String(lobby_payload.get("project_id", "")) == "":
		_start_multiplayer_direct_join(adapter_kind, lobby_payload)
		return
	var lobby_label: String = String(lobby_payload.get("project_name", "session"))
	if lobby_label == "":
		lobby_label = "session"
	var host_label: String = String(lobby_payload.get("host_display_name", "Host"))
	loading_requested.emit("Joining %s…" % lobby_label, "Resolving project and connecting")
	var project: Project = MultiplayerService.resolve_or_bootstrap_join_project(lobby_payload)
	if project == null:
		loading_dismissed.emit()
		toast_requested.emit("error", "Cannot resolve a local project for the chosen session")
		return
	MultiplayerService.set_pending_auto_join(adapter_kind, lobby_payload)
	_remember_and_open(project, project.folder_path, MobileProjectRegistry.SOURCE_SYNCED, host_label)


func _start_multiplayer_direct_join(adapter_kind: String, connect_info: Dictionary) -> void:
	var host_label: String = _format_direct_host_label(adapter_kind, connect_info)
	if not MultiplayerService.direct_join_bootstrap_ready.is_connected(_on_direct_join_bootstrap_ready):
		MultiplayerService.direct_join_bootstrap_ready.connect(_on_direct_join_bootstrap_ready)
	if not MultiplayerService.direct_join_failed.is_connected(_on_direct_join_failed):
		MultiplayerService.direct_join_failed.connect(_on_direct_join_failed)
	loading_requested.emit("Connecting to %s…" % host_label, "Probing host for project info")
	var err: Error = MultiplayerService.begin_direct_join_probe(adapter_kind, connect_info)
	if err != OK:
		loading_dismissed.emit()
		_disconnect_direct_join_signals()
		toast_requested.emit("error", "Could not start direct connect (error %d)" % err)


func _format_direct_host_label(adapter_kind: String, connect_info: Dictionary) -> String:
	match adapter_kind:
		NetworkAdapter.ADAPTER_KIND_ENET:
			var addr: String = String(connect_info.get("address", "127.0.0.1"))
			var port: int = int(connect_info.get("port", EnetAdapter.DEFAULT_PORT))
			return "%s:%d" % [addr, port]
		NetworkAdapter.ADAPTER_KIND_WEBRTC:
			var room: String = String(connect_info.get("room", ""))
			return "room %s" % room if room != "" else "WebRTC room"
		_:
			return "host"


func _on_direct_join_bootstrap_ready(project: Project, adapter_kind: String, connect_info: Dictionary) -> void:
	_disconnect_direct_join_signals()
	if project == null:
		loading_dismissed.emit()
		toast_requested.emit("error", "Direct connect succeeded but no project could be opened")
		return
	MultiplayerService.set_pending_auto_join(adapter_kind, connect_info)
	var host_label: String = _format_direct_host_label(adapter_kind, connect_info)
	_remember_and_open(project, project.folder_path, MobileProjectRegistry.SOURCE_SYNCED, host_label)


func _on_direct_join_failed(reason: String) -> void:
	_disconnect_direct_join_signals()
	loading_dismissed.emit()
	var message: String = reason if reason != "" else "Direct connect failed"
	toast_requested.emit("error", "Direct connect failed: %s" % message)


func _disconnect_direct_join_signals() -> void:
	if MultiplayerService.direct_join_bootstrap_ready.is_connected(_on_direct_join_bootstrap_ready):
		MultiplayerService.direct_join_bootstrap_ready.disconnect(_on_direct_join_bootstrap_ready)
	if MultiplayerService.direct_join_failed.is_connected(_on_direct_join_failed):
		MultiplayerService.direct_join_failed.disconnect(_on_direct_join_failed)


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
		var local_folder: String = ""
		var local_name: String = ""
		var project_id: String = String(entry.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_ID, ""))
		if project_id != "":
			var match_idx: int = MobileProjectRegistry.find_index_by_project_id(_registry_entries, project_id)
			if match_idx >= 0:
				var registry_entry: Dictionary = _registry_entries[match_idx]
				local_folder = String(registry_entry.get(MobileProjectRegistry.FIELD_FOLDER, ""))
				local_name = String(registry_entry.get(MobileProjectRegistry.FIELD_NAME, ""))
				if local_folder != "" and not DirAccess.dir_exists_absolute(local_folder):
					local_folder = ""
		row.bind(entry, local_folder, local_name)
		row.pull_requested.connect(_on_lan_host_pull_requested)
		row.push_requested.connect(_on_lan_host_push_requested)
		row.sync_requested.connect(_on_lan_host_sync_requested)


func _on_lan_host_pull_requested(host_entry: Dictionary) -> void:
	var project_id: String = String(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_ID, ""))
	var project_name: String = String(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_NAME, "Synced project"))
	var host_label: String = String(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_HOST_NAME, "Desktop"))
	var existing_idx: int = -1
	if project_id != "":
		existing_idx = MobileProjectRegistry.find_index_by_project_id(_registry_entries, project_id)
	var target_folder: String = ""
	if existing_idx >= 0:
		var existing: Dictionary = _registry_entries[existing_idx]
		target_folder = String(existing.get(MobileProjectRegistry.FIELD_FOLDER, ""))
	if target_folder == "":
		target_folder = MobileStoragePaths.unique_folder(MobileStoragePaths.synced_root(), project_name)
	_pending_sync_target_folder = target_folder
	_pending_sync_host_entry = host_entry
	_pending_flow_kind = LanSyncClient.FLOW_PULL
	_lan_status_label.text = "Syncing '%s' from %s…" % [project_name, host_label]
	loading_requested.emit("Pulling '%s' from %s…" % [project_name, host_label], "Negotiating with host")
	var err: Error = _lan_client.begin_sync(host_entry, target_folder)
	if err != OK:
		_lan_status_label.text = "Sync could not start (%d)" % err
		toast_requested.emit("error", "Could not start sync")
		loading_dismissed.emit()


func _on_lan_host_push_requested(host_entry: Dictionary, local_folder: String) -> void:
	var project_name: String = String(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_NAME, "Project"))
	var host_label: String = String(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_HOST_NAME, "Desktop"))
	_pending_sync_target_folder = local_folder
	_pending_sync_host_entry = host_entry
	_pending_flow_kind = LanSyncClient.FLOW_PUSH
	_lan_status_label.text = "Offering push of '%s' to %s…" % [project_name, host_label]
	loading_requested.emit("Pushing '%s' to %s…" % [project_name, host_label], "Awaiting host decision")
	var err: Error = _lan_client.begin_push(host_entry, local_folder)
	if err != OK:
		_lan_status_label.text = "Push could not start (%d)" % err
		toast_requested.emit("error", "Could not start push")
		loading_dismissed.emit()


func _on_lan_host_sync_requested(host_entry: Dictionary, local_folder: String) -> void:
	var project_name: String = String(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_NAME, "Project"))
	var host_label: String = String(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_HOST_NAME, "Desktop"))
	_pending_sync_target_folder = local_folder
	_pending_sync_host_entry = host_entry
	_pending_flow_kind = LanSyncClient.FLOW_SYNC
	_lan_status_label.text = "Two-way syncing '%s' with %s…" % [project_name, host_label]
	loading_requested.emit("Two-way sync '%s' with %s…" % [project_name, host_label], "Negotiating with host")
	var err: Error = _lan_client.begin_two_way_sync(host_entry, local_folder)
	if err != OK:
		_lan_status_label.text = "Sync could not start (%d)" % err
		toast_requested.emit("error", "Could not start sync")
		loading_dismissed.emit()


func _on_offer_decision_received(decision: String, op_kind: String) -> void:
	match decision:
		LanSyncProtocol.DECISION_REJECT:
			if op_kind == LanSyncClient.FLOW_SYNC:
				_lan_status_label.text = "Desktop rejected push; pulling only…"
				toast_requested.emit("info", "Desktop rejected push. Pulling changes only.")
				loading_progress.emit("Desktop rejected push — pulling only…")
			else:
				_lan_status_label.text = "Desktop rejected push."
				toast_requested.emit("warning", "Desktop rejected the push.")
				loading_dismissed.emit()
		LanSyncProtocol.DECISION_REJECT_AND_BLOCK:
			_lan_status_label.text = "Desktop rejected & blocked this device."
			toast_requested.emit("error", "Desktop blocked further sync from this device.")
			loading_dismissed.emit()
		LanSyncProtocol.DECISION_ACCEPT_ALL:
			_lan_status_label.text = "Desktop accepted: newest-wins merge in progress…"
			loading_progress.emit("Desktop accepted — merging…")
		LanSyncProtocol.DECISION_ACCEPT_REVIEW:
			_lan_status_label.text = "Desktop is reviewing conflicts…"
			loading_progress.emit("Desktop is reviewing conflicts…")


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
	toast_requested.emit("info", "Desktop merge done: %d accepted, %d kept by desktop." % [kept_theirs, kept_mine])


func _on_sync_progress(stage: String, current: int, total: int, current_path: String) -> void:
	var subtitle: String = ""
	match stage:
		LanSyncClient.STAGE_MANIFEST:
			subtitle = "Receiving project manifest…"
		LanSyncClient.STAGE_OFFER:
			subtitle = "Waiting for desktop to respond to offer…"
		LanSyncClient.STAGE_PUSH:
			if total > 0:
				subtitle = "Pushing %d/%d: %s" % [current, total, current_path]
			else:
				subtitle = "Pushing files…"
		LanSyncClient.STAGE_REVIEW:
			subtitle = "Desktop is finalizing merge…"
		_:
			if total > 0:
				subtitle = "Pulling %d/%d: %s" % [current, total, current_path]
			else:
				subtitle = "Pulling files…"
	_lan_status_label.text = subtitle
	loading_progress.emit(subtitle)


func _on_sync_completed(project_folder: String, project_id: String) -> void:
	_lan_status_label.text = "Sync complete: %s" % project_folder
	var host_label: String = String(_pending_sync_host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_HOST_NAME, ""))
	var project: Project = Project.load_from_folder(project_folder)
	if project == null:
		toast_requested.emit("error", "Synced project failed to open")
		loading_dismissed.emit()
		return
	if project_id != "" and project.id != project_id:
		toast_requested.emit("warning", "Synced project ID mismatched")
	_pending_sync_target_folder = ""
	_pending_sync_host_entry = {}
	loading_progress.emit("Opening synced project…")
	_remember_and_open(project, project_folder, MobileProjectRegistry.SOURCE_SYNCED, host_label)


func _on_sync_failed(reason: String) -> void:
	_lan_status_label.text = "Sync failed: %s" % reason
	toast_requested.emit("error", "Sync failed (%s)" % reason)
	_pending_sync_target_folder = ""
	_pending_sync_host_entry = {}
	loading_dismissed.emit()


func _on_lan_log(severity: String, message: String) -> void:
	_append_log(severity, message)
	if severity == "error":
		toast_requested.emit("error", message)

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
