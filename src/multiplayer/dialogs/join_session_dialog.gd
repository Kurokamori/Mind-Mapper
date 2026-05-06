class_name JoinSessionDialog
extends AcceptDialog

signal join_confirmed(adapter_kind: String, connect_info: Dictionary)

@onready var _adapter_option: OptionButton = %AdapterOption
@onready var _adapter_status: Label = %AdapterStatusLabel
@onready var _direct_address_field: LineEdit = %DirectAddressField
@onready var _direct_port_field: SpinBox = %DirectPortField
@onready var _direct_row: HBoxContainer = %DirectRow
@onready var _direct_port_row: HBoxContainer = %DirectPortRow
@onready var _lobby_list: ItemList = %LobbyList
@onready var _refresh_button: Button = %RefreshButton
@onready var _display_name_field: LineEdit = %DisplayNameField

var _adapter_kinds: Array[String] = []
var _current_lobbies: Array = []


func _ready() -> void:
	title = "Join multiplayer session"
	min_size = Vector2(640, 480)
	get_ok_button().text = "Join"
	add_cancel_button("Cancel")
	confirmed.connect(_on_confirmed)
	_adapter_option.item_selected.connect(_on_adapter_changed)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_lobby_list.item_activated.connect(_on_lobby_activated)
	_direct_port_field.min_value = 1024
	_direct_port_field.max_value = 65535
	_direct_port_field.value = EnetAdapter.DEFAULT_PORT
	_display_name_field.text = KeypairService.display_name()
	_populate_adapters()
	MultiplayerService.lobby_list_updated.connect(_on_lobby_list_updated)


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
	if MultiplayerService.is_adapter_available(NetworkAdapter.ADAPTER_KIND_STEAM):
		_adapter_option.select(_adapter_kinds.find(NetworkAdapter.ADAPTER_KIND_STEAM))
	elif _adapter_kinds.has(NetworkAdapter.ADAPTER_KIND_LAN):
		_adapter_option.select(_adapter_kinds.find(NetworkAdapter.ADAPTER_KIND_LAN))
	else:
		_adapter_option.select(0)
	_on_adapter_changed(_adapter_option.selected)


func _adapter_label(kind: String) -> String:
	match kind:
		NetworkAdapter.ADAPTER_KIND_STEAM:
			return "Steam (friends list)"
		NetworkAdapter.ADAPTER_KIND_LAN:
			return "LAN (browse same network)"
		NetworkAdapter.ADAPTER_KIND_ENET:
			return "ENet (direct IP)"
		_:
			return kind


func _on_adapter_changed(idx: int) -> void:
	if idx < 0 or idx >= _adapter_kinds.size():
		return
	var kind: String = _adapter_kinds[idx]
	var available: bool = MultiplayerService.is_adapter_available(kind)
	_adapter_status.text = MultiplayerService.adapter_unavailability_reason(kind) if not available else ""
	_adapter_status.add_theme_color_override("font_color", Color(0.95, 0.45, 0.4, 1.0))
	_direct_row.visible = (kind == NetworkAdapter.ADAPTER_KIND_ENET)
	_direct_port_row.visible = (kind == NetworkAdapter.ADAPTER_KIND_ENET)
	_lobby_list.clear()
	_current_lobbies.clear()
	if kind != NetworkAdapter.ADAPTER_KIND_ENET and available:
		_request_lobby_refresh(kind)


func _on_refresh_pressed() -> void:
	var kind: String = selected_adapter_kind()
	if kind == "":
		return
	_request_lobby_refresh(kind)


func _request_lobby_refresh(kind: String) -> void:
	_lobby_list.clear()
	_lobby_list.add_item("Searching…")
	_lobby_list.set_item_disabled(0, true)
	MultiplayerService.discover_lobbies(kind, {"format_version": Project.FORMAT_VERSION})


func _on_lobby_list_updated(adapter_kind: String, lobbies: Array) -> void:
	if adapter_kind != selected_adapter_kind():
		return
	_current_lobbies = lobbies
	_lobby_list.clear()
	if lobbies.is_empty():
		_lobby_list.add_item("(no lobbies found)")
		_lobby_list.set_item_disabled(0, true)
		return
	for entry_v: Variant in lobbies:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var label: String = "%s — host %s (%d/%d)" % [
			String(entry.get("project_name", "Untitled Project")),
			String(entry.get("host_display_name", "Host")),
			int(entry.get("member_count", 1)),
			int(entry.get("max_members", 16)),
		]
		_lobby_list.add_item(label)
		var idx: int = _lobby_list.item_count - 1
		_lobby_list.set_item_metadata(idx, entry)


func _on_lobby_activated(_index: int) -> void:
	_on_confirmed()


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
	var connect_info: Dictionary = {}
	if kind == NetworkAdapter.ADAPTER_KIND_ENET:
		var addr: String = _direct_address_field.text.strip_edges()
		if addr == "":
			addr = "127.0.0.1"
		connect_info["address"] = addr
		connect_info["port"] = int(_direct_port_field.value)
	else:
		var idx: int = _lobby_list.get_selected_items()[0] if not _lobby_list.get_selected_items().is_empty() else -1
		if idx < 0 or _lobby_list.is_item_disabled(idx):
			return
		var entry: Variant = _lobby_list.get_item_metadata(idx)
		if typeof(entry) == TYPE_DICTIONARY:
			connect_info = (entry as Dictionary).duplicate()
	emit_signal("join_confirmed", kind, connect_info)
