class_name ModifyPropertyCommand
extends HistoryCommand

var _editor: Node
var _item_id: String
var _key: String
var _from_value: Variant
var _to_value: Variant


func _init(editor: Node, item_id: String, key: String, from_value: Variant, to_value: Variant) -> void:
	_editor = editor
	_item_id = item_id
	_key = key
	_from_value = from_value
	_to_value = to_value


func do() -> void:
	var item: BoardItem = _editor.find_item_by_id(_item_id)
	if item != null:
		item.apply_property(_key, _to_value)
	_record_value(_to_value)
	_editor.request_save()


func undo() -> void:
	var item: BoardItem = _editor.find_item_by_id(_item_id)
	if item != null:
		item.apply_property(_key, _from_value)
	_record_value(_from_value)
	_editor.request_save()


func record_op_forward() -> void:
	_record_value(_to_value)


func rollback_local() -> void:
	var item: BoardItem = _editor.find_item_by_id(_item_id) if _editor != null else null
	if item != null:
		item.apply_property(_key, _from_value)


func primary_op_kind() -> String:
	return OpKinds.SET_ITEM_PROPERTY


func _record_value(value: Variant) -> void:
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	OpBus.record_local_change(OpKinds.SET_ITEM_PROPERTY, {
		"item_id": _item_id,
		"key": _key,
		"value": _serialize_property_value(value),
	}, board_id)


static func _serialize_property_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_VECTOR2:
		return [(value as Vector2).x, (value as Vector2).y]
	if typeof(value) == TYPE_COLOR:
		var c: Color = value
		return [c.r, c.g, c.b, c.a]
	if typeof(value) == TYPE_PACKED_STRING_ARRAY:
		var arr: Array = []
		for s: String in (value as PackedStringArray):
			arr.append(s)
		return arr
	return value


func description() -> String:
	return "Modify %s" % _key
