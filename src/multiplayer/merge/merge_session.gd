class_name MergeSession
extends RefCounted

signal preflight_request_ready(payload: Dictionary)
signal finalize_ready(payload: Dictionary)
signal merge_completed(report_id: String)
signal merge_aborted(reason: String)
signal dialog_show_requested(conflicts: Array, non_conflicting_local_count: int, non_conflicting_remote_count: int, host_display_name: String)
signal dialog_close_requested()

const STATE_IDLE: int = 0
const STATE_PREFLIGHT_PENDING: int = 1
const STATE_ANALYZING: int = 2
const STATE_AWAITING_USER: int = 3
const STATE_APPLYING: int = 4
const STATE_DONE: int = 5
const STATE_CANCELLED: int = 6

var _state: int = STATE_IDLE
var _project: Project = null
var _host_display_name: String = ""
var _board_clocks_at_start: Dictionary = {}
var _local_diff_ops: Dictionary = {}
var _remote_response_payload: Dictionary = {}
var _conflicts: Array = []
var _non_conflicting_local: Array = []
var _non_conflicting_remote: Array = []
var _report_id: String = ""


func _init(project: Project) -> void:
	_project = project


func current_state() -> int:
	return _state


func is_active() -> bool:
	return _state != STATE_IDLE and _state != STATE_DONE and _state != STATE_CANCELLED


func begin() -> void:
	if _project == null or OpBus.oplog() == null:
		emit_signal("merge_aborted", "no_project")
		_state = STATE_CANCELLED
		return
	_board_clocks_at_start.clear()
	_local_diff_ops.clear()
	_conflicts.clear()
	_non_conflicting_local.clear()
	_non_conflicting_remote.clear()
	_report_id = ""
	var oplog: OpLog = OpBus.oplog()
	var board_clocks_payload: Dictionary = {}
	for board_id: String in oplog.all_known_boards():
		oplog.ensure_loaded(board_id)
		var clock: VectorClock = oplog.vector_clock_for_board(board_id)
		_board_clocks_at_start[board_id] = clock
		board_clocks_payload[board_id] = clock.to_dict()
	_state = STATE_PREFLIGHT_PENDING
	emit_signal("preflight_request_ready", {"boards": board_clocks_payload})


func handle_preflight_response(payload: Dictionary) -> void:
	if _state != STATE_PREFLIGHT_PENDING:
		return
	_state = STATE_ANALYZING
	_host_display_name = String(payload.get("host_display_name", ""))
	_remote_response_payload = payload.duplicate(true)
	var boards_raw: Variant = payload.get("boards", {})
	if typeof(boards_raw) != TYPE_DICTIONARY:
		_abort("malformed_response")
		return
	var boards: Dictionary = boards_raw
	var local_diff_total: Array = []
	var remote_diff_total: Array = []
	for board_id_v: Variant in boards.keys():
		var board_id: String = String(board_id_v)
		var board_block: Dictionary = boards[board_id_v] as Dictionary
		var host_clock_raw: Variant = board_block.get("host_clock", {})
		var host_clock: VectorClock = VectorClock.from_dict(host_clock_raw)
		var local_diff: Array = _local_ops_missing_from_host(board_id, host_clock)
		_local_diff_ops[board_id] = local_diff
		for op in local_diff:
			local_diff_total.append(op)
		var remote_ops_raw: Variant = board_block.get("missing_for_client", [])
		if typeof(remote_ops_raw) == TYPE_ARRAY:
			for op_raw_v: Variant in (remote_ops_raw as Array):
				if typeof(op_raw_v) != TYPE_DICTIONARY:
					continue
				var remote_op: Op = Op.from_dict(op_raw_v)
				if remote_op.op_id == "" or OpBus.has_seen(remote_op.op_id):
					continue
				remote_diff_total.append(remote_op)
	var analysis: Dictionary = MergeAnalyzer.analyze(local_diff_total, remote_diff_total)
	_conflicts = analysis.get("conflicts", []) as Array
	_non_conflicting_local = analysis.get("non_conflicting_local", []) as Array
	_non_conflicting_remote = analysis.get("non_conflicting_remote", []) as Array
	if _conflicts.is_empty():
		_apply_no_conflict_merge()
		return
	_state = STATE_AWAITING_USER
	emit_signal("dialog_show_requested", _conflicts, _non_conflicting_local.size(), _non_conflicting_remote.size(), _host_display_name)


func handle_user_resolution(resolved_conflicts: Array) -> void:
	if _state != STATE_AWAITING_USER:
		return
	_conflicts = resolved_conflicts
	_apply_resolutions()


func cancel() -> void:
	if not is_active():
		return
	_state = STATE_CANCELLED
	emit_signal("dialog_close_requested")
	emit_signal("merge_aborted", "user_cancelled")


func _apply_no_conflict_merge() -> void:
	_state = STATE_APPLYING
	MultiplayerService.set_merge_broadcast_suppressed(true)
	for op_v: Variant in _non_conflicting_remote:
		if op_v is Op:
			OpBus.ingest_remote(op_v)
	var ops_to_apply: Array = []
	for op_v: Variant in _non_conflicting_local:
		if op_v is Op:
			ops_to_apply.append((op_v as Op).to_dict())
	MultiplayerService.set_merge_broadcast_suppressed(false)
	_finalize_and_emit_report(ops_to_apply, [])


func _apply_resolutions() -> void:
	_state = STATE_APPLYING
	MultiplayerService.set_merge_broadcast_suppressed(true)
	for op_v: Variant in _non_conflicting_remote:
		if op_v is Op:
			OpBus.ingest_remote(op_v)
	var ops_to_apply: Array = []
	for op_v: Variant in _non_conflicting_local:
		if op_v is Op:
			ops_to_apply.append((op_v as Op).to_dict())
	var entries: Array = []
	var kept_local_count: int = 0
	var kept_host_count: int = 0
	for c_v: Variant in _conflicts:
		var conflict: Dictionary = c_v as Dictionary
		var resolution: String = String(conflict.get("resolution", MergeAnalyzer.RESOLUTION_PENDING))
		var local_ops: Array = conflict.get("local_ops", []) as Array
		var remote_ops: Array = conflict.get("remote_ops", []) as Array
		var resurrection_path: String = _resurrection_path(conflict, resolution, local_ops, remote_ops)
		match resurrection_path:
			"resurrect_for_local":
				kept_local_count += 1
				_apply_resurrection_for_keep_local(conflict, local_ops, remote_ops, ops_to_apply, entries)
				continue
			"resurrect_for_remote":
				kept_host_count += 1
				_apply_resurrection_for_keep_remote(conflict, local_ops, remote_ops, entries)
				continue
		match resolution:
			MergeAnalyzer.RESOLUTION_KEEP_LOCAL:
				kept_local_count += 1
				for r_op_v: Variant in remote_ops:
					if r_op_v is Op:
						OpBus.ingest_remote(r_op_v)
				for l_op_v: Variant in local_ops:
					if not (l_op_v is Op):
						continue
					var l_op: Op = l_op_v
					var fresh: Op = OpBus.emit_local(l_op.kind, l_op.payload, l_op.board_id)
					if fresh != null:
						ops_to_apply.append(fresh.to_dict())
				entries.append(_make_report_entry(conflict, "Override applied (your edit kept)", true))
			MergeAnalyzer.RESOLUTION_KEEP_REMOTE:
				kept_host_count += 1
				for r_op_v: Variant in remote_ops:
					if r_op_v is Op:
						OpBus.ingest_remote(r_op_v)
				entries.append(_make_report_entry(conflict, "Host edit kept (your offline edit dropped)", false))
			_:
				kept_host_count += 1
				for r_op_v: Variant in remote_ops:
					if r_op_v is Op:
						OpBus.ingest_remote(r_op_v)
				entries.append(_make_report_entry(conflict, "Host edit kept (unresolved)", false))
	MultiplayerService.set_merge_broadcast_suppressed(false)
	_finalize_and_emit_report(ops_to_apply, entries, kept_local_count, kept_host_count)


func _resurrection_path(conflict: Dictionary, resolution: String, local_ops: Array, remote_ops: Array) -> String:
	if String(conflict.get("target_kind", "")) != MergeAnalyzer.TARGET_KIND_ITEM:
		return ""
	var has_remote_delete: bool = _ops_contain_kind(remote_ops, OpKinds.DELETE_ITEM)
	var has_local_delete: bool = _ops_contain_kind(local_ops, OpKinds.DELETE_ITEM)
	if resolution == MergeAnalyzer.RESOLUTION_KEEP_LOCAL and has_remote_delete and not has_local_delete:
		return "resurrect_for_local"
	if resolution == MergeAnalyzer.RESOLUTION_KEEP_REMOTE and has_local_delete and not has_remote_delete:
		return "resurrect_for_remote"
	return ""


func _apply_resurrection_for_keep_local(conflict: Dictionary, local_ops: Array, remote_ops: Array, ops_to_apply: Array, entries: Array) -> void:
	var item_id: String = String(conflict.get("target_id", ""))
	var board_id: String = ""
	for l_op_v: Variant in local_ops:
		if l_op_v is Op:
			board_id = (l_op_v as Op).board_id
			break
	if board_id == "":
		for r_op_v: Variant in remote_ops:
			if r_op_v is Op:
				board_id = (r_op_v as Op).board_id
				break
	var snapshot: Dictionary = _snapshot_item_from_local_board(board_id, item_id)
	if snapshot.is_empty():
		for r_op_v: Variant in remote_ops:
			if r_op_v is Op:
				OpBus.ingest_remote(r_op_v)
		entries.append(_make_report_entry(conflict, "Host delete kept (could not resurrect — local snapshot missing)", false))
		return
	var fresh: Op = OpBus.emit_local(OpKinds.CREATE_ITEM, {"item_dict": snapshot}, board_id)
	if fresh != null:
		ops_to_apply.append(fresh.to_dict())
	for r_op_v: Variant in remote_ops:
		if r_op_v is Op and OpBus.oplog() != null:
			OpBus.mark_already_applied(r_op_v)
	entries.append(_make_report_entry(conflict, "Resurrected with your offline edits (host's delete overridden)", true))


func _apply_resurrection_for_keep_remote(conflict: Dictionary, local_ops: Array, remote_ops: Array, entries: Array) -> void:
	var delete_op: Op = null
	for l_op_v: Variant in local_ops:
		if l_op_v is Op and (l_op_v as Op).kind == OpKinds.DELETE_ITEM:
			delete_op = l_op_v
			break
	if delete_op == null or delete_op.inverse_payload.is_empty():
		for r_op_v: Variant in remote_ops:
			if r_op_v is Op:
				OpBus.ingest_remote(r_op_v)
		entries.append(_make_report_entry(conflict, "Host edit kept (could not resurrect — no inverse snapshot)", false))
		return
	var item_dict: Dictionary = (delete_op.inverse_payload as Dictionary).get("item_dict", {}) as Dictionary
	if item_dict.is_empty():
		for r_op_v: Variant in remote_ops:
			if r_op_v is Op:
				OpBus.ingest_remote(r_op_v)
		entries.append(_make_report_entry(conflict, "Host edit kept (could not resurrect — no item snapshot)", false))
		return
	var board_id: String = delete_op.board_id
	OpBus.emit_local(OpKinds.CREATE_ITEM, {"item_dict": item_dict.duplicate(true)}, board_id)
	for r_op_v: Variant in remote_ops:
		if r_op_v is Op:
			OpBus.ingest_remote(r_op_v)
	entries.append(_make_report_entry(conflict, "Resurrected and host's edit applied (your offline delete overridden)", false))


func _ops_contain_kind(ops: Array, kind: String) -> bool:
	for op_v: Variant in ops:
		if op_v is Op and (op_v as Op).kind == kind:
			return true
	return false


func _snapshot_item_from_local_board(board_id: String, item_id: String) -> Dictionary:
	if _project == null or board_id == "" or item_id == "":
		return {}
	var board: Board = _project.read_board(board_id)
	if board == null:
		return {}
	for d_v: Variant in board.items:
		if typeof(d_v) != TYPE_DICTIONARY:
			continue
		if String((d_v as Dictionary).get("id", "")) == item_id:
			return (d_v as Dictionary).duplicate(true)
	return {}


func _finalize_and_emit_report(ops_to_apply: Array, override_entries: Array, kept_local_count: int = 0, kept_host_count: int = 0) -> void:
	_report_id = Uuid.v4()
	var payload: Dictionary = {
		"report_id": _report_id,
		"author_display_name": KeypairService.display_name(),
		"author_stable_id": KeypairService.stable_id(),
		"origin_unix": int(Time.get_unix_time_from_system()),
		"kept_local_count": kept_local_count,
		"kept_host_count": kept_host_count,
		"auto_merged_count": _non_conflicting_local.size() + _non_conflicting_remote.size(),
		"ops_to_apply": ops_to_apply,
		"entries": override_entries,
	}
	_state = STATE_DONE
	emit_signal("dialog_close_requested")
	emit_signal("finalize_ready", payload)
	emit_signal("merge_completed", _report_id)


func _make_report_entry(conflict: Dictionary, resolution_label: String, can_rollback: bool) -> Dictionary:
	var local_summary: Dictionary = conflict.get("local_summary", {}) as Dictionary
	var remote_summary: Dictionary = conflict.get("remote_summary", {}) as Dictionary
	var winning_summary: Dictionary = local_summary if can_rollback else remote_summary
	var op_id: String = String(winning_summary.get("op_id", ""))
	var target_label: String = ""
	match String(conflict.get("target_kind", "")):
		MergeAnalyzer.TARGET_KIND_ITEM:
			target_label = "Node %s" % String(conflict.get("target_id", ""))
		MergeAnalyzer.TARGET_KIND_CONNECTION:
			target_label = "Connection %s" % String(conflict.get("target_id", ""))
		MergeAnalyzer.TARGET_KIND_COMMENT:
			target_label = "Comment %s" % String(conflict.get("target_id", ""))
		MergeAnalyzer.TARGET_KIND_BOARD:
			target_label = "Board %s" % String(conflict.get("target_id", ""))
		_:
			target_label = String(conflict.get("target_id", ""))
	return {
		"op_id": op_id,
		"target_label": target_label,
		"property_label": String(conflict.get("property_label", "")),
		"value_text": String(winning_summary.get("value_text", "")),
		"meta_text": _format_meta(winning_summary),
		"resolution_label": resolution_label,
		"can_rollback": can_rollback,
		"rolled_back": false,
	}


func _format_meta(summary: Dictionary) -> String:
	var author: String = String(summary.get("author_display_name", ""))
	var unix: int = int(summary.get("origin_unix", 0))
	if author == "" and unix <= 0:
		return ""
	var ts: String = "(unknown)"
	if unix > 0:
		var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix)
		ts = "%04d-%02d-%02d %02d:%02d:%02d" % [
			int(dt.get("year", 0)), int(dt.get("month", 0)), int(dt.get("day", 0)),
			int(dt.get("hour", 0)), int(dt.get("minute", 0)), int(dt.get("second", 0)),
		]
	return "%s · %s" % [author, ts]


func _local_ops_missing_from_host(board_id: String, host_clock: VectorClock) -> Array:
	var oplog: OpLog = OpBus.oplog()
	if oplog == null:
		return []
	oplog.ensure_loaded(board_id)
	var local_clock: VectorClock = oplog.vector_clock_for_board(board_id)
	var diff: Dictionary = local_clock.difference_to_send(host_clock)
	var out: Array = []
	for stable_id: String in diff.keys():
		var range_d: Dictionary = diff[stable_id]
		var seq_from: int = int(range_d.get("from", 1))
		var seq_to: int = int(range_d.get("to", 1))
		var ops: Array = oplog.ops_in_range(board_id, stable_id, seq_from, seq_to)
		for op_v: Variant in ops:
			if op_v is Op:
				out.append(op_v)
	return out


func _abort(reason: String) -> void:
	_state = STATE_CANCELLED
	emit_signal("dialog_close_requested")
	emit_signal("merge_aborted", reason)
