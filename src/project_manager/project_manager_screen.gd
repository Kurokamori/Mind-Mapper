class_name ProjectManagerScreen
extends Control

signal project_chosen(project: Project)
signal loading_requested(title: String, subtitle: String)

@onready var _grid_container: VBoxContainer = %GridContainer
@onready var _empty_label: Label = %EmptyLabel
@onready var _scroll: ScrollContainer = %Scroll
@onready var _new_button: Button = %NewButton
@onready var _open_button: Button = %OpenButton
@onready var _create_dialog: FileDialog = %CreateDialog
@onready var _open_dialog: FileDialog = %OpenDialog
@onready var _name_dialog: AcceptDialog = %NameDialog
@onready var _name_edit: LineEdit = %NameEdit
@onready var _join_session_button: Button = %JoinSessionButton
@onready var _settings_button: MenuButton = %SettingsButton
@onready var _host_session_dialog: HostSessionDialog = %HostSessionDialog
@onready var _join_session_dialog: JoinSessionDialog = %JoinSessionDialog
@onready var _remote_browser: DesktopLanBrowserPanel = %RemoteBrowser
@onready var _remote_section_header: Label = %RemoteSectionHeader
@onready var _broadcasts_indicator: Label = %BroadcastsIndicator
@onready var _broadcasts_toggle: Button = %BroadcastsToggleButton
@onready var _section_header: Label = $CenterMargin/ContentLimit/ContentPanel/Margins/VBox/SectionHeader

const SETTINGS_THEME_ID: int = 0
const SETTINGS_KEYBINDINGS_ID: int = 1

const THEME_DIALOG_SCENE: PackedScene = preload("res://src/editor/dialogs/theme_dialog.tscn")
const KEYBINDINGS_DIALOG_SCENE: PackedScene = preload("res://src/editor/dialogs/keybindings_dialog.tscn")

const BROADCASTS_INACTIVE_COLOR: Color = Color(0.55, 0.6, 0.7, 1)
const BROADCASTS_ACTIVE_COLOR: Color = Color(0.35, 0.85, 0.45, 1)

var _pending_create_folder: String = ""
var _pending_host_folder: String = ""
var _live_lobbies_by_project_id: Dictionary = {}
var _showing_remote_view: bool = false
var _last_known_broadcasts_count: int = 0


func _ready() -> void:
	_apply_prominent_scrollbar()
	_name_dialog.add_cancel_button("Cancel")
	_new_button.pressed.connect(_on_new_pressed)
	_open_button.pressed.connect(_on_open_pressed)
	_create_dialog.dir_selected.connect(_on_create_folder_chosen)
	_open_dialog.dir_selected.connect(_on_open_folder_chosen)
	_name_dialog.confirmed.connect(_on_create_confirmed)
	_join_session_button.pressed.connect(_on_join_session_pressed)
	_host_session_dialog.host_confirmed.connect(_on_host_session_confirmed)
	_join_session_dialog.join_confirmed.connect(_on_join_session_confirmed)
	_setup_settings_menu()
	ProjectStore.recent_changed.connect(_refresh)
	MultiplayerService.lobby_list_updated.connect(_on_lobby_list_updated)
	SyncHostService.broadcast_state_changed.connect(_on_broadcast_state_changed)
	_broadcasts_toggle.pressed.connect(_on_broadcasts_toggle_pressed)
	_remote_browser.host_pulled.connect(_on_remote_host_pulled)
	_remote_browser.host_synced.connect(_on_remote_host_synced)
	_remote_browser.toast_requested.connect(_on_remote_toast_requested)
	if DesktopLanSyncService != null:
		DesktopLanSyncService.hosts_changed.connect(_on_remote_hosts_changed)
		_update_broadcasts_indicator(DesktopLanSyncService.discovered_hosts().size())
	else:
		_update_broadcasts_indicator(0)
	_apply_view_mode()
	_refresh()
	_request_lobby_discovery()


func _apply_prominent_scrollbar() -> void:
	if _scroll == null:
		return
	var vbar: VScrollBar = _scroll.get_v_scroll_bar()
	if vbar != null:
		vbar.theme_type_variation = &"ProminentScrollbar"
		vbar.custom_minimum_size = Vector2(14, 0)
	var hbar: HScrollBar = _scroll.get_h_scroll_bar()
	if hbar != null:
		hbar.theme_type_variation = &"ProminentScrollbarH"
		hbar.custom_minimum_size = Vector2(0, 14)


func _request_lobby_discovery() -> void:
	for kind: String in [NetworkAdapter.ADAPTER_KIND_LAN, NetworkAdapter.ADAPTER_KIND_STEAM]:
		if MultiplayerService.is_adapter_available(kind):
			MultiplayerService.discover_lobbies(kind, {"format_version": Project.FORMAT_VERSION})


func _on_lobby_list_updated(adapter_kind: String, lobbies: Array) -> void:
	for entry_v: Variant in lobbies:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var project_id: String = String(entry.get("project_id", ""))
		if project_id == "":
			continue
		entry["adapter_kind"] = adapter_kind
		_live_lobbies_by_project_id[project_id] = entry
	_refresh()


func _refresh() -> void:
	for child in _grid_container.get_children():
		child.queue_free()
	var entries: Array = ProjectStore.recent()
	_empty_label.visible = entries.is_empty() and not _showing_remote_view
	for entry in entries:
		var card: ProjectCard = ProjectCard.create()
		card.bind(entry)
		card.open_requested.connect(_on_card_open)
		card.forget_requested.connect(_on_card_forget)
		card.join_live_requested.connect(_on_card_join_live)
		card.host_requested.connect(_on_card_host_requested)
		card.broadcast_toggle_requested.connect(_on_card_broadcast_toggle_requested)
		_grid_container.add_child(card)
		var project_id: String = String(entry.get("id", ""))
		if project_id != "" and _live_lobbies_by_project_id.has(project_id):
			var lobby: Dictionary = _live_lobbies_by_project_id[project_id]
			card.mark_live(lobby, String(lobby.get("adapter_kind", "")))
		var folder_path: String = String(entry.get("folder_path", ""))
		if folder_path != "" and SyncHostService.is_broadcasting(folder_path):
			card.set_broadcast_active(true)


func _on_card_join_live(folder_path: String, lobby_entry: Dictionary, adapter_kind: String) -> void:
	var project: Project = ProjectStore.open_project(folder_path)
	if project == null:
		return
	MultiplayerService.set_pending_auto_join(adapter_kind, lobby_entry)
	emit_signal("project_chosen", project)


func _on_card_host_requested(folder_path: String) -> void:
	_pending_host_folder = folder_path
	PopupSizer.popup_fit(_host_session_dialog, {"preferred": Vector2i(520, 280)})


func _on_host_session_confirmed(adapter_kind: String, settings: Dictionary) -> void:
	var folder_path: String = _pending_host_folder
	_pending_host_folder = ""
	if folder_path == "":
		return
	if adapter_kind == SyncHostService.BROADCAST_ADAPTER_KIND:
		var err: Error = SyncHostService.start_broadcasting(folder_path)
		if err != OK:
			_show_inline_message("Could not start LAN broadcast (%d)." % err)
		return
	if MultiplayerService.is_in_session():
		MultiplayerService.leave_session()
	var project: Project = ProjectStore.open_project(folder_path)
	if project == null:
		push_warning("ProjectManagerScreen: failed to open project at %s for hosting" % folder_path)
		return
	MultiplayerService.set_pending_auto_host(adapter_kind, settings)
	emit_signal("project_chosen", project)


func _on_card_broadcast_toggle_requested(folder_path: String, want_active: bool) -> void:
	if folder_path == "":
		return
	if want_active:
		var err: Error = SyncHostService.start_broadcasting(folder_path)
		if err != OK:
			_show_inline_message("Could not start LAN broadcast (%d)." % err)
			_refresh_broadcast_state_for_folder(folder_path)
	else:
		SyncHostService.stop_broadcasting(folder_path)


func _on_broadcast_state_changed(folder_path: String, _project_id: String, _active: bool) -> void:
	_refresh_broadcast_state_for_folder(folder_path)
	_refresh_broadcast_state_for_folder(SyncHostService.active_folder_path())


func _refresh_broadcast_state_for_folder(folder_path: String) -> void:
	if folder_path == "":
		return
	for child in _grid_container.get_children():
		var card: ProjectCard = child as ProjectCard
		if card == null:
			continue
		if card.folder_path() != folder_path:
			continue
		card.set_broadcast_active(SyncHostService.is_broadcasting(folder_path))


func _on_join_session_pressed() -> void:
	PopupSizer.popup_fit(_join_session_dialog, {"preferred": Vector2i(680, 520)})


func _on_join_session_confirmed(adapter_kind: String, connect_info: Dictionary) -> void:
	if MultiplayerService.is_in_session():
		MultiplayerService.leave_session()
	var lobby_payload: Dictionary = connect_info.duplicate(true)
	if String(lobby_payload.get("project_id", "")) == "":
		_start_direct_join_probe(adapter_kind, lobby_payload)
		return
	var lobby_label: String = String(lobby_payload.get("project_name", "session"))
	if lobby_label == "":
		lobby_label = "session"
	loading_requested.emit("Joining %s…" % lobby_label, "Resolving project and connecting")
	var project: Project = MultiplayerService.resolve_or_bootstrap_join_project(lobby_payload)
	if project == null:
		_dismiss_loading()
		_show_inline_message("Cannot resolve or create a local project for the chosen session.")
		return
	MultiplayerService.set_pending_auto_join(adapter_kind, lobby_payload)
	emit_signal("project_chosen", project)


func _start_direct_join_probe(adapter_kind: String, connect_info: Dictionary) -> void:
	var host_label: String = _format_direct_host_label(adapter_kind, connect_info)
	if not MultiplayerService.direct_join_bootstrap_ready.is_connected(_on_direct_join_bootstrap_ready):
		MultiplayerService.direct_join_bootstrap_ready.connect(_on_direct_join_bootstrap_ready)
	if not MultiplayerService.direct_join_failed.is_connected(_on_direct_join_failed):
		MultiplayerService.direct_join_failed.connect(_on_direct_join_failed)
	loading_requested.emit("Connecting to %s…" % host_label, "Probing host for project info")
	var err: Error = MultiplayerService.begin_direct_join_probe(adapter_kind, connect_info)
	if err != OK:
		_dismiss_loading()
		_disconnect_direct_join_signals()
		_show_inline_message("Could not start direct connect (error %d)." % err)


func _format_direct_host_label(adapter_kind: String, connect_info: Dictionary) -> String:
	if adapter_kind == NetworkAdapter.ADAPTER_KIND_ENET:
		var addr: String = String(connect_info.get("address", "127.0.0.1"))
		var port: int = int(connect_info.get("port", EnetAdapter.DEFAULT_PORT))
		return "%s:%d" % [addr, port]
	return "host"


func _on_direct_join_bootstrap_ready(project: Project, adapter_kind: String, connect_info: Dictionary) -> void:
	_disconnect_direct_join_signals()
	if project == null:
		_dismiss_loading()
		_show_inline_message("Direct connect succeeded but no project could be opened.")
		return
	var registered: Project = ProjectStore.open_project(project.folder_path)
	var resolved: Project = registered if registered != null else project
	MultiplayerService.set_pending_auto_join(adapter_kind, connect_info)
	emit_signal("project_chosen", resolved)


func _on_direct_join_failed(reason: String) -> void:
	_disconnect_direct_join_signals()
	_dismiss_loading()
	var message: String = reason if reason != "" else "Direct connect failed."
	_show_inline_message("Direct connect failed: %s" % message)


func _disconnect_direct_join_signals() -> void:
	if MultiplayerService.direct_join_bootstrap_ready.is_connected(_on_direct_join_bootstrap_ready):
		MultiplayerService.direct_join_bootstrap_ready.disconnect(_on_direct_join_bootstrap_ready)
	if MultiplayerService.direct_join_failed.is_connected(_on_direct_join_failed):
		MultiplayerService.direct_join_failed.disconnect(_on_direct_join_failed)


func _dismiss_loading() -> void:
	var root: Node = get_parent()
	while root != null:
		if root is Bootstrap:
			(root as Bootstrap).hide_loading()
			return
		root = root.get_parent()


func _on_broadcasts_toggle_pressed() -> void:
	_showing_remote_view = not _showing_remote_view
	_apply_view_mode()


func _apply_view_mode() -> void:
	_section_header.visible = not _showing_remote_view
	_scroll.visible = not _showing_remote_view
	if not _showing_remote_view:
		_empty_label.visible = ProjectStore.recent().is_empty()
	else:
		_empty_label.visible = false
	_remote_section_header.visible = _showing_remote_view
	_remote_browser.visible = _showing_remote_view
	if _showing_remote_view:
		_remote_browser.refresh_now()


func _on_remote_hosts_changed(host_list: Array) -> void:
	_update_broadcasts_indicator(host_list.size())


func _update_broadcasts_indicator(count: int) -> void:
	_last_known_broadcasts_count = count
	var color: Color = BROADCASTS_ACTIVE_COLOR if count > 0 else BROADCASTS_INACTIVE_COLOR
	_broadcasts_indicator.add_theme_color_override("font_color", color)
	var noun: String = "project" if count == 1 else "projects"
	_broadcasts_toggle.text = "%d available %s on your network" % [count, noun]


func _on_remote_host_pulled(folder_path: String, _project_id: String, _host_entry: Dictionary) -> void:
	var project: Project = ProjectStore.open_project(folder_path)
	if project == null:
		_show_inline_message("Pulled project could not be opened from %s." % folder_path)
		return
	emit_signal("project_chosen", project)


func _on_remote_host_synced(folder_path: String, _project_id: String, _host_entry: Dictionary) -> void:
	var project: Project = ProjectStore.open_project(folder_path)
	if project == null:
		return
	emit_signal("project_chosen", project)


func _on_remote_toast_requested(severity: String, message: String) -> void:
	if severity == "error":
		_show_inline_message(message)


func _show_inline_message(text: String) -> void:
	var dlg: AcceptDialog = AcceptDialog.new()
	dlg.title = "Multiplayer"
	dlg.dialog_text = text
	add_child(dlg)
	PopupSizer.popup_fit(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)


func _on_new_pressed() -> void:
	PopupSizer.popup_fit(_create_dialog, {"ratio": Vector2(0.7, 0.7)})


func _on_open_pressed() -> void:
	PopupSizer.popup_fit(_open_dialog, {"ratio": Vector2(0.7, 0.7)})


func _on_create_folder_chosen(folder: String) -> void:
	_pending_create_folder = folder
	_name_edit.text = ""
	PopupSizer.popup_fit(_name_dialog, {"preferred": Vector2i(360, 140)})
	_name_edit.grab_focus()


func _on_create_confirmed() -> void:
	var name_str: String = _name_edit.text.strip_edges()
	if name_str == "":
		name_str = "Untitled Project"
	if _pending_create_folder == "":
		return
	var project: Project = ProjectStore.create_project(_pending_create_folder, name_str)
	_pending_create_folder = ""
	if project != null:
		emit_signal("project_chosen", project)


func _on_open_folder_chosen(folder: String) -> void:
	var project: Project = ProjectStore.open_project(folder)
	if project != null:
		emit_signal("project_chosen", project)


func _on_card_open(folder: String) -> void:
	var project: Project = ProjectStore.open_project(folder)
	if project != null:
		emit_signal("project_chosen", project)


func _on_card_forget(folder: String) -> void:
	ProjectStore.forget(folder)


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
	PopupSizer.popup_fit(dlg, {"preferred": Vector2i(992, 752)})


func _open_keybindings_dialog() -> void:
	var dlg: Window = KEYBINDINGS_DIALOG_SCENE.instantiate()
	add_child(dlg)
	PopupSizer.popup_fit(dlg, {"preferred": Vector2i(560, 540)})
