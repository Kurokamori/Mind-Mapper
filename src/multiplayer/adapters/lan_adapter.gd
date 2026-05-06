class_name LanAdapter
extends EnetAdapter

const BROADCAST_PORT: int = 27820
const PROBE_INTERVAL_SEC: float = 1.5
const LOBBY_TIMEOUT_SEC: float = 5.0
const PROTOCOL_MAGIC: String = "MM-LAN-V1"
const MESSAGE_PROBE: String = "probe"
const MESSAGE_ANNOUNCE: String = "announce"

var _host_listen_socket: PacketPeerUDP = null
var _client_socket: PacketPeerUDP = null
var _probe_timer: Timer = null
var _scrub_timer: Timer = null
var _seen_lobbies: Dictionary = {}
var _is_host_announcing: bool = false
var _is_discovering: bool = false
var _broadcast_address: String = "255.255.255.255"


func adapter_kind() -> String:
	return ADAPTER_KIND_LAN


func is_available() -> bool:
	return true


func _ready() -> void:
	super._ready()
	_probe_timer = Timer.new()
	_probe_timer.wait_time = PROBE_INTERVAL_SEC
	_probe_timer.one_shot = false
	_probe_timer.autostart = false
	_probe_timer.timeout.connect(_on_probe_tick)
	add_child(_probe_timer)
	_scrub_timer = Timer.new()
	_scrub_timer.wait_time = 1.0
	_scrub_timer.one_shot = false
	_scrub_timer.autostart = false
	_scrub_timer.timeout.connect(_on_scrub_tick)
	add_child(_scrub_timer)
	set_process(false)


func host(metadata: Dictionary) -> Error:
	var err: Error = super.host(metadata)
	if err != OK:
		return err
	_start_host_announcer()
	return OK


func leave() -> void:
	_stop_host_announcer()
	_stop_discovery()
	super.leave()


func discover_lobbies(filter: Dictionary) -> Error:
	_seen_lobbies.clear()
	_start_discovery()
	emit_signal("lobby_list_updated", _build_lobby_list())
	return OK


func cancel_discovery() -> void:
	_stop_discovery()


func _start_host_announcer() -> void:
	if _is_host_announcing:
		return
	_host_listen_socket = PacketPeerUDP.new()
	_host_listen_socket.set_broadcast_enabled(true)
	var bind_err: Error = _host_listen_socket.bind(BROADCAST_PORT)
	if bind_err != OK:
		_emit_error("LAN host announcer bind failed: %s" % str(bind_err))
		_host_listen_socket = null
		return
	_is_host_announcing = true
	_update_process_state()


func _stop_host_announcer() -> void:
	if _host_listen_socket != null:
		_host_listen_socket.close()
		_host_listen_socket = null
	_is_host_announcing = false
	_update_process_state()


func _start_discovery() -> void:
	if _is_discovering:
		_on_probe_tick()
		return
	_client_socket = PacketPeerUDP.new()
	_client_socket.set_broadcast_enabled(true)
	var bind_err: Error = _client_socket.bind(0)
	if bind_err != OK:
		_emit_error("LAN discovery bind failed: %s" % str(bind_err))
		_client_socket = null
		return
	var dest_err: Error = _client_socket.set_dest_address(_broadcast_address, BROADCAST_PORT)
	if dest_err != OK:
		_emit_error("LAN discovery set_dest_address failed: %s" % str(dest_err))
		_client_socket.close()
		_client_socket = null
		return
	_is_discovering = true
	_probe_timer.start()
	_scrub_timer.start()
	_update_process_state()
	_on_probe_tick()


func _stop_discovery() -> void:
	if _probe_timer != null:
		_probe_timer.stop()
	if _scrub_timer != null:
		_scrub_timer.stop()
	if _client_socket != null:
		_client_socket.close()
		_client_socket = null
	_is_discovering = false
	_update_process_state()


func _update_process_state() -> void:
	set_process(_is_host_announcing or _is_discovering)


func _process(_delta: float) -> void:
	if _is_host_announcing and _host_listen_socket != null:
		while _host_listen_socket.get_available_packet_count() > 0:
			var probe_bytes: PackedByteArray = _host_listen_socket.get_packet()
			var probe_ip: String = _host_listen_socket.get_packet_ip()
			var probe_port: int = _host_listen_socket.get_packet_port()
			_handle_incoming_probe(probe_bytes, probe_ip, probe_port)
	if _is_discovering and _client_socket != null:
		while _client_socket.get_available_packet_count() > 0:
			var ann_bytes: PackedByteArray = _client_socket.get_packet()
			var ann_ip: String = _client_socket.get_packet_ip()
			_handle_incoming_announcement(ann_bytes, ann_ip)


func _handle_incoming_probe(bytes: PackedByteArray, sender_ip: String, sender_port: int) -> void:
	if local_peer_identity == null:
		return
	var raw: String = bytes.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if String(data.get("magic", "")) != PROTOCOL_MAGIC:
		return
	if String(data.get("type", "")) != MESSAGE_PROBE:
		return
	_send_announcement_to(sender_ip, sender_port)


func _send_announcement_to(target_ip: String, target_port: int) -> void:
	var payload: Dictionary = _build_announcement_payload()
	var bytes: PackedByteArray = JSON.stringify(payload).to_utf8_buffer()
	var sender: PacketPeerUDP = PacketPeerUDP.new()
	var bind_err: Error = sender.bind(0)
	if bind_err != OK:
		return
	var dest_err: Error = sender.set_dest_address(target_ip, target_port)
	if dest_err != OK:
		sender.close()
		return
	sender.put_packet(bytes)
	sender.close()


func _build_announcement_payload() -> Dictionary:
	return {
		"magic": PROTOCOL_MAGIC,
		"type": MESSAGE_ANNOUNCE,
		"lobby_id": String(lobby_metadata.get("lobby_id", local_peer_identity.stable_id)),
		"port": int(lobby_metadata.get("port", DEFAULT_PORT)),
		"project_id": String(lobby_metadata.get("project_id", "")),
		"project_name": String(lobby_metadata.get("project_name", "Untitled Project")),
		"root_board_id": String(lobby_metadata.get("root_board_id", "")),
		"host_display_name": local_peer_identity.display_name,
		"host_stable_id": local_peer_identity.stable_id,
		"format_version": int(lobby_metadata.get("format_version", 1)),
		"member_count": active_peers().size(),
		"max_members": MAX_PEERS,
	}


func _handle_incoming_announcement(bytes: PackedByteArray, sender_ip: String) -> void:
	var raw: String = bytes.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if String(data.get("magic", "")) != PROTOCOL_MAGIC:
		return
	if String(data.get("type", "")) != MESSAGE_ANNOUNCE:
		return
	var lobby_id: String = String(data.get("lobby_id", ""))
	if lobby_id == "":
		return
	var entry: Dictionary = {
		"lobby_id": lobby_id,
		"address": sender_ip,
		"port": int(data.get("port", DEFAULT_PORT)),
		"project_id": String(data.get("project_id", "")),
		"project_name": String(data.get("project_name", "Untitled Project")),
		"root_board_id": String(data.get("root_board_id", "")),
		"host_display_name": String(data.get("host_display_name", "Host")),
		"host_stable_id": String(data.get("host_stable_id", "")),
		"format_version": int(data.get("format_version", 1)),
		"member_count": int(data.get("member_count", 1)),
		"max_members": int(data.get("max_members", MAX_PEERS)),
		"adapter_kind": ADAPTER_KIND_LAN,
		"last_seen_ms": Time.get_ticks_msec(),
	}
	var was_change: bool = not _seen_lobbies.has(lobby_id) or _lobby_metadata_differs(_seen_lobbies[lobby_id], entry)
	_seen_lobbies[lobby_id] = entry
	if was_change:
		emit_signal("lobby_list_updated", _build_lobby_list())


func _lobby_metadata_differs(prior: Dictionary, current: Dictionary) -> bool:
	for key: String in ["address", "port", "project_id", "project_name", "host_display_name", "member_count"]:
		if prior.get(key, null) != current.get(key, null):
			return true
	return false


func _on_probe_tick() -> void:
	if not _is_discovering or _client_socket == null:
		return
	var probe: Dictionary = {
		"magic": PROTOCOL_MAGIC,
		"type": MESSAGE_PROBE,
	}
	var bytes: PackedByteArray = JSON.stringify(probe).to_utf8_buffer()
	_client_socket.put_packet(bytes)


func _on_scrub_tick() -> void:
	var now: int = Time.get_ticks_msec()
	var stale: Array[String] = []
	for lobby_id: String in _seen_lobbies.keys():
		var entry: Dictionary = _seen_lobbies[lobby_id]
		var last_seen: int = int(entry.get("last_seen_ms", 0))
		if now - last_seen > int(LOBBY_TIMEOUT_SEC * 1000.0):
			stale.append(lobby_id)
	if stale.is_empty():
		return
	for lobby_id: String in stale:
		_seen_lobbies.erase(lobby_id)
	emit_signal("lobby_list_updated", _build_lobby_list())


func _build_lobby_list() -> Array:
	var out: Array = []
	for entry in _seen_lobbies.values():
		out.append((entry as Dictionary).duplicate())
	out.sort_custom(_compare_lobby_entries)
	return out


func _compare_lobby_entries(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("project_name", "")).naturalnocasecmp_to(String(b.get("project_name", ""))) < 0
