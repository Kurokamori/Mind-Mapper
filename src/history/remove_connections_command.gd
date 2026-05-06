class_name RemoveConnectionsCommand
extends HistoryCommand

var _editor: Node
var _captured: Array = []


func _init(editor: Node, connections: Array) -> void:
	_editor = editor
	for c: Variant in connections:
		if c is Connection:
			_captured.append((c as Connection).to_dict())
		elif typeof(c) == TYPE_DICTIONARY:
			_captured.append((c as Dictionary).duplicate(true))


func do() -> void:
	if _editor == null:
		return
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	for d: Dictionary in _captured:
		var connection_id: String = String(d.get("id", ""))
		_editor.remove_connection_by_id(connection_id)
		OpBus.record_local_change(OpKinds.DELETE_CONNECTION, {"connection_id": connection_id}, board_id)
	_editor.request_save()


func undo() -> void:
	if _editor == null:
		return
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	for d: Dictionary in _captured:
		_editor.add_connection(Connection.from_dict(d))
		OpBus.record_local_change(OpKinds.CREATE_CONNECTION, {"connection_dict": d}, board_id)
	_editor.request_save()


func description() -> String:
	return "Remove connections"
