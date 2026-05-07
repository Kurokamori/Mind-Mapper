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
	_record_op()
	_editor.request_save()


func undo() -> void:
	if _editor == null or not _editor.has_method("apply_z_order_snapshot"):
		return
	_editor.apply_z_order_snapshot(_previous_order)
	_record_op()
	_editor.request_save()


func _record_op() -> void:
	if _editor == null or not _editor.has_method("get_z_order_snapshot"):
		return
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	var current_order: Array = _editor.get_z_order_snapshot()
	OpBus.record_local_change(OpKinds.REORDER_ITEMS, {"order": current_order}, board_id)


func primary_op_kind() -> String:
	return OpKinds.REORDER_ITEMS


func description() -> String:
	return "Reorder items"
