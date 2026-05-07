extends Node

signal session_state_changed(state: int)
signal participants_changed()
signal presence_updated(stable_id: String)
signal presence_removed(stable_id: String)
signal ping_marker_received(world_pos: Vector2, color: Color, stable_id: String)
signal session_log(severity: String, message: String)
signal local_permissions_changed(can_edit: bool)
signal lobby_list_updated(adapter_kind: String, lobbies: Array)
signal editing_lock_changed(item_id: String, holder_stable_id: String)
signal board_request_in_progress(board_id: String, stable_id: String)
signal board_received(board_id: String)
signal merge_dialog_requested(conflicts: Array, non_conflicting_local_count: int, non_conflicting_remote_count: int, host_display_name: String)
signal merge_dialog_close_requested()
signal merge_report_received(report: Dictionary)
signal merge_report_entry_rolled_back(report_id: String, op_id: String)
signal merge_report_fully_rolled_back(report_id: String)
signal chat_message_received(entry: Dictionary)
signal chat_history_cleared()

const STATE_IDLE: int = 0
const STATE_HOSTING: int = 1
const STATE_JOINING: int = 2
const STATE_CONNECTED: int = 3
const STATE_ERROR: int = 4

const PRESENCE_BROADCAST_HZ: float = 20.0
const HEARTBEAT_HZ: float = 1.0
const PRESENCE_SCRUB_HZ: float = 1.0
const BOARD_HASH_INTERVAL_OPS: int = 64
const CHAT_MESSAGE_MAX_LENGTH: int = 2000
const CHAT_HISTORY_MAX_ENTRIES: int = 250

const ROLE_OWNER: String = ParticipantsManifest.ROLE_OWNER
const ROLE_CO_AUTHOR: String = ParticipantsManifest.ROLE_CO_AUTHOR
const ROLE_GUEST: String = ParticipantsManifest.ROLE_GUEST

var _adapters: Dictionary = {}
var _active_adapter: NetworkAdapter = null
var _state: int = STATE_IDLE
var _project: Project = null
var _manifest: ParticipantsManifest = null
var _local_role: String = ROLE_OWNER
var _is_session_host: bool = false
var _session_host_stable_id: String = ""
var _peers_by_stable_id: Dictionary = {}
var _peers_by_network_id: Dictionary = {}
var _network_id_to_stable_id: Dictionary = {}
var _presence_by_stable_id: Dictionary = {}
var _editing_locks: Dictionary = {}
var _editing_locks_local: Array[String] = []
var _ops_since_last_hash: int = 0
var _local_lamport_stride: int = 0
var _editor: Node = null
var _asset_transfer: AssetTransferService = null
var _presence_send_timer: Timer = null
var _heartbeat_timer: Timer = null
var _scrub_timer: Timer = null
var _last_cursor_world: Vector2 = Vector2.ZERO
var _last_selection_rect: Rect2 = Rect2()
var _last_viewport_rect: Rect2 = Rect2()
var _has_cursor: bool = false
var _has_selection_rect: bool = false
var _has_viewport_rect: bool = false
var _board_request_outstanding: Dictionary = {}
var _map_request_outstanding: Dictionary = {}
var _tileset_request_outstanding: Dictionary = {}
var _local_presence: PresenceState = null
var _pending_auto_host: Dictionary = {}
var _pending_auto_join: Dictionary = {}
var _leaving_session: bool = false
var _last_known_can_edit: bool = true
var _merge_session: MergeSession = null
var _host_merge_ledger: Dictionary = {}
var _suppress_local_op_broadcast: bool = false
var _chat_history: Array = []


func _ready() -> void:
	_register_adapters()
	_presence_send_timer = Timer.new()
	_presence_send_timer.wait_time = 1.0 / PRESENCE_BROADCAST_HZ
	_presence_send_timer.one_shot = false
	_presence_send_timer.autostart = false
	_presence_send_timer.timeout.connect(_on_presence_send_tick)
	add_child(_presence_send_timer)
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.wait_time = 1.0 / HEARTBEAT_HZ
	_heartbeat_timer.one_shot = false
	_heartbeat_timer.autostart = false
	_heartbeat_timer.timeout.connect(_on_heartbeat_tick)
	add_child(_heartbeat_timer)
	_scrub_timer = Timer.new()
	_scrub_timer.wait_time = 1.0 / PRESENCE_SCRUB_HZ
	_scrub_timer.one_shot = false
	_scrub_timer.autostart = false
	_scrub_timer.timeout.connect(_on_presence_scrub)
	add_child(_scrub_timer)
	AppState.project_opened.connect(_on_project_opened)
	AppState.project_closed.connect(_on_project_closed)
	AppState.current_board_changed.connect(_on_board_changed)
	OpBus.local_op_emitted.connect(_on_local_op_emitted)
	OpBus.remote_op_applied.connect(_on_remote_op_applied)


func _register_adapters() -> void:
	for name: String in [NetworkAdapter.ADAPTER_KIND_ENET, NetworkAdapter.ADAPTER_KIND_LAN, NetworkAdapter.ADAPTER_KIND_STEAM]:
		var adapter: NetworkAdapter = _build_adapter(name)
		if adapter != null:
			adapter.name = "Adapter_%s" % name
			add_child(adapter)
			_adapters[name] = adapter
			adapter.peer_connected.connect(_on_peer_connected.bind(adapter))
			adapter.peer_disconnected.connect(_on_peer_disconnected.bind(adapter))
			adapter.message_received.connect(_on_message_received.bind(adapter))
			adapter.connection_state_changed.connect(_on_adapter_state_changed.bind(adapter))
			adapter.error_occurred.connect(_on_adapter_error.bind(adapter))
			adapter.lobby_list_updated.connect(func(lobbies: Array) -> void:
				emit_signal("lobby_list_updated", adapter.adapter_kind(), lobbies))


func _build_adapter(kind: String) -> NetworkAdapter:
	match kind:
		NetworkAdapter.ADAPTER_KIND_ENET:
			return EnetAdapter.new()
		NetworkAdapter.ADAPTER_KIND_LAN:
			return LanAdapter.new()
		NetworkAdapter.ADAPTER_KIND_STEAM:
			return SteamAdapter.new()
	return null


func adapter_kinds() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in _adapters.keys():
		out.append(String(k))
	return out


func adapter_for(kind: String) -> NetworkAdapter:
	return _adapters.get(kind, null)


func is_adapter_available(kind: String) -> bool:
	var adapter: NetworkAdapter = _adapters.get(kind, null)
	return adapter != null and adapter.is_available()


func adapter_unavailability_reason(kind: String) -> String:
	var adapter: NetworkAdapter = _adapters.get(kind, null)
	if adapter == null:
		return "Adapter not registered."
	return adapter.unavailability_reason()


func bind_editor(editor: Node) -> void:
	_editor = editor


func unbind_editor() -> void:
	_editor = null


func current_state() -> int:
	return _state


func is_in_session() -> bool:
	return _state == STATE_HOSTING or _state == STATE_CONNECTED


func is_session_host() -> bool:
	return _is_session_host


func is_session_guest() -> bool:
	return _local_role == ROLE_GUEST


func is_guest_session_role() -> bool:
	return _local_role == ROLE_GUEST


func local_role() -> String:
	return _local_role


func local_stable_id() -> String:
	KeypairService.ensure_ready()
	return KeypairService.stable_id()


func local_display_name() -> String:
	KeypairService.ensure_ready()
	return KeypairService.display_name()


func local_network_id() -> int:
	if _active_adapter == null or _active_adapter.local_peer_identity == null:
		return 1
	return _active_adapter.local_peer_identity.network_id


func public_key_for_stable_id(stable_id: String) -> String:
	if _manifest == null:
		return ""
	return _manifest.public_key_of(stable_id)


func participants_manifest() -> ParticipantsManifest:
	return _manifest


func participants_list() -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	if _manifest != null:
		for k: Variant in _manifest.participants.keys():
			var stable_id_key: String = String(k)
			var entry: Dictionary = (_manifest.participants[k] as Dictionary).duplicate()
			entry["stable_id"] = stable_id_key
			entry["connected"] = _is_stable_id_connected(stable_id_key)
			out.append(entry)
			seen[stable_id_key] = true
	for peer_v: Variant in _peers_by_stable_id.values():
		if not (peer_v is PeerIdentity):
			continue
		var peer: PeerIdentity = peer_v
		if peer.stable_id == "" or seen.has(peer.stable_id):
			continue
		out.append({
			"stable_id": peer.stable_id,
			"display_name": peer.display_name,
			"role": ParticipantsManifest.ROLE_GUEST,
			"public_key": peer.public_key_hex,
			"connected": true,
		})
		seen[peer.stable_id] = true
	for sid_v: Variant in _presence_by_stable_id.keys():
		var sid: String = String(sid_v)
		if sid == "" or seen.has(sid):
			continue
		var state: PresenceState = _presence_by_stable_id[sid_v] as PresenceState
		if state == null:
			continue
		out.append({
			"stable_id": sid,
			"display_name": state.display_name,
			"role": ParticipantsManifest.ROLE_GUEST,
			"public_key": "",
			"connected": true,
		})
		seen[sid] = true
	out.sort_custom(_compare_participant_entries)
	return out


func _is_stable_id_connected(stable_id: String) -> bool:
	if stable_id == "":
		return false
	if stable_id == KeypairService.stable_id() and is_in_session():
		return true
	if _peers_by_stable_id.has(stable_id):
		return true
	return _presence_by_stable_id.has(stable_id)


func _compare_participant_entries(a: Dictionary, b: Dictionary) -> bool:
	var role_a: String = String(a.get("role", ""))
	var role_b: String = String(b.get("role", ""))
	if role_a != role_b:
		if role_a == ROLE_OWNER:
			return true
		if role_b == ROLE_OWNER:
			return false
	return String(a.get("display_name", "")).naturalnocasecmp_to(String(b.get("display_name", ""))) < 0


func presence_for(stable_id: String) -> PresenceState:
	return _presence_by_stable_id.get(stable_id, null) as PresenceState


func all_presence() -> Array:
	var out: Array = []
	for v in _presence_by_stable_id.values():
		out.append(v)
	return out


func host_session(adapter_kind: String, settings: Dictionary) -> Error:
	if _project == null:
		_log_error("Cannot host: no project open")
		return ERR_UNCONFIGURED
	var adapter: NetworkAdapter = _adapters.get(adapter_kind, null)
	if adapter == null or not adapter.is_available():
		_log_error("Adapter %s unavailable: %s" % [adapter_kind, adapter.unavailability_reason() if adapter != null else "missing"])
		return ERR_UNAVAILABLE
	_ensure_manifest_loaded()
	if _manifest != null and not _manifest.is_owner(KeypairService.stable_id()):
		_local_role = ROLE_CO_AUTHOR
	else:
		_local_role = ROLE_OWNER
	_set_state(STATE_HOSTING)
	_activate_adapter(adapter)
	_is_session_host = true
	_session_host_stable_id = KeypairService.stable_id()
	var metadata: Dictionary = _build_lobby_metadata(settings)
	var err: Error = adapter.host(metadata)
	if err != OK:
		_set_state(STATE_ERROR)
		return err
	_register_local_in_session()
	_start_session_timers()
	return OK


func join_session(adapter_kind: String, connect_info: Dictionary) -> Error:
	var adapter: NetworkAdapter = _adapters.get(adapter_kind, null)
	if adapter == null or not adapter.is_available():
		_log_error("Adapter %s unavailable: %s" % [adapter_kind, adapter.unavailability_reason() if adapter != null else "missing"])
		return ERR_UNAVAILABLE
	_set_state(STATE_JOINING)
	_activate_adapter(adapter)
	_is_session_host = false
	_session_host_stable_id = String(connect_info.get("host_stable_id", ""))
	var err: Error = adapter.join(connect_info)
	if err != OK:
		_set_state(STATE_ERROR)
		return err
	return OK


func leave_session() -> void:
	if _leaving_session:
		return
	_leaving_session = true
	var adapter: NetworkAdapter = _active_adapter
	_active_adapter = null
	if adapter != null:
		adapter.leave()
	_peers_by_stable_id.clear()
	_peers_by_network_id.clear()
	_network_id_to_stable_id.clear()
	_presence_by_stable_id.clear()
	_editing_locks.clear()
	_editing_locks_local.clear()
	_is_session_host = false
	_session_host_stable_id = ""
	_local_presence = null
	_board_request_outstanding.clear()
	_map_request_outstanding.clear()
	_tileset_request_outstanding.clear()
	_host_merge_ledger.clear()
	if _merge_session != null:
		_merge_session.cancel()
		_merge_session = null
	_stop_session_timers()
	_set_state(STATE_IDLE)
	emit_signal("participants_changed")
	notify_permissions_maybe_changed()
	clear_chat_history()
	_leaving_session = false


func discover_lobbies(adapter_kind: String, filter: Dictionary) -> Error:
	var adapter: NetworkAdapter = _adapters.get(adapter_kind, null)
	if adapter == null or not adapter.is_available():
		return ERR_UNAVAILABLE
	return adapter.discover_lobbies(filter)


func cancel_discovery(adapter_kind: String) -> void:
	var adapter: NetworkAdapter = _adapters.get(adapter_kind, null)
	if adapter == null:
		return
	adapter.cancel_discovery()


func add_co_author_by_public_key(public_key_pem: String, display_name: String) -> Op:
	if _manifest == null or not _manifest.is_owner(KeypairService.stable_id()):
		return null
	var stable_id: String = "kp:" + KeypairService.fingerprint_for_pem(public_key_pem)
	if _manifest.has_participant(stable_id):
		return null
	var payload: Dictionary = {
		"stable_id": stable_id,
		"public_key": public_key_pem,
		"display_name": display_name,
	}
	var op: Op = OpBus.emit_local(OpKinds.ADD_PARTICIPANT, payload, "")
	return op


func remove_co_author(stable_id: String) -> Op:
	if _manifest == null or not _manifest.is_owner(KeypairService.stable_id()):
		return null
	if stable_id == _manifest.owner_stable_id:
		return null
	var op: Op = OpBus.emit_local(OpKinds.REMOVE_PARTICIPANT, {"stable_id": stable_id}, "")
	return op


func transfer_ownership(new_owner_stable_id: String) -> Op:
	if _manifest == null or not _manifest.is_owner(KeypairService.stable_id()):
		return null
	if not _manifest.has_participant(new_owner_stable_id):
		return null
	var op: Op = OpBus.emit_local(OpKinds.TRANSFER_OWNERSHIP, {"new_owner_stable_id": new_owner_stable_id}, "")
	return op


func set_guest_policy(policy: String) -> Op:
	if _manifest == null or not _manifest.is_owner(KeypairService.stable_id()):
		return null
	var op: Op = OpBus.emit_local(OpKinds.SET_GUEST_POLICY, {"policy": policy}, "")
	return op


func set_project_property(key: String, value: Variant) -> Op:
	if _manifest == null or not _manifest.is_owner(KeypairService.stable_id()):
		return null
	var op: Op = OpBus.emit_local(OpKinds.SET_PROJECT_PROPERTY, {"key": key, "value": value}, "")
	return op


func local_can_edit() -> bool:
	if _manifest == null:
		return true
	var local_id: String = KeypairService.stable_id()
	if _manifest.is_owner(local_id) or _manifest.has_participant(local_id):
		return true
	return _manifest.guest_policy == ParticipantsManifest.GUEST_POLICY_EDIT


func notify_permissions_maybe_changed() -> void:
	var current: bool = local_can_edit()
	if current == _last_known_can_edit:
		return
	_last_known_can_edit = current
	emit_signal("local_permissions_changed", current)


func local_can_emit(kind: String) -> bool:
	if kind == "":
		return true
	if _manifest == null:
		return true
	var local_id: String = KeypairService.stable_id()
	if OpKinds.is_owner_only(kind):
		return _manifest.is_owner(local_id)
	var role: String = _resolve_role_for(local_id)
	if role == ROLE_GUEST:
		match _manifest.guest_policy:
			ParticipantsManifest.GUEST_POLICY_VIEW:
				return false
			ParticipantsManifest.GUEST_POLICY_COMMENT:
				return OpKinds.is_comment_kind(kind) or kind == OpKinds.SET_ITEM_PROPERTY
			ParticipantsManifest.GUEST_POLICY_EDIT:
				return true
		return false
	return true


func local_role_label() -> String:
	if _manifest == null:
		return ROLE_OWNER
	return _resolve_role_for(KeypairService.stable_id())


func is_op_authorized(op: Op) -> bool:
	if _manifest == null:
		return true
	if OpKinds.is_owner_only(op.kind):
		return _manifest.is_owner(op.author_stable_id)
	var role: String = _resolve_role_for(op.author_stable_id)
	if role == ROLE_GUEST:
		match _manifest.guest_policy:
			ParticipantsManifest.GUEST_POLICY_VIEW:
				return false
			ParticipantsManifest.GUEST_POLICY_COMMENT:
				return OpKinds.is_comment_kind(op.kind) or op.kind == OpKinds.SET_ITEM_PROPERTY
			ParticipantsManifest.GUEST_POLICY_EDIT:
				return true
		return false
	return true


func apply_manifest_op(op: Op) -> void:
	if _manifest == null:
		return
	match op.kind:
		OpKinds.ADD_PARTICIPANT:
			var stable_id: String = String(op.payload.get("stable_id", ""))
			var public_key: String = String(op.payload.get("public_key", ""))
			var display_name: String = String(op.payload.get("display_name", "Player"))
			if stable_id != "" and public_key != "":
				_manifest.add_co_author(stable_id, public_key, display_name)
		OpKinds.REMOVE_PARTICIPANT:
			var stable_id: String = String(op.payload.get("stable_id", ""))
			if stable_id != "":
				_manifest.remove_participant(stable_id)
		OpKinds.TRANSFER_OWNERSHIP:
			var new_owner: String = String(op.payload.get("new_owner_stable_id", ""))
			if new_owner != "":
				_manifest.transfer_ownership(new_owner)
		OpKinds.SET_GUEST_POLICY:
			_manifest.guest_policy = String(op.payload.get("policy", _manifest.guest_policy))
		OpKinds.SET_PROJECT_PROPERTY:
			var key: String = String(op.payload.get("key", ""))
			var value: Variant = op.payload.get("value", null)
			_apply_project_property(key, value)
	_manifest.append_op(op)
	if _project != null:
		_manifest.save(_project)
	if _local_role != ROLE_OWNER and _manifest.is_owner(KeypairService.stable_id()):
		_local_role = ROLE_OWNER
	emit_signal("participants_changed")
	notify_permissions_maybe_changed()


func notify_peer_left(peer: PeerIdentity) -> void:
	if peer == null:
		return
	var stable_id: String = peer.stable_id
	_release_locks_for(stable_id)
	if _presence_by_stable_id.has(stable_id):
		_presence_by_stable_id.erase(stable_id)
		emit_signal("presence_removed", stable_id)
	emit_signal("participants_changed")


func update_local_cursor(world_pos: Vector2) -> void:
	_last_cursor_world = world_pos
	_has_cursor = true


func update_local_selection_rect(rect: Rect2, has_rect: bool) -> void:
	_last_selection_rect = rect
	_has_selection_rect = has_rect


func update_local_viewport_rect(rect: Rect2, has_rect: bool) -> void:
	_last_viewport_rect = rect
	_has_viewport_rect = has_rect


func acquire_editing_lock(item_id: String) -> bool:
	if item_id == "":
		return false
	if _editing_locks.has(item_id) and String(_editing_locks[item_id].get("stable_id", "")) != KeypairService.stable_id():
		return false
	_editing_locks[item_id] = {"stable_id": KeypairService.stable_id(), "ts_ms": Time.get_ticks_msec()}
	if not _editing_locks_local.has(item_id):
		_editing_locks_local.append(item_id)
	if is_in_session() and _active_adapter != null:
		_active_adapter.send_to_all(NetworkMessage.KIND_EDITING_LOCK, {"item_id": item_id, "stable_id": KeypairService.stable_id()})
	emit_signal("editing_lock_changed", item_id, KeypairService.stable_id())
	return true


func release_editing_lock(item_id: String) -> void:
	if item_id == "":
		return
	if _editing_locks.has(item_id) and String(_editing_locks[item_id].get("stable_id", "")) == KeypairService.stable_id():
		_editing_locks.erase(item_id)
	_editing_locks_local.erase(item_id)
	if is_in_session() and _active_adapter != null:
		_active_adapter.send_to_all(NetworkMessage.KIND_EDITING_UNLOCK, {"item_id": item_id, "stable_id": KeypairService.stable_id()})
	emit_signal("editing_lock_changed", item_id, "")


func editing_lock_holder(item_id: String) -> String:
	if not _editing_locks.has(item_id):
		return ""
	return String(_editing_locks[item_id].get("stable_id", ""))


func send_ping_marker(world_pos: Vector2) -> void:
	if not is_in_session() or _active_adapter == null:
		return
	var color: Color = PeerIdentity.color_for_stable_id(KeypairService.stable_id())
	_active_adapter.send_to_all(NetworkMessage.KIND_PING_MARKER, {
		"world_pos": [world_pos.x, world_pos.y],
		"color": [color.r, color.g, color.b, color.a],
		"stable_id": KeypairService.stable_id(),
	})
	emit_signal("ping_marker_received", world_pos, color, KeypairService.stable_id())


func send_chat_message(text: String) -> Error:
	if not is_in_session() or _active_adapter == null:
		return ERR_UNAVAILABLE
	var trimmed: String = text.strip_edges()
	if trimmed == "":
		return ERR_PARAMETER_RANGE_ERROR
	if trimmed.length() > CHAT_MESSAGE_MAX_LENGTH:
		trimmed = trimmed.substr(0, CHAT_MESSAGE_MAX_LENGTH)
	KeypairService.ensure_ready()
	var local_id: String = KeypairService.stable_id()
	var local_name: String = KeypairService.display_name()
	var local_color: Color = _chat_color_for_stable_id(local_id)
	var timestamp_unix: int = int(Time.get_unix_time_from_system())
	var entry: Dictionary = {
		"stable_id": local_id,
		"display_name": local_name,
		"color": local_color,
		"text": trimmed,
		"timestamp_ms": Time.get_ticks_msec(),
		"timestamp_unix": timestamp_unix,
		"is_system": false,
		"is_local": true,
	}
	_record_chat_entry(entry)
	_active_adapter.send_to_all(NetworkMessage.KIND_CHAT_MESSAGE, {
		"text": trimmed,
		"timestamp_unix": timestamp_unix,
	})
	return OK


func recent_chat_messages() -> Array:
	return _chat_history.duplicate(true)


func clear_chat_history() -> void:
	if _chat_history.is_empty():
		return
	_chat_history.clear()
	emit_signal("chat_history_cleared")


func _handle_chat_message(from_network_id: int, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var d: Dictionary = payload
	var text: String = String(d.get("text", "")).strip_edges()
	if text == "":
		return
	if text.length() > CHAT_MESSAGE_MAX_LENGTH:
		text = text.substr(0, CHAT_MESSAGE_MAX_LENGTH)
	var stable_id: String = String(_network_id_to_stable_id.get(from_network_id, ""))
	var display_name: String = ""
	var color: Color = _chat_color_for_stable_id(stable_id)
	var presence: PresenceState = _presence_by_stable_id.get(stable_id, null) as PresenceState
	if presence != null:
		if presence.display_name != "":
			display_name = presence.display_name
		color = presence.avatar_color
	if display_name == "":
		var peer: PeerIdentity = _peers_by_network_id.get(from_network_id, null) as PeerIdentity
		if peer != null:
			if peer.display_name != "":
				display_name = peer.display_name
			if presence == null:
				color = peer.avatar_color
	if display_name == "":
		display_name = "Player"
	var timestamp_unix: int = int(d.get("timestamp_unix", int(Time.get_unix_time_from_system())))
	var entry: Dictionary = {
		"stable_id": stable_id,
		"display_name": display_name,
		"color": color,
		"text": text,
		"timestamp_ms": Time.get_ticks_msec(),
		"timestamp_unix": timestamp_unix,
		"is_system": false,
		"is_local": false,
	}
	_record_chat_entry(entry)


func _record_chat_entry(entry: Dictionary) -> void:
	_chat_history.append(entry)
	if _chat_history.size() > CHAT_HISTORY_MAX_ENTRIES:
		var overflow: int = _chat_history.size() - CHAT_HISTORY_MAX_ENTRIES
		for i: int in range(overflow):
			_chat_history.pop_front()
	emit_signal("chat_message_received", entry.duplicate(true))


func _chat_color_for_stable_id(stable_id: String) -> Color:
	if stable_id == "":
		return PeerIdentity.color_for_stable_id("")
	var presence: PresenceState = _presence_by_stable_id.get(stable_id, null) as PresenceState
	if presence != null:
		return presence.avatar_color
	var peer: PeerIdentity = _peers_by_stable_id.get(stable_id, null) as PeerIdentity
	if peer != null:
		return peer.avatar_color
	return PeerIdentity.color_for_stable_id(stable_id)


func request_board(board_id: String) -> void:
	if not is_in_session() or _active_adapter == null or board_id == "":
		return
	if _board_request_outstanding.has(board_id):
		return
	_board_request_outstanding[board_id] = true
	emit_signal("board_request_in_progress", board_id, KeypairService.stable_id())
	if _is_session_host:
		return
	_active_adapter.send_to_peer(NetworkAdapter.HOST_NETWORK_ID, NetworkMessage.KIND_BOARD_REQUEST, {"board_id": board_id})


func request_map_page(map_id: String) -> void:
	if not is_in_session() or _active_adapter == null or map_id == "":
		return
	if _map_request_outstanding.has(map_id):
		return
	_map_request_outstanding[map_id] = true
	if _is_session_host:
		return
	_active_adapter.send_to_peer(NetworkAdapter.HOST_NETWORK_ID, NetworkMessage.KIND_MAP_REQUEST, {"map_id": map_id})


func request_tileset(tileset_id: String) -> void:
	if not is_in_session() or _active_adapter == null or tileset_id == "":
		return
	if _tileset_request_outstanding.has(tileset_id):
		return
	_tileset_request_outstanding[tileset_id] = true
	if _is_session_host:
		return
	_active_adapter.send_to_peer(NetworkAdapter.HOST_NETWORK_ID, NetworkMessage.KIND_TILESET_REQUEST, {"tileset_id": tileset_id})


func _on_project_opened(project: Project) -> void:
	_project = project
	_ensure_manifest_loaded()
	OpBus.bind_project(project)
	_asset_transfer = AssetTransferService.new(project, _send_to_peer_proxy)
	if _manifest != null and _manifest.is_owner(KeypairService.stable_id()):
		_local_role = ROLE_OWNER
	elif _manifest != null and _manifest.has_participant(KeypairService.stable_id()):
		_local_role = ROLE_CO_AUTHOR
	else:
		_local_role = ROLE_OWNER
	emit_signal("participants_changed")
	notify_permissions_maybe_changed()
	_consume_pending_session_intent()


func set_pending_auto_host(adapter_kind: String, settings: Dictionary) -> void:
	_pending_auto_host = {"kind": adapter_kind, "settings": settings.duplicate(true)}
	_pending_auto_join = {}


func set_pending_auto_join(adapter_kind: String, connect_info: Dictionary) -> void:
	_pending_auto_join = {"kind": adapter_kind, "connect_info": connect_info.duplicate(true)}
	_pending_auto_host = {}


func clear_pending_session_intent() -> void:
	_pending_auto_host = {}
	_pending_auto_join = {}


func _consume_pending_session_intent() -> void:
	if not _pending_auto_host.is_empty():
		var kind: String = String(_pending_auto_host.get("kind", ""))
		var settings: Dictionary = _pending_auto_host.get("settings", {})
		_pending_auto_host = {}
		if kind != "":
			host_session(kind, settings)
		return
	if not _pending_auto_join.is_empty():
		var jkind: String = String(_pending_auto_join.get("kind", ""))
		var connect_info: Dictionary = _pending_auto_join.get("connect_info", {})
		_pending_auto_join = {}
		if jkind != "":
			join_session(jkind, connect_info)


func resolve_or_bootstrap_join_project(lobby_entry: Dictionary) -> Project:
	if typeof(lobby_entry) != TYPE_DICTIONARY:
		return null
	var project_id: String = String(lobby_entry.get("project_id", ""))
	var project_name: String = String(lobby_entry.get("project_name", "Untitled Project"))
	var root_board_id: String = String(lobby_entry.get("root_board_id", ""))
	if project_id == "":
		return null
	for rec_v: Variant in ProjectStore.recent():
		if typeof(rec_v) != TYPE_DICTIONARY:
			continue
		var rec: Dictionary = rec_v
		if String(rec.get("id", "")) == project_id:
			var folder_path: String = String(rec.get("folder_path", ""))
			if folder_path == "":
				continue
			var existing: Project = ProjectStore.open_project(folder_path)
			if existing != null:
				return existing
	var safe_name: String = project_name.strip_edges().replace("/", "_").replace("\\", "_").replace(":", "_")
	if safe_name == "":
		safe_name = "Shared"
	var short_id: String = project_id.substr(0, 8) if project_id.length() >= 8 else project_id
	var folder_user: String = "user://received_projects/%s_%s" % [safe_name, short_id]
	var folder_abs: String = ProjectSettings.globalize_path(folder_user)
	var existing_local: Project = Project.load_from_folder(folder_abs)
	if existing_local != null and existing_local.id == project_id:
		return existing_local
	return Project.create_shell(folder_abs, project_id, project_name, root_board_id)


func _on_project_closed() -> void:
	leave_session()
	_project = null
	_manifest = null
	_asset_transfer = null
	OpBus.unbind_project()
	emit_signal("participants_changed")
	notify_permissions_maybe_changed()


func _on_board_changed(_board: Board) -> void:
	_ops_since_last_hash = 0


func _ensure_manifest_loaded() -> void:
	if _project == null:
		_manifest = null
		return
	KeypairService.ensure_ready()
	_manifest = ParticipantsManifest.load_or_create(_project, KeypairService.stable_id(), KeypairService.public_key_pem(), KeypairService.display_name())
	if _manifest != null and _manifest.is_owner(KeypairService.stable_id()):
		if String((_manifest.participants[KeypairService.stable_id()] as Dictionary).get("display_name", "")) != KeypairService.display_name():
			(_manifest.participants[KeypairService.stable_id()] as Dictionary)["display_name"] = KeypairService.display_name()
			_manifest.save(_project)


func _activate_adapter(adapter: NetworkAdapter) -> void:
	if _active_adapter == adapter:
		return
	_active_adapter = adapter
	KeypairService.ensure_ready()
	var local_ident: PeerIdentity = PeerIdentity.make(adapter.adapter_kind(), NetworkAdapter.HOST_NETWORK_ID, KeypairService.stable_id(), KeypairService.display_name())
	local_ident.public_key_hex = KeypairService.public_key_pem()
	adapter.local_peer_identity = local_ident


func _build_lobby_metadata(settings: Dictionary) -> Dictionary:
	var metadata: Dictionary = settings.duplicate(true) if settings != null else {}
	metadata["lobby_id"] = String(metadata.get("lobby_id", "%s_%d" % [KeypairService.stable_id(), Time.get_ticks_msec()]))
	metadata["project_id"] = _project.id if _project != null else ""
	metadata["project_name"] = _project.name if _project != null else "Untitled Project"
	metadata["root_board_id"] = _project.root_board_id if _project != null else ""
	metadata["host_display_name"] = KeypairService.display_name()
	metadata["host_stable_id"] = KeypairService.stable_id()
	metadata["format_version"] = Project.FORMAT_VERSION
	metadata["max_members"] = int(metadata.get("max_members", 16))
	if not metadata.has("port"):
		metadata["port"] = EnetAdapter.DEFAULT_PORT
	return metadata


func _register_local_in_session() -> void:
	if _active_adapter == null or _active_adapter.local_peer_identity == null:
		return
	var local_ident: PeerIdentity = _active_adapter.local_peer_identity
	_peers_by_stable_id[local_ident.stable_id] = local_ident
	_peers_by_network_id[local_ident.network_id] = local_ident
	_network_id_to_stable_id[local_ident.network_id] = local_ident.stable_id
	_local_presence = PresenceState.new()
	_local_presence.stable_id = local_ident.stable_id
	_local_presence.network_id = local_ident.network_id
	_local_presence.display_name = local_ident.display_name
	_local_presence.avatar_color = local_ident.avatar_color
	_local_presence.role = _local_role
	_local_presence.hosting = _is_session_host
	if AppState.current_board != null:
		_local_presence.board_id = AppState.current_board.id
	_presence_by_stable_id[local_ident.stable_id] = _local_presence
	emit_signal("participants_changed")


func _start_session_timers() -> void:
	_presence_send_timer.start()
	_heartbeat_timer.start()
	_scrub_timer.start()


func _stop_session_timers() -> void:
	_presence_send_timer.stop()
	_heartbeat_timer.stop()
	_scrub_timer.stop()


func _on_peer_connected(peer: PeerIdentity, _adapter: NetworkAdapter) -> void:
	if peer == null:
		return
	_peers_by_network_id[peer.network_id] = peer
	_network_id_to_stable_id[peer.network_id] = peer.stable_id
	if peer.stable_id != "":
		_peers_by_stable_id[peer.stable_id] = peer
	emit_signal("participants_changed")


func _on_peer_disconnected(peer_network_id: int, _reason: String, _adapter: NetworkAdapter) -> void:
	var stable_id: String = String(_network_id_to_stable_id.get(peer_network_id, ""))
	_peers_by_network_id.erase(peer_network_id)
	if stable_id != "":
		_peers_by_stable_id.erase(stable_id)
		_network_id_to_stable_id.erase(peer_network_id)
		_release_locks_for(stable_id)
		_presence_by_stable_id.erase(stable_id)
		emit_signal("presence_removed", stable_id)
	emit_signal("participants_changed")


func _on_message_received(from_network_id: int, kind: String, payload: Variant, adapter: NetworkAdapter) -> void:
	if adapter != _active_adapter:
		return
	_register_message_sender(from_network_id, kind, payload)
	match kind:
		NetworkMessage.KIND_HELLO:
			_handle_hello(from_network_id, payload)
		NetworkMessage.KIND_HELLO_ACK:
			_handle_hello_ack(from_network_id, payload)
		NetworkMessage.KIND_ROSTER:
			_handle_roster(from_network_id, payload)
		NetworkMessage.KIND_OP:
			_handle_op_message(from_network_id, payload)
		NetworkMessage.KIND_OP_BATCH:
			_handle_op_batch(from_network_id, payload)
		NetworkMessage.KIND_VECTOR_CLOCK_REQUEST:
			_handle_vector_clock_request(from_network_id, payload)
		NetworkMessage.KIND_VECTOR_CLOCK_OFFER:
			_handle_vector_clock_offer(from_network_id, payload)
		NetworkMessage.KIND_OPLOG_REQUEST:
			_handle_oplog_request(from_network_id, payload)
		NetworkMessage.KIND_OPLOG_RESPONSE:
			_handle_oplog_response(from_network_id, payload)
		NetworkMessage.KIND_BOARD_REQUEST:
			_handle_board_request(from_network_id, payload)
		NetworkMessage.KIND_BOARD_RESPONSE:
			_handle_board_response(from_network_id, payload)
		NetworkMessage.KIND_MAP_REQUEST:
			_handle_map_request(from_network_id, payload)
		NetworkMessage.KIND_MAP_RESPONSE:
			_handle_map_response(from_network_id, payload)
		NetworkMessage.KIND_TILESET_REQUEST:
			_handle_tileset_request(from_network_id, payload)
		NetworkMessage.KIND_TILESET_RESPONSE:
			_handle_tileset_response(from_network_id, payload)
		NetworkMessage.KIND_PRESENCE:
			_handle_presence(from_network_id, payload)
		NetworkMessage.KIND_HEARTBEAT:
			_handle_heartbeat(from_network_id, payload)
		NetworkMessage.KIND_PING_MARKER:
			_handle_ping_marker(from_network_id, payload)
		NetworkMessage.KIND_EDITING_LOCK:
			_handle_editing_lock(from_network_id, payload)
		NetworkMessage.KIND_EDITING_UNLOCK:
			_handle_editing_unlock(from_network_id, payload)
		NetworkMessage.KIND_BOARD_HASH:
			_handle_board_hash(from_network_id, payload)
		NetworkMessage.KIND_DESYNC_RESYNC:
			_handle_desync_resync(from_network_id, payload)
		NetworkMessage.KIND_KICK:
			_handle_kick(payload)
		NetworkMessage.KIND_MERGE_PREFLIGHT:
			_handle_merge_preflight(from_network_id, payload)
		NetworkMessage.KIND_MERGE_PREFLIGHT_RESPONSE:
			_handle_merge_preflight_response(from_network_id, payload)
		NetworkMessage.KIND_MERGE_FINALIZE:
			_handle_merge_finalize(from_network_id, payload)
		NetworkMessage.KIND_CHAT_MESSAGE:
			_handle_chat_message(from_network_id, payload)
		NetworkMessage.KIND_GUEST_POLICY:
			pass
		NetworkMessage.KIND_ASSET_QUERY:
			if _asset_transfer != null:
				_asset_transfer.handle_query_request(from_network_id, payload.get("asset_names", []) as Array)
		NetworkMessage.KIND_ASSET_OFFER:
			if _asset_transfer != null:
				_asset_transfer.handle_offer(from_network_id, payload.get("asset_names", []) as Array)
		NetworkMessage.KIND_ASSET_REQUEST:
			if _asset_transfer != null:
				_asset_transfer.handle_request(from_network_id, String((payload as Dictionary).get("asset_name", "")))
		NetworkMessage.KIND_ASSET_CHUNK:
			_handle_asset_chunk(from_network_id, payload)
		NetworkMessage.KIND_ASSET_DENY:
			if _asset_transfer != null:
				_asset_transfer.handle_deny(String((payload as Dictionary).get("asset_name", "")), String((payload as Dictionary).get("reason", "")))
		_:
			pass


func _on_adapter_state_changed(state: int, adapter: NetworkAdapter) -> void:
	if adapter != _active_adapter:
		return
	match state:
		NetworkAdapter.STATE_HOSTING:
			_set_state(STATE_HOSTING)
		NetworkAdapter.STATE_CONNECTED:
			_set_state(STATE_CONNECTED)
			_register_local_in_session()
			_send_hello_to_host()
			_start_session_timers()
			_request_root_board_if_missing()
		NetworkAdapter.STATE_DISCONNECTED:
			leave_session()
		NetworkAdapter.STATE_ERROR:
			_set_state(STATE_ERROR)


func _on_adapter_error(message: String, _adapter: NetworkAdapter) -> void:
	_log_error(message)


func _on_local_op_emitted(op: Op) -> void:
	if not is_in_session() or _active_adapter == null:
		return
	if op.scope == OpKinds.SCOPE_MANIFEST:
		apply_manifest_op(op)
	if _suppress_local_op_broadcast:
		return
	_active_adapter.send_to_all(NetworkMessage.KIND_OP, op.to_dict())
	_ops_since_last_hash += 1
	if _is_session_host and _ops_since_last_hash >= BOARD_HASH_INTERVAL_OPS:
		_broadcast_board_hash(op.board_id)
		_ops_since_last_hash = 0


func _on_remote_op_applied(op: Op) -> void:
	if op == null:
		return
	if op.payload.has("asset_name"):
		var asset_name: String = String(op.payload.get("asset_name", ""))
		if asset_name != "" and _asset_transfer != null and not _asset_transfer.has_local_asset(asset_name):
			_asset_transfer.request_unknown_assets([asset_name], _resolve_op_origin_network_id(op))
	_notify_remote_board_topology(op)


func _notify_remote_board_topology(op: Op) -> void:
	match op.kind:
		OpKinds.CREATE_BOARD, OpKinds.RENAME_BOARD, OpKinds.REPARENT_BOARD:
			var board_id: String = String(op.payload.get("board_id", ""))
			if board_id == "":
				return
			AppState.emit_signal("board_modified", board_id)
			if AppState.current_board != null and AppState.current_board.id == board_id and op.kind == OpKinds.RENAME_BOARD:
				AppState.current_board.name = String(op.payload.get("name", AppState.current_board.name))
				AppState.emit_signal("navigation_changed")
		OpKinds.DELETE_BOARD:
			var deleted_board_id: String = String(op.payload.get("board_id", ""))
			if deleted_board_id == "":
				return
			AppState.emit_signal("board_modified", deleted_board_id)
			if AppState.current_board != null and AppState.current_board.id == deleted_board_id and _project != null:
				var fallback: String = _project.root_board_id
				if fallback != "":
					AppState.navigate_to_board(fallback)
		OpKinds.CREATE_MAP_PAGE, OpKinds.RENAME_MAP_PAGE:
			var map_id: String = String(op.payload.get("map_id", ""))
			if map_id == "":
				return
			AppState.emit_signal("map_page_modified", map_id)
			if AppState.current_map_page != null and AppState.current_map_page.id == map_id and op.kind == OpKinds.RENAME_MAP_PAGE:
				AppState.current_map_page.name = String(op.payload.get("name", AppState.current_map_page.name))
				AppState.emit_signal("navigation_changed")
		OpKinds.DELETE_MAP_PAGE:
			var deleted_map_id: String = String(op.payload.get("map_id", ""))
			if deleted_map_id == "":
				return
			AppState.emit_signal("map_page_modified", deleted_map_id)
			if AppState.current_map_page != null and AppState.current_map_page.id == deleted_map_id and _project != null:
				AppState.current_map_page = null
				if _project.root_board_id != "":
					AppState.navigate_to_board(_project.root_board_id)
		OpKinds.CREATE_TILESET, OpKinds.UPDATE_TILESET:
			var tileset_id: String = String(op.payload.get("tileset_id", ""))
			if tileset_id == "" or _asset_transfer == null:
				return
			var ts: TileSetResource = _project.read_tileset(tileset_id) if _project != null else null
			if ts != null and ts.image_asset_name != "":
				var asset_name: String = AssetTransferService.make_tileset_asset_name(tileset_id, ts.image_asset_name)
				if not _asset_transfer.has_local_asset(asset_name):
					_asset_transfer.request_unknown_assets([asset_name], _resolve_op_origin_network_id(op))
			AppState.notify_tileset_received(tileset_id)
		OpKinds.DELETE_TILESET:
			var deleted_tileset_id: String = String(op.payload.get("tileset_id", ""))
			if deleted_tileset_id != "":
				AppState.notify_tileset_received(deleted_tileset_id)
		OpKinds.SET_MAP_PROPERTY, OpKinds.MAP_INSERT_LAYER, OpKinds.MAP_REMOVE_LAYER, \
		OpKinds.MAP_REORDER_LAYER, OpKinds.MAP_SET_LAYER_PROPERTY, OpKinds.MAP_SET_LAYER_CELLS, \
		OpKinds.MAP_ADD_OBJECT, OpKinds.MAP_REMOVE_OBJECT, OpKinds.MAP_MOVE_OBJECT, OpKinds.MAP_SET_OBJECT_PROPERTY:
			var content_map_id: String = op.board_id
			if content_map_id == "":
				content_map_id = String(op.payload.get("map_id", ""))
			if content_map_id != "":
				AppState.emit_signal("map_page_modified", content_map_id)


func _register_message_sender(from_network_id: int, _kind: String, _payload: Variant) -> void:
	if from_network_id == 0:
		return
	if _peers_by_network_id.has(from_network_id):
		return


func _resolve_op_origin_network_id(op: Op) -> int:
	if op.author_network_id != 0:
		return op.author_network_id
	for nid: int in _network_id_to_stable_id.keys():
		if String(_network_id_to_stable_id[nid]) == op.author_stable_id:
			return nid
	return NetworkAdapter.HOST_NETWORK_ID if not _is_session_host else NetworkAdapter.BROADCAST_NETWORK_ID


func _handle_hello(from_network_id: int, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var d: Dictionary = payload
	var ident_raw: Variant = d.get("identity", null)
	if typeof(ident_raw) != TYPE_DICTIONARY:
		return
	var peer_ident: PeerIdentity = PeerIdentity.from_dict(ident_raw)
	peer_ident.network_id = from_network_id
	_peers_by_network_id[from_network_id] = peer_ident
	_network_id_to_stable_id[from_network_id] = peer_ident.stable_id
	if peer_ident.stable_id != "":
		_peers_by_stable_id[peer_ident.stable_id] = peer_ident
	if _active_adapter is EnetAdapter:
		(_active_adapter as EnetAdapter).register_remote_peer(from_network_id, peer_ident)
	if _is_session_host:
		_send_hello_ack(from_network_id, peer_ident)
		_send_roster(from_network_id)
		_push_board_snapshot_to(from_network_id, _project.root_board_id if _project != null else "")
	emit_signal("participants_changed")


func _handle_hello_ack(_from_network_id: int, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var d: Dictionary = payload
	var manifest_raw: Variant = d.get("manifest", null)
	if typeof(manifest_raw) == TYPE_DICTIONARY and _manifest != null:
		var remote_manifest: ParticipantsManifest = ParticipantsManifest.from_dict(manifest_raw)
		_manifest = remote_manifest
		if _project != null:
			_manifest.save(_project)
		if _manifest.is_owner(KeypairService.stable_id()):
			_local_role = ROLE_OWNER
		elif _manifest.has_participant(KeypairService.stable_id()):
			_local_role = ROLE_CO_AUTHOR
		else:
			_local_role = ROLE_GUEST
		_replay_missing_manifest_ops(remote_manifest)
		emit_signal("participants_changed")
		notify_permissions_maybe_changed()
	_apply_remote_project_manifest(d.get("project_manifest", null))
	_start_client_merge_session()


func _apply_remote_project_manifest(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY or _project == null:
		return
	var pm: Dictionary = raw
	var board_index_raw: Variant = pm.get("board_index", {})
	if typeof(board_index_raw) == TYPE_DICTIONARY:
		_project.board_index = (board_index_raw as Dictionary).duplicate(true)
	var map_index_raw: Variant = pm.get("map_page_index", {})
	if typeof(map_index_raw) == TYPE_DICTIONARY:
		_project.map_page_index = (map_index_raw as Dictionary).duplicate(true)
	var tileset_index_raw: Variant = pm.get("tileset_index", {})
	if typeof(tileset_index_raw) == TYPE_DICTIONARY:
		_project.tileset_index = (tileset_index_raw as Dictionary).duplicate(true)
	var pname: String = String(pm.get("name", _project.name))
	if pname != "":
		_project.name = pname
	_project.write_manifest()
	for board_id_v: Variant in _project.board_index.keys():
		AppState.emit_signal("board_modified", String(board_id_v))
	for map_id_v: Variant in _project.map_page_index.keys():
		AppState.emit_signal("map_page_modified", String(map_id_v))
	for tileset_id_v: Variant in _project.tileset_index.keys():
		AppState.notify_tileset_received(String(tileset_id_v))


func _handle_roster(_from_network_id: int, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var members: Variant = (payload as Dictionary).get("members", [])
	if typeof(members) != TYPE_ARRAY:
		return
	for m_v: Variant in (members as Array):
		if typeof(m_v) != TYPE_DICTIONARY:
			continue
		var ident: PeerIdentity = PeerIdentity.from_dict(m_v)
		_peers_by_network_id[ident.network_id] = ident
		_network_id_to_stable_id[ident.network_id] = ident.stable_id
		if ident.stable_id != "":
			_peers_by_stable_id[ident.stable_id] = ident
	emit_signal("participants_changed")


func _handle_op_message(_from_network_id: int, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var op: Op = Op.from_dict(payload)
	if op.op_id == "":
		return
	OpBus.ingest_remote(op)
	if _is_session_host and is_in_session() and _active_adapter != null:
		_relay_op_to_others(op, _resolve_op_origin_network_id(op))


func _handle_op_batch(from_network_id: int, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var ops: Variant = (payload as Dictionary).get("ops", [])
	if typeof(ops) != TYPE_ARRAY:
		return
	for op_raw: Variant in (ops as Array):
		if typeof(op_raw) != TYPE_DICTIONARY:
			continue
		var op: Op = Op.from_dict(op_raw)
		if op.op_id == "":
			continue
		OpBus.ingest_remote(op)
		if _is_session_host:
			_relay_op_to_others(op, from_network_id)


func _handle_vector_clock_request(from_network_id: int, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY or OpBus.oplog() == null:
		return
	var board_id: String = String((payload as Dictionary).get("board_id", ""))
	OpBus.oplog().ensure_loaded(board_id)
	var clock: VectorClock = OpBus.oplog().vector_clock_for_board(board_id)
	_active_adapter.send_to_peer(from_network_id, NetworkMessage.KIND_VECTOR_CLOCK_OFFER, {"board_id": board_id, "clock": clock.to_dict()})


func _handle_vector_clock_offer(from_network_id: int, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY or OpBus.oplog() == null:
		return
	var board_id: String = String((payload as Dictionary).get("board_id", ""))
	OpBus.oplog().ensure_loaded(board_id)
	var remote_clock: VectorClock = VectorClock.from_dict((payload as Dictionary).get("clock", {}))
	var local_clock: VectorClock = OpBus.oplog().vector_clock_for_board(board_id)
	var diff: Dictionary = local_clock.difference_to_send(remote_clock)
	if diff.is_empty():
		return
	var ops_to_send: Array = []
	for stable_id: String in diff.keys():
		var range_d: Dictionary = diff[stable_id]
		var seq_from: int = int(range_d.get("from", 1))
		var seq_to: int = int(range_d.get("to", 1))
		var ops: Array = OpBus.oplog().ops_in_range(board_id, stable_id, seq_from, seq_to)
		for op_v: Variant in ops:
			if op_v is Op:
				ops_to_send.append((op_v as Op).to_dict())
	if ops_to_send.is_empty():
		return
	_active_adapter.send_to_peer(from_network_id, NetworkMessage.KIND_OPLOG_RESPONSE, {"board_id": board_id, "ops": ops_to_send})


func _handle_oplog_request(from_network_id: int, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY or OpBus.oplog() == null:
		return
	var board_id: String = String((payload as Dictionary).get("board_id", ""))
	OpBus.oplog().ensure_loaded(board_id)
	var ops: Array = OpBus.oplog().ops_for_board(board_id)
	var dicts: Array = []
	for op_v: Variant in ops:
		if op_v is Op:
			dicts.append((op_v as Op).to_dict())
	_active_adapter.send_to_peer(from_network_id, NetworkMessage.KIND_OPLOG_RESPONSE, {"board_id": board_id, "ops": dicts})


func _handle_oplog_response(from_network_id: int, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var ops_raw: Variant = (payload as Dictionary).get("ops", [])
	if typeof(ops_raw) != TYPE_ARRAY:
		return
	for op_raw: Variant in (ops_raw as Array):
		if typeof(op_raw) != TYPE_DICTIONARY:
			continue
		var op: Op = Op.from_dict(op_raw)
		if op.op_id == "":
			continue
		OpBus.ingest_remote(op)


func _handle_board_request(from_network_id: int, payload: Variant) -> void:
	if _project == null or typeof(payload) != TYPE_DICTIONARY:
		return
	var board_id: String = String((payload as Dictionary).get("board_id", ""))
	var board: Board = _project.read_board(board_id)
	if board == null:
		_active_adapter.send_to_peer(from_network_id, NetworkMessage.KIND_BOARD_RESPONSE, {"board_id": board_id, "missing": true})
		return
	OpBus.oplog().ensure_loaded(board_id)
	var clock: VectorClock = OpBus.oplog().vector_clock_for_board(board_id)
	_active_adapter.send_to_peer(from_network_id, NetworkMessage.KIND_BOARD_RESPONSE, {
		"board_id": board_id,
		"board": board.to_dict(),
		"clock": clock.to_dict(),
	})


func _handle_board_response(_from_network_id: int, payload: Variant) -> void:
	if _project == null or typeof(payload) != TYPE_DICTIONARY:
		return
	var board_id: String = String((payload as Dictionary).get("board_id", ""))
	if (payload as Dictionary).get("missing", false):
		_board_request_outstanding.erase(board_id)
		return
	var board_raw: Variant = (payload as Dictionary).get("board", null)
	if typeof(board_raw) == TYPE_DICTIONARY:
		var board: Board = Board.from_dict(board_raw)
		_project.write_board(board)
		var asset_names: Array = _collect_asset_names_from_board(board)
		if _asset_transfer != null and not asset_names.is_empty():
			_asset_transfer.request_unknown_assets(asset_names, NetworkAdapter.HOST_NETWORK_ID)
		emit_signal("board_received", board_id)
		if AppState.current_project != null and AppState.current_project == _project:
			AppState.apply_remote_board_snapshot(board)
	_board_request_outstanding.erase(board_id)


func _handle_map_request(from_network_id: int, payload: Variant) -> void:
	if _project == null or _active_adapter == null or typeof(payload) != TYPE_DICTIONARY:
		return
	var map_id: String = String((payload as Dictionary).get("map_id", ""))
	var page: MapPage = _project.read_map_page(map_id)
	if page == null:
		_active_adapter.send_to_peer(from_network_id, NetworkMessage.KIND_MAP_RESPONSE, {"map_id": map_id, "missing": true})
		return
	_active_adapter.send_to_peer(from_network_id, NetworkMessage.KIND_MAP_RESPONSE, {
		"map_id": map_id,
		"page": page.to_dict(),
	})


func _handle_map_response(_from_network_id: int, payload: Variant) -> void:
	if _project == null or typeof(payload) != TYPE_DICTIONARY:
		return
	var map_id: String = String((payload as Dictionary).get("map_id", ""))
	if (payload as Dictionary).get("missing", false):
		_map_request_outstanding.erase(map_id)
		return
	var page_raw: Variant = (payload as Dictionary).get("page", null)
	if typeof(page_raw) == TYPE_DICTIONARY:
		var page: MapPage = MapPage.from_dict(page_raw)
		page.id = map_id
		_project.write_map_page(page)
		var tileset_ids: Array[String] = page.tilesets_used()
		for ts_id: String in tileset_ids:
			if not FileAccess.file_exists(_project.tileset_manifest_path(ts_id)):
				request_tileset(ts_id)
		AppState.apply_remote_map_page_snapshot(page)
	_map_request_outstanding.erase(map_id)


func _handle_tileset_request(from_network_id: int, payload: Variant) -> void:
	if _project == null or _active_adapter == null or typeof(payload) != TYPE_DICTIONARY:
		return
	var tileset_id: String = String((payload as Dictionary).get("tileset_id", ""))
	var ts: TileSetResource = _project.read_tileset(tileset_id)
	if ts == null:
		_active_adapter.send_to_peer(from_network_id, NetworkMessage.KIND_TILESET_RESPONSE, {"tileset_id": tileset_id, "missing": true})
		return
	_active_adapter.send_to_peer(from_network_id, NetworkMessage.KIND_TILESET_RESPONSE, {
		"tileset_id": tileset_id,
		"tileset": ts.to_dict(),
	})
	if ts.image_asset_name != "" and _asset_transfer != null:
		var asset_name: String = AssetTransferService.make_tileset_asset_name(ts.id, ts.image_asset_name)
		_asset_transfer.handle_query_request(from_network_id, [asset_name])


func _handle_tileset_response(_from_network_id: int, payload: Variant) -> void:
	if _project == null or typeof(payload) != TYPE_DICTIONARY:
		return
	var tileset_id: String = String((payload as Dictionary).get("tileset_id", ""))
	if (payload as Dictionary).get("missing", false):
		_tileset_request_outstanding.erase(tileset_id)
		return
	var ts_raw: Variant = (payload as Dictionary).get("tileset", null)
	if typeof(ts_raw) == TYPE_DICTIONARY:
		var ts: TileSetResource = TileSetResource.from_dict(ts_raw)
		_project.write_tileset(ts)
		if ts.image_asset_name != "" and _asset_transfer != null:
			var asset_name: String = AssetTransferService.make_tileset_asset_name(ts.id, ts.image_asset_name)
			if not _asset_transfer.has_local_asset(asset_name):
				_asset_transfer.request_unknown_assets([asset_name], NetworkAdapter.HOST_NETWORK_ID)
		AppState.notify_tileset_received(tileset_id)
	_tileset_request_outstanding.erase(tileset_id)


func _request_root_board_if_missing() -> void:
	if _project == null or _is_session_host:
		return
	var root_id: String = _project.root_board_id
	if root_id == "":
		return
	var board_path: String = _project.board_path(root_id)
	if FileAccess.file_exists(board_path):
		return
	request_board(root_id)


func _handle_presence(_from_network_id: int, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var d: Dictionary = payload
	var stable_id: String = String(d.get("stable_id", ""))
	if stable_id == "":
		return
	var state: PresenceState = _presence_by_stable_id.get(stable_id, null) as PresenceState
	if state == null:
		state = PresenceState.new()
		state.stable_id = stable_id
		state.network_id = int(d.get("network_id", 0))
		state.avatar_color = PeerIdentity.color_for_stable_id(stable_id)
	state.merge_from_dict(d)
	_presence_by_stable_id[stable_id] = state
	emit_signal("presence_updated", stable_id)


func _handle_heartbeat(from_network_id: int, _payload: Variant) -> void:
	var stable_id: String = String(_network_id_to_stable_id.get(from_network_id, ""))
	if stable_id == "":
		return
	var state: PresenceState = _presence_by_stable_id.get(stable_id, null) as PresenceState
	if state != null:
		state.last_heartbeat_ms = Time.get_ticks_msec()


func _handle_ping_marker(_from_network_id: int, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var d: Dictionary = payload
	var pos_raw: Variant = d.get("world_pos", null)
	if typeof(pos_raw) != TYPE_ARRAY or (pos_raw as Array).size() < 2:
		return
	var color_raw: Variant = d.get("color", null)
	var color: Color = Color(0.78, 0.84, 0.95, 1.0)
	if typeof(color_raw) == TYPE_ARRAY and (color_raw as Array).size() >= 3:
		var arr: Array = color_raw
		var a: float = 1.0 if arr.size() < 4 else float(arr[3])
		color = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
	emit_signal("ping_marker_received", Vector2(float(pos_raw[0]), float(pos_raw[1])), color, String(d.get("stable_id", "")))


func _handle_editing_lock(_from_network_id: int, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var item_id: String = String((payload as Dictionary).get("item_id", ""))
	var stable_id: String = String((payload as Dictionary).get("stable_id", ""))
	if item_id == "" or stable_id == "":
		return
	_editing_locks[item_id] = {"stable_id": stable_id, "ts_ms": Time.get_ticks_msec()}
	emit_signal("editing_lock_changed", item_id, stable_id)


func _handle_editing_unlock(_from_network_id: int, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var item_id: String = String((payload as Dictionary).get("item_id", ""))
	if item_id == "":
		return
	_editing_locks.erase(item_id)
	emit_signal("editing_lock_changed", item_id, "")


func _handle_board_hash(_from_network_id: int, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY or _project == null:
		return
	var board_id: String = String((payload as Dictionary).get("board_id", ""))
	var remote_hash: String = String((payload as Dictionary).get("hash", ""))
	if board_id == "" or remote_hash == "":
		return
	var local_hash: String = _compute_board_hash(board_id)
	if local_hash != remote_hash and _is_session_host == false:
		request_board(board_id)


func _handle_desync_resync(_from_network_id: int, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var board_id: String = String((payload as Dictionary).get("board_id", ""))
	if board_id != "":
		request_board(board_id)


func _handle_kick(payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var stable_id: String = String((payload as Dictionary).get("stable_id", ""))
	if stable_id == KeypairService.stable_id():
		leave_session()


func _handle_asset_chunk(from_network_id: int, payload: Variant) -> void:
	if _asset_transfer == null or typeof(payload) != TYPE_DICTIONARY:
		return
	var result: Dictionary = _asset_transfer.handle_chunk(from_network_id, payload)
	if bool(result.get("completed", false)):
		_notify_asset_received(String(result.get("asset_name", "")))


func _send_hello_to_host() -> void:
	if _active_adapter == null or _active_adapter.local_peer_identity == null:
		return
	var local_ident: PeerIdentity = _active_adapter.local_peer_identity
	_active_adapter.send_to_peer(NetworkAdapter.HOST_NETWORK_ID, NetworkMessage.KIND_HELLO, {
		"identity": local_ident.to_dict(),
		"adapter_kind": _active_adapter.adapter_kind(),
	})


func _push_board_snapshot_to(to_network_id: int, board_id: String) -> void:
	if _project == null or _active_adapter == null or board_id == "":
		return
	var board: Board = _project.read_board(board_id)
	if board == null:
		return
	OpBus.oplog().ensure_loaded(board_id)
	var clock: VectorClock = OpBus.oplog().vector_clock_for_board(board_id)
	_active_adapter.send_to_peer(to_network_id, NetworkMessage.KIND_BOARD_RESPONSE, {
		"board_id": board_id,
		"board": board.to_dict(),
		"clock": clock.to_dict(),
	})


func _send_hello_ack(to_network_id: int, _peer_ident: PeerIdentity) -> void:
	if _active_adapter == null:
		return
	var manifest_dict: Dictionary = _manifest.to_dict() if _manifest != null else {}
	var project_manifest: Dictionary = {}
	if _project != null:
		project_manifest = {
			"id": _project.id,
			"name": _project.name,
			"root_board_id": _project.root_board_id,
			"board_index": _project.board_index.duplicate(true),
			"map_page_index": _project.map_page_index.duplicate(true),
			"tileset_index": _project.tileset_index.duplicate(true),
		}
	_active_adapter.send_to_peer(to_network_id, NetworkMessage.KIND_HELLO_ACK, {
		"manifest": manifest_dict,
		"project_manifest": project_manifest,
	})


func _send_roster(to_network_id: int) -> void:
	if _active_adapter == null:
		return
	var members: Array = []
	for peer_v: Variant in _peers_by_network_id.values():
		if peer_v is PeerIdentity:
			members.append((peer_v as PeerIdentity).to_dict())
	_active_adapter.send_to_peer(to_network_id, NetworkMessage.KIND_ROSTER, {"members": members})


func _send_vector_clock_offers_for_all_boards() -> void:
	if _project == null or _active_adapter == null or OpBus.oplog() == null:
		return
	for board_id: String in OpBus.oplog().all_known_boards():
		OpBus.oplog().ensure_loaded(board_id)
		var clock: VectorClock = OpBus.oplog().vector_clock_for_board(board_id)
		_active_adapter.send_to_peer(NetworkAdapter.HOST_NETWORK_ID, NetworkMessage.KIND_VECTOR_CLOCK_OFFER, {
			"board_id": board_id,
			"clock": clock.to_dict(),
		})


func _replay_missing_manifest_ops(remote_manifest: ParticipantsManifest) -> void:
	for op_raw_v: Variant in remote_manifest.ops_log:
		if typeof(op_raw_v) != TYPE_DICTIONARY:
			continue
		var op: Op = Op.from_dict(op_raw_v)
		if op.op_id == "":
			continue
		if OpBus.has_seen(op.op_id):
			continue
		OpBus.ingest_remote(op)


func _on_presence_send_tick() -> void:
	if not is_in_session() or _active_adapter == null or _local_presence == null:
		return
	_local_presence.cursor_world = _last_cursor_world
	_local_presence.has_cursor = _has_cursor
	_local_presence.selection_world_rect = _last_selection_rect
	_local_presence.has_selection_rect = _has_selection_rect
	_local_presence.viewport_world_rect = _last_viewport_rect
	_local_presence.has_viewport_rect = _has_viewport_rect
	_local_presence.role = _local_role
	_local_presence.hosting = _is_session_host
	_local_presence.editing_lock_item_ids = PackedStringArray(_editing_locks_local)
	if AppState.current_board != null:
		_local_presence.board_id = AppState.current_board.id
	_local_presence.last_heartbeat_ms = Time.get_ticks_msec()
	_active_adapter.send_to_all(NetworkMessage.KIND_PRESENCE, _local_presence.to_dict())


func _on_heartbeat_tick() -> void:
	if not is_in_session() or _active_adapter == null:
		return
	_active_adapter.send_to_all(NetworkMessage.KIND_HEARTBEAT, {"stable_id": KeypairService.stable_id()})


func _on_presence_scrub() -> void:
	var stale_ids: Array[String] = []
	for stable_id: String in _presence_by_stable_id.keys():
		var state: PresenceState = _presence_by_stable_id[stable_id] as PresenceState
		if state == null or stable_id == KeypairService.stable_id():
			continue
		if state.is_stale():
			stale_ids.append(stable_id)
	for stable_id: String in stale_ids:
		_presence_by_stable_id.erase(stable_id)
		emit_signal("presence_removed", stable_id)
	var stale_locks: Array[String] = []
	for item_id: String in _editing_locks.keys():
		var entry: Dictionary = _editing_locks[item_id] as Dictionary
		var lock_stable: String = String(entry.get("stable_id", ""))
		if lock_stable == "" or lock_stable == KeypairService.stable_id():
			continue
		var holder_present: bool = _presence_by_stable_id.has(lock_stable)
		if not holder_present:
			stale_locks.append(item_id)
	for item_id: String in stale_locks:
		_editing_locks.erase(item_id)
		emit_signal("editing_lock_changed", item_id, "")


func _broadcast_board_hash(board_id: String) -> void:
	if board_id == "" or _active_adapter == null:
		return
	var hash_value: String = _compute_board_hash(board_id)
	_active_adapter.send_to_all(NetworkMessage.KIND_BOARD_HASH, {"board_id": board_id, "hash": hash_value})


func _compute_board_hash(board_id: String) -> String:
	if _project == null:
		return ""
	var b: Board = _project.read_board(board_id)
	if b == null:
		return ""
	var raw: String = JSON.stringify(b.to_dict(), "", true, true)
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(raw.to_utf8_buffer())
	var bytes: PackedByteArray = ctx.finish()
	var out: String = ""
	for b2: int in bytes:
		out += "%02x" % int(b2)
	return out


func _relay_op_to_others(op: Op, original_sender_network_id: int) -> void:
	if _active_adapter == null:
		return
	for nid_v: Variant in _peers_by_network_id.keys():
		var nid: int = int(nid_v)
		if nid == original_sender_network_id:
			continue
		if nid == local_network_id():
			continue
		_active_adapter.send_to_peer(nid, NetworkMessage.KIND_OP, op.to_dict())


func _release_locks_for(stable_id: String) -> void:
	if stable_id == "":
		return
	var to_release: Array[String] = []
	for item_id: String in _editing_locks.keys():
		var entry: Dictionary = _editing_locks[item_id] as Dictionary
		if String(entry.get("stable_id", "")) == stable_id:
			to_release.append(item_id)
	for item_id: String in to_release:
		_editing_locks.erase(item_id)
		emit_signal("editing_lock_changed", item_id, "")


func _resolve_role_for(stable_id: String) -> String:
	if _manifest == null:
		return ROLE_OWNER
	if not _manifest.has_participant(stable_id):
		return ROLE_GUEST
	return _manifest.role_of(stable_id)


func _apply_project_property(key: String, value: Variant) -> void:
	if _project == null:
		return
	match key:
		"name":
			_project.name = String(value)
			_project.write_manifest()
		"discovery_enabled":
			_project.discovery_enabled = bool(value)
			_project.write_manifest()
			var root: Node = get_tree().root if get_tree() != null else null
			if root != null and root.has_node("SteamPresenceService"):
				SteamPresenceService.notify_project_discovery_changed()


func set_project_discovery_enabled(enabled: bool) -> Op:
	return set_project_property("discovery_enabled", enabled)


func project_discovery_enabled() -> bool:
	if _project == null:
		return true
	return _project.discovery_enabled


func _set_state(state: int) -> void:
	if _state == state:
		return
	_state = state
	emit_signal("session_state_changed", state)


func _log_error(message: String) -> void:
	push_error("MultiplayerService: %s" % message)
	emit_signal("session_log", "error", message)


func _send_to_peer_proxy(peer_network_id: int, kind: String, payload: Variant) -> void:
	if _active_adapter == null:
		return
	_active_adapter.send_to_peer(peer_network_id, kind, payload)


func _collect_asset_names_from_board(board: Board) -> Array:
	var out: Array = []
	if board.background_image_asset != "":
		out.append(board.background_image_asset)
	for d_v: Variant in board.items:
		if typeof(d_v) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = d_v
		for key: String in ["asset_name", "background_image_asset", "image_asset", "sound_asset"]:
			if d.has(key):
				out.append(String(d[key]))
	return out


func _notify_asset_received(asset_name: String) -> void:
	if _editor != null and _editor.has_method("on_asset_streamed"):
		_editor.call("on_asset_streamed", asset_name)
	if asset_name.begins_with(AssetTransferService.TILESET_PREFIX):
		var rest: String = asset_name.substr(AssetTransferService.TILESET_PREFIX.length())
		var slash_idx: int = rest.find("/")
		if slash_idx > 0:
			var tileset_id: String = rest.substr(0, slash_idx)
			AppState.notify_tileset_received(tileset_id)


func _start_client_merge_session() -> void:
	if _project == null or OpBus.oplog() == null:
		_send_vector_clock_offers_for_all_boards()
		return
	if _merge_session != null:
		return
	_merge_session = MergeSession.new(_project)
	_merge_session.preflight_request_ready.connect(_on_merge_preflight_request_ready)
	_merge_session.dialog_show_requested.connect(_on_merge_dialog_show_requested)
	_merge_session.dialog_close_requested.connect(_on_merge_dialog_close_requested)
	_merge_session.finalize_ready.connect(_on_merge_finalize_ready)
	_merge_session.merge_completed.connect(_on_merge_session_completed)
	_merge_session.merge_aborted.connect(_on_merge_session_aborted)
	_merge_session.begin()


func _on_merge_preflight_request_ready(payload: Dictionary) -> void:
	if _active_adapter == null:
		return
	_active_adapter.send_to_peer(NetworkAdapter.HOST_NETWORK_ID, NetworkMessage.KIND_MERGE_PREFLIGHT, payload)


func _on_merge_dialog_show_requested(conflicts: Array, non_conflicting_local_count: int, non_conflicting_remote_count: int, host_display_name: String) -> void:
	emit_signal("merge_dialog_requested", conflicts, non_conflicting_local_count, non_conflicting_remote_count, host_display_name)


func _on_merge_dialog_close_requested() -> void:
	emit_signal("merge_dialog_close_requested")


func _on_merge_finalize_ready(payload: Dictionary) -> void:
	if _active_adapter == null:
		return
	_active_adapter.send_to_peer(NetworkAdapter.HOST_NETWORK_ID, NetworkMessage.KIND_MERGE_FINALIZE, payload)


func _on_merge_session_completed(_report_id: String) -> void:
	_merge_session = null


func _on_merge_session_aborted(reason: String) -> void:
	_merge_session = null
	_log_error("Merge aborted: %s" % reason)
	if reason == "user_cancelled":
		leave_session()


func handle_merge_user_resolution(resolved_conflicts: Array) -> void:
	if _merge_session == null:
		return
	_merge_session.handle_user_resolution(resolved_conflicts)


func handle_merge_user_cancel() -> void:
	if _merge_session == null:
		return
	_merge_session.cancel()


func set_merge_broadcast_suppressed(suppressed: bool) -> void:
	_suppress_local_op_broadcast = suppressed


func _handle_merge_preflight(from_network_id: int, payload: Variant) -> void:
	if not _is_session_host:
		return
	if typeof(payload) != TYPE_DICTIONARY:
		return
	if OpBus.oplog() == null:
		return
	var boards_raw: Variant = (payload as Dictionary).get("boards", {})
	if typeof(boards_raw) != TYPE_DICTIONARY:
		return
	var client_boards: Dictionary = boards_raw
	var oplog: OpLog = OpBus.oplog()
	var board_keys: Dictionary = {}
	for board_id_v: Variant in client_boards.keys():
		board_keys[String(board_id_v)] = true
	for known_board: String in oplog.all_known_boards():
		board_keys[known_board] = true
	var response_boards: Dictionary = {}
	for board_id: String in board_keys.keys():
		oplog.ensure_loaded(board_id)
		var host_clock: VectorClock = oplog.vector_clock_for_board(board_id)
		var client_clock_raw: Variant = client_boards.get(board_id, {})
		var client_clock: VectorClock = VectorClock.from_dict(client_clock_raw)
		var diff: Dictionary = host_clock.difference_to_send(client_clock)
		var missing: Array = []
		for stable_id: String in diff.keys():
			var range_d: Dictionary = diff[stable_id]
			var seq_from: int = int(range_d.get("from", 1))
			var seq_to: int = int(range_d.get("to", 1))
			var ops: Array = oplog.ops_in_range(board_id, stable_id, seq_from, seq_to)
			for op_v: Variant in ops:
				if op_v is Op:
					missing.append((op_v as Op).to_dict())
		response_boards[board_id] = {
			"host_clock": host_clock.to_dict(),
			"missing_for_client": missing,
		}
	_active_adapter.send_to_peer(from_network_id, NetworkMessage.KIND_MERGE_PREFLIGHT_RESPONSE, {
		"host_display_name": KeypairService.display_name(),
		"boards": response_boards,
	})


func _handle_merge_preflight_response(_from_network_id: int, payload: Variant) -> void:
	if _merge_session == null:
		return
	if typeof(payload) != TYPE_DICTIONARY:
		return
	_merge_session.handle_preflight_response(payload)


func _handle_merge_finalize(from_network_id: int, payload: Variant) -> void:
	if not _is_session_host:
		return
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var d: Dictionary = payload
	var report_id: String = String(d.get("report_id", ""))
	if report_id == "":
		return
	var ops_raw: Variant = d.get("ops_to_apply", [])
	var entries_raw: Variant = d.get("entries", [])
	var ledger_entries: Array = []
	if typeof(ops_raw) == TYPE_ARRAY:
		for op_dict_v: Variant in (ops_raw as Array):
			if typeof(op_dict_v) != TYPE_DICTIONARY:
				continue
			var op: Op = Op.from_dict(op_dict_v)
			if op.op_id == "":
				continue
			if OpBus.has_seen(op.op_id):
				continue
			var pre_state: Dictionary = _capture_pre_state_for_op(op)
			OpBus.ingest_remote(op)
			_relay_op_to_others(op, from_network_id)
			ledger_entries.append({
				"op_id": op.op_id,
				"kind": op.kind,
				"board_id": op.board_id,
				"payload": op.payload.duplicate(true),
				"pre_state": pre_state,
			})
	_host_merge_ledger[report_id] = ledger_entries
	var entries_array: Array = (entries_raw as Array).duplicate(true) if typeof(entries_raw) == TYPE_ARRAY else []
	var kept_local: int = int(d.get("kept_local_count", 0))
	var kept_host: int = int(d.get("kept_host_count", 0))
	if entries_array.is_empty() and kept_local == 0 and kept_host == 0:
		_host_merge_ledger.erase(report_id)
		return
	var report: Dictionary = {
		"report_id": report_id,
		"author_display_name": String(d.get("author_display_name", "")),
		"author_stable_id": String(d.get("author_stable_id", "")),
		"origin_unix": int(d.get("origin_unix", Time.get_unix_time_from_system())),
		"kept_local_count": kept_local,
		"kept_host_count": kept_host,
		"auto_merged_count": int(d.get("auto_merged_count", 0)),
		"entries": entries_array,
	}
	emit_signal("merge_report_received", report)


func handle_host_rollback_individual(report_id: String, op_id: String) -> void:
	if not _is_session_host:
		return
	if not _host_merge_ledger.has(report_id):
		return
	var entries: Array = _host_merge_ledger[report_id] as Array
	for entry_v: Variant in entries:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		if String(entry.get("op_id", "")) != op_id:
			continue
		if bool(entry.get("rolled_back", false)):
			return
		_emit_rollback_for_entry(entry)
		entry["rolled_back"] = true
		emit_signal("merge_report_entry_rolled_back", report_id, op_id)
		return


func handle_host_rollback_all(report_id: String) -> void:
	if not _is_session_host:
		return
	if not _host_merge_ledger.has(report_id):
		return
	var entries: Array = _host_merge_ledger[report_id] as Array
	for i in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[i] as Dictionary
		if bool(entry.get("rolled_back", false)):
			continue
		_emit_rollback_for_entry(entry)
		entry["rolled_back"] = true
	emit_signal("merge_report_fully_rolled_back", report_id)


func handle_host_dismiss_report(report_id: String) -> void:
	_host_merge_ledger.erase(report_id)


func _capture_pre_state_for_op(op: Op) -> Dictionary:
	if _project == null:
		return {}
	var board_id: String = op.board_id
	if board_id == "":
		return {}
	var board: Board = _project.read_board(board_id)
	if board == null:
		return {}
	match op.kind:
		OpKinds.SET_ITEM_PROPERTY:
			var iid: String = String(op.payload.get("item_id", ""))
			var pkey: String = String(op.payload.get("key", ""))
			for d_v: Variant in board.items:
				if typeof(d_v) != TYPE_DICTIONARY:
					continue
				if String((d_v as Dictionary).get("id", "")) != iid:
					continue
				return {"prior_value": (d_v as Dictionary).get(pkey, null), "had_key": (d_v as Dictionary).has(pkey)}
		OpKinds.MOVE_ITEMS:
			var entries_raw: Variant = op.payload.get("entries", [])
			var prior: Array = []
			if typeof(entries_raw) == TYPE_ARRAY:
				for e_v: Variant in (entries_raw as Array):
					if typeof(e_v) != TYPE_DICTIONARY:
						continue
					var eid: String = String((e_v as Dictionary).get("id", ""))
					for d_v: Variant in board.items:
						if typeof(d_v) != TYPE_DICTIONARY:
							continue
						if String((d_v as Dictionary).get("id", "")) != eid:
							continue
						var pos_raw: Variant = (d_v as Dictionary).get("position", [0, 0])
						prior.append({"id": eid, "to": pos_raw})
						break
			return {"entries": prior}
		OpKinds.DELETE_ITEM:
			var did: String = String(op.payload.get("item_id", ""))
			for d_v: Variant in board.items:
				if typeof(d_v) == TYPE_DICTIONARY and String((d_v as Dictionary).get("id", "")) == did:
					return {"item_dict": (d_v as Dictionary).duplicate(true)}
		OpKinds.CREATE_ITEM:
			var item_dict_raw: Variant = op.payload.get("item_dict", null)
			if typeof(item_dict_raw) == TYPE_DICTIONARY:
				return {"item_id": String((item_dict_raw as Dictionary).get("id", ""))}
		OpKinds.SET_CONNECTION_PROPERTY:
			var cid_s: String = String(op.payload.get("connection_id", ""))
			var ckey: String = String(op.payload.get("key", ""))
			for c_v: Variant in board.connections:
				if typeof(c_v) == TYPE_DICTIONARY and String((c_v as Dictionary).get("id", "")) == cid_s:
					return {"prior_value": (c_v as Dictionary).get(ckey, null)}
		OpKinds.DELETE_CONNECTION:
			var cid_d: String = String(op.payload.get("connection_id", ""))
			for c_v: Variant in board.connections:
				if typeof(c_v) == TYPE_DICTIONARY and String((c_v as Dictionary).get("id", "")) == cid_d:
					return {"connection_dict": (c_v as Dictionary).duplicate(true)}
		OpKinds.CREATE_CONNECTION:
			var conn_dict_raw: Variant = op.payload.get("connection_dict", null)
			if typeof(conn_dict_raw) == TYPE_DICTIONARY:
				return {"connection_id": String((conn_dict_raw as Dictionary).get("id", ""))}
		OpKinds.SET_BOARD_PROPERTY:
			var bkey: String = String(op.payload.get("key", ""))
			match bkey:
				"name":
					return {"prior_value": board.name}
				"background_image_asset":
					return {"prior_value": board.background_image_asset}
				"background_image_mode":
					return {"prior_value": board.background_image_mode}
				"background_color_override":
					var bc: Color = board.background_color_override
					return {"prior_value": [bc.r, bc.g, bc.b, bc.a]}
				"parent_board_id":
					return {"prior_value": board.parent_board_id}
	return {}


func _emit_rollback_for_entry(entry: Dictionary) -> void:
	var kind: String = String(entry.get("kind", ""))
	var board_id: String = String(entry.get("board_id", ""))
	var pre_state: Dictionary = entry.get("pre_state", {}) as Dictionary
	var payload: Dictionary = entry.get("payload", {}) as Dictionary
	match kind:
		OpKinds.SET_ITEM_PROPERTY:
			OpBus.emit_local(OpKinds.SET_ITEM_PROPERTY, {
				"item_id": payload.get("item_id", ""),
				"key": payload.get("key", ""),
				"value": pre_state.get("prior_value", null),
			}, board_id)
		OpKinds.MOVE_ITEMS:
			OpBus.emit_local(OpKinds.MOVE_ITEMS, {"entries": pre_state.get("entries", [])}, board_id)
		OpKinds.DELETE_ITEM:
			var item_dict: Dictionary = pre_state.get("item_dict", {}) as Dictionary
			if not item_dict.is_empty():
				OpBus.emit_local(OpKinds.CREATE_ITEM, {"item_dict": item_dict}, board_id)
		OpKinds.CREATE_ITEM:
			OpBus.emit_local(OpKinds.DELETE_ITEM, {"item_id": pre_state.get("item_id", "")}, board_id)
		OpKinds.SET_CONNECTION_PROPERTY:
			OpBus.emit_local(OpKinds.SET_CONNECTION_PROPERTY, {
				"connection_id": payload.get("connection_id", ""),
				"key": payload.get("key", ""),
				"value": pre_state.get("prior_value", null),
			}, board_id)
		OpKinds.DELETE_CONNECTION:
			var conn_dict: Dictionary = pre_state.get("connection_dict", {}) as Dictionary
			if not conn_dict.is_empty():
				OpBus.emit_local(OpKinds.CREATE_CONNECTION, {"connection_dict": conn_dict}, board_id)
		OpKinds.CREATE_CONNECTION:
			OpBus.emit_local(OpKinds.DELETE_CONNECTION, {"connection_id": pre_state.get("connection_id", "")}, board_id)
		OpKinds.SET_BOARD_PROPERTY:
			OpBus.emit_local(OpKinds.SET_BOARD_PROPERTY, {
				"key": payload.get("key", ""),
				"value": pre_state.get("prior_value", null),
			}, board_id)
		_:
			_log_error("Rollback unsupported for kind %s" % kind)
