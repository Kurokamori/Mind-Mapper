class_name ProjectManagerScreen
extends Control

signal project_chosen(project: Project)

@onready var _grid_container: VBoxContainer = %GridContainer
@onready var _empty_label: Label = %EmptyLabel
@onready var _new_button: Button = %NewButton
@onready var _open_button: Button = %OpenButton
@onready var _create_dialog: FileDialog = %CreateDialog
@onready var _open_dialog: FileDialog = %OpenDialog
@onready var _name_dialog: AcceptDialog = %NameDialog
@onready var _name_edit: LineEdit = %NameEdit
@onready var _join_session_button: Button = %JoinSessionButton
@onready var _host_session_dialog: HostSessionDialog = %HostSessionDialog
@onready var _join_session_dialog: JoinSessionDialog = %JoinSessionDialog

var _pending_create_folder: String = ""
var _pending_host_folder: String = ""
var _live_lobbies_by_project_id: Dictionary = {}


func _ready() -> void:
	ThemeManager.apply_relative_font_sizes(self, {
		"Margins/VBox/Title": 2.30,
		"Margins/VBox/SectionHeader": 1.30,
	})
	_name_dialog.add_cancel_button("Cancel")
	_new_button.pressed.connect(_on_new_pressed)
	_open_button.pressed.connect(_on_open_pressed)
	_create_dialog.dir_selected.connect(_on_create_folder_chosen)
	_open_dialog.dir_selected.connect(_on_open_folder_chosen)
	_name_dialog.confirmed.connect(_on_create_confirmed)
	_join_session_button.pressed.connect(_on_join_session_pressed)
	_host_session_dialog.host_confirmed.connect(_on_host_session_confirmed)
	_join_session_dialog.join_confirmed.connect(_on_join_session_confirmed)
	ProjectStore.recent_changed.connect(_refresh)
	MultiplayerService.lobby_list_updated.connect(_on_lobby_list_updated)
	_refresh()
	_request_lobby_discovery()


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
	_empty_label.visible = entries.is_empty()
	for entry in entries:
		var card: ProjectCard = ProjectCard.create()
		card.bind(entry)
		card.open_requested.connect(_on_card_open)
		card.forget_requested.connect(_on_card_forget)
		card.join_live_requested.connect(_on_card_join_live)
		card.host_requested.connect(_on_card_host_requested)
		_grid_container.add_child(card)
		var project_id: String = String(entry.get("id", ""))
		if project_id != "" and _live_lobbies_by_project_id.has(project_id):
			var lobby: Dictionary = _live_lobbies_by_project_id[project_id]
			card.mark_live(lobby, String(lobby.get("adapter_kind", "")))


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
	if MultiplayerService.is_in_session():
		MultiplayerService.leave_session()
	var folder_path: String = _pending_host_folder
	_pending_host_folder = ""
	if folder_path == "":
		return
	var project: Project = ProjectStore.open_project(folder_path)
	if project == null:
		push_warning("ProjectManagerScreen: failed to open project at %s for hosting" % folder_path)
		return
	MultiplayerService.set_pending_auto_host(adapter_kind, settings)
	emit_signal("project_chosen", project)


func _on_join_session_pressed() -> void:
	PopupSizer.popup_fit(_join_session_dialog, {"preferred": Vector2i(680, 520)})


func _on_join_session_confirmed(adapter_kind: String, connect_info: Dictionary) -> void:
	if MultiplayerService.is_in_session():
		MultiplayerService.leave_session()
	var lobby_payload: Dictionary = connect_info.duplicate(true)
	if String(lobby_payload.get("project_id", "")) == "":
		_show_inline_message("Direct ENet connect from the project manager is not supported — open a project first, then join.")
		return
	var project: Project = MultiplayerService.resolve_or_bootstrap_join_project(lobby_payload)
	if project == null:
		_show_inline_message("Cannot resolve or create a local project for the chosen session.")
		return
	MultiplayerService.set_pending_auto_join(adapter_kind, lobby_payload)
	emit_signal("project_chosen", project)


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
