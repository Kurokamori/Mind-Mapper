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
signal offer_decision_received(decision: String, op_kind: String)
signal offer_review_result(resolutions: Array)
signal defer_review_requested(conflicting_paths: Array, incoming_only_paths: Array, host_name: String, project_name: String, op_kind: String)

const STATE_IDLE: int = 0
const STATE_CONNECTING: int = 1
const STATE_HANDSHAKING: int = 2
const STATE_FETCHING_MANIFEST: int = 3
const STATE_DOWNLOADING: int = 4
const STATE_READY: int = 5
const STATE_UPLOADING: int = 6
const STATE_ERROR: int = 7
const STATE_OFFERING: int = 8
const STATE_AWAITING_OFFER_DECISION: int = 9
const STATE_AWAITING_REVIEW_RESULT: int = 10
const STATE_AWAITING_USER_RESOLUTION: int = 11

const STAGE_MANIFEST: String = "manifest"
const STAGE_FILES: String = "files"
const STAGE_OFFER: String = "offer"
const STAGE_PUSH: String = "push"
const STAGE_REVIEW: String = "review"

const SYNCING_MARKER_FILENAME: String = ".__syncing"
const CONNECT_TIMEOUT_MSEC: int = 8000
const RESPONSE_TIMEOUT_MSEC: int = 15000
const REVIEW_TIMEOUT_MSEC: int = 600000
const HELLO_RETRY_MSEC: int = 1000

const FLOW_PULL: String = "pull"
const FLOW_PUSH: String = "push"
const FLOW_SYNC: String = "sync"

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
var _stream_deadline_msec: int = 0
var _last_hello_sent_msec: int = 0
var _text_handshake_buffer: String = ""
var _pending_binary_after_text_handshake: PackedByteArray = PackedByteArray()
var _pending_outbound: PackedByteArray = PackedByteArray()
var _active_flow: String = FLOW_PULL
var _offer_files_meta: Array = []
var _offer_push_paths: Array = []
var _offer_total: int = 0
var _offer_sent_count: int = 0
var _last_offer_decision: String = ""
var _kept_mine_paths_pending_pull: PackedStringArray = PackedStringArray()
var _last_host_entry: Dictionary = {}
var _last_target_folder: String = ""
var _last_active_flow: String = ""
var _interrupted_for_reconnect: bool = false


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


func display_name() -> String:
	return _client_display_name


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
	return _begin_flow(host_entry, target_folder, FLOW_PULL)


func begin_push(host_entry: Dictionary, source_folder: String) -> Error:
	return _begin_flow(host_entry, source_folder, FLOW_PUSH)


func begin_two_way_sync(host_entry: Dictionary, project_folder: String) -> Error:
	return _begin_flow(host_entry, project_folder, FLOW_SYNC)


func _begin_flow(host_entry: Dictionary, project_folder: String, flow: String) -> Error:
	if is_busy():
		_emit_log("warning", "begin_%s called while busy (state=%d); resetting to retry." % [flow, _state])
		_force_reset()
	var address: String = String(host_entry.get("address", ""))
	var port: int = int(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_TCP_PORT, LanSyncProtocol.TCP_PORT))
	_expected_project_id = String(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_ID, ""))
	if address == "" or port <= 0 or project_folder == "":
		return ERR_INVALID_PARAMETER
	if (flow == FLOW_PUSH or flow == FLOW_SYNC) and not DirAccess.dir_exists_absolute(project_folder):
		return ERR_FILE_NOT_FOUND
	_active_flow = flow
	_target_folder = project_folder
	_target_address = address
	_target_port = port
	_last_host_entry = host_entry.duplicate(true)
	_last_target_folder = project_folder
	_last_active_flow = flow
	_interrupted_for_reconnect = false
	_files_pending.clear()
	_files_total = 0
	_current_path = ""
	_expected_relative_paths = PackedStringArray()
	_offer_files_meta.clear()
	_offer_push_paths.clear()
	_offer_total = 0
	_offer_sent_count = 0
	_last_offer_decision = ""
	_kept_mine_paths_pending_pull = PackedStringArray()
	if flow == FLOW_PULL:
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
	_stream_deadline_msec = 0
	_last_hello_sent_msec = 0
	_text_handshake_buffer = ""
	_pending_binary_after_text_handshake = PackedByteArray()
	_pending_outbound = PackedByteArray()
	_active_flow = FLOW_PULL
	_offer_files_meta.clear()
	_offer_push_paths.clear()
	_offer_total = 0
	_offer_sent_count = 0
	_last_offer_decision = ""
	_kept_mine_paths_pending_pull = PackedStringArray()
	_set_state(STATE_IDLE)


func push_file(project_folder: String, relative_path: String, bytes: PackedByteArray) -> Error:
	if not ProjectFileManifest.is_writable_from_client(relative_path):
		return ERR_INVALID_PARAMETER
	if project_folder == "" or _expected_project_id == "":
		return ERR_UNCONFIGURED
	_put_queue.append({
		"path": relative_path,
		"bytes": bytes,
		"mtime": int(FileAccess.get_modified_time(project_folder.path_join(relative_path))),
	})
	if _state == STATE_READY:
		_send_next_put()
	elif _state == STATE_IDLE or _state == STATE_ERROR:
		_target_folder = project_folder
		_active_flow = FLOW_PULL
		return _connect()
	return OK


func current_state() -> int:
	return _state


func is_busy() -> bool:
	if _state == STATE_IDLE or _state == STATE_ERROR or _state == STATE_READY:
		return false
	return true


func mark_interrupted_for_reconnect() -> void:
	if _state == STATE_IDLE or _state == STATE_READY:
		return
	_interrupted_for_reconnect = true
	_force_reset()


func needs_reconnect() -> bool:
	if not _interrupted_for_reconnect:
		return false
	if _last_active_flow == "" or _last_target_folder == "":
		return false
	if _last_host_entry.is_empty():
		return false
	return true


func reconnect() -> Error:
	if not needs_reconnect():
		return ERR_UNAVAILABLE
	var host_entry: Dictionary = _last_host_entry.duplicate(true)
	var folder: String = _last_target_folder
	var flow: String = _last_active_flow
	_interrupted_for_reconnect = false
	return _begin_flow(host_entry, folder, flow)


func _connect() -> Error:
	_stream = StreamPeerTCP.new()
	_stream.set_no_delay(true)
	_reader = LanSyncEnvelopeReader.new()
	var err: Error = _stream.connect_to_host(_target_address, _target_port)
	if err != OK:
		_set_state(STATE_ERROR)
		sync_failed.emit("connect_failed")
		return err
	_set_state(STATE_CONNECTING)
	_set_stream_deadline(CONNECT_TIMEOUT_MSEC)
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
	_flush_pending_outbound()
	if _stream == null:
		return
	_check_stream_timeout()
	if _stream == null:
		return
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
		_send_hello(true)
	elif status == StreamPeerTCP.STATUS_CONNECTED and _state == STATE_HANDSHAKING:
		var now_msec: int = Time.get_ticks_msec()
		if now_msec - _last_hello_sent_msec >= HELLO_RETRY_MSEC:
			_send_hello(false)
	var available: int = _stream.get_available_bytes()
	if available > 0:
		_emit_log("info", "Received %d byte(s) from LAN host" % available)
		_set_stream_deadline(RESPONSE_TIMEOUT_MSEC if _state != STATE_AWAITING_REVIEW_RESULT else REVIEW_TIMEOUT_MSEC)
		var pkg: Array = _stream.get_data(available)
		var err: Error = pkg[0]
		if err != OK:
			_handle_stream_error("read_error_%d" % err)
			return
		var data: PackedByteArray = pkg[1]
		if _try_handle_text_handshake(data):
			if _reader != null and not _pending_binary_after_text_handshake.is_empty():
				_reader.feed(_pending_binary_after_text_handshake)
				_pending_binary_after_text_handshake = PackedByteArray()
				if _reader.is_in_error():
					_handle_stream_error("envelope_%s" % _reader.error_message())
					return
				while _reader != null and _reader.has_envelope():
					var env_after_text: Dictionary = _reader.consume_envelope()
					if env_after_text.is_empty():
						break
					_handle_envelope(env_after_text)
					if _reader == null:
						return
			return
		if _reader == null:
			return
		_reader.feed(data)
		if _reader.is_in_error():
			_handle_stream_error("envelope_%s" % _reader.error_message())
			return
		while _reader != null and _reader.has_envelope():
			var env: Dictionary = _reader.consume_envelope()
			if env.is_empty():
				break
			_handle_envelope(env)
			if _reader == null:
				return


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
		LanSyncProtocol.MSG_OFFER_DECISION:
			_on_offer_decision(message)
		LanSyncProtocol.MSG_REVIEW_RESULT:
			_on_review_result(message)
		LanSyncProtocol.MSG_PONG:
			pass


func _on_hello_ok(_message: Dictionary) -> void:
	if _state != STATE_HANDSHAKING:
		return
	if _active_flow == FLOW_PUSH or _active_flow == FLOW_SYNC:
		_start_offer_phase()
	else:
		_start_pull_manifest()


func _start_pull_manifest() -> void:
	_set_state(STATE_FETCHING_MANIFEST)
	sync_progress.emit(STAGE_MANIFEST, 0, 1, "")
	_send_message(LanSyncProtocol.MSG_LIST, {}, PackedByteArray())


func _start_offer_phase() -> void:
	_offer_files_meta = _build_offer_manifest(_target_folder)
	if _offer_files_meta.is_empty() and _active_flow == FLOW_PUSH:
		_handle_stream_error("nothing_to_push")
		return
	var op_kind: String = LanSyncProtocol.OFFER_OP_SYNC if _active_flow == FLOW_SYNC else LanSyncProtocol.OFFER_OP_PUSH
	_set_state(STATE_AWAITING_OFFER_DECISION)
	sync_progress.emit(STAGE_OFFER, 0, 1, "")
	_send_message(LanSyncProtocol.MSG_OFFER, {
		LanSyncProtocol.OFFER_FIELD_OP_KIND: op_kind,
		LanSyncProtocol.OFFER_FIELD_CLIENT_NAME: _client_display_name,
		LanSyncProtocol.OFFER_FIELD_FILES: _offer_files_meta,
	}, PackedByteArray())


func _build_offer_manifest(folder: String) -> Array:
	var entries: Array = []
	var relative_files: Array = _collect_relative_files(folder, "")
	for rel_v: Variant in relative_files:
		var rel: String = String(rel_v)
		if not ProjectFileManifest.is_writable_from_client(rel):
			continue
		var abs: String = folder.path_join(rel)
		var f: FileAccess = FileAccess.open(abs, FileAccess.READ)
		if f == null:
			continue
		var size: int = int(f.get_length())
		var bytes: PackedByteArray = f.get_buffer(size)
		f.close()
		entries.append({
			ProjectFileManifest.FIELD_PATH: rel,
			ProjectFileManifest.FIELD_SIZE: size,
			ProjectFileManifest.FIELD_MTIME: int(FileAccess.get_modified_time(abs)),
			ProjectFileManifest.FIELD_HASH: LanSyncProtocol.sha256_hex(bytes),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get(ProjectFileManifest.FIELD_PATH, "")) < String(b.get(ProjectFileManifest.FIELD_PATH, ""))
	)
	return entries


func _on_offer_decision(message: Dictionary) -> void:
	if _state != STATE_AWAITING_OFFER_DECISION and _state != STATE_AWAITING_USER_RESOLUTION:
		return
	var decision: String = String(message.get(LanSyncProtocol.OFFER_FIELD_DECISION, LanSyncProtocol.DECISION_REJECT))
	_last_offer_decision = decision
	offer_decision_received.emit(decision, _active_flow)
	match decision:
		LanSyncProtocol.DECISION_REJECT:
			if _active_flow == FLOW_SYNC:
				_emit_log("info", "Host rejected push; continuing with pull.")
				_prepare_target_for_pull()
				_start_pull_manifest()
			else:
				_handle_stream_error("offer_rejected")
		LanSyncProtocol.DECISION_REJECT_AND_BLOCK:
			_handle_stream_error("offer_rejected_blocked")
		LanSyncProtocol.DECISION_ACCEPT_ALL, LanSyncProtocol.DECISION_ACCEPT_REVIEW:
			if _state == STATE_AWAITING_USER_RESOLUTION:
				_set_state(STATE_AWAITING_OFFER_DECISION)
			_begin_offer_push_uploads()
		LanSyncProtocol.DECISION_DEFER_TO_REQUESTER:
			_enter_defer_review(message)
		_:
			_handle_stream_error("offer_unknown_decision_%s" % decision)


func _enter_defer_review(message: Dictionary) -> void:
	_set_state(STATE_AWAITING_USER_RESOLUTION)
	_set_stream_deadline(REVIEW_TIMEOUT_MSEC)
	var conflicts_v: Variant = message.get(LanSyncProtocol.OFFER_FIELD_CONFLICTS, [])
	var incoming_v: Variant = message.get(LanSyncProtocol.OFFER_FIELD_INCOMING_ONLY, [])
	var conflicts: Array = (conflicts_v as Array).duplicate() if typeof(conflicts_v) == TYPE_ARRAY else []
	var incoming_only: Array = (incoming_v as Array).duplicate() if typeof(incoming_v) == TYPE_ARRAY else []
	var host_name: String = String(message.get(LanSyncProtocol.OFFER_FIELD_HOST_NAME, ""))
	var project_name: String = String(message.get(LanSyncProtocol.OFFER_FIELD_PROJECT_NAME, ""))
	defer_review_requested.emit(conflicts, incoming_only, host_name, project_name, _active_flow)


func submit_offer_resolution(per_file_kept_mine: Dictionary) -> Error:
	if _state != STATE_AWAITING_USER_RESOLUTION:
		return ERR_UNAVAILABLE
	var clean: Dictionary = {}
	for key_v: Variant in per_file_kept_mine.keys():
		clean[String(key_v)] = bool(per_file_kept_mine[key_v])
	_send_message(LanSyncProtocol.MSG_OFFER_RESOLUTION, {
		LanSyncProtocol.OFFER_FIELD_KEPT_MINE: clean,
	}, PackedByteArray())
	return OK


func cancel_offer_resolution() -> void:
	if _state != STATE_AWAITING_USER_RESOLUTION:
		return
	_send_message(LanSyncProtocol.MSG_BYE, {}, PackedByteArray())
	_handle_stream_error("offer_resolution_cancelled")


func _prepare_target_for_pull() -> void:
	if not DirAccess.dir_exists_absolute(_target_folder):
		DirAccess.make_dir_recursive_absolute(_target_folder)
	var marker_err: Error = _write_syncing_marker(_target_folder)
	if marker_err != OK:
		_emit_log("warning", "Could not write syncing marker before pull (%d); proceeding." % marker_err)


func _begin_offer_push_uploads() -> void:
	_offer_push_paths.clear()
	for entry_v: Variant in _offer_files_meta:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		_offer_push_paths.append(String((entry_v as Dictionary).get(ProjectFileManifest.FIELD_PATH, "")))
	_offer_total = _offer_push_paths.size()
	_offer_sent_count = 0
	if _offer_push_paths.is_empty():
		_finish_offer_uploads()
		return
	_set_state(STATE_UPLOADING)
	sync_progress.emit(STAGE_PUSH, 0, _offer_total, "")
	_send_next_offer_put()


func _send_next_offer_put() -> void:
	if _offer_push_paths.is_empty():
		_finish_offer_uploads()
		return
	var relative_path: String = String(_offer_push_paths[0])
	var abs: String = _target_folder.path_join(relative_path)
	var bytes: PackedByteArray = PackedByteArray()
	var f: FileAccess = FileAccess.open(abs, FileAccess.READ)
	if f != null:
		var size: int = int(f.get_length())
		bytes = f.get_buffer(size)
		f.close()
	var mtime: int = int(FileAccess.get_modified_time(abs))
	_send_message(LanSyncProtocol.MSG_PUT, {
		"path": relative_path,
		"size": bytes.size(),
		"hash": LanSyncProtocol.sha256_hex(bytes),
		ProjectFileManifest.FIELD_MTIME: mtime,
	}, bytes)


func _finish_offer_uploads() -> void:
	_set_state(STATE_AWAITING_REVIEW_RESULT)
	sync_progress.emit(STAGE_REVIEW, 0, 1, "")
	_send_message(LanSyncProtocol.MSG_PUSH_COMPLETE, {}, PackedByteArray())
	_set_stream_deadline(REVIEW_TIMEOUT_MSEC)


func _on_review_result(message: Dictionary) -> void:
	if _state != STATE_AWAITING_REVIEW_RESULT:
		return
	var resolutions_v: Variant = message.get(LanSyncProtocol.OFFER_FIELD_RESOLUTIONS, [])
	var resolutions: Array = []
	if typeof(resolutions_v) == TYPE_ARRAY:
		resolutions = (resolutions_v as Array).duplicate(true)
	offer_review_result.emit(resolutions)
	_kept_mine_paths_pending_pull = PackedStringArray()
	for entry_v: Variant in resolutions:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		if bool(entry.get(LanSyncProtocol.OFFER_FIELD_KEPT_MINE, false)):
			_kept_mine_paths_pending_pull.append(String(entry.get("path", "")))
	_prepare_target_for_pull()
	_start_pull_manifest()


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
	if _state == STATE_UPLOADING and (_active_flow == FLOW_PUSH or _active_flow == FLOW_SYNC):
		put_completed.emit(path)
		if not _offer_push_paths.is_empty():
			_offer_push_paths.pop_front()
		_offer_sent_count += 1
		sync_progress.emit(STAGE_PUSH, _offer_sent_count, _offer_total, path)
		_send_next_offer_put()
		return
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
	if _state == STATE_UPLOADING and (_active_flow == FLOW_PUSH or _active_flow == FLOW_SYNC):
		if not _offer_push_paths.is_empty():
			_offer_push_paths.pop_front()
		_offer_sent_count += 1
		sync_progress.emit(STAGE_PUSH, _offer_sent_count, _offer_total, path)
		_send_next_offer_put()
		return
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
	var mtime: int = int(entry.get("mtime", int(Time.get_unix_time_from_system())))
	_set_state(STATE_UPLOADING)
	_send_message(LanSyncProtocol.MSG_PUT, {
		"path": path,
		"size": bytes.size(),
		"hash": LanSyncProtocol.sha256_hex(bytes),
		ProjectFileManifest.FIELD_MTIME: mtime,
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
		if not ProjectFileManifest.is_writable_from_client(normalized):
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
	_stream_deadline_msec = 0
	_last_hello_sent_msec = 0
	_text_handshake_buffer = ""
	_pending_binary_after_text_handshake = PackedByteArray()
	_pending_outbound = PackedByteArray()


func _send_hello(refresh_deadline: bool) -> void:
	_last_hello_sent_msec = Time.get_ticks_msec()
	_emit_log("info", "Sending hello to LAN host")
	_send_message(LanSyncProtocol.MSG_HELLO, {"client_name": _client_display_name}, PackedByteArray(), refresh_deadline)


func _try_handle_text_handshake(data: PackedByteArray) -> bool:
	if data.is_empty():
		return false
	var first: int = int(data[0])
	if _text_handshake_buffer == "" and first != 123 and first != 91:
		return false
	_text_handshake_buffer += data.get_string_from_utf8()
	var newline_idx: int = _text_handshake_buffer.find("\n")
	if newline_idx < 0:
		return true
	var line: String = _text_handshake_buffer.substr(0, newline_idx).strip_edges()
	var trailing: String = _text_handshake_buffer.substr(newline_idx + 1)
	_text_handshake_buffer = ""
	var parsed: Variant = JSON.parse_string(line)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var message: Dictionary = parsed as Dictionary
	if String(message.get(LanSyncProtocol.KIND_FIELD, "")) != LanSyncProtocol.MSG_HELLO_OK:
		return false
	if _state == STATE_HANDSHAKING:
		_emit_log("info", "Received text hello_ok from LAN host")
		_on_hello_ok(message)
	else:
		_emit_log("info", "Ignored repeated text hello_ok from LAN host")
	if trailing != "":
		_pending_binary_after_text_handshake = trailing.to_utf8_buffer()
	return true


func _send_message(kind: String, payload: Dictionary, body: PackedByteArray, refresh_deadline: bool = true) -> void:
	if _stream == null:
		return
	var msg: Dictionary = LanSyncProtocol.make_message(kind, payload)
	var envelope: PackedByteArray = LanSyncProtocol.encode_envelope(msg, body)
	_pending_outbound.append_array(envelope)
	_flush_pending_outbound()
	if _stream != null:
		_stream.poll()
	if refresh_deadline:
		_set_stream_deadline(RESPONSE_TIMEOUT_MSEC)


func _flush_pending_outbound() -> void:
	if _stream == null:
		return
	if _pending_outbound.is_empty():
		return
	var offset: int = 0
	while offset < _pending_outbound.size():
		var remaining: PackedByteArray = _pending_outbound.slice(offset)
		var result: Array = _stream.put_partial_data(remaining)
		var err: Error = result[0]
		if err != OK:
			_handle_stream_error("send_failed_%d" % err)
			return
		var wrote: int = int(result[1])
		if wrote <= 0:
			break
		offset += wrote
	if offset > 0:
		_set_stream_deadline(RESPONSE_TIMEOUT_MSEC)
	if offset >= _pending_outbound.size():
		_pending_outbound = PackedByteArray()
	else:
		_pending_outbound = _pending_outbound.slice(offset)


func _set_stream_deadline(timeout_msec: int) -> void:
	_stream_deadline_msec = Time.get_ticks_msec() + timeout_msec


func _check_stream_timeout() -> void:
	if _stream_deadline_msec <= 0:
		return
	if _state == STATE_IDLE or _state == STATE_READY or _state == STATE_ERROR:
		return
	if Time.get_ticks_msec() <= _stream_deadline_msec:
		return
	match _state:
		STATE_CONNECTING:
			_handle_stream_error("connect_timeout")
		STATE_HANDSHAKING:
			_handle_stream_error("hello_timeout")
		STATE_FETCHING_MANIFEST:
			_handle_stream_error("manifest_timeout")
		STATE_DOWNLOADING:
			_handle_stream_error("download_timeout_%s" % _current_path)
		STATE_UPLOADING:
			_handle_stream_error("upload_timeout")
		STATE_AWAITING_OFFER_DECISION:
			_handle_stream_error("offer_decision_timeout")
		STATE_AWAITING_REVIEW_RESULT:
			_handle_stream_error("review_result_timeout")
		STATE_AWAITING_USER_RESOLUTION:
			_handle_stream_error("user_resolution_timeout")
		_:
			_handle_stream_error("stream_timeout")


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
