class_name BlockStackMoveCommand
extends HistoryCommand

var _editor: Node
var _source_stack_id: String
var _target_stack_id: String
var _source_before: Array
var _target_before: Array
var _source_after: Array
var _target_after: Array


func _init(
	editor: Node,
	source_stack_id: String,
	target_stack_id: String,
	source_before: Array,
	target_before: Array,
	source_after: Array,
	target_after: Array,
) -> void:
	_editor = editor
	_source_stack_id = source_stack_id
	_target_stack_id = target_stack_id
	_source_before = source_before.duplicate(true)
	_target_before = target_before.duplicate(true)
	_source_after = source_after.duplicate(true)
	_target_after = target_after.duplicate(true)


func do() -> void:
	_apply(_source_after, _target_after)


func undo() -> void:
	_apply(_source_before, _target_before)


func record_op_forward() -> void:
	_emit_op(_source_after, _target_after)


func rollback_local() -> void:
	if _editor == null:
		return
	if _source_stack_id == _target_stack_id:
		var only: BoardItem = _editor.find_item_by_id(_source_stack_id)
		if only != null:
			only.apply_property("blocks", _source_before)
		return
	var s: BoardItem = _editor.find_item_by_id(_source_stack_id)
	if s != null:
		s.apply_property("blocks", _source_before)
	var t: BoardItem = _editor.find_item_by_id(_target_stack_id)
	if t != null:
		t.apply_property("blocks", _target_before)


func primary_op_kind() -> String:
	return OpKinds.SET_ITEM_PROPERTY


func _apply(src: Array, tgt: Array) -> void:
	if _source_stack_id == _target_stack_id:
		var only: BoardItem = _editor.find_item_by_id(_source_stack_id)
		if only != null:
			only.apply_property("blocks", src)
	else:
		var s: BoardItem = _editor.find_item_by_id(_source_stack_id)
		if s != null:
			s.apply_property("blocks", src)
		var t: BoardItem = _editor.find_item_by_id(_target_stack_id)
		if t != null:
			t.apply_property("blocks", tgt)
	_emit_op(src, tgt)
	if _editor.has_method("request_save"):
		_editor.request_save()


func _emit_op(src: Array, tgt: Array) -> void:
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	OpBus.record_local_change(OpKinds.SET_ITEM_PROPERTY, {"item_id": _source_stack_id, "key": "blocks", "value": src}, board_id)
	if _source_stack_id != _target_stack_id:
		OpBus.record_local_change(OpKinds.SET_ITEM_PROPERTY, {"item_id": _target_stack_id, "key": "blocks", "value": tgt}, board_id)


func description() -> String:
	return "Move block"
