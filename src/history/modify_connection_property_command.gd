class_name ModifyConnectionPropertyCommand
extends HistoryCommand

var _editor: Node
var _connection_id: String
var _key: String
var _from_value: Variant
var _to_value: Variant


func _init(editor: Node, connection_id: String, key: String, from_value: Variant, to_value: Variant) -> void:
	_editor = editor
	_connection_id = connection_id
	_key = key
	_from_value = from_value
	_to_value = to_value


func do() -> void:
	_apply(_to_value)


func undo() -> void:
	_apply(_from_value)


func record_op_forward() -> void:
	_emit_op(_to_value)


func rollback_local() -> void:
	if _editor == null:
		return
	var c: Connection = _editor.find_connection_by_id(_connection_id)
	if c == null:
		return
	c.apply_property(_key, _from_value)
	if _editor.has_method("notify_connection_updated"):
		_editor.notify_connection_updated(c)


func primary_op_kind() -> String:
	return OpKinds.SET_CONNECTION_PROPERTY


func _apply(value: Variant) -> void:
	if _editor == null:
		return
	var c: Connection = _editor.find_connection_by_id(_connection_id)
	if c == null:
		return
	c.apply_property(_key, value)
	if _editor.has_method("notify_connection_updated"):
		_editor.notify_connection_updated(c)
	_emit_op(value)
	_editor.request_save()


func _emit_op(value: Variant) -> void:
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	OpBus.record_local_change(OpKinds.SET_CONNECTION_PROPERTY, {
		"connection_id": _connection_id,
		"key": _key,
		"value": ModifyPropertyCommand._serialize_property_value(value),
	}, board_id)


func description() -> String:
	return "Modify connection %s" % _key
