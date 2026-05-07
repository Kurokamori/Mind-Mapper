class_name AddItemsCommand
extends HistoryCommand

var _editor: Node
var _item_dicts: Array
var _instantiated_ids: Array[String] = []
var _instantiated_dicts: Dictionary = {}


func _init(editor: Node, item_dicts: Array) -> void:
	_editor = editor
	_item_dicts = item_dicts.duplicate(true)


func do() -> void:
	_instantiated_ids.clear()
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	for d in _item_dicts:
		var inst: BoardItem = _editor.instantiate_item_from_dict(d)
		if inst == null:
			continue
		_instantiated_ids.append(inst.item_id)
		var emitted_dict: Dictionary = inst.to_dict()
		_instantiated_dicts[inst.item_id] = emitted_dict.duplicate(true)
		OpBus.record_local_change(OpKinds.CREATE_ITEM, {"item_dict": emitted_dict}, board_id)
	_editor.request_save()


func undo() -> void:
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	for id in _instantiated_ids:
		_editor.remove_item_by_id(id)
		var inverse: Dictionary = {}
		if _instantiated_dicts.has(id):
			inverse = {"item_dict": (_instantiated_dicts[id] as Dictionary).duplicate(true)}
		OpBus.record_local_change(OpKinds.DELETE_ITEM, {"item_id": id}, board_id, inverse)
	_instantiated_ids.clear()
	_editor.request_save()


func primary_op_kind() -> String:
	return OpKinds.CREATE_ITEM


func description() -> String:
	return "Add items"
