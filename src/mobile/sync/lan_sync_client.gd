class_name LanSyncClient
extends Node

signal hosts_changed(host_list: Array)
signal connection_state_changed(state: int)
signal sync_progress(stage: String, current: int, total: int, current_path: String)
signal sync_completed(project_folder: String, project_id: String)
signal sync_failed(reason: String)
signal put_completed(relative_path: String)
signal put_failed(relative_path: String, reason: String)
signal log_message(severity: String, message: String)

const STATE_IDLE: int = 0
const STATE_CONNECTING: int = 1
const STATE_HANDSHAKING: int = 2
const STATE_FETCHING_MANIFEST: int = 3
const STATE_DOWNLOADING: int = 4
const STATE_READY: int = 5
const STATE_UPLOADING: int = 6
const STATE_ERROR: int = 7

const STAGE_MANIFEST: String = "manifest"
const STAGE_FILES: String = "files"

const SYNCING_MARKER_FILENAME: String = ".__syncing"

var _udp_listener: PacketPeerUDP = null
var _stream: StreamPeerTCP = null
var _reader: LanSyncEnvelopeReader = null
var _process_timer: Timer = null
var _scrub_timer: Timer = null
var _hosts: Dictionary = {}
var _state: int = STATE_IDLE
var _target_folder: String = ""
var _target_address: String = ""
var _target_port: int = 0
var _expected_project_id: String = ""
var _files_pending: Array = []
var _files_total: int = 0
var _current_path: String = ""
var _client_display_name: String = "Loom Mobile"
var _put_queue: Array = []
var _discovering: bool = false
var _expected_relative_paths: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_process_timer = Timer.new()
	_process_timer.wait_time = 0.05
	_process_timer.one_shot = false
	_process_timer.autostart = false
	_process_timer.timeout.connect(_on_process_tick)
	add_child(_process_timer)
	_scrub_timer = Timer.new()
	_scrub_timer.wait_time = 1.0
	_scrub_timer.one_shot = false
	_scrub_timer.autostart = false
	_scrub_timer.timeout.connect(_on_scrub_tick)
	add_child(_scrub_timer)


func set_display_name(value: String) -> void:
	_client_display_name = value.strip_edges() if value.strip_edges() != "" else "Loom Mobile"


func start_discovery() -> Error:
	if _discovering:
		return OK
	_udp_listener = PacketPeerUDP.new()
	_udp_listener.set_broadcast_enabled(true)
	var err: Error = _udp_listener.bind(LanSyncProtocol.UDP_PORT, "0.0.0.0")
	if err != OK:
		_emit_log("error", "UDP bind failed: %d" % err)
		_udp_listener = null
		return err
	_discovering = true
	_process_timer.start()
	_scrub_timer.start()
	_emit_log("info", "LAN discovery started")
	return OK


func stop_discovery() -> void:
	if not _discovering:
		return
	_discovering = false
	if _udp_listener != null:
		_udp_listener.close()
		_udp_listener = null
	_hosts.clear()
	hosts_changed.emit(known_hosts())
	if _state == STATE_IDLE:
		_process_timer.stop()
		_scrub_timer.stop()


func known_hosts() -> Array:
	var out: Array = []
	for key: String in _hosts.keys():
		var entry: Dictionary = _hosts[key]
		out.append(entry.duplicate(true))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(b.get("last_seen_msec", 0)) < int(a.get("last_seen_msec", 0))
	)
	return out


func begin_sync(host_entry: Dictionary, target_folder: String) -> Error:
	if is_busy():
		_emit_log("warning", "begin_sync called while busy (state=%d); resetting to retry." % _state)
		_force_reset()
	var address: String = String(host_entry.get("address", ""))
	var port: int = int(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_TCP_PORT, LanSyncProtocol.TCP_PORT))
	_expected_project_id = String(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_ID, ""))
	if address == "" or port <= 0 or target_folder == "":
		return ERR_INVALID_PARAMETER
	_target_folder = target_folder
	_target_address = address
	_target_port = port
	_files_pending.clear()
	_files_total = 0
	_current_path = ""
	_expected_relative_paths = PackedStringArray()
	if not DirAccess.dir_exists_absolute(_target_folder):
		var mk_err: Error = DirAccess.make_dir_recursive_absolute(_target_folder)
		if mk_err != OK:
			_set_state(STATE_ERROR)
			sync_failed.emit("cannot_make_target_dir_%d" % mk_err)
			return mk_err
	var marker_err: Error = _write_syncing_marker(_target_folder)
	if marker_err != OK:
		_emit_log("warning", "Could not write syncing marker (%d); proceeding anyway." % marker_err)
	return _connect()


func _force_reset() -> void:
	if _stream != null:
		_stream.disconnect_from_host()
	_stream = null
	_reader = null
	_put_queue.clear()
	_set_state(STATE_IDLE)


func push_file(project_folder: String, relative_path: String, bytes: PackedByteArray) -> Error:
	if not ProjectFileManifest.is_writable_from_client(relative_path):
		return ERR_INVALID_PARAMETER
	if project_folder == "" or _expected_project_id == "":
		return ERR_UNCONFIGURED
	_put_queue.append({
		"path": relative_path,
		"bytes": bytes,
	})
	if _state == STATE_READY:
		_send_next_put()
	elif _state == STATE_IDLE or _state == STATE_ERROR:
		_target_folder = project_folder
		return _connect()
	return OK


func current_state() -> int:
	return _state


func is_busy() -> bool:
	return _state != STATE_IDLE and _state != STATE_ERROR and _state != STATE_READY


func _connect() -> Error:
	_stream = StreamPeerTCP.new()
	_reader = LanSyncEnvelopeReader.new()
	var err: Error = _stream.connect_to_host(_target_address, _target_port)
	if err != OK:
		_set_state(STATE_ERROR)
		sync_failed.emit("connect_failed")
		return err
	_set_state(STATE_CONNECTING)
	_process_timer.start()
	return OK


func _on_process_tick() -> void:
	_process_discovery()
	_process_stream()


func _process_discovery() -> void:
	if not _discovering or _udp_listener == null:
		return
	var changed: bool = false
	while _udp_listener.get_available_packet_count() > 0:
		var packet: PackedByteArray = _udp_listener.get_packet()
		var src: String = _udp_listener.get_packet_ip()
		var port: int = _udp_listener.get_packet_port()
		var parsed: Dictionary = LanSyncProtocol.parse_announce_packet(packet)
		if parsed.is_empty():
			continue
		var project_id: String = String(parsed.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_ID, ""))
		if project_id == "":
			continue
		var key: String = "%s|%s" % [src, project_id]
		var existing: Dictionary = _hosts.get(key, {})
		existing["address"] = src
		existing["udp_port"] = port
		existing["last_seen_msec"] = Time.get_ticks_msec()
		existing[LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_ID] = project_id
		existing[LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_NAME] = String(parsed.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_NAME, ""))
		existing[LanSyncProtocol.ANNOUNCE_FIELD_HOST_NAME] = String(parsed.get(LanSyncProtocol.ANNOUNCE_FIELD_HOST_NAME, ""))
		existing[LanSyncProtocol.ANNOUNCE_FIELD_TCP_PORT] = int(parsed.get(LanSyncProtocol.ANNOUNCE_FIELD_TCP_PORT, LanSyncProtocol.TCP_PORT))
		_hosts[key] = existing
		changed = true
	if changed:
		hosts_changed.emit(known_hosts())


func _on_scrub_tick() -> void:
	if not _discovering:
		return
	var now_msec: int = Time.get_ticks_msec()
	var timeout_msec: int = int(LanSyncProtocol.ANNOUNCE_TIMEOUT_SEC * 1000.0)
	var removed: bool = false
	for key: String in _hosts.keys():
		var entry: Dictionary = _hosts[key]
		if now_msec - int(entry.get("last_seen_msec", 0)) > timeout_msec:
			_hosts.erase(key)
			removed = true
	if removed:
		hosts_changed.emit(known_hosts())


func _process_stream() -> void:
	if _stream == null:
		return
	_stream.poll()
	var status: int = _stream.get_status()
	if status == StreamPeerTCP.STATUS_ERROR:
		_handle_stream_error("stream_error")
		return
	if status == StreamPeerTCP.STATUS_NONE:
		if _state != STATE_IDLE and _state != STATE_READY:
			_handle_stream_error("disconnected_unexpectedly")
		return
	if status == StreamPeerTCP.STATUS_CONNECTING:
		return
	if status == StreamPeerTCP.STATUS_CONNECTED and _state == STATE_CONNECTING:
		_set_state(STATE_HANDSHAKING)
		_send_message(LanSyncProtocol.MSG_HELLO, {"client_name": _client_display_name}, PackedByteArray())
	var available: int = _stream.get_available_bytes()
	if available > 0:
		var pkg: Array = _stream.get_data(available)
		var err: Error = pkg[0]
		if err != OK:
			_handle_stream_error("read_error_%d" % err)
			return
		var data: PackedByteArray = pkg[1]
		_reader.feed(data)
		if _reader.is_in_error():
			_handle_stream_error("envelope_%s" % _reader.error_message())
			return
		while _reader.has_envelope():
			var env: Dictionary = _reader.consume_envelope()
			if env.is_empty():
				break
			_handle_envelope(env)


func _handle_envelope(env: Dictionary) -> void:
	var message: Dictionary = env.get("message", {}) as Dictionary
	var body: PackedByteArray = env.get("body", PackedByteArray()) as PackedByteArray
	var kind: String = String(message.get(LanSyncProtocol.KIND_FIELD, ""))
	match kind:
		LanSyncProtocol.MSG_HELLO_OK:
			_on_hello_ok(message)
		LanSyncProtocol.MSG_LIST_OK:
			_on_list_ok(message)
		LanSyncProtocol.MSG_GET_OK:
			_on_get_ok(message, body)
		LanSyncProtocol.MSG_GET_ERR:
			_on_get_err(message)
		LanSyncProtocol.MSG_PUT_OK:
			_on_put_ok(message)
		LanSyncProtocol.MSG_PUT_ERR:
			_on_put_err(message)
		LanSyncProtocol.MSG_PONG:
			pass


func _on_hello_ok(_message: Dictionary) -> void:
	if _state == STATE_HANDSHAKING:
		_set_state(STATE_FETCHING_MANIFEST)
		sync_progress.emit(STAGE_MANIFEST, 0, 1, "")
		_send_message(LanSyncProtocol.MSG_LIST, {}, PackedByteArray())


func _on_list_ok(message: Dictionary) -> void:
	var summary: Dictionary = message.get("project_summary", {}) as Dictionary
	var declared_id: String = String(summary.get("project_id", ""))
	if _expected_project_id != "" and declared_id != "" and declared_id != _expected_project_id:
		_handle_stream_error("project_id_mismatch")
		return
	var files_v: Variant = message.get("files", [])
	if typeof(files_v) != TYPE_ARRAY:
		_handle_stream_error("bad_manifest")
		return
	_files_pending = (files_v as Array).duplicate(true)
	_files_total = _files_pending.size()
	_expected_relative_paths = PackedStringArray()
	for entry_v: Variant in _files_pending:
		if typeof(entry_v) == TYPE_DICTIONARY:
			_expected_relative_paths.append(String((entry_v as Dictionary).get(ProjectFileManifest.FIELD_PATH, "")))
	_set_state(STATE_DOWNLOADING)
	sync_progress.emit(STAGE_FILES, 0, _files_total, "")
	_fetch_next_file()


func _fetch_next_file() -> void:
	if _files_pending.is_empty():
		_finalize_sync()
		return
	var entry: Dictionary = _files_pending[0]
	_current_path = String(entry.get(ProjectFileManifest.FIELD_PATH, ""))
	_send_message(LanSyncProtocol.MSG_GET, {"path": _current_path}, PackedByteArray())


func _on_get_ok(message: Dictionary, body: PackedByteArray) -> void:
	if _state != STATE_DOWNLOADING:
		return
	var path: String = String(message.get("path", ""))
	if path != _current_path:
		_handle_stream_error("path_mismatch")
		return
	var declared_hash: String = String(message.get("hash", ""))
	var actual_hash: String = LanSyncProtocol.sha256_hex(body)
	if declared_hash != "" and declared_hash != actual_hash:
		_handle_stream_error("hash_mismatch")
		return
	var write_err: Error = _write_file_with_retry(_target_folder, path, body)
	if write_err != OK:
		_handle_stream_error("write_failed_%d" % write_err)
		return
	if not _files_pending.is_empty():
		_files_pending.pop_front()
	var done: int = _files_total - _files_pending.size()
	sync_progress.emit(STAGE_FILES, done, _files_total, path)
	_fetch_next_file()


func _write_file_with_retry(project_root: String, relative_path: String, bytes: PackedByteArray) -> Error:
	var last_err: Error = OK
	for attempt: int in range(3):
		last_err = ProjectFileManifest.write_file_bytes(project_root, relative_path, bytes)
		if last_err == OK:
			return OK
		_emit_log("warning", "Write attempt %d for %s returned %d; retrying." % [attempt + 1, relative_path, last_err])
	return last_err


func _on_get_err(message: Dictionary) -> void:
	var reason: String = String(message.get("reason", "get_failed"))
	_handle_stream_error("get_err_%s" % reason)


func _on_put_ok(message: Dictionary) -> void:
	var path: String = String(message.get("path", ""))
	put_completed.emit(path)
	if not _put_queue.is_empty():
		_put_queue.pop_front()
	if not _put_queue.is_empty():
		_send_next_put()
	else:
		_set_state(STATE_READY)


func _on_put_err(message: Dictionary) -> void:
	var path: String = String(message.get("path", ""))
	var reason: String = String(message.get("reason", "put_failed"))
	put_failed.emit(path, reason)
	if not _put_queue.is_empty():
		_put_queue.pop_front()
	if not _put_queue.is_empty():
		_send_next_put()
	else:
		_set_state(STATE_READY)


func _send_next_put() -> void:
	if _put_queue.is_empty():
		_set_state(STATE_READY)
		return
	var entry: Dictionary = _put_queue[0]
	var bytes: PackedByteArray = entry["bytes"] as PackedByteArray
	var path: String = String(entry["path"])
	_set_state(STATE_UPLOADING)
	_send_message(LanSyncProtocol.MSG_PUT, {
		"path": path,
		"size": bytes.size(),
		"hash": LanSyncProtocol.sha256_hex(bytes),
	}, bytes)


func _finalize_sync() -> void:
	_send_message(LanSyncProtocol.MSG_BYE, {}, PackedByteArray())
	_prune_orphan_files()
	_remove_syncing_marker(_target_folder)
	_set_state(STATE_READY)
	sync_completed.emit(_target_folder, _expected_project_id)
	_disconnect_stream()


func _handle_stream_error(reason: String) -> void:
	_emit_log("warning", "Sync error: %s" % reason)
	_set_state(STATE_ERROR)
	sync_failed.emit(reason)
	_disconnect_stream()


func _write_syncing_marker(project_root: String) -> Error:
	var marker_path: String = project_root.path_join(SYNCING_MARKER_FILENAME)
	var f: FileAccess = FileAccess.open(marker_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(str(int(Time.get_unix_time_from_system())))
	f.close()
	return OK


func _remove_syncing_marker(project_root: String) -> void:
	var marker_path: String = project_root.path_join(SYNCING_MARKER_FILENAME)
	if FileAccess.file_exists(marker_path):
		DirAccess.remove_absolute(marker_path)


func _prune_orphan_files() -> void:
	if _target_folder == "":
		return
	if _expected_relative_paths.is_empty():
		return
	var expected_set: Dictionary = {}
	for rp: String in _expected_relative_paths:
		expected_set[rp.replace("\\", "/")] = true
	var orphans: Array = _collect_relative_files(_target_folder, "")
	for rel: String in orphans:
		var normalized: String = rel.replace("\\", "/")
		if normalized == SYNCING_MARKER_FILENAME:
			continue
		if expected_set.has(normalized):
			continue
		var abs_path: String = _target_folder.path_join(normalized)
		DirAccess.remove_absolute(abs_path)


func _collect_relative_files(root: String, prefix: String) -> Array:
	var out: Array = []
	var dir_path: String = root.path_join(prefix) if prefix != "" else root
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var entry: String = d.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var relative: String = entry if prefix == "" else prefix.path_join(entry)
			if d.current_is_dir():
				var inner: Array = _collect_relative_files(root, relative)
				for sub: String in inner:
					out.append(sub)
			else:
				out.append(relative.replace("\\", "/"))
		entry = d.get_next()
	d.list_dir_end()
	return out


func _disconnect_stream() -> void:
	if _stream != null:
		_stream.disconnect_from_host()
		_stream = null
	_reader = null


func _send_message(kind: String, payload: Dictionary, body: PackedByteArray) -> void:
	if _stream == null:
		return
	var msg: Dictionary = LanSyncProtocol.make_message(kind, payload)
	var envelope: PackedByteArray = LanSyncProtocol.encode_envelope(msg, body)
	var err: Error = _stream.put_data(envelope)
	if err != OK:
		_handle_stream_error("send_failed_%d" % err)


func _set_state(state: int) -> void:
	if _state == state:
		return
	_state = state
	connection_state_changed.emit(state)


func _emit_log(severity: String, message: String) -> void:
	if severity == "error":
		printerr("[LanSyncClient] %s" % message)
	else:
		print("[LanSyncClient:%s] %s" % [severity, message])
	log_message.emit(severity, message)


func _delete_directory_recursive(target: String) -> void:
	var d: DirAccess = DirAccess.open(target)
	if d == null:
		return
	d.list_dir_begin()
	var entry: String = d.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var full: String = target.path_join(entry)
			if d.current_is_dir():
				_delete_directory_recursive(full)
				DirAccess.remove_absolute(full)
			else:
				DirAccess.remove_absolute(full)
		entry = d.get_next()
	d.list_dir_end()
	DirAccess.remove_absolute(target)
