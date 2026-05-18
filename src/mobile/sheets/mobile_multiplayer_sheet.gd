class_name MobileMultiplayerSheet
extends Control

signal session_active_changed(active: bool)
signal status_message(severity: String, message: String)

const MODE_HOST: String = "host"
const MODE_JOIN: String = "join"

const ADAPTER_LAN: String = NetworkAdapter.ADAPTER_KIND_LAN
const ADAPTER_ENET: String = NetworkAdapter.ADAPTER_KIND_ENET
const ADAPTER_WEBRTC: String = NetworkAdapter.ADAPTER_KIND_WEBRTC

const ROOM_CODE_ALPHABET: String = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const ROOM_CODE_LENGTH: int = 6

@onready var _status_banner: PanelContainer = %StatusBanner
@onready var _status_label: Label = %StatusLabel

@onready var _picker_section: VBoxContainer = %PickerSection
@onready var _session_section: VBoxContainer = %SessionSection

@onready var _mode_host_btn: Button = %ModeHostButton
@onready var _mode_join_btn: Button = %ModeJoinButton

@onready var _adapter_lan_btn: Button = %AdapterLanButton
@onready var _adapter_enet_btn: Button = %AdapterEnetButton
@onready var _adapter_webrtc_btn: Button = %AdapterWebRTCButton
@onready var _adapter_status_label: Label = %AdapterStatusLabel

@onready var _enet_host_panel: VBoxContainer = %EnetHostPanel
@onready var _enet_join_panel: VBoxContainer = %EnetJoinPanel
@onready var _lan_host_panel: VBoxContainer = %LanHostPanel
@onready var _lan_join_panel: VBoxContainer = %LanJoinPanel
@onready var _webrtc_host_panel: VBoxContainer = %WebRTCHostPanel
@onready var _webrtc_join_panel: VBoxContainer = %WebRTCJoinPanel

@onready var _enet_host_port: SpinBox = %EnetHostPort
@onready var _enet_host_bind: LineEdit = %EnetHostBind
@onready var _enet_host_max_members: SpinBox = %EnetHostMaxMembers
@onready var _enet_join_address: LineEdit = %EnetJoinAddress
@onready var _enet_join_port: SpinBox = %EnetJoinPort

@onready var _lan_host_port: SpinBox = %LanHostPort
@onready var _lan_host_max_members: SpinBox = %LanHostMaxMembers
@onready var _lan_lobby_list: ItemList = %LanLobbyList
@onready var _lan_refresh_button: Button = %LanRefreshButton

@onready var _webrtc_host_signaling: LineEdit = %WebRTCHostSignaling
@onready var _webrtc_host_room: LineEdit = %WebRTCHostRoom
@onready var _webrtc_host_generate: Button = %WebRTCHostGenerate
@onready var _webrtc_join_signaling: LineEdit = %WebRTCJoinSignaling
@onready var _webrtc_join_room: LineEdit = %WebRTCJoinRoom

@onready var _display_name_field: LineEdit = %DisplayNameField
@onready var _identity_label: Label = %IdentityLabel
@onready var _primary_button: Button = %PrimaryActionButton
@onready var _error_label: Label = %ErrorLabel

@onready var _session_title: Label = %SessionTitleLabel
@onready var _session_detail: Label = %SessionDetailLabel
@onready var _role_label: Label = %RoleLabel
@onready var _participants_list: ItemList = %ParticipantsList
@onready var _leave_button: Button = %LeaveButton

var _mode: String = MODE_HOST
var _adapter_kind: String = ADAPTER_LAN
var _current_lobbies: Array = []
var _suppress_webrtc_echo: bool = false


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_configure_spinboxes()
	_configure_initial_text()
	_connect_local_signals()
	_connect_service_signals()
	_apply_mode_buttons()
	_apply_adapter_buttons()
	_refresh_visibility()
	_refresh_adapter_status()
	_refresh_session_view()
	if _mode == MODE_JOIN and _adapter_kind == ADAPTER_LAN:
		_request_lan_refresh()


func _exit_tree() -> void:
	if MultiplayerService == null:
		return
	if MultiplayerService.session_state_changed.is_connected(_on_session_state_changed):
		MultiplayerService.session_state_changed.disconnect(_on_session_state_changed)
	if MultiplayerService.participants_changed.is_connected(_on_participants_changed):
		MultiplayerService.participants_changed.disconnect(_on_participants_changed)
	if MultiplayerService.lobby_list_updated.is_connected(_on_lobby_list_updated):
		MultiplayerService.lobby_list_updated.disconnect(_on_lobby_list_updated)
	if MultiplayerService.session_log.is_connected(_on_session_log):
		MultiplayerService.session_log.disconnect(_on_session_log)


func _configure_spinboxes() -> void:
	_enet_host_port.min_value = 1024
	_enet_host_port.max_value = 65535
	_enet_host_port.value = EnetAdapter.DEFAULT_PORT
	_enet_host_max_members.min_value = 2
	_enet_host_max_members.max_value = 250
	_enet_host_max_members.value = 16
	_enet_join_port.min_value = 1024
	_enet_join_port.max_value = 65535
	_enet_join_port.value = EnetAdapter.DEFAULT_PORT
	_lan_host_port.min_value = 1024
	_lan_host_port.max_value = 65535
	_lan_host_port.value = EnetAdapter.DEFAULT_PORT
	_lan_host_max_members.min_value = 2
	_lan_host_max_members.max_value = 250
	_lan_host_max_members.value = 16


func _configure_initial_text() -> void:
	KeypairService.ensure_ready()
	_display_name_field.text = KeypairService.display_name()
	_identity_label.text = "Identity: %s" % KeypairService.stable_id()
	_webrtc_join_room.text = UserPrefs.webrtc_last_room_code
	_enet_host_bind.text = "*"
	_error_label.text = ""


func _connect_local_signals() -> void:
	_mode_host_btn.toggled.connect(_on_mode_host_toggled)
	_mode_join_btn.toggled.connect(_on_mode_join_toggled)
	_adapter_lan_btn.toggled.connect(_on_adapter_lan_toggled)
	_adapter_enet_btn.toggled.connect(_on_adapter_enet_toggled)
	_adapter_webrtc_btn.toggled.connect(_on_adapter_webrtc_toggled)
	_primary_button.pressed.connect(_on_primary_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)
	_lan_refresh_button.pressed.connect(_on_lan_refresh_pressed)
	_lan_lobby_list.item_activated.connect(_on_lan_lobby_activated)
	_webrtc_host_generate.pressed.connect(_on_webrtc_generate_pressed)
	_webrtc_host_signaling.text_changed.connect(_on_webrtc_host_signaling_changed)
	_webrtc_join_signaling.text_changed.connect(_on_webrtc_join_signaling_changed)
	_webrtc_host_room.text_changed.connect(_on_webrtc_host_room_changed)
	_webrtc_join_room.text_changed.connect(_on_webrtc_join_room_changed)
	_display_name_field.text_submitted.connect(_on_display_name_submitted)


func _connect_service_signals() -> void:
	if not MultiplayerService.session_state_changed.is_connected(_on_session_state_changed):
		MultiplayerService.session_state_changed.connect(_on_session_state_changed)
	if not MultiplayerService.participants_changed.is_connected(_on_participants_changed):
		MultiplayerService.participants_changed.connect(_on_participants_changed)
	if not MultiplayerService.lobby_list_updated.is_connected(_on_lobby_list_updated):
		MultiplayerService.lobby_list_updated.connect(_on_lobby_list_updated)
	if not MultiplayerService.session_log.is_connected(_on_session_log):
		MultiplayerService.session_log.connect(_on_session_log)


func _on_mode_host_toggled(pressed: bool) -> void:
	if not pressed:
		_mode_host_btn.set_pressed_no_signal(true)
		return
	_mode = MODE_HOST
	_apply_mode_buttons()
	_refresh_visibility()
	_clear_error()


func _on_mode_join_toggled(pressed: bool) -> void:
	if not pressed:
		_mode_join_btn.set_pressed_no_signal(true)
		return
	_mode = MODE_JOIN
	_apply_mode_buttons()
	_refresh_visibility()
	_clear_error()
	if _adapter_kind == ADAPTER_LAN:
		_request_lan_refresh()


func _apply_mode_buttons() -> void:
	_mode_host_btn.set_pressed_no_signal(_mode == MODE_HOST)
	_mode_join_btn.set_pressed_no_signal(_mode == MODE_JOIN)


func _on_adapter_lan_toggled(pressed: bool) -> void:
	_select_adapter(ADAPTER_LAN, pressed)


func _on_adapter_enet_toggled(pressed: bool) -> void:
	_select_adapter(ADAPTER_ENET, pressed)


func _on_adapter_webrtc_toggled(pressed: bool) -> void:
	_select_adapter(ADAPTER_WEBRTC, pressed)


func _select_adapter(kind: String, pressed: bool) -> void:
	if not pressed:
		_apply_adapter_buttons()
		return
	_adapter_kind = kind
	_apply_adapter_buttons()
	_refresh_visibility()
	_refresh_adapter_status()
	_clear_error()
	if _mode == MODE_JOIN and kind == ADAPTER_LAN:
		_request_lan_refresh()


func _apply_adapter_buttons() -> void:
	_adapter_lan_btn.set_pressed_no_signal(_adapter_kind == ADAPTER_LAN)
	_adapter_enet_btn.set_pressed_no_signal(_adapter_kind == ADAPTER_ENET)
	_adapter_webrtc_btn.set_pressed_no_signal(_adapter_kind == ADAPTER_WEBRTC)
	_adapter_lan_btn.disabled = not MultiplayerService.is_adapter_available(ADAPTER_LAN)
	_adapter_enet_btn.disabled = not MultiplayerService.is_adapter_available(ADAPTER_ENET)
	_adapter_webrtc_btn.disabled = not MultiplayerService.is_adapter_available(ADAPTER_WEBRTC)


func _refresh_visibility() -> void:
	var hosting: bool = _mode == MODE_HOST
	_enet_host_panel.visible = hosting and _adapter_kind == ADAPTER_ENET
	_enet_join_panel.visible = (not hosting) and _adapter_kind == ADAPTER_ENET
	_lan_host_panel.visible = hosting and _adapter_kind == ADAPTER_LAN
	_lan_join_panel.visible = (not hosting) and _adapter_kind == ADAPTER_LAN
	_webrtc_host_panel.visible = hosting and _adapter_kind == ADAPTER_WEBRTC
	_webrtc_join_panel.visible = (not hosting) and _adapter_kind == ADAPTER_WEBRTC
	_primary_button.text = "Start hosting" if hosting else "Join session"


func _refresh_adapter_status() -> void:
	var available: bool = MultiplayerService.is_adapter_available(_adapter_kind)
	if not available:
		_adapter_status_label.text = MultiplayerService.adapter_unavailability_reason(_adapter_kind)
		_adapter_status_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.40))
		return
	var message: String = ""
	match _adapter_kind:
		ADAPTER_LAN:
			message = "Same Wi-Fi only — hosts are discovered automatically."
		ADAPTER_ENET:
			message = "Direct IP and port (default %d). Share both out-of-band." % EnetAdapter.DEFAULT_PORT
		ADAPTER_WEBRTC:
			message = "Internet multiplayer via a signaling server and shared room code."
	_adapter_status_label.text = message
	_adapter_status_label.add_theme_color_override("font_color", Color(0.65, 0.78, 0.95))


func _request_lan_refresh() -> void:
	_lan_lobby_list.clear()
	_lan_lobby_list.add_item("Searching…")
	_lan_lobby_list.set_item_disabled(0, true)
	_current_lobbies.clear()
	var err: Error = MultiplayerService.discover_lobbies(ADAPTER_LAN, {"format_version": Project.FORMAT_VERSION})
	if err != OK:
		_lan_lobby_list.clear()
		_lan_lobby_list.add_item("(LAN discovery unavailable)")
		_lan_lobby_list.set_item_disabled(0, true)


func _on_lan_refresh_pressed() -> void:
	_request_lan_refresh()


func _on_lobby_list_updated(adapter_kind: String, lobbies: Array) -> void:
	if adapter_kind != ADAPTER_LAN:
		return
	_current_lobbies = lobbies
	_lan_lobby_list.clear()
	if lobbies.is_empty():
		_lan_lobby_list.add_item("(no lobbies found)")
		_lan_lobby_list.set_item_disabled(0, true)
		return
	for entry_v: Variant in lobbies:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var label: String = "%s — %s  (%d/%d)" % [
			String(entry.get("project_name", "Untitled project")),
			String(entry.get("host_display_name", "Host")),
			int(entry.get("member_count", 1)),
			int(entry.get("max_members", 16)),
		]
		_lan_lobby_list.add_item(label)
		var idx: int = _lan_lobby_list.item_count - 1
		_lan_lobby_list.set_item_metadata(idx, entry)


func _on_lan_lobby_activated(_index: int) -> void:
	if _mode == MODE_JOIN:
		_on_primary_pressed()


func _on_webrtc_host_signaling_changed(value: String) -> void:
	if _suppress_webrtc_echo:
		return
	UserPrefs.set_webrtc_signaling_url(value)
	_suppress_webrtc_echo = true
	_webrtc_join_signaling.text = UserPrefs.webrtc_signaling_url
	_suppress_webrtc_echo = false


func _on_webrtc_join_signaling_changed(value: String) -> void:
	if _suppress_webrtc_echo:
		return
	UserPrefs.set_webrtc_signaling_url(value)
	_suppress_webrtc_echo = true
	_webrtc_host_signaling.text = UserPrefs.webrtc_signaling_url
	_suppress_webrtc_echo = false


func _on_webrtc_host_room_changed(value: String) -> void:
	_normalize_room_into(_webrtc_host_room, value)


func _on_webrtc_join_room_changed(value: String) -> void:
	_normalize_room_into(_webrtc_join_room, value)


func _normalize_room_into(field: LineEdit, raw_value: String) -> void:
	var normalized: String = WebRTCSignalingClient.normalize_room_code(raw_value)
	if normalized != raw_value:
		var caret: int = field.caret_column
		field.text = normalized
		field.caret_column = min(caret, normalized.length())
	UserPrefs.set_webrtc_last_room_code(normalized)


func _on_webrtc_generate_pressed() -> void:
	var generated: String = _generate_room_code()
	_webrtc_host_room.text = generated
	UserPrefs.set_webrtc_last_room_code(generated)


func _generate_room_code() -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var out: String = ""
	for i: int in range(ROOM_CODE_LENGTH):
		out += ROOM_CODE_ALPHABET[rng.randi_range(0, ROOM_CODE_ALPHABET.length() - 1)]
	return out


func _on_display_name_submitted(value: String) -> void:
	var trimmed: String = value.strip_edges()
	if trimmed == "":
		return
	KeypairService.set_display_name(trimmed)


func _on_primary_pressed() -> void:
	_clear_error()
	if not MultiplayerService.is_adapter_available(_adapter_kind):
		_show_error(MultiplayerService.adapter_unavailability_reason(_adapter_kind))
		return
	var trimmed_name: String = _display_name_field.text.strip_edges()
	if trimmed_name != "":
		KeypairService.set_display_name(trimmed_name)
	if _mode == MODE_HOST:
		_start_host()
	else:
		_start_join()


func _start_host() -> void:
	if AppState.current_project == null:
		_show_error("Open a project before hosting.")
		return
	var settings: Dictionary = _build_host_settings()
	if settings.is_empty():
		return
	var err: Error = MultiplayerService.host_session(_adapter_kind, settings)
	if err != OK:
		_show_error("Could not start hosting (error %s)." % str(err))


func _build_host_settings() -> Dictionary:
	var settings: Dictionary = {}
	match _adapter_kind:
		ADAPTER_LAN:
			settings["port"] = int(_lan_host_port.value)
			settings["max_members"] = int(_lan_host_max_members.value)
			settings["bind_address"] = "*"
		ADAPTER_ENET:
			settings["port"] = int(_enet_host_port.value)
			settings["max_members"] = int(_enet_host_max_members.value)
			var bind_text: String = _enet_host_bind.text.strip_edges()
			settings["bind_address"] = bind_text if bind_text != "" else "*"
		ADAPTER_WEBRTC:
			var url: String = _webrtc_host_signaling.text.strip_edges()
			var room: String = WebRTCSignalingClient.normalize_room_code(_webrtc_host_room.text)
			if url == "":
				_show_error("Enter a signaling server URL.")
				return {}
			if not WebRTCSignalingClient.is_valid_room_code(room):
				_show_error("Room code must be 4–32 letters or digits.")
				return {}
			settings["signaling_url"] = url
			settings["room"] = room
			settings["max_members"] = 16
	return settings


func _start_join() -> void:
	var connect_info: Dictionary = _build_join_info()
	if connect_info.is_empty() and _adapter_kind != ADAPTER_LAN:
		return
	if _adapter_kind == ADAPTER_LAN and connect_info.is_empty():
		return
	var err: Error = MultiplayerService.join_session(_adapter_kind, connect_info)
	if err != OK:
		_show_error("Could not join (error %s)." % str(err))


func _build_join_info() -> Dictionary:
	var connect_info: Dictionary = {}
	match _adapter_kind:
		ADAPTER_LAN:
			var sel: PackedInt32Array = _lan_lobby_list.get_selected_items()
			if sel.is_empty():
				_show_error("Pick a lobby from the list first.")
				return {}
			var idx: int = sel[0]
			if _lan_lobby_list.is_item_disabled(idx):
				_show_error("Pick a lobby from the list first.")
				return {}
			var meta: Variant = _lan_lobby_list.get_item_metadata(idx)
			if typeof(meta) == TYPE_DICTIONARY:
				connect_info = (meta as Dictionary).duplicate(true)
			if connect_info.is_empty():
				_show_error("Selected lobby is missing connection info.")
				return {}
		ADAPTER_ENET:
			var addr: String = _enet_join_address.text.strip_edges()
			if addr == "":
				_show_error("Enter the host IP address.")
				return {}
			connect_info["address"] = addr
			connect_info["port"] = int(_enet_join_port.value)
		ADAPTER_WEBRTC:
			var url: String = _webrtc_join_signaling.text.strip_edges()
			var room: String = WebRTCSignalingClient.normalize_room_code(_webrtc_join_room.text)
			if url == "":
				_show_error("Enter the signaling server URL.")
				return {}
			if not WebRTCSignalingClient.is_valid_room_code(room):
				_show_error("Room code must be 4–32 letters or digits.")
				return {}
			connect_info["signaling_url"] = url
			connect_info["room"] = room
	return connect_info


func _on_leave_pressed() -> void:
	MultiplayerService.leave_session()


func _on_session_state_changed(_state: int) -> void:
	_refresh_session_view()


func _on_participants_changed() -> void:
	_refresh_participants()


func _on_session_log(severity: String, message: String) -> void:
	if severity == "error" or severity == "warning":
		_show_error(message)
	status_message.emit(severity, message)


func _refresh_session_view() -> void:
	var state: int = MultiplayerService.current_state()
	var in_session: bool = state == MultiplayerService.STATE_HOSTING \
		or state == MultiplayerService.STATE_CONNECTED \
		or state == MultiplayerService.STATE_JOINING
	_picker_section.visible = not in_session
	_session_section.visible = in_session
	_status_banner.visible = state != MultiplayerService.STATE_IDLE
	match state:
		MultiplayerService.STATE_IDLE:
			_status_label.text = "Not connected"
			_session_title.text = "Not connected"
			_session_detail.text = ""
		MultiplayerService.STATE_HOSTING:
			_status_label.text = "Hosting · %s" % _adapter_display(_adapter_kind)
			_session_title.text = "Hosting via %s" % _adapter_display(_adapter_kind)
			_session_detail.text = "Waiting for collaborators…"
		MultiplayerService.STATE_JOINING:
			_status_label.text = "Joining · %s" % _adapter_display(_adapter_kind)
			_session_title.text = "Connecting…"
			_session_detail.text = "Negotiating with host"
		MultiplayerService.STATE_CONNECTED:
			_status_label.text = "Connected · %s" % _adapter_display(_adapter_kind)
			_session_title.text = "Connected via %s" % _adapter_display(_adapter_kind)
			_session_detail.text = "Session active"
		MultiplayerService.STATE_ERROR:
			_status_label.text = "Connection error"
			_session_title.text = "Connection error"
			_session_detail.text = "Leave the session and try again."
	_role_label.text = "Role: %s" % _format_role(MultiplayerService.local_role())
	_refresh_participants()
	session_active_changed.emit(in_session)


func _refresh_participants() -> void:
	_participants_list.clear()
	var rows: Array = MultiplayerService.participants_list()
	if rows.is_empty():
		_participants_list.add_item("(no participants yet)")
		_participants_list.set_item_disabled(0, true)
		return
	for row_v: Variant in rows:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var connected: bool = bool(row.get("connected", false))
		var suffix: String = "" if connected else " (offline)"
		var label: String = "%s · %s%s" % [
			String(row.get("display_name", "Peer")),
			_format_role(String(row.get("role", ""))),
			suffix,
		]
		_participants_list.add_item(label)


func _adapter_display(kind: String) -> String:
	match kind:
		ADAPTER_LAN:
			return "LAN"
		ADAPTER_ENET:
			return "ENet"
		ADAPTER_WEBRTC:
			return "WebRTC"
	return kind


func _format_role(role: String) -> String:
	match role:
		MultiplayerService.ROLE_OWNER:
			return "Owner"
		MultiplayerService.ROLE_CO_AUTHOR:
			return "Co-author"
		MultiplayerService.ROLE_GUEST:
			return "Guest"
	if role == "":
		return "—"
	return role


func _show_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = message != ""


func _clear_error() -> void:
	_error_label.text = ""
	_error_label.visible = false
