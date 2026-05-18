class_name WebRTCSignalingClient
extends Node

signal connected()
signal hosted(room: String)
signal joined(room: String, host_peer_id: int, host_metadata: Dictionary, existing_peers: Array)
signal peer_joined(peer_id: int, metadata: Dictionary)
signal peer_left(peer_id: int, reason: String)
signal signal_received(from_peer_id: int, data: Dictionary)
signal room_closed(reason: String)
signal disconnected(close_code: int, reason: String)
signal error_received(code: String, message: String)

const PROTOCOL_VERSION: int = 1
const HELLO_TIMEOUT_SEC: float = 12.0
const ROOM_CODE_PATTERN: String = "^[A-Z0-9]{4,32}$"

const ROLE_NONE: int = 0
const ROLE_HOST: int = 1
const ROLE_JOIN: int = 2

var _socket: WebSocketPeer = null
var _url: String = ""
var _role: int = ROLE_NONE
var _hello_payload: Dictionary = {}
var _hello_sent: bool = false
var _hello_timer: Timer = null
var _is_connected: bool = false
var _is_polling: bool = false


func _ready() -> void:
	_hello_timer = Timer.new()
	_hello_timer.one_shot = true
	_hello_timer.wait_time = HELLO_TIMEOUT_SEC
	_hello_timer.timeout.connect(_on_hello_timeout)
	add_child(_hello_timer)
	set_process(false)


func is_connected_to_server() -> bool:
	return _is_connected


static func normalize_room_code(raw: String) -> String:
	return raw.strip_edges().to_upper()


static func is_valid_room_code(code: String) -> bool:
	if code.length() < 4 or code.length() > 32:
		return false
	var regex: RegEx = RegEx.new()
	if regex.compile(ROOM_CODE_PATTERN) != OK:
		return false
	return regex.search(code) != null


func host_room(url: String, room_code: String, peer_id: int, metadata: Dictionary) -> Error:
	if _is_polling:
		close()
	_role = ROLE_HOST
	_hello_payload = {
		"type": "host",
		"protocol": PROTOCOL_VERSION,
		"room": room_code,
		"peer_id": peer_id,
		"metadata": metadata.duplicate(true),
	}
	return _open(url)


func join_room(url: String, room_code: String, peer_id: int, metadata: Dictionary) -> Error:
	if _is_polling:
		close()
	_role = ROLE_JOIN
	_hello_payload = {
		"type": "join",
		"protocol": PROTOCOL_VERSION,
		"room": room_code,
		"peer_id": peer_id,
		"metadata": metadata.duplicate(true),
	}
	return _open(url)


func send_signal(to_peer_id: int, data: Dictionary) -> Error:
	if not _is_connected or _socket == null:
		return ERR_UNAVAILABLE
	var frame: Dictionary = {
		"type": "signal",
		"to": to_peer_id,
		"data": data,
	}
	return _send_json(frame)


func send_leave(reason: String) -> void:
	if not _is_connected or _socket == null:
		return
	var frame: Dictionary = {
		"type": "leave",
		"reason": reason,
	}
	_send_json(frame)


func flush_and_close(timeout_msec: int = 750) -> void:
	if _socket == null:
		close()
		return
	var deadline_usec: int = Time.get_ticks_usec() + (timeout_msec * 1000)
	while Time.get_ticks_usec() < deadline_usec:
		_socket.poll()
		var state: int = _socket.get_ready_state()
		if state != WebSocketPeer.STATE_OPEN:
			break
		if _socket.get_current_outbound_buffered_amount() == 0:
			break
		OS.delay_msec(10)
	if _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.close(1000, "client_leave")
	var close_deadline_usec: int = Time.get_ticks_usec() + (timeout_msec * 1000)
	while _socket != null and Time.get_ticks_usec() < close_deadline_usec:
		_socket.poll()
		var s: int = _socket.get_ready_state()
		if s == WebSocketPeer.STATE_CLOSED:
			break
		OS.delay_msec(10)
	close()


func close() -> void:
	_hello_timer.stop()
	_hello_sent = false
	_is_connected = false
	_role = ROLE_NONE
	if _socket != null:
		_socket.close()
		_socket = null
	_is_polling = false
	set_process(false)


func _open(url: String) -> Error:
	_url = url
	_socket = WebSocketPeer.new()
	var err: Error = _socket.connect_to_url(url)
	if err != OK:
		_socket = null
		return err
	_is_polling = true
	set_process(true)
	return OK


func _process(_delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	var state: int = _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _is_connected:
			_is_connected = true
			emit_signal("connected")
			_send_hello()
		if _socket == null:
			return
		while _socket.get_available_packet_count() > 0:
			var raw: PackedByteArray = _socket.get_packet()
			_handle_incoming(raw)
			if _socket == null:
				return
	elif state == WebSocketPeer.STATE_CLOSED:
		var code: int = _socket.get_close_code()
		var reason: String = _socket.get_close_reason()
		_hello_timer.stop()
		_socket = null
		_is_polling = false
		_is_connected = false
		_role = ROLE_NONE
		set_process(false)
		emit_signal("disconnected", code, reason)


func _send_hello() -> void:
	if _hello_sent:
		return
	if _hello_payload.is_empty():
		return
	if _send_json(_hello_payload) == OK:
		_hello_sent = true
		_hello_timer.start()


func _send_json(frame: Dictionary) -> Error:
	if _socket == null:
		return ERR_UNAVAILABLE
	var text: String = JSON.stringify(frame)
	var bytes: PackedByteArray = text.to_utf8_buffer()
	return _socket.send(bytes, WebSocketPeer.WRITE_MODE_TEXT)


func _handle_incoming(raw: PackedByteArray) -> void:
	var text: String = raw.get_string_from_utf8()
	if text == "":
		return
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var frame: Dictionary = parsed
	var kind: String = String(frame.get("type", ""))
	match kind:
		"hosted":
			_hello_timer.stop()
			emit_signal("hosted", String(frame.get("room", "")))
		"joined":
			_hello_timer.stop()
			var existing_raw: Variant = frame.get("existing_peers", [])
			var existing: Array = existing_raw if typeof(existing_raw) == TYPE_ARRAY else []
			emit_signal(
				"joined",
				String(frame.get("room", "")),
				int(frame.get("host_peer_id", 1)),
				(frame.get("host_metadata", {}) as Dictionary) if typeof(frame.get("host_metadata", {})) == TYPE_DICTIONARY else {},
				existing,
			)
		"peer_joined":
			var meta_raw: Variant = frame.get("metadata", {})
			emit_signal(
				"peer_joined",
				int(frame.get("peer_id", 0)),
				(meta_raw as Dictionary) if typeof(meta_raw) == TYPE_DICTIONARY else {},
			)
		"peer_left":
			emit_signal(
				"peer_left",
				int(frame.get("peer_id", 0)),
				String(frame.get("reason", "")),
			)
		"signal":
			var data_raw: Variant = frame.get("data", {})
			if typeof(data_raw) != TYPE_DICTIONARY:
				return
			emit_signal(
				"signal_received",
				int(frame.get("from", 0)),
				data_raw as Dictionary,
			)
		"room_closed":
			emit_signal("room_closed", String(frame.get("reason", "")))
		"error":
			emit_signal(
				"error_received",
				String(frame.get("code", "unknown")),
				String(frame.get("message", "")),
			)
		_:
			pass


func _on_hello_timeout() -> void:
	if _is_connected:
		emit_signal("error_received", "hello_timeout", "Signaling server did not acknowledge hello within %d seconds." % int(HELLO_TIMEOUT_SEC))
	close()
