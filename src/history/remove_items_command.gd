class_name RemoveItemsCommand
extends HistoryCommand

var _editor: Node
var _captured: Array = []
var _captured_connections: Array = []


func _init(editor: Node, items: Array) -> void:
	_editor = editor
	for it in items:
		if it is BoardItem:
			_captured.append((it as BoardItem).to_dict())


func do() -> void:
	_captured_connections.clear()
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	for d: Dictionary in _captured:
		var item_id: String = String(d.get("id", ""))
		if item_id != "" and _editor != null and _editor.has_method("remove_connections_referencing_item"):
			var pruned: Array = _editor.remove_connections_referencing_item(item_id)
			for c: Variant in pruned:
				var captured_dict: Dictionary = (c as Connection).to_dict() if c is Connection else (c as Dictionary).duplicate(true) if typeof(c) == TYPE_DICTIONARY else {}
				if not captured_dict.is_empty():
					_captured_connections.append(captured_dict)
					OpBus.record_local_change(OpKinds.DELETE_CONNECTION, {"connection_id": String(captured_dict.get("id", ""))}, board_id)
		_editor.remove_item_by_id(item_id)
		OpBus.record_local_change(OpKinds.DELETE_ITEM, {"item_id": item_id}, board_id, {"item_dict": d.duplicate(true)})
	_editor.request_save()


func undo() -> void:
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	for d: Dictionary in _captured:
		_editor.instantiate_item_from_dict(d)
		OpBus.record_local_change(OpKinds.CREATE_ITEM, {"item_dict": d}, board_id)
	for c_dict: Dictionary in _captured_connections:
		if _editor.has_method("add_connection"):
			_editor.add_connection(Connection.from_dict(c_dict))
		OpBus.record_local_change(OpKinds.CREATE_CONNECTION, {"connection_dict": c_dict}, board_id)
	_captured_connections.clear()
	_editor.request_save()


func primary_op_kind() -> String:
	return OpKinds.DELETE_ITEM


func description() -> String:
	return "Remove items"
