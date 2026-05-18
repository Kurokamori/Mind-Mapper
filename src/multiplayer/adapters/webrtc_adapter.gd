class_name WebRTCAdapter
extends EnetAdapter

const SIGNALING_URL: String = "wss://loom-server-286e75174041.herokuapp.com/ws"
const DEFAULT_STUN_SERVERS: Array = [
	"stun:stun.l.google.com:19302",
	"stun:stun.cloudflare.com:3478",
]
const OPEN_RELAY_TURN_USERNAME: String = "openrelayproject"
const OPEN_RELAY_TURN_CREDENTIAL: String = "openrelayproject"
const OPEN_RELAY_TURN_URLS: Array = [
	"turn:openrelay.metered.ca:80",
	"turn:openrelay.metered.ca:443",
	"turn:openrelay.metered.ca:443?transport=tcp",
]
const CHANNEL_COUNT_WEBRTC: int = 4
const JOINER_PEER_ID_MIN: int = 2
const JOINER_PEER_ID_MAX: int = 2147483646
const WEBRTC_MAX_MESSAGE_BYTES: int = 14336

var _signaling: WebRTCSignalingClient = null
var _rtc_peer: WebRTCMultiplayerPeer = null
var _connections: Dictionary = {}
var _pending_remote_ice: Dictionary = {}
var _local_peer_id: int = 0
var _room_code: String = ""
var _signaling_url: String = ""
var _ice_servers: Array = []
var _host_metadata_for_room: Dictionary = {}
var _join_metadata_for_room: Dictionary = {}
var _availability_reason: String = ""


func adapter_kind() -> String:
	return ADAPTER_KIND_WEBRTC


func _max_outbound_message_bytes() -> int:
	return WEBRTC_MAX_MESSAGE_BYTES


func is_available() -> bool:
	if not ClassDB.class_exists("WebRTCPeerConnection"):
		_availability_reason = "Godot build is missing WebRTC support — install or rebuild Godot with the WebRTC module enabled."
		return false
	if not ClassDB.class_exists("WebRTCMultiplayerPeer"):
		_availability_reason = "Godot build is missing WebRTCMultiplayerPeer."
		return false
	_availability_reason = ""
	return true


func unavailability_reason() -> String:
	if is_available():
		return ""
	return _availability_reason


func _ready() -> void:
	super._ready()
	_signaling = WebRTCSignalingClient.new()
	_signaling.name = "Signaling"
	add_child(_signaling)
	_signaling.connected.connect(_on_signaling_connected)
	_signaling.hosted.connect(_on_signaling_hosted)
	_signaling.joined.connect(_on_signaling_joined)
	_signaling.peer_joined.connect(_on_signaling_peer_joined)
	_signaling.peer_left.connect(_on_signaling_peer_left)
	_signaling.signal_received.connect(_on_signaling_signal)
	_signaling.room_closed.connect(_on_signaling_room_closed)
	_signaling.disconnected.connect(_on_signaling_disconnected)
	_signaling.error_received.connect(_on_signaling_error)


func host(metadata: Dictionary) -> Error:
	if not is_available():
		_emit_error(unavailability_reason())
		return ERR_UNAVAILABLE
	var raw_room: String = String(metadata.get("room", ""))
	var room: String = WebRTCSignalingClient.normalize_room_code(raw_room)
	if not WebRTCSignalingClient.is_valid_room_code(room):
		_emit_error("Invalid room code (must be 4–32 alphanumeric characters).")
		_set_state(STATE_ERROR)
		return ERR_INVALID_PARAMETER
	if connection_state != STATE_DISCONNECTED:
		leave()
	_attach_multiplayer_signals()
	_ice_servers = _read_ice_servers(metadata)
	_signaling_url = SIGNALING_URL
	_room_code = room
	_local_peer_id = HOST_NETWORK_ID
	_host_metadata_for_room = _build_signaling_metadata(metadata, true)
	_rtc_peer = WebRTCMultiplayerPeer.new()
	var create_err: Error = _rtc_peer.create_mesh(_local_peer_id)
	if create_err != OK:
		_rtc_peer = null
		_emit_error("WebRTCMultiplayerPeer.create_mesh failed: %s" % str(create_err))
		_set_state(STATE_ERROR)
		return create_err
	_scene_tree.get_multiplayer().multiplayer_peer = _rtc_peer
	if local_peer_identity != null:
		local_peer_identity.kind = ADAPTER_KIND_WEBRTC
		local_peer_identity.network_id = HOST_NETWORK_ID
		_peers_by_id[HOST_NETWORK_ID] = local_peer_identity
	var lobby_metadata_local: Dictionary = metadata.duplicate(true)
	lobby_metadata_local["room"] = room
	update_lobby_metadata(lobby_metadata_local)
	_set_state(STATE_RESOLVING)
	var sig_err: Error = _signaling.host_room(SIGNALING_URL, room, _local_peer_id, _host_metadata_for_room)
	if sig_err != OK:
		_emit_error("Signaling host_room failed: %s" % str(sig_err))
		_teardown_rtc()
		_set_state(STATE_ERROR)
		return sig_err
	return OK


func join(connect_info: Dictionary) -> Error:
	if not is_available():
		_emit_error(unavailability_reason())
		return ERR_UNAVAILABLE
	var raw_room: String = String(connect_info.get("room", ""))
	var room: String = WebRTCSignalingClient.normalize_room_code(raw_room)
	if not WebRTCSignalingClient.is_valid_room_code(room):
		_emit_error("Invalid room code.")
		_set_state(STATE_ERROR)
		return ERR_INVALID_PARAMETER
	if connection_state != STATE_DISCONNECTED:
		leave()
	_attach_multiplayer_signals()
	_ice_servers = _read_ice_servers(connect_info)
	_signaling_url = SIGNALING_URL
	_room_code = room
	_local_peer_id = _generate_joiner_peer_id()
	_join_metadata_for_room = _build_signaling_metadata(connect_info, false)
	_rtc_peer = WebRTCMultiplayerPeer.new()
	var create_err: Error = _rtc_peer.create_mesh(_local_peer_id)
	if create_err != OK:
		_rtc_peer = null
		_emit_error("WebRTCMultiplayerPeer.create_mesh failed: %s" % str(create_err))
		_set_state(STATE_ERROR)
		return create_err
	_scene_tree.get_multiplayer().multiplayer_peer = _rtc_peer
	if local_peer_identity != null:
		local_peer_identity.kind = ADAPTER_KIND_WEBRTC
		local_peer_identity.network_id = _local_peer_id
		_peers_by_id[_local_peer_id] = local_peer_identity
	_set_state(STATE_RESOLVING)
	var sig_err: Error = _signaling.join_room(SIGNALING_URL, room, _local_peer_id, _join_metadata_for_room)
	if sig_err != OK:
		_emit_error("Signaling join_room failed: %s" % str(sig_err))
		_teardown_rtc()
		_set_state(STATE_ERROR)
		return sig_err
	return OK


func leave() -> void:
	if _signaling != null and _signaling.is_connected_to_server():
		_signaling.send_leave("user_quit")
		_signaling.flush_and_close()
	elif _signaling != null:
		_signaling.close()
	_teardown_rtc()
	_pending_remote_ice.clear()
	_room_code = ""
	_signaling_url = ""
	_host_metadata_for_room.clear()
	_join_metadata_for_room.clear()
	_local_peer_id = 0
	if _scene_tree != null:
		var api: MultiplayerAPI = _scene_tree.get_multiplayer()
		if api.multiplayer_peer is WebRTCMultiplayerPeer:
			api.multiplayer_peer = null
	_peers_by_id.clear()
	_pending_hellos.clear()
	_inbound_chunks.clear()
	_set_state(STATE_DISCONNECTED)


func discover_lobbies(_filter: Dictionary) -> Error:
	emit_signal("lobby_list_updated", [])
	return OK


func current_room_code() -> String:
	return _room_code


func signaling_url() -> String:
	return _signaling_url


func _teardown_rtc() -> void:
	for peer_id_v: Variant in _connections.keys():
		var conn: WebRTCPeerConnection = _connections[peer_id_v] as WebRTCPeerConnection
		if conn != null:
			conn.close()
	_connections.clear()
	if _rtc_peer != null:
		_rtc_peer.close()
		_rtc_peer = null


func _read_ice_servers(source: Dictionary) -> Array:
	var raw: Variant = source.get("ice_servers", null)
	if typeof(raw) == TYPE_ARRAY and not (raw as Array).is_empty():
		var out: Array = []
		for v: Variant in raw as Array:
			if typeof(v) == TYPE_DICTIONARY:
				out.append((v as Dictionary).duplicate(true))
			else:
				out.append({"urls": String(v)})
		return out
	return _default_ice_servers()


func _default_ice_servers() -> Array:
	var entries: Array = []
	for stun_url: String in DEFAULT_STUN_SERVERS:
		entries.append({"urls": stun_url})
	for turn_url: String in OPEN_RELAY_TURN_URLS:
		entries.append({
			"urls": turn_url,
			"username": OPEN_RELAY_TURN_USERNAME,
			"credential": OPEN_RELAY_TURN_CREDENTIAL,
		})
	return entries


func _build_signaling_metadata(source: Dictionary, is_host: bool) -> Dictionary:
	var ident: PeerIdentity = local_peer_identity
	var display_name: String = ident.display_name if ident != null else "Player"
	var stable_id: String = ident.stable_id if ident != null else ""
	var meta: Dictionary = {
		"display_name": display_name,
		"stable_id": stable_id,
		"format_version": int(source.get("format_version", 1)),
	}
	if is_host:
		meta["project_id"] = String(source.get("project_id", ""))
		meta["project_name"] = String(source.get("project_name", "Untitled Project"))
		meta["root_board_id"] = String(source.get("root_board_id", ""))
		meta["host_display_name"] = display_name
		meta["host_stable_id"] = stable_id
		meta["max_members"] = int(source.get("max_members", MAX_PEERS))
	return meta


func _generate_joiner_peer_id() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(JOINER_PEER_ID_MIN, JOINER_PEER_ID_MAX)


func _build_peer_connection(remote_peer_id: int) -> WebRTCPeerConnection:
	if _rtc_peer == null:
		_emit_error("WebRTC peer not initialized when adding remote peer %d." % remote_peer_id)
		return null
	if remote_peer_id < 1 or remote_peer_id == _local_peer_id:
		_emit_error("Refusing to add invalid remote peer id %d (local id %d)." % [remote_peer_id, _local_peer_id])
		return null
	if _connections.has(remote_peer_id):
		return _connections[remote_peer_id] as WebRTCPeerConnection
	var ice_entries: Array = []
	for entry_v: Variant in _ice_servers:
		if typeof(entry_v) == TYPE_DICTIONARY:
			ice_entries.append((entry_v as Dictionary).duplicate(true))
		else:
			ice_entries.append({"urls": String(entry_v)})
	var conn: WebRTCPeerConnection = WebRTCPeerConnection.new()
	var init_config: Dictionary = {"iceServers": ice_entries}
	var err: Error = conn.initialize(init_config)
	if err != OK:
		_emit_error("WebRTCPeerConnection.initialize failed for peer %d: %s (%d)" % [remote_peer_id, error_string(err), err])
		return null
	conn.session_description_created.connect(_on_session_description_created.bind(remote_peer_id))
	conn.ice_candidate_created.connect(_on_ice_candidate_created.bind(remote_peer_id))
	var add_err: Error = _rtc_peer.add_peer(conn, remote_peer_id)
	if add_err != OK:
		_emit_error("WebRTCMultiplayerPeer.add_peer failed for peer %d (local %d): %s (%d). Ensure the WebRTC GDExtension is installed for this Godot build." % [remote_peer_id, _local_peer_id, error_string(add_err), add_err])
		return null
	_connections[remote_peer_id] = conn
	_flush_pending_ice(remote_peer_id, conn)
	return conn


func _drop_peer_connection(remote_peer_id: int) -> void:
	var had_connection: bool = _connections.has(remote_peer_id)
	var conn: WebRTCPeerConnection = _connections.get(remote_peer_id, null) as WebRTCPeerConnection
	if conn != null:
		conn.close()
	_connections.erase(remote_peer_id)
	_pending_remote_ice.erase(remote_peer_id)
	if had_connection and _rtc_peer != null and _rtc_peer.has_peer(remote_peer_id):
		_rtc_peer.remove_peer(remote_peer_id)


func _flush_pending_ice(remote_peer_id: int, conn: WebRTCPeerConnection) -> void:
	var pending: Variant = _pending_remote_ice.get(remote_peer_id, null)
	if typeof(pending) != TYPE_ARRAY:
		return
	for entry_v: Variant in pending as Array:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		conn.add_ice_candidate(
			String(entry.get("media", "")),
			int(entry.get("index", 0)),
			String(entry.get("name", "")),
		)
	_pending_remote_ice.erase(remote_peer_id)


func _queue_remote_ice(remote_peer_id: int, ice_data: Dictionary) -> void:
	var bucket: Array = _pending_remote_ice.get(remote_peer_id, [])
	bucket.append(ice_data.duplicate(true))
	_pending_remote_ice[remote_peer_id] = bucket


func _on_signaling_connected() -> void:
	pass


func _on_signaling_hosted(room: String) -> void:
	_room_code = room
	_set_state(STATE_HOSTING)


func _on_signaling_joined(room: String, host_peer_id: int, host_metadata: Dictionary, existing_peers: Array) -> void:
	_room_code = room
	_set_state(STATE_CONNECTING)
	_initiate_offer_for(host_peer_id, host_metadata)
	for entry_v: Variant in existing_peers:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var other_peer_id: int = int(entry.get("peer_id", 0))
		if other_peer_id == 0 or other_peer_id == _local_peer_id or other_peer_id == host_peer_id:
			continue
		var other_meta_raw: Variant = entry.get("metadata", {})
		var other_meta: Dictionary = other_meta_raw if typeof(other_meta_raw) == TYPE_DICTIONARY else {}
		_initiate_offer_for(other_peer_id, other_meta)


func _initiate_offer_for(remote_peer_id: int, _remote_metadata: Dictionary) -> void:
	if _connections.has(remote_peer_id):
		return
	var conn: WebRTCPeerConnection = _build_peer_connection(remote_peer_id)
	if conn == null:
		return
	var err: Error = conn.create_offer()
	if err != OK:
		_emit_error("WebRTCPeerConnection.create_offer failed for peer %d: %s" % [remote_peer_id, str(err)])


func _on_signaling_peer_joined(peer_id: int, _metadata: Dictionary) -> void:
	if peer_id == _local_peer_id:
		return
	if _connections.has(peer_id):
		return


func _on_signaling_peer_left(peer_id: int, _reason: String) -> void:
	if peer_id == _local_peer_id:
		return
	_drop_peer_connection(peer_id)


func _on_signaling_signal(from_peer_id: int, data: Dictionary) -> void:
	var kind: String = String(data.get("kind", ""))
	match kind:
		"offer":
			var conn_offer: WebRTCPeerConnection = _connections.get(from_peer_id, null) as WebRTCPeerConnection
			if conn_offer == null:
				conn_offer = _build_peer_connection(from_peer_id)
			if conn_offer == null:
				return
			conn_offer.set_remote_description("offer", String(data.get("sdp", "")))
		"answer":
			var conn_answer: WebRTCPeerConnection = _connections.get(from_peer_id, null) as WebRTCPeerConnection
			if conn_answer == null:
				return
			conn_answer.set_remote_description("answer", String(data.get("sdp", "")))
		"ice":
			var conn_ice: WebRTCPeerConnection = _connections.get(from_peer_id, null) as WebRTCPeerConnection
			if conn_ice == null:
				_queue_remote_ice(from_peer_id, data)
				return
			conn_ice.add_ice_candidate(
				String(data.get("media", "")),
				int(data.get("index", 0)),
				String(data.get("name", "")),
			)
		_:
			pass


func _on_signaling_room_closed(reason: String) -> void:
	_emit_error("Signaling room closed: %s" % reason)
	leave()


func _on_signaling_disconnected(close_code: int, reason: String) -> void:
	if connection_state == STATE_DISCONNECTED:
		return
	if close_code != 0:
		_emit_error("Signaling disconnected (code %d): %s" % [close_code, reason])
	_teardown_rtc()
	_set_state(STATE_DISCONNECTED)


func _on_signaling_error(code: String, message: String) -> void:
	_emit_error("Signaling error [%s]: %s" % [code, message])
	if connection_state == STATE_RESOLVING or connection_state == STATE_CONNECTING:
		_set_state(STATE_ERROR)


func _on_peer_connected(peer_id: int) -> void:
	if local_peer_identity == null:
		return
	if connection_state == STATE_DISCONNECTED or connection_state == STATE_ERROR:
		return
	if not _peers_by_id.has(peer_id):
		var placeholder: PeerIdentity = PeerIdentity.make(adapter_kind(), peer_id, "", "Player")
		_peers_by_id[peer_id] = placeholder
		emit_signal("peer_connected", placeholder)
	if connection_state == STATE_CONNECTING:
		_set_state(STATE_CONNECTED)
		if local_peer_identity != null:
			local_peer_identity.network_id = _local_peer_id
			_peers_by_id[_local_peer_id] = local_peer_identity
	var hello_payload: Dictionary = _build_hello_payload()
	rpc_id(peer_id, "_remote_receive", _local_peer_id, NetworkMessage.KIND_HELLO, hello_payload)


func _on_session_description_created(type: String, sdp: String, remote_peer_id: int) -> void:
	var conn: WebRTCPeerConnection = _connections.get(remote_peer_id, null) as WebRTCPeerConnection
	if conn == null:
		return
	var err: Error = conn.set_local_description(type, sdp)
	if err != OK:
		_emit_error("set_local_description(%s) failed for peer %d: %s" % [type, remote_peer_id, str(err)])
		return
	if _signaling == null or not _signaling.is_connected_to_server():
		return
	_signaling.send_signal(remote_peer_id, {
		"kind": type,
		"sdp": sdp,
	})


func _on_ice_candidate_created(media: String, index: int, name: String, remote_peer_id: int) -> void:
	if _signaling == null or not _signaling.is_connected_to_server():
		return
	_signaling.send_signal(remote_peer_id, {
		"kind": "ice",
		"media": media,
		"index": index,
		"name": name,
	})
