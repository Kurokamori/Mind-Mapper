class_name LanSyncHost
extends Node

signal client_connected(remote_address: String)
signal client_disconnected(remote_address: String)
signal file_received(relative_path: String, byte_count: int)
signal log_message(severity: String, message: String)

const HOST_NAME_FALLBACK: String = "Loom Desktop"

var _project: Project = null
var _tcp_server: TCPServer = null
var _udp_socket: PacketPeerUDP = null
var _announce_timer: Timer = null
var _process_timer: Timer = null
var _connections: Array = []
var _running: bool = false
var _host_display_name: String = ""


func _ready() -> void:
	_announce_timer = Timer.new()
	_announce_timer.wait_time = LanSyncProtocol.ANNOUNCE_INTERVAL_SEC
	_announce_timer.one_shot = false
	_announce_timer.autostart = false
	_announce_timer.timeout.connect(_on_announce_tick)
	add_child(_announce_timer)
	_process_timer = Timer.new()
	_process_timer.wait_time = 0.05
	_process_timer.one_shot = false
	_process_timer.autostart = false
	_process_timer.timeout.connect(_on_process_tick)
	add_child(_process_timer)


func is_running() -> bool:
	return _running


func bind_project(project: Project) -> void:
	_project = project


func current_project() -> Project:
	return _project


func set_host_display_name(name: String) -> void:
	_host_display_name = name.strip_edges()


func start() -> Error:
	if _running:
		return OK
	if _project == null:
		return ERR_UNCONFIGURED
	_tcp_server = TCPServer.new()
	var tcp_err: Error = _tcp_server.listen(LanSyncProtocol.TCP_PORT)
	if tcp_err != OK:
		_tcp_server = null
		_emit_log("error", "TCP listen failed: %d" % tcp_err)
		return tcp_err
	_udp_socket = PacketPeerUDP.new()
	_udp_socket.set_broadcast_enabled(true)
	var udp_err: Error = _udp_socket.bind(0, "0.0.0.0")
	if udp_err != OK:
		_emit_log("warning", "UDP bind for outbound announces failed: %d" % udp_err)
	_udp_socket.set_dest_address("255.255.255.255", LanSyncProtocol.UDP_PORT)
	_running = true
	_announce_timer.start()
	_process_timer.start()
	_emit_log("info", "LAN sync host started on TCP %d, announcing on UDP %d" % [LanSyncProtocol.TCP_PORT, LanSyncProtocol.UDP_PORT])
	for ip: String in IP.get_local_addresses():
		if not ip.contains(":") and not ip.begins_with("127."):
			_emit_log("info", "Listening on local address %s" % ip)
	_on_announce_tick()
	return OK


func stop() -> void:
	if not _running:
		return
	_running = false
	_announce_timer.stop()
	_process_timer.stop()
	if _tcp_server != null:
		_tcp_server.stop()
		_tcp_server = null
	if _udp_socket != null:
		_udp_socket.close()
		_udp_socket = null
	for entry: Dictionary in _connections:
		var conn: StreamPeerTCP = entry.get("stream", null)
		if conn != null:
			conn.disconnect_from_host()
	_connections.clear()


func _on_announce_tick() -> void:
	if not _running or _udp_socket == null or _project == null:
		return
	var packet: PackedByteArray = LanSyncProtocol.make_announce_packet(
		_project.id,
		_project.name,
		_effective_host_name(),
	)
	_udp_socket.set_dest_address("255.255.255.255", LanSyncProtocol.UDP_PORT)
	_udp_socket.put_packet(packet)
	for subnet_broadcast: String in _local_subnet_broadcasts():
		_udp_socket.set_dest_address(subnet_broadcast, LanSyncProtocol.UDP_PORT)
		_udp_socket.put_packet(packet)


func _local_subnet_broadcasts() -> Array[String]:
	var out: Array[String] = []
	var addresses: PackedStringArray = IP.get_local_addresses()
	for raw_address: String in addresses:
		if raw_address.contains(":"):
			continue
		var parts: PackedStringArray = raw_address.split(".")
		if parts.size() != 4:
			continue
		var broadcast_address: String = "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
		if not out.has(broadcast_address):
			out.append(broadcast_address)
	return out


func _effective_host_name() -> String:
	if _host_display_name != "":
		return _host_display_name
	var sys: String = OS.get_environment("COMPUTERNAME")
	if sys == "":
		sys = OS.get_environment("HOSTNAME")
	if sys == "":
		sys = HOST_NAME_FALLBACK
	return sys


func _on_process_tick() -> void:
	if not _running:
		return
	_accept_new_connections()
	_process_connections()


func _accept_new_connections() -> void:
	if _tcp_server == null:
		return
	while _tcp_server.is_connection_available():
		var stream: StreamPeerTCP = _tcp_server.take_connection()
		if stream == null:
			break
		var address: String = stream.get_connected_host()
		var entry: Dictionary = {
			"stream": stream,
			"reader": LanSyncEnvelopeReader.new(),
			"address": address,
			"hello_done": false,
		}
		_connections.append(entry)
		_emit_log("info", "Client connected: %s" % address)
		client_connected.emit(address)


func _process_connections() -> void:
	var to_remove: Array = []
	for entry: Dictionary in _connections:
		var stream: StreamPeerTCP = entry["stream"]
		stream.poll()
		var status: int = stream.get_status()
		if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
			to_remove.append(entry)
			continue
		var available: int = stream.get_available_bytes()
		if available > 0:
			var pkg: Array = stream.get_data(available)
			var err: Error = pkg[0]
			if err != OK:
				_emit_log("warning", "Read error on %s: %d" % [entry["address"], err])
				to_remove.append(entry)
				continue
			var data: PackedByteArray = pkg[1]
			var reader: LanSyncEnvelopeReader = entry["reader"]
			reader.feed(data)
			if reader.is_in_error():
				_emit_log("warning", "Envelope error from %s: %s" % [entry["address"], reader.error_message()])
				to_remove.append(entry)
				continue
			while reader.has_envelope():
				var envelope: Dictionary = reader.consume_envelope()
				if envelope.is_empty():
					break
				_handle_message(entry, envelope)
				if reader.is_in_error():
					to_remove.append(entry)
					break
	for entry: Dictionary in to_remove:
		_close_connection(entry)


func _close_connection(entry: Dictionary) -> void:
	var stream: StreamPeerTCP = entry.get("stream", null)
	if stream != null:
		stream.disconnect_from_host()
	_connections.erase(entry)
	_emit_log("info", "Client disconnected: %s" % entry.get("address", ""))
	client_disconnected.emit(String(entry.get("address", "")))


func _handle_message(entry: Dictionary, envelope: Dictionary) -> void:
	var message: Dictionary = envelope.get("message", {}) as Dictionary
	var body: PackedByteArray = envelope.get("body", PackedByteArray()) as PackedByteArray
	var kind: String = String(message.get(LanSyncProtocol.KIND_FIELD, ""))
	match kind:
		LanSyncProtocol.MSG_HELLO:
			_handle_hello(entry, message)
		LanSyncProtocol.MSG_LIST:
			_handle_list(entry)
		LanSyncProtocol.MSG_GET:
			_handle_get(entry, message)
		LanSyncProtocol.MSG_PUT:
			_handle_put(entry, message, body)
		LanSyncProtocol.MSG_PING:
			_send(entry, LanSyncProtocol.MSG_PONG, {}, PackedByteArray())
		LanSyncProtocol.MSG_BYE:
			_close_connection(entry)
		_:
			_emit_log("warning", "Unknown message kind: %s" % kind)


func _handle_hello(entry: Dictionary, message: Dictionary) -> void:
	entry["hello_done"] = true
	entry["client_name"] = String(message.get("client_name", "Mobile"))
	_send(entry, LanSyncProtocol.MSG_HELLO_OK, {
		"server_name": _effective_host_name(),
		"server_version": Project.FORMAT_VERSION,
		"project_summary": ProjectFileManifest.project_summary(_project),
	}, PackedByteArray())


func _handle_list(entry: Dictionary) -> void:
	if _project == null:
		_send(entry, LanSyncProtocol.MSG_GET_ERR, {"reason": "no_project"}, PackedByteArray())
		return
	var files: Array = ProjectFileManifest.build_for_project(_project)
	_send(entry, LanSyncProtocol.MSG_LIST_OK, {
		"project_summary": ProjectFileManifest.project_summary(_project),
		"files": files,
	}, PackedByteArray())


func _handle_get(entry: Dictionary, message: Dictionary) -> void:
	var relative: String = String(message.get("path", ""))
	if not ProjectFileManifest.is_safe_relative_path(relative):
		_send(entry, LanSyncProtocol.MSG_GET_ERR, {"path": relative, "reason": "unsafe_path"}, PackedByteArray())
		return
	if _project == null:
		_send(entry, LanSyncProtocol.MSG_GET_ERR, {"path": relative, "reason": "no_project"}, PackedByteArray())
		return
	var bytes: PackedByteArray = ProjectFileManifest.read_file_bytes(_project.folder_path, relative)
	if bytes.is_empty() and not _is_zero_byte_file(_project.folder_path, relative):
		_send(entry, LanSyncProtocol.MSG_GET_ERR, {"path": relative, "reason": "missing"}, PackedByteArray())
		return
	_send(entry, LanSyncProtocol.MSG_GET_OK, {
		"path": relative,
		"size": bytes.size(),
		"hash": LanSyncProtocol.sha256_hex(bytes),
	}, bytes)


func _handle_put(entry: Dictionary, message: Dictionary, body: PackedByteArray) -> void:
	var relative: String = String(message.get("path", ""))
	if not ProjectFileManifest.is_writable_from_client(relative):
		_send(entry, LanSyncProtocol.MSG_PUT_ERR, {"path": relative, "reason": "write_forbidden"}, PackedByteArray())
		return
	if _project == null:
		_send(entry, LanSyncProtocol.MSG_PUT_ERR, {"path": relative, "reason": "no_project"}, PackedByteArray())
		return
	var declared_hash: String = String(message.get("hash", ""))
	var actual_hash: String = LanSyncProtocol.sha256_hex(body)
	if declared_hash != "" and declared_hash != actual_hash:
		_send(entry, LanSyncProtocol.MSG_PUT_ERR, {"path": relative, "reason": "hash_mismatch"}, PackedByteArray())
		return
	var err: Error = ProjectFileManifest.write_file_bytes(_project.folder_path, relative, body)
	if err != OK:
		_send(entry, LanSyncProtocol.MSG_PUT_ERR, {"path": relative, "reason": "write_failed", "code": err}, PackedByteArray())
		return
	_send(entry, LanSyncProtocol.MSG_PUT_OK, {"path": relative, "hash": actual_hash}, PackedByteArray())
	file_received.emit(relative, body.size())


func _is_zero_byte_file(project_root: String, relative_path: String) -> bool:
	var abs: String = project_root.path_join(relative_path)
	if not FileAccess.file_exists(abs):
		return false
	var f: FileAccess = FileAccess.open(abs, FileAccess.READ)
	if f == null:
		return false
	var size: int = int(f.get_length())
	f.close()
	return size == 0


func _send(entry: Dictionary, kind: String, payload: Dictionary, body: PackedByteArray) -> void:
	var stream: StreamPeerTCP = entry.get("stream", null)
	if stream == null:
		return
	var msg: Dictionary = LanSyncProtocol.make_message(kind, payload)
	var envelope: PackedByteArray = LanSyncProtocol.encode_envelope(msg, body)
	var err: Error = stream.put_data(envelope)
	if err != OK:
		_emit_log("warning", "put_data failed (%s): %d" % [kind, err])


func _emit_log(severity: String, message: String) -> void:
	if severity == "error":
		printerr("[LanSyncHost] %s" % message)
	else:
		print("[LanSyncHost:%s] %s" % [severity, message])
	log_message.emit(severity, message)
