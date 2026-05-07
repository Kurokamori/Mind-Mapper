class_name MoveItemsBetweenBoardsCommand
extends HistoryCommand

var _editor: Node
var _source_board_id: String
var _target_board_id: String
var _entries: Array
var _pruned_connections: Array = []


func _init(editor: Node, source_board_id: String, target_board_id: String, entries: Array) -> void:
	_editor = editor
	_source_board_id = source_board_id
	_target_board_id = target_board_id
	_entries = entries.duplicate(true)


func do() -> void:
	_pruned_connections.clear()
	for entry in _entries:
		var id: String = String(entry.get("dict", {}).get("id", ""))
		if id == "":
			continue
		if _editor.has_method("remove_connections_referencing_item"):
			var pruned: Array = _editor.remove_connections_referencing_item(id)
			for c: Variant in pruned:
				if c is Connection:
					_pruned_connections.append((c as Connection).to_dict())
				elif typeof(c) == TYPE_DICTIONARY:
					_pruned_connections.append((c as Dictionary).duplicate(true))
		_editor.remove_item_by_id(id)
		var captured_source_dict: Dictionary = (entry.get("dict", {}) as Dictionary).duplicate(true)
		OpBus.record_local_change(OpKinds.DELETE_ITEM, {"item_id": id}, _source_board_id, {"item_dict": captured_source_dict})
	if AppState.current_project == null:
		return
	var target: Board = AppState.current_project.read_board(_target_board_id)
	if target == null:
		return
	for entry in _entries:
		var d: Dictionary = (entry.get("dict", {}) as Dictionary).duplicate(true)
		var to_pos: Variant = entry.get("target_position", null)
		if typeof(to_pos) == TYPE_ARRAY and (to_pos as Array).size() >= 2:
			d["position"] = [float(to_pos[0]), float(to_pos[1])]
		target.items.append(d)
		OpBus.record_local_change(OpKinds.CREATE_ITEM, {"item_dict": d}, _target_board_id)
	AppState.write_board(target)
	for c_dict: Dictionary in _pruned_connections:
		OpBus.record_local_change(OpKinds.DELETE_CONNECTION, {"connection_id": String(c_dict.get("id", ""))}, _source_board_id)
	_editor.request_save()


func undo() -> void:
	if AppState.current_project == null:
		return
	var target: Board = AppState.current_project.read_board(_target_board_id)
	if target != null:
		var move_ids: Dictionary = {}
		for entry in _entries:
			var id: String = String(entry.get("dict", {}).get("id", ""))
			if id != "":
				move_ids[id] = true
		var keep: Array = []
		for d in target.items:
			if not move_ids.has(String(d.get("id", ""))):
				keep.append(d)
			else:
				OpBus.record_local_change(OpKinds.DELETE_ITEM, {"item_id": String(d.get("id", ""))}, _target_board_id, {"item_dict": (d as Dictionary).duplicate(true)})
		target.items = keep
		AppState.write_board(target)
	for entry in _entries:
		var d: Dictionary = (entry.get("dict", {}) as Dictionary).duplicate(true)
		var from_pos: Variant = entry.get("source_position", null)
		if typeof(from_pos) == TYPE_ARRAY and (from_pos as Array).size() >= 2:
			d["position"] = [float(from_pos[0]), float(from_pos[1])]
		_editor.instantiate_item_from_dict(d)
		OpBus.record_local_change(OpKinds.CREATE_ITEM, {"item_dict": d}, _source_board_id)
	for c_dict: Dictionary in _pruned_connections:
		if _editor.has_method("add_connection"):
			_editor.add_connection(Connection.from_dict(c_dict))
		OpBus.record_local_change(OpKinds.CREATE_CONNECTION, {"connection_dict": c_dict}, _source_board_id)
	_pruned_connections.clear()
	_editor.request_save()


func primary_op_kind() -> String:
	return OpKinds.CREATE_ITEM


func description() -> String:
	return "Move into board"
