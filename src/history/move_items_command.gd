class_name MoveItemsCommand
extends HistoryCommand

var _editor: Node
var _entries: Array


func _init(editor: Node, entries: Array) -> void:
	_editor = editor
	_entries = entries.duplicate(true)


func do() -> void:
	for e in _entries:
		var item: BoardItem = _editor.find_item_by_id(String(e.get("id", "")))
		if item != null:
			var to_arr: Array = e.get("to", [0, 0])
			item.position = Vector2(float(to_arr[0]), float(to_arr[1]))
	_emit_op(true)
	_editor.request_save()


func undo() -> void:
	for e in _entries:
		var item: BoardItem = _editor.find_item_by_id(String(e.get("id", "")))
		if item != null:
			var from_arr: Array = e.get("from", [0, 0])
			item.position = Vector2(float(from_arr[0]), float(from_arr[1]))
	_emit_op(false)
	_editor.request_save()


func record_op_forward() -> void:
	_emit_op(true)


func rollback_local() -> void:
	if _editor == null:
		return
	for e in _entries:
		var item: BoardItem = _editor.find_item_by_id(String(e.get("id", "")))
		if item != null:
			var from_arr: Array = e.get("from", [0, 0])
			item.position = Vector2(float(from_arr[0]), float(from_arr[1]))


func primary_op_kind() -> String:
	return OpKinds.MOVE_ITEMS


func _emit_op(forward: bool) -> void:
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	var entries_for_op: Array = []
	for e in _entries:
		var to_arr: Array = (e.get("to", [0, 0]) as Array) if forward else (e.get("from", [0, 0]) as Array)
		entries_for_op.append({"id": String(e.get("id", "")), "to": [float(to_arr[0]), float(to_arr[1])]})
	OpBus.record_local_change(OpKinds.MOVE_ITEMS, {"entries": entries_for_op}, board_id)


func description() -> String:
	return "Move items"
