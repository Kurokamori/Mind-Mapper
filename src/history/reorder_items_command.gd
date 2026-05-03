class_name ReorderItemsCommand
extends HistoryCommand

var _editor: Node
var _item_ids: Array
var _direction: String

const DIR_BRING_FORWARD: String = "forward"
const DIR_BRING_TO_FRONT: String = "front"
const DIR_SEND_BACKWARD: String = "backward"
const DIR_SEND_TO_BACK: String = "back"

var _previous_order: Array = []


func _init(editor: Node, item_ids: Array, direction: String) -> void:
	_editor = editor
	_item_ids = item_ids.duplicate()
	_direction = direction


func do() -> void:
	if _editor == null or not _editor.has_method("get_z_order_snapshot"):
		return
	_previous_order = _editor.get_z_order_snapshot()
	_editor.apply_reorder(_item_ids, _direction)
	_editor.request_save()


func undo() -> void:
	if _editor == null or not _editor.has_method("apply_z_order_snapshot"):
		return
	_editor.apply_z_order_snapshot(_previous_order)
	_editor.request_save()


func description() -> String:
	return "Reorder items"
