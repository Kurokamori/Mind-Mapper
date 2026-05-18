class_name HostSessionDialog
extends AcceptDialog

signal host_confirmed(adapter_kind: String, settings: Dictionary)

@onready var _adapter_option: OptionButton = %AdapterOption
@onready var _adapter_status: Label = %AdapterStatusLabel
@onready var _port_field: SpinBox = %PortField
@onready var _max_members_field: SpinBox = %MaxMembersField
@onready var _display_name_field: LineEdit = %DisplayNameField
@onready var _stable_id_label: Label = %StableIdLabel
@onready var _public_key_fingerprint_label: Label = %FingerprintLabel
@onready var _summary_label: Label = %SummaryLabel
@onready var _bind_address_field: LineEdit = %BindAddressField
@onready var _port_label: Label = $Margin/VBox/NetRow/PortLabel
@onready var _bind_label: Label = $Margin/VBox/NetRow/BindLabel
@onready var _max_label: Label = $Margin/VBox/IdentityRow/MaxLabel
@onready var _webrtc_room_row: HBoxContainer = %WebRTCRoomRow
@onready var _webrtc_room_field: LineEdit = %WebRTCRoomField
@onready var _webrtc_generate_button: Button = %WebRTCGenerateButton

var _adapter_kinds: Array[String] = []


func _ready() -> void:
	ThemeManager.apply_relative_font_size(_adapter_status, 0.80)
	ThemeManager.apply_relative_font_size(_stable_id_label, 0.72)
	ThemeManager.apply_relative_font_size(_public_key_fingerprint_label, 0.72)
	ThemeManager.apply_relative_font_size(_summary_label, 0.80)
	title = "Host multiplayer session"
	min_size = Vector2(480, 240)
	get_ok_button().text = "Start hosting"
	add_cancel_button("Cancel")
	confirmed.connect(_on_confirmed)
	_port_field.min_value = 1024
	_port_field.max_value = 65535
	_port_field.value = EnetAdapter.DEFAULT_PORT
	_max_members_field.min_value = 2
	_max_members_field.max_value = 250
	_max_members_field.value = 16
	_adapter_option.item_selected.connect(_on_adapter_changed)
	_webrtc_room_field.text = UserPrefs.webrtc_last_room_code
	_webrtc_room_field.text_changed.connect(_on_webrtc_room_changed)
	_webrtc_generate_button.pressed.connect(_on_webrtc_generate_pressed)
	_display_name_field.text = KeypairService.display_name()
	_stable_id_label.text = "Identity: %s" % KeypairService.stable_id()
	_public_key_fingerprint_label.text = "Public key: %s" % KeypairService.public_key_fingerprint()
	_populate_adapters()
	_refresh_summary()


func _populate_adapters() -> void:
	_adapter_option.clear()
	_adapter_kinds.clear()
	for kind: String in MultiplayerService.adapter_kinds():
		var available: bool = MultiplayerService.is_adapter_available(kind)
		var label: String = "%s%s" % [_adapter_label(kind), "" if available else "  (unavailable)"]
		_adapter_option.add_item(label)
		var idx: int = _adapter_option.item_count - 1
		_adapter_option.set_item_disabled(idx, not available)
		_adapter_kinds.append(kind)
	_adapter_option.add_item(_adapter_label(SyncHostService.BROADCAST_ADAPTER_KIND))
	_adapter_kinds.append(SyncHostService.BROADCAST_ADAPTER_KIND)
	if _adapter_kinds.has(NetworkAdapter.ADAPTER_KIND_STEAM):
		var steam_idx: int = _adapter_kinds.find(NetworkAdapter.ADAPTER_KIND_STEAM)
		if MultiplayerService.is_adapter_available(NetworkAdapter.ADAPTER_KIND_STEAM):
			_adapter_option.select(steam_idx)
		else:
			var lan_idx: int = _adapter_kinds.find(NetworkAdapter.ADAPTER_KIND_LAN)
			if lan_idx >= 0:
				_adapter_option.select(lan_idx)
			else:
				_adapter_option.select(0)
	else:
		_adapter_option.select(0)
	_on_adapter_changed(_adapter_option.selected)


func _adapter_label(kind: String) -> String:
	match kind:
		NetworkAdapter.ADAPTER_KIND_STEAM:
			return "Steam (friends, lobby invites)"
		NetworkAdapter.ADAPTER_KIND_LAN:
			return "LAN (broadcast, same network)"
		NetworkAdapter.ADAPTER_KIND_ENET:
			return "ENet (direct IP / port)"
		NetworkAdapter.ADAPTER_KIND_WEBRTC:
			return "WebRTC (internet, signaling server)"
		SyncHostService.BROADCAST_ADAPTER_KIND:
			return "Broadcast to phone (LAN sync only — no full session)"
		_:
			return kind


func _on_adapter_changed(idx: int) -> void:
	if idx < 0 or idx >= _adapter_kinds.size():
		return
	var kind: String = _adapter_kinds[idx]
	var is_broadcast: bool = kind == SyncHostService.BROADCAST_ADAPTER_KIND
	var is_webrtc: bool = kind == NetworkAdapter.ADAPTER_KIND_WEBRTC
	var available: bool = true if is_broadcast else MultiplayerService.is_adapter_available(kind)
	if not available:
		_adapter_status.text = MultiplayerService.adapter_unavailability_reason(kind)
		_adapter_status.add_theme_color_override("font_color", Color(0.95, 0.45, 0.4, 1.0))
	else:
		match kind:
			NetworkAdapter.ADAPTER_KIND_STEAM:
				_adapter_status.text = "Steam friends will see this lobby in the overlay."
			NetworkAdapter.ADAPTER_KIND_LAN:
				_adapter_status.text = "Other clients on this LAN will see the host in the lobby browser."
			NetworkAdapter.ADAPTER_KIND_ENET:
				_adapter_status.text = "Share the host IP and port with collaborators (port %d default)." % EnetAdapter.DEFAULT_PORT
			NetworkAdapter.ADAPTER_KIND_WEBRTC:
				_adapter_status.text = "Internet multiplayer via WebRTC. Share the room code with collaborators — they join through the same signaling server."
			SyncHostService.BROADCAST_ADAPTER_KIND:
				_adapter_status.text = "Lightweight: announces this project so phones running Loom Mobile can pull, push, or sync over Wi-Fi. No real-time multiplayer session is started."
		_adapter_status.add_theme_color_override("font_color", Color(0.65, 0.78, 0.95, 1.0))
	_port_field.editable = (not is_broadcast) and (not is_webrtc) and kind != NetworkAdapter.ADAPTER_KIND_STEAM
	_bind_address_field.editable = (not is_broadcast) and kind == NetworkAdapter.ADAPTER_KIND_ENET
	_max_members_field.editable = not is_broadcast
	_set_network_row_visible((not is_broadcast) and (not is_webrtc))
	_set_webrtc_rows_visible(is_webrtc)
	get_ok_button().text = "Start broadcast" if is_broadcast else "Start hosting"
	_refresh_summary()


func _set_network_row_visible(visible_: bool) -> void:
	_port_field.visible = visible_
	_bind_address_field.visible = visible_
	_max_members_field.visible = visible_
	if _port_label != null:
		_port_label.visible = visible_
	if _bind_label != null:
		_bind_label.visible = visible_
	if _max_label != null:
		_max_label.visible = visible_


func _set_webrtc_rows_visible(visible_: bool) -> void:
	if _webrtc_room_row != null:
		_webrtc_room_row.visible = visible_


func _refresh_summary() -> void:
	if _summary_label == null:
		return
	var idx: int = _adapter_option.selected
	if idx < 0 or idx >= _adapter_kinds.size():
		_summary_label.text = ""
		return
	var kind: String = _adapter_kinds[idx]
	match kind:
		NetworkAdapter.ADAPTER_KIND_STEAM:
			_summary_label.text = "Hosting via Steam — friends can use the in-game invite or accept lobby invites from the friends list."
		NetworkAdapter.ADAPTER_KIND_LAN:
			_summary_label.text = "Hosting on LAN port %d — other LAN players can join from the LAN browser." % int(_port_field.value)
		NetworkAdapter.ADAPTER_KIND_ENET:
			_summary_label.text = "Direct ENet on port %d. Share IP+port out-of-band." % int(_port_field.value)
		NetworkAdapter.ADAPTER_KIND_WEBRTC:
			var room_preview: String = WebRTCSignalingClient.normalize_room_code(_webrtc_room_field.text)
			if room_preview == "":
				_summary_label.text = "WebRTC mesh — enter a signaling URL and pick a room code to share."
			else:
				_summary_label.text = "WebRTC mesh — room code \"%s\". Share this code with collaborators." % room_preview
		SyncHostService.BROADCAST_ADAPTER_KIND:
			_summary_label.text = "Broadcasting on UDP %d / TCP %d. Phones with Loom Mobile on the same Wi-Fi will see this project in their picker." % [LanSyncProtocol.UDP_PORT, LanSyncProtocol.TCP_PORT]
		_:
			_summary_label.text = ""


func selected_adapter_kind() -> String:
	var idx: int = _adapter_option.selected
	if idx < 0 or idx >= _adapter_kinds.size():
		return ""
	return _adapter_kinds[idx]


func _on_webrtc_room_changed(value: String) -> void:
	var normalized: String = WebRTCSignalingClient.normalize_room_code(value)
	if normalized != value:
		var caret: int = _webrtc_room_field.caret_column
		_webrtc_room_field.text = normalized
		_webrtc_room_field.caret_column = min(caret, normalized.length())
	UserPrefs.set_webrtc_last_room_code(normalized)
	_refresh_summary()


func _on_webrtc_generate_pressed() -> void:
	var generated: String = _generate_room_code()
	_webrtc_room_field.text = generated
	UserPrefs.set_webrtc_last_room_code(generated)
	_refresh_summary()


func _generate_room_code() -> String:
	var alphabet: String = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var out: String = ""
	for i: int in range(6):
		out += alphabet[rng.randi_range(0, alphabet.length() - 1)]
	return out


func _on_confirmed() -> void:
	var kind: String = selected_adapter_kind()
	if kind == "":
		return
	if _display_name_field.text.strip_edges() != "":
		KeypairService.set_display_name(_display_name_field.text)
	var settings: Dictionary = {
		"port": int(_port_field.value),
		"max_members": int(_max_members_field.value),
		"bind_address": _bind_address_field.text.strip_edges() if _bind_address_field.text.strip_edges() != "" else "*",
	}
	if kind == NetworkAdapter.ADAPTER_KIND_WEBRTC:
		settings["room"] = WebRTCSignalingClient.normalize_room_code(_webrtc_room_field.text)
	emit_signal("host_confirmed", kind, settings)
