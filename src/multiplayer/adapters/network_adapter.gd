class_name NetworkAdapter
extends Node

signal connection_state_changed(state: int)
signal peer_connected(peer_identity: PeerIdentity)
signal peer_disconnected(peer_network_id: int, reason: String)
signal message_received(from_network_id: int, kind: String, payload: Variant)
signal lobby_list_updated(lobbies: Array)
signal error_occurred(message: String)

const STATE_DISCONNECTED: int = 0
const STATE_RESOLVING: int = 1
const STATE_CONNECTING: int = 2
const STATE_HOSTING: int = 3
const STATE_CONNECTED: int = 4
const STATE_ERROR: int = 5

const HOST_NETWORK_ID: int = 1
const BROADCAST_NETWORK_ID: int = 0

const ADAPTER_KIND_STEAM: String = "steam"
const ADAPTER_KIND_LAN: String = "lan"
const ADAPTER_KIND_ENET: String = "enet"
const ADAPTER_KIND_WEBRTC: String = "webrtc"

var local_peer_identity: PeerIdentity = null
var connection_state: int = STATE_DISCONNECTED
var lobby_metadata: Dictionary = {}


func adapter_kind() -> String:
	return ""


func is_available() -> bool:
	return false


func unavailability_reason() -> String:
	return ""


func host(metadata: Dictionary) -> Error:
	push_error("NetworkAdapter.host not implemented for kind=%s" % adapter_kind())
	return ERR_UNCONFIGURED


func join(connect_info: Dictionary) -> Error:
	push_error("NetworkAdapter.join not implemented for kind=%s" % adapter_kind())
	return ERR_UNCONFIGURED


func leave() -> void:
	pass


func discover_lobbies(filter: Dictionary) -> Error:
	return OK


func cancel_discovery() -> void:
	pass


func send_to_peer(peer_network_id: int, kind: String, payload: Variant) -> Error:
	push_error("NetworkAdapter.send_to_peer not implemented for kind=%s" % adapter_kind())
	return ERR_UNCONFIGURED


func send_to_all(kind: String, payload: Variant) -> Error:
	push_error("NetworkAdapter.send_to_all not implemented for kind=%s" % adapter_kind())
	return ERR_UNCONFIGURED


func update_lobby_metadata(metadata: Dictionary) -> void:
	lobby_metadata = metadata.duplicate(true)


func active_peers() -> Array[PeerIdentity]:
	return []


func is_host() -> bool:
	return connection_state == STATE_HOSTING


func is_connected_to_session() -> bool:
	return connection_state == STATE_CONNECTED or connection_state == STATE_HOSTING


func _set_state(state: int) -> void:
	if connection_state == state:
		return
	connection_state = state
	emit_signal("connection_state_changed", state)


func _emit_error(message: String) -> void:
	push_error("NetworkAdapter[%s]: %s" % [adapter_kind(), message])
	emit_signal("error_occurred", message)
