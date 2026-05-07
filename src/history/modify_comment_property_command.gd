class_name ModifyCommentPropertyCommand
extends HistoryCommand

var _editor: Node
var _comment_id: String
var _key: String
var _from_value: Variant
var _to_value: Variant


func _init(editor: Node, comment_id: String, key: String, from_value: Variant, to_value: Variant) -> void:
	_editor = editor
	_comment_id = comment_id
	_key = key
	_from_value = from_value
	_to_value = to_value


func do() -> void:
	_apply(_to_value)


func undo() -> void:
	_apply(_from_value)


func record_op_forward() -> void:
	_record(_to_value)


func rollback_local() -> void:
	if _editor != null and _editor.has_method("apply_comment_property_locally"):
		_editor.call("apply_comment_property_locally", _comment_id, _key, _from_value)


func primary_op_kind() -> String:
	return OpKinds.SET_COMMENT_PROPERTY


func description() -> String:
	return "Modify comment %s" % _key


func _apply(value: Variant) -> void:
	if _editor != null and _editor.has_method("apply_comment_property_locally"):
		_editor.call("apply_comment_property_locally", _comment_id, _key, value)
	_record(value)
	if _editor != null and _editor.has_method("request_save"):
		_editor.call("request_save")


func _record(value: Variant) -> void:
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	OpBus.record_local_change(OpKinds.SET_COMMENT_PROPERTY, {
		"comment_id": _comment_id,
		"key": _key,
		"value": _serialize_value(value),
	}, board_id)


static func _serialize_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_COLOR:
		var c: Color = value
		return [c.r, c.g, c.b, c.a]
	return value
