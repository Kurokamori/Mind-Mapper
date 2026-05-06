class_name OpLog
extends RefCounted

const OPLOG_DIR: String = "oplog"
const VECTOR_CLOCK_FILENAME: String = "vector_clocks.json"
const RING_BUFFER_DEFAULT: int = 4000

var _project: Project = null
var _per_board_ops: Dictionary = {}
var _per_board_vector_clock: Dictionary = {}
var _per_board_lamport_max: Dictionary = {}
var _seen_op_ids: Dictionary = {}
var _ring_buffer_size: int = RING_BUFFER_DEFAULT
var _initialized: bool = false


func _init(project: Project, ring_buffer_size_value: int = RING_BUFFER_DEFAULT) -> void:
	_project = project
	_ring_buffer_size = ring_buffer_size_value


func ensure_loaded(board_id: String) -> void:
	if _project == null or board_id == "":
		return
	if _per_board_ops.has(board_id):
		return
	_per_board_ops[board_id] = []
	_per_board_vector_clock[board_id] = VectorClock.new()
	_per_board_lamport_max[board_id] = 0
	var path: String = _board_log_path(board_id)
	if not FileAccess.file_exists(path):
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var line: String = f.get_line()
		if line == "":
			continue
		var parsed: Variant = JSON.parse_string(line)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var op: Op = Op.from_dict(parsed)
		if op.op_id == "":
			continue
		if _seen_op_ids.has(op.op_id):
			continue
		_seen_op_ids[op.op_id] = true
		(_per_board_ops[board_id] as Array).append(op)
		_observe_in_clock(board_id, op)
	f.close()


func ensure_project_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_project._ensure_directories()
	var oplog_dir: String = _project.folder_path.path_join(OPLOG_DIR)
	if not DirAccess.dir_exists_absolute(oplog_dir):
		DirAccess.make_dir_recursive_absolute(oplog_dir)


func append(op: Op) -> bool:
	if op == null or op.op_id == "":
		return false
	ensure_project_initialized()
	if _seen_op_ids.has(op.op_id):
		return false
	var board_id: String = op.board_id if op.board_id != "" else "_project_"
	if not _per_board_ops.has(board_id):
		ensure_loaded(board_id)
	(_per_board_ops[board_id] as Array).append(op)
	_seen_op_ids[op.op_id] = true
	_observe_in_clock(board_id, op)
	_append_to_disk(board_id, op)
	_trim_ring_buffer(board_id)
	return true


func has_op(op_id: String) -> bool:
	return _seen_op_ids.has(op_id)


func ops_for_board(board_id: String) -> Array:
	if not _per_board_ops.has(board_id):
		ensure_loaded(board_id)
	return (_per_board_ops[board_id] as Array).duplicate()


func vector_clock_for_board(board_id: String) -> VectorClock:
	if not _per_board_vector_clock.has(board_id):
		ensure_loaded(board_id)
	return (_per_board_vector_clock[board_id] as VectorClock).clone()


func lamport_max_for_board(board_id: String) -> int:
	if not _per_board_lamport_max.has(board_id):
		ensure_loaded(board_id)
	return int(_per_board_lamport_max.get(board_id, 0))


func ops_in_range(board_id: String, stable_id: String, from_seq: int, to_seq: int) -> Array:
	var out: Array = []
	if not _per_board_ops.has(board_id):
		ensure_loaded(board_id)
	var counter: int = 0
	for op_v: Variant in (_per_board_ops[board_id] as Array):
		var op: Op = op_v as Op
		if op == null or op.author_stable_id != stable_id:
			continue
		counter += 1
		if counter >= from_seq and counter <= to_seq:
			out.append(op)
	return out


func all_known_boards() -> Array[String]:
	var ids: Array[String] = []
	if _project == null:
		return ids
	ensure_project_initialized()
	var d: DirAccess = DirAccess.open(_project.folder_path.path_join(OPLOG_DIR))
	if d == null:
		return ids
	d.list_dir_begin()
	var entry: String = d.get_next()
	while entry != "":
		if not d.current_is_dir() and entry.ends_with(".jsonl"):
			ids.append(entry.replace(".jsonl", ""))
		entry = d.get_next()
	d.list_dir_end()
	return ids


func compact(board_id: String, max_size: int) -> void:
	if not _per_board_ops.has(board_id):
		return
	var arr: Array = _per_board_ops[board_id] as Array
	if arr.size() <= max_size:
		return
	var trimmed: Array = arr.slice(arr.size() - max_size)
	_per_board_ops[board_id] = trimmed
	_rewrite_log(board_id)


func _observe_in_clock(board_id: String, op: Op) -> void:
	var vc: VectorClock = _per_board_vector_clock.get(board_id, VectorClock.new())
	if op.author_stable_id != "":
		vc.observe(op.author_stable_id, vc.get_value(op.author_stable_id) + 1)
	_per_board_vector_clock[board_id] = vc
	if op.lamport_ts > int(_per_board_lamport_max.get(board_id, 0)):
		_per_board_lamport_max[board_id] = op.lamport_ts


func _append_to_disk(board_id: String, op: Op) -> void:
	var path: String = _board_log_path(board_id)
	var f: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE_READ)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return
	f.seek_end()
	f.store_line(JSON.stringify(op.to_dict()))
	f.close()


func _rewrite_log(board_id: String) -> void:
	var path: String = _board_log_path(board_id)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	for op_v: Variant in (_per_board_ops[board_id] as Array):
		var op: Op = op_v as Op
		if op == null:
			continue
		f.store_line(JSON.stringify(op.to_dict()))
	f.close()


func _trim_ring_buffer(board_id: String) -> void:
	var arr: Array = _per_board_ops.get(board_id, []) as Array
	if arr.size() <= _ring_buffer_size * 2:
		return
	compact(board_id, _ring_buffer_size)


func _board_log_path(board_id: String) -> String:
	return _project.folder_path.path_join(OPLOG_DIR).path_join("%s.jsonl" % board_id)
