class_name MapModifyObjectPropertyCommand
extends HistoryCommand

var _editor: Node
var _object_id: String
var _key: String
var _from_value: Variant
var _to_value: Variant


func _init(editor: Node, object_id: String, key: String, from_value: Variant, to_value: Variant) -> void:
	_editor = editor
	_object_id = object_id
	_key = key
	_from_value = from_value
	_to_value = to_value


func do() -> void:
	if _editor != null:
		_editor.apply_object_property(_object_id, _key, _to_value)
		_editor.request_save()


func undo() -> void:
	if _editor != null:
		_editor.apply_object_property(_object_id, _key, _from_value)
		_editor.request_save()


func description() -> String:
	return "Object %s" % _key
