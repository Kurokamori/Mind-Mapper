class_name SteamAdapter
extends NetworkAdapter

const STEAM_PROBE_SINGLETONS: Array[String] = ["Steam", "GodotSteam"]
const LOBBY_TYPE_FRIENDS_ONLY: int = 1
const LOBBY_TYPE_INVISIBLE: int = 3
const STEAM_CHANNEL_RELIABLE: int = 0
const STEAM_CHANNEL_UNRELIABLE: int = 1
const STEAM_SEND_RELIABLE: int = 8
const STEAM_SEND_UNRELIABLE: int = 0

var _steam: Object = null
var _steam_singleton_name: String = ""
var _lobby_id: int = 0
var _peers_by_steam_id: Dictionary = {}
var _peers_by_network_id: Dictionary = {}
var _next_synthetic_network_id: int = 2
var _steam_id_to_network_id: Dictionary = {}
var _is_owner: bool = false


func adapter_kind() -> String:
	return ADAPTER_KIND_STEAM


func is_available() -> bool:
	return _steam != null


func unavailability_reason() -> String:
	if _steam != null:
		return ""
	return "Steam multiplayer is unavailable in this build. Install the GodotSteam addon and run the game through Steam."


func _ready() -> void:
	_resolve_steam_singleton()


func _resolve_steam_singleton() -> void:
	var root: Node = Engine.get_main_loop().root if Engine.get_main_loop() != null else null
	if root == null:
		return
	for name: String in STEAM_PROBE_SINGLETONS:
		if root.has_node(name):
			var node: Node = root.get_node(name)
			if node != null:
				_steam = node
				_steam_singleton_name = name
				_connect_steam_signals(node)
				return
	for name: String in STEAM_PROBE_SINGLETONS:
		if Engine.has_singleton(name):
			_steam = Engine.get_singleton(name)
			_steam_singleton_name = name
			_connect_steam_signals_object(_steam)
			return


func _connect_steam_signals(node: Node) -> void:
	if node.has_signal("lobby_created") and not node.is_connected("lobby_created", _on_steam_lobby_created):
		node.connect("lobby_created", _on_steam_lobby_created)
	if node.has_signal("lobby_joined") and not node.is_connected("lobby_joined", _on_steam_lobby_joined):
		node.connect("lobby_joined", _on_steam_lobby_joined)
	if node.has_signal("lobby_chat_update") and not node.is_connected("lobby_chat_update", _on_steam_lobby_chat_update):
		node.connect("lobby_chat_update", _on_steam_lobby_chat_update)
	if node.has_signal("p2p_session_request") and not node.is_connected("p2p_session_request", _on_p2p_session_request):
		node.connect("p2p_session_request", _on_p2p_session_request)
	if node.has_signal("network_messages_session_request") and not node.is_connected("network_messages_session_request", _on_p2p_session_request):
		node.connect("network_messages_session_request", _on_p2p_session_request)
	if node.has_signal("lobby_match_list") and not node.is_connected("lobby_match_list", _on_lobby_match_list):
		node.connect("lobby_match_list", _on_lobby_match_list)
	set_process(true)


func _connect_steam_signals_object(obj: Object) -> void:
	if obj == null:
		return
	if obj.has_signal("lobby_created") and not obj.is_connected("lobby_created", _on_steam_lobby_created):
		obj.connect("lobby_created", _on_steam_lobby_created)
	if obj.has_signal("lobby_joined") and not obj.is_connected("lobby_joined", _on_steam_lobby_joined):
		obj.connect("lobby_joined", _on_steam_lobby_joined)
	if obj.has_signal("lobby_chat_update") and not obj.is_connected("lobby_chat_update", _on_steam_lobby_chat_update):
		obj.connect("lobby_chat_update", _on_steam_lobby_chat_update)
	if obj.has_signal("p2p_session_request") and not obj.is_connected("p2p_session_request", _on_p2p_session_request):
		obj.connect("p2p_session_request", _on_p2p_session_request)
	if obj.has_signal("network_messages_session_request") and not obj.is_connected("network_messages_session_request", _on_p2p_session_request):
		obj.connect("network_messages_session_request", _on_p2p_session_request)
	if obj.has_signal("lobby_match_list") and not obj.is_connected("lobby_match_list", _on_lobby_match_list):
		obj.connect("lobby_match_list", _on_lobby_match_list)
	set_process(true)


func host(metadata: Dictionary) -> Error:
	if not is_available():
		_emit_error(unavailability_reason())
		_set_state(STATE_ERROR)
		return ERR_UNCONFIGURED
	_is_owner = true
	update_lobby_metadata(metadata)
	var max_members: int = int(metadata.get("max_members", 16))
	if _steam.has_method("createLobby"):
		_steam.call("createLobby", LOBBY_TYPE_FRIENDS_ONLY, max_members)
	elif _steam.has_method("create_lobby"):
		_steam.call("create_lobby", LOBBY_TYPE_FRIENDS_ONLY, max_members)
	else:
		_emit_error("Steam.createLobby unavailable on this build")
		return ERR_UNAVAILABLE
	_set_state(STATE_RESOLVING)
	return OK


func join(connect_info: Dictionary) -> Error:
	if not is_available():
		_emit_error(unavailability_reason())
		_set_state(STATE_ERROR)
		return ERR_UNCONFIGURED
	_is_owner = false
	var lobby_id: int = int(connect_info.get("lobby_id", 0))
	if lobby_id == 0:
		_emit_error("Steam join missing lobby_id")
		return ERR_INVALID_PARAMETER
	if _steam.has_method("joinLobby"):
		_steam.call("joinLobby", lobby_id)
	elif _steam.has_method("join_lobby"):
		_steam.call("join_lobby", lobby_id)
	else:
		_emit_error("Steam.joinLobby unavailable on this build")
		return ERR_UNAVAILABLE
	_set_state(STATE_CONNECTING)
	return OK


func leave() -> void:
	if _steam != null and _lobby_id != 0:
		if _steam.has_method("leaveLobby"):
			_steam.call("leaveLobby", _lobby_id)
		elif _steam.has_method("leave_lobby"):
			_steam.call("leave_lobby", _lobby_id)
	_lobby_id = 0
	_peers_by_steam_id.clear()
	_peers_by_network_id.clear()
	_steam_id_to_network_id.clear()
	_set_state(STATE_DISCONNECTED)


func discover_lobbies(filter: Dictionary) -> Error:
	if not is_available():
		return ERR_UNAVAILABLE
	if _steam.has_method("addRequestLobbyListStringFilter"):
		var format_version: int = int(filter.get("format_version", 1))
		_steam.call("addRequestLobbyListStringFilter", "format_version", str(format_version), 0)
	if _steam.has_method("requestLobbyList"):
		_steam.call("requestLobbyList")
	return OK


func send_to_peer(peer_network_id: int, kind: String, payload: Variant) -> Error:
	if not is_available():
		return ERR_UNAVAILABLE
	if peer_network_id == BROADCAST_NETWORK_ID:
		return send_to_all(kind, payload)
	var ident: PeerIdentity = _peers_by_network_id.get(peer_network_id, null) as PeerIdentity
	if ident == null:
		return ERR_DOES_NOT_EXIST
	var steam_id: int = int(ident.stable_id) if ident.stable_id.is_valid_int() else 0
	if steam_id == 0:
		return ERR_DOES_NOT_EXIST
	return _steam_send(steam_id, kind, payload)


func send_to_all(kind: String, payload: Variant) -> Error:
	if not is_available():
		return ERR_UNAVAILABLE
	for ident_v: Variant in _peers_by_network_id.values():
		var ident: PeerIdentity = ident_v as PeerIdentity
		if ident == null or local_peer_identity != null and ident.network_id == local_peer_identity.network_id:
			continue
		var steam_id: int = int(ident.stable_id) if ident.stable_id.is_valid_int() else 0
		if steam_id == 0:
			continue
		_steam_send(steam_id, kind, payload)
	return OK


func active_peers() -> Array[PeerIdentity]:
	var out: Array[PeerIdentity] = []
	for v in _peers_by_network_id.values():
		out.append(v as PeerIdentity)
	return out


func _steam_send(steam_id: int, kind: String, payload: Variant) -> Error:
	var envelope: Dictionary = NetworkMessage.envelope(kind, payload)
	var bytes: PackedByteArray = JSON.stringify(envelope).to_utf8_buffer()
	var channel: int = NetworkMessage.channel_for(kind)
	var send_type: int = STEAM_SEND_UNRELIABLE if NetworkMessage.is_unreliable(kind) else STEAM_SEND_RELIABLE
	if _steam.has_method("sendP2PPacket"):
		_steam.call("sendP2PPacket", steam_id, bytes, send_type, channel)
		return OK
	if _steam.has_method("sendMessageToUser"):
		_steam.call("sendMessageToUser", steam_id, bytes, send_type, channel)
		return OK
	return ERR_UNAVAILABLE


func _process(_delta: float) -> void:
	if not is_available() or not is_connected_to_session() and connection_state != STATE_RESOLVING and connection_state != STATE_CONNECTING:
		return
	_drain_p2p_packets()


func _drain_p2p_packets() -> void:
	if _steam == null:
		return
	for channel: int in [STEAM_CHANNEL_RELIABLE, STEAM_CHANNEL_UNRELIABLE]:
		if not _steam.has_method("getAvailableP2PPacketSize") and not _steam.has_method("get_available_p2p_packet_size"):
			break
		while _steam_has_packet(channel):
			var raw: Dictionary = _steam_read_packet(channel)
			if raw.is_empty():
				break
			var bytes: PackedByteArray = raw.get("data", PackedByteArray())
			var sender_steam_id: int = int(raw.get("steam_id_remote", 0))
			if bytes.is_empty() or sender_steam_id == 0:
				continue
			var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
			if typeof(parsed) != TYPE_DICTIONARY:
				continue
			var env: Dictionary = parsed
			var sender_network_id: int = _ensure_network_id_for_steam_id(sender_steam_id)
			emit_signal("message_received", sender_network_id, String(env.get("kind", "")), env.get("payload", null))


func _steam_has_packet(channel: int) -> bool:
	if _steam.has_method("getAvailableP2PPacketSize"):
		return int(_steam.call("getAvailableP2PPacketSize", channel)) > 0
	if _steam.has_method("get_available_p2p_packet_size"):
		return int(_steam.call("get_available_p2p_packet_size", channel)) > 0
	return false


func _steam_read_packet(channel: int) -> Dictionary:
	if _steam.has_method("readP2PPacket"):
		var v: Variant = _steam.call("readP2PPacket", 4096, channel)
		if typeof(v) == TYPE_DICTIONARY:
			return v
	if _steam.has_method("read_p2p_packet"):
		var v2: Variant = _steam.call("read_p2p_packet", 4096, channel)
		if typeof(v2) == TYPE_DICTIONARY:
			return v2
	return {}


func _ensure_network_id_for_steam_id(steam_id: int) -> int:
	var key: String = str(steam_id)
	if _steam_id_to_network_id.has(key):
		return int(_steam_id_to_network_id[key])
	var nid: int = _next_synthetic_network_id
	_next_synthetic_network_id += 1
	_steam_id_to_network_id[key] = nid
	return nid


func _on_steam_lobby_created(connect_result: int, lobby_id: int) -> void:
	if connect_result != 1:
		_emit_error("Steam createLobby failed (result=%d)" % connect_result)
		_set_state(STATE_ERROR)
		return
	_lobby_id = lobby_id
	if _steam.has_method("setLobbyData"):
		for key: String in lobby_metadata.keys():
			_steam.call("setLobbyData", lobby_id, key, str(lobby_metadata[key]))
	if local_peer_identity != null:
		local_peer_identity.network_id = HOST_NETWORK_ID
		_peers_by_network_id[HOST_NETWORK_ID] = local_peer_identity
		if local_peer_identity.stable_id.is_valid_int():
			_steam_id_to_network_id[local_peer_identity.stable_id] = HOST_NETWORK_ID
	_set_state(STATE_HOSTING)


func _on_steam_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != 1:
		_emit_error("Steam joinLobby failed (response=%d)" % response)
		_set_state(STATE_ERROR)
		return
	_lobby_id = lobby_id
	_set_state(STATE_CONNECTED)
	if local_peer_identity != null:
		var local_steam_id: int = _local_steam_id()
		var nid: int = _ensure_network_id_for_steam_id(local_steam_id) if local_steam_id != 0 else 1
		local_peer_identity.network_id = nid
		_peers_by_network_id[nid] = local_peer_identity


func _on_steam_lobby_chat_update(lobby_id: int, changed_id: int, _maker_id: int, chat_state: int) -> void:
	if lobby_id != _lobby_id:
		return
	if chat_state == 1:
		var nid: int = _ensure_network_id_for_steam_id(changed_id)
		var ident: PeerIdentity = PeerIdentity.make(ADAPTER_KIND_STEAM, nid, str(changed_id), _steam_persona_name(changed_id))
		_peers_by_network_id[nid] = ident
		_peers_by_steam_id[str(changed_id)] = ident
		emit_signal("peer_connected", ident)
	else:
		var nid_v: Variant = _steam_id_to_network_id.get(str(changed_id), null)
		if nid_v != null:
			var nid: int = int(nid_v)
			var ident: PeerIdentity = _peers_by_network_id.get(nid, null) as PeerIdentity
			_peers_by_network_id.erase(nid)
			_peers_by_steam_id.erase(str(changed_id))
			emit_signal("peer_disconnected", nid, "")
			if ident != null:
				MultiplayerService.notify_peer_left(ident)


func _on_p2p_session_request(remote_steam_id: int) -> void:
	if _steam.has_method("acceptP2PSessionWithUser"):
		_steam.call("acceptP2PSessionWithUser", remote_steam_id)


func _on_lobby_match_list(lobbies: Array) -> void:
	var out: Array = []
	for raw_id: Variant in lobbies:
		var lobby_id: int = int(raw_id)
		var entry: Dictionary = {
			"lobby_id": lobby_id,
			"adapter_kind": ADAPTER_KIND_STEAM,
		}
		if _steam.has_method("getLobbyData"):
			entry["project_id"] = String(_steam.call("getLobbyData", lobby_id, "project_id"))
			entry["project_name"] = String(_steam.call("getLobbyData", lobby_id, "project_name"))
			entry["root_board_id"] = String(_steam.call("getLobbyData", lobby_id, "root_board_id"))
			entry["host_display_name"] = String(_steam.call("getLobbyData", lobby_id, "host_display_name"))
			entry["host_stable_id"] = String(_steam.call("getLobbyData", lobby_id, "host_stable_id"))
			entry["format_version"] = int(_steam.call("getLobbyData", lobby_id, "format_version"))
		out.append(entry)
	emit_signal("lobby_list_updated", out)


func _local_steam_id() -> int:
	if _steam == null:
		return 0
	if _steam.has_method("getSteamID"):
		return int(_steam.call("getSteamID"))
	if _steam.has_method("get_steam_id"):
		return int(_steam.call("get_steam_id"))
	return 0


func _steam_persona_name(steam_id: int) -> String:
	if _steam == null:
		return "Steam User"
	if _steam.has_method("getFriendPersonaName"):
		return String(_steam.call("getFriendPersonaName", steam_id))
	if _steam.has_method("get_friend_persona_name"):
		return String(_steam.call("get_friend_persona_name", steam_id))
	return "Steam User"
