class_name PresenceAvatarStrip
extends HBoxContainer

signal host_session_requested()
signal join_session_requested()
signal manage_participants_requested()
signal leave_session_requested()
signal follow_camera_requested(stable_id: String)
signal toggle_viewport_ghosts_requested()
signal toggle_presence_overlay_requested()

const AVATAR_SCENE: PackedScene = preload("res://src/multiplayer/presence/presence_avatar.tscn")

@onready var _avatar_row: HBoxContainer = %AvatarRow
@onready var _state_label: Label = %StateLabel
@onready var _menu_button: MenuButton = %MenuButton
@onready var _backend_label: Label = %BackendLabel
@onready var _participant_count_label: Label = %ParticipantCountLabel

const MENU_HOST: int = 1
const MENU_JOIN: int = 2
const MENU_MANAGE: int = 3
const MENU_LEAVE: int = 4
const MENU_TOGGLE_VIEWPORT: int = 5
const MENU_TOGGLE_OVERLAY: int = 6


func _ready() -> void:
	ThemeManager.apply_relative_font_size(_state_label, 0.85)
	ThemeManager.apply_relative_font_size(_backend_label, 0.72)
	ThemeManager.apply_relative_font_size(_participant_count_label, 0.72)
	if _menu_button == null:
		return
	var popup: PopupMenu = _menu_button.get_popup()
	popup.clear()
	popup.add_item("Host session…", MENU_HOST)
	popup.add_item("Join session…", MENU_JOIN)
	popup.add_separator()
	popup.add_item("Manage participants…", MENU_MANAGE)
	popup.add_separator()
	popup.add_check_item("Show peer viewports", MENU_TOGGLE_VIEWPORT)
	popup.add_check_item("Show presence overlay", MENU_TOGGLE_OVERLAY)
	popup.set_item_checked(popup.get_item_index(MENU_TOGGLE_OVERLAY), true)
	popup.add_separator()
	popup.add_item("Leave session", MENU_LEAVE)
	popup.id_pressed.connect(_on_menu_id_pressed)
	popup.about_to_popup.connect(_refresh_menu_items)
	MultiplayerService.session_state_changed.connect(_refresh_state)
	MultiplayerService.participants_changed.connect(_refresh)
	MultiplayerService.presence_updated.connect(func(_id: String) -> void: _refresh())
	MultiplayerService.presence_removed.connect(func(_id: String) -> void: _refresh())
	_refresh_menu_items()
	_refresh()


func mark_overlay_enabled(enabled: bool) -> void:
	var popup: PopupMenu = _menu_button.get_popup()
	popup.set_item_checked(popup.get_item_index(MENU_TOGGLE_OVERLAY), enabled)


func mark_viewport_ghosts_enabled(enabled: bool) -> void:
	var popup: PopupMenu = _menu_button.get_popup()
	popup.set_item_checked(popup.get_item_index(MENU_TOGGLE_VIEWPORT), enabled)


func _refresh_state(_state: int) -> void:
	_refresh()


func _refresh_menu_items() -> void:
	if _menu_button == null:
		return
	var popup: PopupMenu = _menu_button.get_popup()
	var in_session: bool = MultiplayerService.is_in_session()
	var host_idx: int = popup.get_item_index(MENU_HOST)
	var join_idx: int = popup.get_item_index(MENU_JOIN)
	var manage_idx: int = popup.get_item_index(MENU_MANAGE)
	var leave_idx: int = popup.get_item_index(MENU_LEAVE)
	if host_idx >= 0:
		popup.set_item_disabled(host_idx, in_session)
	if join_idx >= 0:
		popup.set_item_disabled(join_idx, in_session)
	if manage_idx >= 0:
		popup.set_item_disabled(manage_idx, not in_session)
	if leave_idx >= 0:
		popup.set_item_disabled(leave_idx, not in_session)


func _refresh() -> void:
	_clear_avatars()
	var local_stable_id: String = MultiplayerService.local_stable_id()
	var participants: Array = MultiplayerService.participants_list()
	var presence_count: int = 0
	var in_session: bool = MultiplayerService.is_in_session()
	if in_session:
		_state_label.text = "Live"
		_state_label.add_theme_color_override("font_color", Color(0.5, 0.95, 0.6, 1.0))
		_menu_button.text = "Live ▾"
	else:
		_state_label.text = "Solo"
		_state_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78, 1.0))
		_menu_button.text = "Solo ▾"
	_refresh_menu_items()
	if MultiplayerService.is_in_session():
		var local_present: bool = false
		for entry_v: Variant in participants:
			var entry: Dictionary = entry_v
			var stable_id: String = String(entry.get("stable_id", ""))
			var is_self: bool = stable_id == local_stable_id
			if is_self:
				local_present = true
			var presence: PresenceState = MultiplayerService.presence_for(stable_id)
			var hosting: bool = presence != null and presence.hosting
			var color: Color = presence.avatar_color if presence != null else PeerIdentity.color_for_stable_id(stable_id)
			_add_avatar(stable_id, String(entry.get("display_name", "Player")), String(entry.get("role", ParticipantsManifest.ROLE_CO_AUTHOR)), hosting, color, is_self)
			presence_count += 1
		for state_v: Variant in MultiplayerService.all_presence():
			var state: PresenceState = state_v as PresenceState
			if state == null:
				continue
			var stable_id: String = state.stable_id
			if stable_id == "":
				continue
			var already_present: bool = false
			for entry_v: Variant in participants:
				if String((entry_v as Dictionary).get("stable_id", "")) == stable_id:
					already_present = true
					break
			if already_present:
				continue
			var is_self: bool = stable_id == local_stable_id
			_add_avatar(stable_id, state.display_name, ParticipantsManifest.ROLE_GUEST, state.hosting, state.avatar_color, is_self)
			presence_count += 1
	_participant_count_label.text = "%d / %d" % [presence_count, max(participants.size(), 1)] if MultiplayerService.is_in_session() else ""
	if MultiplayerService.is_in_session() and MultiplayerService.adapter_for(_active_adapter_kind()) != null:
		_backend_label.text = _active_adapter_kind().to_upper()
	else:
		_backend_label.text = ""


func _active_adapter_kind() -> String:
	for kind: String in [NetworkAdapter.ADAPTER_KIND_STEAM, NetworkAdapter.ADAPTER_KIND_LAN, NetworkAdapter.ADAPTER_KIND_ENET]:
		var adapter: NetworkAdapter = MultiplayerService.adapter_for(kind)
		if adapter != null and adapter.is_connected_to_session():
			return kind
	return ""


func _clear_avatars() -> void:
	for child in _avatar_row.get_children():
		child.queue_free()


func _add_avatar(stable_id: String, display_name: String, role: String, hosting: bool, color: Color, is_self: bool) -> void:
	var avatar: PresenceAvatar = AVATAR_SCENE.instantiate()
	_avatar_row.add_child(avatar)
	avatar.bind(stable_id, display_name, role, hosting, color, is_self)
	avatar.follow_camera_requested.connect(_on_avatar_follow_requested)


func _on_avatar_follow_requested(stable_id: String) -> void:
	emit_signal("follow_camera_requested", stable_id)


func _on_menu_id_pressed(id: int) -> void:
	match id:
		MENU_HOST:
			emit_signal("host_session_requested")
		MENU_JOIN:
			emit_signal("join_session_requested")
		MENU_MANAGE:
			emit_signal("manage_participants_requested")
		MENU_LEAVE:
			emit_signal("leave_session_requested")
		MENU_TOGGLE_VIEWPORT:
			emit_signal("toggle_viewport_ghosts_requested")
		MENU_TOGGLE_OVERLAY:
			emit_signal("toggle_presence_overlay_requested")
