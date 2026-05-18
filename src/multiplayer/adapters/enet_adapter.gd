class_name EnetAdapter
extends NetworkAdapter

const DEFAULT_PORT: int = 27819
const MAX_PEERS: int = 32
const CHANNEL_COUNT: int = 4
const RPC_RELIABLE_OPS: int = 0
const RPC_UNRELIABLE_PRESENCE: int = 0
const CHUNK_ASSEMBLY_TIMEOUT_MSEC: int = 30000

var _peer: ENetMultiplayerPeer = null
var _scene_tree: SceneTree = null
var _peers_by_id: Dictionary = {}
var _pending_hellos: Dictionary = {}
var _bind_address: String = "*"
var _bind_port: int = DEFAULT_PORT
var _remote_address: String = ""
var _remote_port: int = DEFAULT_PORT
var _outbound_chunk_counter: int = 0
var _inbound_chunks: Dictionary = {}


func adapter_kind() -> String:
	return ADAPTER_KIND_ENET


func is_available() -> bool:
	return true


func _ready() -> void:
	_scene_tree = get_tree()
	_attach_multiplayer_signals()


func _attach_multiplayer_signals() -> void:
	if _scene_tree == null:
		return
	var multiplayer_api: MultiplayerAPI = _scene_tree.get_multiplayer()
	if multiplayer_api == null:
		return
	if not multiplayer_api.peer_connected.is_connected(_on_peer_connected):
		multiplayer_api.peer_connected.connect(_on_peer_connected)
	if not multiplayer_api.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer_api.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer_api.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer_api.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer_api.connection_failed.is_connected(_on_connection_failed):
		multiplayer_api.connection_failed.connect(_on_connection_failed)
	if not multiplayer_api.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer_api.server_disconnected.connect(_on_server_disconnected)


func host(metadata: Dictionary) -> Error:
	if connection_state != STATE_DISCONNECTED:
		leave()
	_attach_multiplayer_signals()
	_peer = ENetMultiplayerPeer.new()
	_bind_port = int(metadata.get("port", DEFAULT_PORT))
	_bind_address = String(metadata.get("bind_address", "*"))
	var err: Error = _peer.create_server(_bind_port, MAX_PEERS, CHANNEL_COUNT)
	if err != OK:
		_peer = null
		_emit_error("ENet host failed: %s" % str(err))
		_set_state(STATE_ERROR)
		return err
	_scene_tree.get_multiplayer().multiplayer_peer = _peer
	update_lobby_metadata(metadata)
	if local_peer_identity != null:
		local_peer_identity.network_id = HOST_NETWORK_ID
		_peers_by_id[HOST_NETWORK_ID] = local_peer_identity
	_set_state(STATE_HOSTING)
	return OK


func join(connect_info: Dictionary) -> Error:
	if connection_state != STATE_DISCONNECTED:
		leave()
	_attach_multiplayer_signals()
	_peer = ENetMultiplayerPeer.new()
	_remote_address = String(connect_info.get("address", "127.0.0.1"))
	_remote_port = int(connect_info.get("port", DEFAULT_PORT))
	var err: Error = _peer.create_client(_remote_address, _remote_port, CHANNEL_COUNT)
	if err != OK:
		_peer = null
		_emit_error("ENet client failed: %s" % str(err))
		_set_state(STATE_ERROR)
		return err
	_scene_tree.get_multiplayer().multiplayer_peer = _peer
	_set_state(STATE_CONNECTING)
	return OK


func leave() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	if _scene_tree != null:
		var api: MultiplayerAPI = _scene_tree.get_multiplayer()
		if api.multiplayer_peer is ENetMultiplayerPeer:
			api.multiplayer_peer = null
	_peers_by_id.clear()
	_pending_hellos.clear()
	_inbound_chunks.clear()
	_set_state(STATE_DISCONNECTED)


func send_to_peer(peer_network_id: int, kind: String, payload: Variant) -> Error:
	if _scene_tree == null or not is_connected_to_session():
		return ERR_UNAVAILABLE
	var api: MultiplayerAPI = _scene_tree.get_multiplayer()
	var local_id: int = api.get_unique_id()
	if peer_network_id == local_id:
		emit_signal("message_received", local_id, kind, payload)
		return OK
	var max_bytes: int = _max_outbound_message_bytes()
	if max_bytes > 0:
		var encoded: PackedByteArray = var_to_bytes(payload)
		if encoded.size() > max_bytes:
			return _send_chunked_to_peer(peer_network_id, local_id, kind, encoded, max_bytes)
	rpc_id(peer_network_id, "_remote_receive", local_id, kind, payload)
	return OK


func send_to_all(kind: String, payload: Variant) -> Error:
	if _scene_tree == null or not is_connected_to_session():
		return ERR_UNAVAILABLE
	var api: MultiplayerAPI = _scene_tree.get_multiplayer()
	var local_id: int = api.get_unique_id()
	var max_bytes: int = _max_outbound_message_bytes()
	var encoded: PackedByteArray = PackedByteArray()
	var must_chunk: bool = false
	if max_bytes > 0:
		encoded = var_to_bytes(payload)
		must_chunk = encoded.size() > max_bytes
	for peer_id: int in api.get_peers():
		if peer_id == local_id:
			continue
		if must_chunk:
			_send_chunked_to_peer(peer_id, local_id, kind, encoded, max_bytes)
		else:
			rpc_id(peer_id, "_remote_receive", local_id, kind, payload)
	return OK


func _max_outbound_message_bytes() -> int:
	return 0


func _send_chunked_to_peer(peer_network_id: int, local_id: int, kind: String, encoded: PackedByteArray, max_bytes: int) -> Error:
	if max_bytes <= 0:
		return ERR_INVALID_PARAMETER
	_outbound_chunk_counter += 1
	var transfer_id: String = "%d-%d" % [local_id, _outbound_chunk_counter]
	var total_bytes: int = encoded.size()
	var total_chunks: int = int(ceil(float(total_bytes) / float(max_bytes)))
	for chunk_index: int in total_chunks:
		var start: int = chunk_index * max_bytes
		var end: int = min(start + max_bytes, total_bytes)
		var slice: PackedByteArray = encoded.slice(start, end)
		rpc_id(peer_network_id, "_remote_receive_chunk", local_id, transfer_id, chunk_index, total_chunks, kind, slice)
	return OK


@rpc("any_peer", "reliable", "call_remote")
func _remote_receive_chunk(_sender_remote_id: int, transfer_id: String, chunk_index: int, total_chunks: int, kind: String, chunk: PackedByteArray) -> void:
	var sender_real_id: int = multiplayer.get_remote_sender_id()
	if total_chunks <= 0 or chunk_index < 0 or chunk_index >= total_chunks:
		return
	var key: String = "%d::%s" % [sender_real_id, transfer_id]
	_purge_stale_chunk_assemblies()
	var state_v: Variant = _inbound_chunks.get(key, null)
	var state: Dictionary
	if state_v == null:
		var parts: Array = []
		parts.resize(total_chunks)
		state = {
			"parts": parts,
			"received": 0,
			"total": total_chunks,
			"kind": kind,
			"bytes": 0,
			"started_msec": Time.get_ticks_msec(),
		}
		_inbound_chunks[key] = state
	else:
		state = state_v
	if int(state["total"]) != total_chunks:
		_inbound_chunks.erase(key)
		return
	var existing: Variant = (state["parts"] as Array)[chunk_index]
	if existing != null and (existing as PackedByteArray).size() > 0:
		return
	(state["parts"] as Array)[chunk_index] = chunk
	state["received"] = int(state["received"]) + 1
	state["bytes"] = int(state["bytes"]) + chunk.size()
	if int(state["received"]) < total_chunks:
		return
	_inbound_chunks.erase(key)
	var combined: PackedByteArray = PackedByteArray()
	for part_v: Variant in state["parts"] as Array:
		combined.append_array(part_v as PackedByteArray)
	var decoded: Variant = bytes_to_var(combined)
	emit_signal("message_received", sender_real_id, kind, decoded)


func _purge_stale_chunk_assemblies() -> void:
	if _inbound_chunks.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var stale_keys: Array = []
	for key_v: Variant in _inbound_chunks.keys():
		var st: Dictionary = _inbound_chunks[key_v]
		if now - int(st.get("started_msec", now)) > CHUNK_ASSEMBLY_TIMEOUT_MSEC:
			stale_keys.append(key_v)
	for k: Variant in stale_keys:
		_inbound_chunks.erase(k)


func active_peers() -> Array[PeerIdentity]:
	var out: Array[PeerIdentity] = []
	for v in _peers_by_id.values():
		out.append(v as PeerIdentity)
	return out


@rpc("any_peer", "reliable", "call_remote")
func _remote_receive(_sender_remote_id: int, kind: String, payload: Variant) -> void:
	var sender_real_id: int = multiplayer.get_remote_sender_id()
	emit_signal("message_received", sender_real_id, kind, payload)


func _on_peer_connected(peer_id: int) -> void:
	if local_peer_identity == null:
		return
	if connection_state == STATE_DISCONNECTED or connection_state == STATE_ERROR:
		return
	if not _peers_by_id.has(peer_id):
		var placeholder: PeerIdentity = PeerIdentity.make(adapter_kind(), peer_id, "", "Player")
		_peers_by_id[peer_id] = placeholder
		emit_signal("peer_connected", placeholder)
	if connection_state == STATE_HOSTING:
		var hello_payload: Dictionary = _build_hello_payload()
		rpc_id(peer_id, "_remote_receive", HOST_NETWORK_ID, NetworkMessage.KIND_HELLO, hello_payload)


func _on_peer_disconnected(peer_id: int) -> void:
	var ident: PeerIdentity = _peers_by_id.get(peer_id, null)
	_peers_by_id.erase(peer_id)
	_pending_hellos.erase(peer_id)
	emit_signal("peer_disconnected", peer_id, "")
	if ident != null:
		MultiplayerService.notify_peer_left(ident)


func _on_connected_to_server() -> void:
	_set_state(STATE_CONNECTED)
	if local_peer_identity != null:
		local_peer_identity.network_id = _scene_tree.get_multiplayer().get_unique_id()
		_peers_by_id[local_peer_identity.network_id] = local_peer_identity
	rpc_id(HOST_NETWORK_ID, "_remote_receive", _scene_tree.get_multiplayer().get_unique_id(), NetworkMessage.KIND_HELLO, _build_hello_payload())


func _on_connection_failed() -> void:
	_emit_error("ENet connection failed")
	_set_state(STATE_ERROR)


func _on_server_disconnected() -> void:
	_set_state(STATE_DISCONNECTED)
	_peers_by_id.clear()


func register_remote_peer(network_id: int, ident: PeerIdentity) -> void:
	var was_present: bool = _peers_by_id.has(network_id)
	_peers_by_id[network_id] = ident
	if not was_present:
		emit_signal("peer_connected", ident)


func _build_hello_payload() -> Dictionary:
	if local_peer_identity == null:
		return {}
	return {
		"identity": local_peer_identity.to_dict(),
		"adapter_kind": adapter_kind(),
	}
