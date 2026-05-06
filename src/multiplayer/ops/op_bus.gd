extends Node

signal local_op_emitted(op: Op)
signal remote_op_applied(op: Op)
signal op_rejected(op: Op, reason: String)
signal lamport_advanced(value: int)

var _project: Project = null
var _oplog: OpLog = null
var _applier: OpApplier = null
var _lamport_clock: int = 0
var _editor: Node = null
var _seen_op_ids: Dictionary = {}
var _suppress_local_apply: bool = false


func bind_project(project: Project) -> void:
	if _project == project:
		return
	_project = project
	if project == null:
		_oplog = null
		_applier = null
		_lamport_clock = 0
		_seen_op_ids.clear()
		return
	_oplog = OpLog.new(project)
	_applier = OpApplier.new(project)
	_seen_op_ids.clear()
	_lamport_clock = 0
	for board_id: String in _oplog.all_known_boards():
		_oplog.ensure_loaded(board_id)
		var bm: int = _oplog.lamport_max_for_board(board_id)
		if bm > _lamport_clock:
			_lamport_clock = bm
	emit_signal("lamport_advanced", _lamport_clock)


func unbind_project() -> void:
	bind_project(null)


func bind_editor(editor: Node) -> void:
	_editor = editor


func unbind_editor() -> void:
	_editor = null


func current_project() -> Project:
	return _project


func oplog() -> OpLog:
	return _oplog


func applier() -> OpApplier:
	return _applier


func lamport() -> int:
	return _lamport_clock


func observe_lamport(value: int) -> void:
	if value <= _lamport_clock:
		return
	_lamport_clock = value
	emit_signal("lamport_advanced", _lamport_clock)


func tick_lamport() -> int:
	_lamport_clock += 1
	emit_signal("lamport_advanced", _lamport_clock)
	return _lamport_clock


func emit_local(kind: String, payload: Dictionary, board_id: String = "", inverse_payload: Dictionary = {}) -> Op:
	return _emit_local(kind, payload, board_id, inverse_payload, false)


func record_local_change(kind: String, payload: Dictionary, board_id: String = "", inverse_payload: Dictionary = {}) -> Op:
	return _emit_local(kind, payload, board_id, inverse_payload, true)


func _emit_local(kind: String, payload: Dictionary, board_id: String, inverse_payload: Dictionary, skip_local_apply: bool) -> Op:
	if _project == null:
		return null
	var op: Op = Op.make(kind, payload, _resolve_board_id(kind, board_id))
	if inverse_payload != null and not inverse_payload.is_empty():
		op.inverse_payload = inverse_payload.duplicate(true)
	op.lamport_ts = tick_lamport()
	if _has_multiplayer_service():
		op.author_network_id = MultiplayerService.local_network_id()
		if MultiplayerService.is_session_guest() and not OpKinds.is_owner_only(kind):
			op.set_flag(Op.FLAG_EPHEMERAL_GUEST, true)
	else:
		op.author_network_id = 1
	_authenticate_local(op)
	_record_seen(op.op_id)
	if _oplog != null:
		_oplog.append(op)
	if not skip_local_apply and not _suppress_local_apply:
		_apply_locally(op)
	emit_signal("local_op_emitted", op)
	return op


func ingest_remote(op: Op) -> bool:
	if _project == null or op == null:
		return false
	if has_seen(op.op_id):
		return false
	if not _verify_remote(op):
		emit_signal("op_rejected", op, "signature_invalid")
		return false
	if MultiplayerService.is_op_authorized(op):
		observe_lamport(op.lamport_ts)
		if _oplog != null:
			_oplog.append(op)
		_record_seen(op.op_id)
		_apply_remote(op)
		emit_signal("remote_op_applied", op)
		return true
	emit_signal("op_rejected", op, "permission_denied")
	return false


func has_seen(op_id: String) -> bool:
	if _seen_op_ids.has(op_id):
		return true
	if _oplog != null and _oplog.has_op(op_id):
		return true
	return false


func suppress_local_apply(suppress: bool) -> void:
	_suppress_local_apply = suppress


func mark_already_applied(op: Op) -> void:
	_record_seen(op.op_id)
	if _oplog != null:
		_oplog.append(op)


func replay_op_locally(op: Op) -> bool:
	if op == null or _applier == null:
		return false
	op.set_flag(Op.FLAG_REPLAY, true)
	return _apply_remote(op)


func _resolve_board_id(kind: String, board_id: String) -> String:
	var scope: String = OpKinds.scope_for_kind(kind)
	if scope == OpKinds.SCOPE_BOARD:
		if board_id != "":
			return board_id
		if AppState.current_board != null:
			return AppState.current_board.id
	return ""


func _authenticate_local(op: Op) -> void:
	KeypairService.ensure_ready()
	op.author_stable_id = KeypairService.stable_id()
	op.author_display_name = KeypairService.display_name()
	op.public_key_hex = KeypairService.public_key_pem()
	KeypairService.sign_op(op)


func _verify_remote(op: Op) -> bool:
	if op.public_key_hex == "":
		return false
	if op.author_stable_id == "":
		return false
	var participant_pem: String = MultiplayerService.public_key_for_stable_id(op.author_stable_id)
	var pem_to_use: String = participant_pem if participant_pem != "" else op.public_key_hex
	if participant_pem != "" and participant_pem != op.public_key_hex:
		return false
	return KeypairService.verify_op(op, pem_to_use)


func _apply_locally(op: Op) -> void:
	if _applier == null:
		return
	var was_emitted_by_editor: bool = false
	if _editor != null and _editor.has_method("apply_op_locally_through_editor"):
		was_emitted_by_editor = bool(_editor.call("apply_op_locally_through_editor", op))
	if not was_emitted_by_editor:
		_applier.apply_to_project(op)


func _apply_remote(op: Op) -> bool:
	if _applier == null:
		return false
	if op.scope == OpKinds.SCOPE_MANIFEST:
		MultiplayerService.apply_manifest_op(op)
		return true
	var on_current_board: bool = AppState.current_project != null and AppState.current_board != null and op.board_id == AppState.current_board.id
	if on_current_board and _editor != null and _editor.has_method("apply_remote_op"):
		_editor.call("apply_remote_op", op)
		return true
	var result: Dictionary = _applier.apply_to_project(op)
	return bool(result.get("applied", false))


func _record_seen(op_id: String) -> void:
	_seen_op_ids[op_id] = true


func _has_multiplayer_service() -> bool:
	var root: Node = get_tree().root
	return root != null and root.has_node("MultiplayerService")
