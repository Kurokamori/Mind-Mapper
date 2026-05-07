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
		_:
			return kind


func _on_adapter_changed(idx: int) -> void:
	if idx < 0 or idx >= _adapter_kinds.size():
		return
	var kind: String = _adapter_kinds[idx]
	var available: bool = MultiplayerService.is_adapter_available(kind)
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
		_adapter_status.add_theme_color_override("font_color", Color(0.65, 0.78, 0.95, 1.0))
	_port_field.editable = kind != NetworkAdapter.ADAPTER_KIND_STEAM
	_bind_address_field.editable = kind == NetworkAdapter.ADAPTER_KIND_ENET
	_refresh_summary()


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
		_:
			_summary_label.text = ""


func selected_adapter_kind() -> String:
	var idx: int = _adapter_option.selected
	if idx < 0 or idx >= _adapter_kinds.size():
		return ""
	return _adapter_kinds[idx]


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
	emit_signal("host_confirmed", kind, settings)
