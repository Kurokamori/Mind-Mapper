class_name LanSyncHost
extends Node

signal client_connected(remote_address: String)
signal client_disconnected(remote_address: String)
signal file_received(relative_path: String, byte_count: int)
signal offer_received(connection_id: int, op_kind: String, client_name: String, address: String, conflicting_paths: Array, incoming_only_paths: Array, outgoing_only_paths: Array)
signal offer_finalized(connection_id: int, decision: String, applied_relative_paths: PackedStringArray, kept_mine_paths: PackedStringArray)
signal log_message(severity: String, message: String)

const HOST_NAME_FALLBACK: String = "Loom Desktop"
const NEW_CONNECTION_GRACE_MSEC: int = 5000
const SERVER_HELLO_RETRY_MSEC: int = 1000

const OFFER_STAGE_NONE: String = "none"
const OFFER_STAGE_AWAITING_DECISION: String = "awaiting_decision"
const OFFER_STAGE_AWAITING_RESOLUTION: String = "awaiting_resolution"
const OFFER_STAGE_COLLECTING: String = "collecting"
const OFFER_STAGE_COMPLETED: String = "completed"
const OFFER_STAGE_REJECTED: String = "rejected"

var _project: Project = null
var _tcp_server: TCPServer = null
var _udp_socket: PacketPeerUDP = null
var _announce_timer: Timer = null
var _process_timer: Timer = null
var _connections: Array = []
var _running: bool = false
var _host_display_name: String = ""
var _blocked_addresses: Dictionary = {}
var _next_connection_id: int = 1


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


func respond_to_offer(connection_id: int, decision: String, per_file_kept_mine: Dictionary) -> void:
	var entry: Dictionary = _find_connection_by_id(connection_id)
	if entry.is_empty():
		_emit_log("warning", "respond_to_offer: connection %d gone" % connection_id)
		return
	var offer: Dictionary = entry.get("offer", {}) as Dictionary
	if offer.is_empty() or String(offer.get("stage", OFFER_STAGE_NONE)) != OFFER_STAGE_AWAITING_DECISION:
		_emit_log("warning", "respond_to_offer: connection %d not awaiting decision" % connection_id)
		return
	offer["decision"] = decision
	offer["per_file_kept_mine"] = per_file_kept_mine.duplicate(true)
	offer["applied_paths"] = []
	offer["kept_mine_paths"] = []
	offer["complete_received"] = false
	var decision_payload: Dictionary = {
		LanSyncProtocol.OFFER_FIELD_DECISION: decision,
	}
	if decision == LanSyncProtocol.DECISION_REJECT or decision == LanSyncProtocol.DECISION_REJECT_AND_BLOCK:
		offer["stage"] = OFFER_STAGE_REJECTED
		if decision == LanSyncProtocol.DECISION_REJECT_AND_BLOCK:
			var address: String = String(entry.get("address", ""))
			if address != "":
				_blocked_addresses[address] = int(Time.get_unix_time_from_system())
	elif decision == LanSyncProtocol.DECISION_DEFER_TO_REQUESTER:
		offer["stage"] = OFFER_STAGE_AWAITING_RESOLUTION
		decision_payload[LanSyncProtocol.OFFER_FIELD_CONFLICTS] = (offer.get("conflicting_paths", []) as Array).duplicate()
		decision_payload[LanSyncProtocol.OFFER_FIELD_INCOMING_ONLY] = (offer.get("incoming_only_paths", []) as Array).duplicate()
		decision_payload[LanSyncProtocol.OFFER_FIELD_OUTGOING_ONLY] = (offer.get("outgoing_only_paths", []) as Array).duplicate()
		if _project != null:
			decision_payload[LanSyncProtocol.OFFER_FIELD_PROJECT_NAME] = _project.name
		decision_payload[LanSyncProtocol.OFFER_FIELD_HOST_NAME] = _effective_host_name()
	else:
		offer["stage"] = OFFER_STAGE_COLLECTING
	entry["offer"] = offer
	_send(entry, LanSyncProtocol.MSG_OFFER_DECISION, decision_payload, PackedByteArray())


func clear_address_block(address: String) -> void:
	_blocked_addresses.erase(address)


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
		stream.set_no_delay(true)
		var address: String = stream.get_connected_host()
		var entry: Dictionary = {
			"connection_id": _next_connection_id,
			"stream": stream,
			"reader": LanSyncEnvelopeReader.new(),
			"address": address,
			"client_name": "",
			"hello_done": false,
			"created_msec": Time.get_ticks_msec(),
			"last_activity_msec": Time.get_ticks_msec(),
			"last_server_hello_msec": 0,
			"offer": {},
			"pending_outbound": PackedByteArray(),
		}
		_next_connection_id += 1
		_connections.append(entry)
		_emit_log("info", "Client connected: %s (#%d)" % [address, int(entry["connection_id"])])
		client_connected.emit(address)
		_send_text_hello_ok(entry)
		_send_hello_ok(entry)


func _process_connections() -> void:
	var to_remove: Array = []
	for entry: Dictionary in _connections:
		var stream: StreamPeerTCP = entry["stream"]
		stream.poll()
		var status: int = stream.get_status()
		if status == StreamPeerTCP.STATUS_ERROR:
			to_remove.append(entry)
			continue
		if status == StreamPeerTCP.STATUS_NONE:
			if _connection_age_msec(entry) > NEW_CONNECTION_GRACE_MSEC:
				to_remove.append(entry)
			continue
		if not _flush_pending_outbound(entry):
			to_remove.append(entry)
			continue
		var available: int = stream.get_available_bytes()
		if available > 0:
			_emit_log("info", "Received %d byte(s) from %s" % [available, entry["address"]])
			entry["last_activity_msec"] = Time.get_ticks_msec()
			entry["hello_done"] = true
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
		elif not bool(entry.get("hello_done", false)):
			_maybe_resend_hello_ok(entry)
	for entry: Dictionary in to_remove:
		_close_connection(entry)


func _connection_age_msec(entry: Dictionary) -> int:
	return Time.get_ticks_msec() - int(entry.get("created_msec", Time.get_ticks_msec()))


func _close_connection(entry: Dictionary) -> void:
	var stream: StreamPeerTCP = entry.get("stream", null)
	if stream != null:
		stream.disconnect_from_host()
	_connections.erase(entry)
	_emit_log("info", "Client disconnected: %s" % entry.get("address", ""))
	client_disconnected.emit(String(entry.get("address", "")))


func _find_connection_by_id(connection_id: int) -> Dictionary:
	for entry: Dictionary in _connections:
		if int(entry.get("connection_id", -1)) == connection_id:
			return entry
	return {}


func _handle_message(entry: Dictionary, envelope: Dictionary) -> void:
	var message: Dictionary = envelope.get("message", {}) as Dictionary
	var body: PackedByteArray = envelope.get("body", PackedByteArray()) as PackedByteArray
	var kind: String = String(message.get(LanSyncProtocol.KIND_FIELD, ""))
	if kind != LanSyncProtocol.MSG_HELLO and not bool(entry.get("hello_done", false)):
		entry["hello_done"] = true
	match kind:
		LanSyncProtocol.MSG_HELLO:
			_handle_hello(entry, message)
		LanSyncProtocol.MSG_LIST:
			_handle_list(entry)
		LanSyncProtocol.MSG_GET:
			_handle_get(entry, message)
		LanSyncProtocol.MSG_PUT:
			_handle_put(entry, message, body)
		LanSyncProtocol.MSG_OFFER:
			_handle_offer(entry, message)
		LanSyncProtocol.MSG_PUSH_COMPLETE:
			_handle_push_complete(entry)
		LanSyncProtocol.MSG_OFFER_RESOLUTION:
			_handle_offer_resolution(entry, message)
		LanSyncProtocol.MSG_PING:
			_send(entry, LanSyncProtocol.MSG_PONG, {}, PackedByteArray())
		LanSyncProtocol.MSG_BYE:
			_close_connection(entry)
		_:
			_emit_log("warning", "Unknown message kind: %s" % kind)


func _handle_hello(entry: Dictionary, message: Dictionary) -> void:
	entry["hello_done"] = true
	entry["client_name"] = String(message.get("client_name", "Mobile"))
	_send_hello_ok(entry)


func _maybe_resend_hello_ok(entry: Dictionary) -> void:
	var now_msec: int = Time.get_ticks_msec()
	var last_msec: int = int(entry.get("last_server_hello_msec", 0))
	if now_msec - last_msec < SERVER_HELLO_RETRY_MSEC:
		return
	_send_text_hello_ok(entry)
	_send_hello_ok(entry)


func _send_hello_ok(entry: Dictionary) -> void:
	entry["last_server_hello_msec"] = Time.get_ticks_msec()
	_emit_log("info", "Sending binary hello_ok to %s" % entry.get("address", ""))
	_send(entry, LanSyncProtocol.MSG_HELLO_OK, {
		"server_name": _effective_host_name(),
		"server_version": Project.FORMAT_VERSION,
		"project_summary": ProjectFileManifest.project_summary(_project),
	}, PackedByteArray())


func _send_text_hello_ok(entry: Dictionary) -> void:
	var stream: StreamPeerTCP = entry.get("stream", null)
	if stream == null:
		return
	var payload: Dictionary = LanSyncProtocol.make_message(LanSyncProtocol.MSG_HELLO_OK, {
		"server_name": _effective_host_name(),
		"server_version": Project.FORMAT_VERSION,
		"project_summary": ProjectFileManifest.project_summary(_project),
		"text_greeting": true,
	})
	var bytes: PackedByteArray = (JSON.stringify(payload) + "\n").to_utf8_buffer()
	var err: Error = _write_all(stream, bytes)
	if err == OK:
		_emit_log("info", "Sent text hello_ok (%d bytes) to %s" % [bytes.size(), entry.get("address", "")])
		stream.poll()
	else:
		_emit_log("warning", "text hello_ok send failed for %s: %d" % [entry.get("address", ""), err])


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


func _handle_offer(entry: Dictionary, message: Dictionary) -> void:
	if _project == null:
		_send(entry, LanSyncProtocol.MSG_OFFER_DECISION, {
			LanSyncProtocol.OFFER_FIELD_DECISION: LanSyncProtocol.DECISION_REJECT,
			LanSyncProtocol.OFFER_FIELD_NOTE: "no_project_open",
		}, PackedByteArray())
		return
	var address: String = String(entry.get("address", ""))
	if _blocked_addresses.has(address):
		_send(entry, LanSyncProtocol.MSG_OFFER_DECISION, {
			LanSyncProtocol.OFFER_FIELD_DECISION: LanSyncProtocol.DECISION_REJECT_AND_BLOCK,
			LanSyncProtocol.OFFER_FIELD_NOTE: "blocked",
		}, PackedByteArray())
		return
	var op_kind: String = String(message.get(LanSyncProtocol.OFFER_FIELD_OP_KIND, LanSyncProtocol.OFFER_OP_PUSH))
	var client_name: String = String(message.get(LanSyncProtocol.OFFER_FIELD_CLIENT_NAME, entry.get("client_name", "Mobile")))
	if client_name.strip_edges() != "":
		entry["client_name"] = client_name
	var files_v: Variant = message.get(LanSyncProtocol.OFFER_FIELD_FILES, [])
	var incoming_files: Array = (files_v as Array).duplicate(true) if typeof(files_v) == TYPE_ARRAY else []
	var diff: Dictionary = _diff_against_local(incoming_files)
	var offer: Dictionary = {
		"stage": OFFER_STAGE_AWAITING_DECISION,
		"op_kind": op_kind,
		"client_name": client_name,
		"files": incoming_files,
		"incoming_by_path": _index_by_path(incoming_files),
		"conflicting_paths": diff["conflicting_paths"],
		"incoming_only_paths": diff["incoming_only_paths"],
		"outgoing_only_paths": diff["outgoing_only_paths"],
		"decision": "",
		"per_file_kept_mine": {},
		"applied_paths": [],
		"kept_mine_paths": [],
		"complete_received": false,
	}
	entry["offer"] = offer
	offer_received.emit(
		int(entry["connection_id"]),
		op_kind,
		client_name,
		address,
		(diff["conflicting_paths"] as Array).duplicate(),
		(diff["incoming_only_paths"] as Array).duplicate(),
		(diff["outgoing_only_paths"] as Array).duplicate(),
	)


func _diff_against_local(incoming_files: Array) -> Dictionary:
	var conflicting: Array = []
	var incoming_only: Array = []
	var incoming_set: Dictionary = {}
	var local_manifest: Array = ProjectFileManifest.build_for_project(_project)
	var local_by_path: Dictionary = _index_by_path(local_manifest)
	for entry_v: Variant in incoming_files:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry_d: Dictionary = entry_v
		var path: String = String(entry_d.get(ProjectFileManifest.FIELD_PATH, ""))
		if path == "":
			continue
		incoming_set[path] = true
		if not local_by_path.has(path):
			incoming_only.append(path)
			continue
		var local_entry: Dictionary = local_by_path[path]
		var local_hash: String = String(local_entry.get(ProjectFileManifest.FIELD_HASH, ""))
		var remote_hash: String = String(entry_d.get(ProjectFileManifest.FIELD_HASH, ""))
		if local_hash != "" and remote_hash != "" and local_hash != remote_hash:
			conflicting.append(path)
	var outgoing_only: Array = []
	for local_path_v: Variant in local_by_path.keys():
		var local_path: String = String(local_path_v)
		if not incoming_set.has(local_path) and ProjectFileManifest.is_writable_from_client(local_path):
			outgoing_only.append(local_path)
	conflicting.sort()
	incoming_only.sort()
	outgoing_only.sort()
	return {
		"conflicting_paths": conflicting,
		"incoming_only_paths": incoming_only,
		"outgoing_only_paths": outgoing_only,
	}


func _index_by_path(files: Array) -> Dictionary:
	var out: Dictionary = {}
	for entry_v: Variant in files:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry_d: Dictionary = entry_v
		out[String(entry_d.get(ProjectFileManifest.FIELD_PATH, ""))] = entry_d
	return out


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
	var offer: Dictionary = entry.get("offer", {}) as Dictionary
	var stage: String = String(offer.get("stage", OFFER_STAGE_NONE))
	if stage == OFFER_STAGE_REJECTED:
		_send(entry, LanSyncProtocol.MSG_PUT_ERR, {"path": relative, "reason": "rejected"}, PackedByteArray())
		return
	if stage == OFFER_STAGE_COLLECTING:
		_apply_offer_put(entry, offer, relative, body, message)
		return
	var err: Error = ProjectFileManifest.write_file_bytes(_project.folder_path, relative, body)
	if err != OK:
		_send(entry, LanSyncProtocol.MSG_PUT_ERR, {"path": relative, "reason": "write_failed", "code": err}, PackedByteArray())
		return
	_send(entry, LanSyncProtocol.MSG_PUT_OK, {"path": relative, "hash": actual_hash}, PackedByteArray())
	file_received.emit(relative, body.size())


func _apply_offer_put(entry: Dictionary, offer: Dictionary, relative: String, body: PackedByteArray, message: Dictionary) -> void:
	var decision: String = String(offer.get("decision", ""))
	var kept_mine: bool = false
	if decision == LanSyncProtocol.DECISION_ACCEPT_REVIEW:
		var per_file: Dictionary = offer.get("per_file_kept_mine", {}) as Dictionary
		kept_mine = bool(per_file.get(relative, false))
	elif decision == LanSyncProtocol.DECISION_ACCEPT_ALL:
		var incoming_mtime: int = int(message.get(ProjectFileManifest.FIELD_MTIME, 0))
		var local_abs: String = _project.folder_path.path_join(relative)
		if FileAccess.file_exists(local_abs):
			var local_mtime: int = int(FileAccess.get_modified_time(local_abs))
			kept_mine = local_mtime > incoming_mtime
		else:
			kept_mine = false
	if not kept_mine:
		var err: Error = ProjectFileManifest.write_file_bytes(_project.folder_path, relative, body)
		if err != OK:
			_send(entry, LanSyncProtocol.MSG_PUT_ERR, {"path": relative, "reason": "write_failed", "code": err}, PackedByteArray())
			return
		file_received.emit(relative, body.size())
	(offer["applied_paths"] as Array).append(relative)
	if kept_mine:
		(offer["kept_mine_paths"] as Array).append(relative)
	_send(entry, LanSyncProtocol.MSG_PUT_OK, {
		"path": relative,
		"hash": LanSyncProtocol.sha256_hex(body),
		LanSyncProtocol.OFFER_FIELD_KEPT_MINE: kept_mine,
	}, PackedByteArray())


func _handle_offer_resolution(entry: Dictionary, message: Dictionary) -> void:
	var offer: Dictionary = entry.get("offer", {}) as Dictionary
	if offer.is_empty() or String(offer.get("stage", OFFER_STAGE_NONE)) != OFFER_STAGE_AWAITING_RESOLUTION:
		_emit_log("warning", "offer_resolution received in unexpected stage")
		return
	var kept_mine_v: Variant = message.get(LanSyncProtocol.OFFER_FIELD_KEPT_MINE, {})
	var per_file: Dictionary = {}
	if typeof(kept_mine_v) == TYPE_DICTIONARY:
		for path_v: Variant in (kept_mine_v as Dictionary).keys():
			per_file[String(path_v)] = bool((kept_mine_v as Dictionary)[path_v])
	offer["decision"] = LanSyncProtocol.DECISION_ACCEPT_REVIEW
	offer["per_file_kept_mine"] = per_file
	offer["stage"] = OFFER_STAGE_COLLECTING
	entry["offer"] = offer
	_send(entry, LanSyncProtocol.MSG_OFFER_DECISION, {
		LanSyncProtocol.OFFER_FIELD_DECISION: LanSyncProtocol.DECISION_ACCEPT_REVIEW,
	}, PackedByteArray())


func _handle_push_complete(entry: Dictionary) -> void:
	var offer: Dictionary = entry.get("offer", {}) as Dictionary
	if offer.is_empty():
		return
	offer["complete_received"] = true
	offer["stage"] = OFFER_STAGE_COMPLETED
	var applied: Array = (offer.get("applied_paths", []) as Array)
	var kept_mine: Array = (offer.get("kept_mine_paths", []) as Array)
	var kept_mine_set: Dictionary = {}
	for path_v: Variant in kept_mine:
		kept_mine_set[String(path_v)] = true
	var resolutions: Array = []
	var applied_paths_packed: PackedStringArray = PackedStringArray()
	var kept_mine_packed: PackedStringArray = PackedStringArray()
	for path_v: Variant in applied:
		var path: String = String(path_v)
		applied_paths_packed.append(path)
		var is_kept_mine: bool = kept_mine_set.has(path)
		if is_kept_mine:
			kept_mine_packed.append(path)
		resolutions.append({
			"path": path,
			LanSyncProtocol.OFFER_FIELD_KEPT_MINE: is_kept_mine,
		})
	_send(entry, LanSyncProtocol.MSG_REVIEW_RESULT, {
		LanSyncProtocol.OFFER_FIELD_RESOLUTIONS: resolutions,
	}, PackedByteArray())
	offer_finalized.emit(int(entry["connection_id"]), String(offer.get("decision", "")), applied_paths_packed, kept_mine_packed)
	entry["offer"] = {}


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
	var pending: PackedByteArray = entry.get("pending_outbound", PackedByteArray()) as PackedByteArray
	pending.append_array(envelope)
	entry["pending_outbound"] = pending
	if not _flush_pending_outbound(entry):
		_emit_log("warning", "send failed (%s)" % kind)
		return
	stream.poll()


func _flush_pending_outbound(entry: Dictionary) -> bool:
	var stream: StreamPeerTCP = entry.get("stream", null)
	if stream == null:
		return false
	var pending: PackedByteArray = entry.get("pending_outbound", PackedByteArray()) as PackedByteArray
	if pending.is_empty():
		return true
	var offset: int = 0
	while offset < pending.size():
		var remaining: PackedByteArray = pending.slice(offset)
		var result: Array = stream.put_partial_data(remaining)
		var err: Error = result[0]
		if err != OK:
			_emit_log("warning", "outbound flush failed: %d" % err)
			entry["pending_outbound"] = PackedByteArray()
			return false
		var wrote: int = int(result[1])
		if wrote <= 0:
			break
		offset += wrote
	if offset > 0:
		entry["last_activity_msec"] = Time.get_ticks_msec()
	if offset >= pending.size():
		entry["pending_outbound"] = PackedByteArray()
	else:
		entry["pending_outbound"] = pending.slice(offset)
	return true


func _write_all(stream: StreamPeerTCP, bytes: PackedByteArray) -> Error:
	var offset: int = 0
	var guard: int = 0
	while offset < bytes.size():
		var remaining: PackedByteArray = bytes.slice(offset)
		var result: Array = stream.put_partial_data(remaining)
		var err: Error = result[0]
		if err != OK:
			return err
		var wrote: int = int(result[1])
		if wrote <= 0:
			stream.poll()
			guard += 1
			if guard > 4:
				return ERR_BUSY
			continue
		offset += wrote
		guard = 0
	return OK


func _emit_log(severity: String, message: String) -> void:
	if severity == "error":
		printerr("[LanSyncHost] %s" % message)
	else:
		print("[LanSyncHost:%s] %s" % [severity, message])
	log_message.emit(severity, message)
