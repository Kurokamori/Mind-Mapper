class_name AddConnectionsCommand
extends HistoryCommand

var _editor: Node
var _connection_dicts: Array
var _instantiated_ids: Array[String] = []


func _init(editor: Node, connection_dicts: Array) -> void:
	_editor = editor
	_connection_dicts = connection_dicts.duplicate(true)


func do() -> void:
	_instantiated_ids.clear()
	if _editor == null:
		return
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	for d: Variant in _connection_dicts:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var c: Connection = Connection.from_dict(d)
		_editor.add_connection(c)
		_instantiated_ids.append(c.id)
		OpBus.record_local_change(OpKinds.CREATE_CONNECTION, {"connection_dict": c.to_dict()}, board_id)
	_editor.request_save()


func undo() -> void:
	if _editor == null:
		return
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	for connection_id: String in _instantiated_ids:
		_editor.remove_connection_by_id(connection_id)
		OpBus.record_local_change(OpKinds.DELETE_CONNECTION, {"connection_id": connection_id}, board_id)
	_instantiated_ids.clear()
	_editor.request_save()


func description() -> String:
	return "Add connections"
