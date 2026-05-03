class_name PropertyBinder
extends RefCounted

var _editor: Node
var _item: BoardItem
var _key: String
var _pre_value: Variant


func _init(editor: Node, item: BoardItem, key: String, current_value: Variant) -> void:
	_editor = editor
	_item = item
	_key = key
	_pre_value = current_value


func live(value: Variant) -> void:
	if _item != null:
		_item.apply_property(_key, value)


func commit(value: Variant) -> void:
	if _item == null or _editor == null:
		return
	if _values_equal(value, _pre_value):
		return
	History.push_already_done(ModifyPropertyCommand.new(_editor, _item.item_id, _key, _pre_value, value))
	_pre_value = value
	if _editor.has_method("request_save"):
		_editor.request_save()


func _values_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	return a == b
