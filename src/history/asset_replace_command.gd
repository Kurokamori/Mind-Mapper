class_name AssetReplaceCommand
extends HistoryCommand

var _editor: Node
var _item_id: String
var _from_state: Dictionary
var _to_state: Dictionary


func _init(editor: Node, item_id: String, from_state: Dictionary, to_state: Dictionary) -> void:
	_editor = editor
	_item_id = item_id
	_from_state = from_state.duplicate(true)
	_to_state = to_state.duplicate(true)


func do() -> void:
	_apply(_to_state)


func undo() -> void:
	_apply(_from_state)


func record_op_forward() -> void:
	_emit_op(_to_state)


func rollback_local() -> void:
	var item: BoardItem = _editor.find_item_by_id(_item_id) if _editor != null else null
	if item == null:
		return
	item.apply_property("source_mode", int(_from_state.get("source_mode", 0)))
	item.apply_property("source_path", String(_from_state.get("source_path", "")))
	item.apply_property("asset_name", String(_from_state.get("asset_name", "")))


func primary_op_kind() -> String:
	return OpKinds.SET_ITEM_PROPERTY


func _apply(state: Dictionary) -> void:
	var item: BoardItem = _editor.find_item_by_id(_item_id)
	if item == null:
		return
	item.apply_property("source_mode", int(state.get("source_mode", 0)))
	item.apply_property("source_path", String(state.get("source_path", "")))
	item.apply_property("asset_name", String(state.get("asset_name", "")))
	_emit_op(state)
	if _editor.has_method("request_save"):
		_editor.request_save()


func _emit_op(state: Dictionary) -> void:
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	for key: String in ["source_mode", "source_path", "asset_name"]:
		var value: Variant = state.get(key, "")
		OpBus.record_local_change(OpKinds.SET_ITEM_PROPERTY, {"item_id": _item_id, "key": key, "value": value}, board_id)


func description() -> String:
	return "Replace asset"
