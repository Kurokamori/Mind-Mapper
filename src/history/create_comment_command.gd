class_name CreateCommentCommand
extends HistoryCommand

var _editor: Node
var _comment_dict: Dictionary
var _comment_id: String


func _init(editor: Node, comment_dict: Dictionary) -> void:
	_editor = editor
	_comment_dict = CommentData.normalize(comment_dict.duplicate(true))
	_comment_id = String(_comment_dict.get(CommentData.FIELD_ID, ""))


func do() -> void:
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	if _editor != null and _editor.has_method("apply_comment_create_locally"):
		_editor.call("apply_comment_create_locally", _comment_dict)
	OpBus.record_local_change(OpKinds.CREATE_COMMENT, {"comment_dict": _comment_dict.duplicate(true)}, board_id)
	if _editor != null and _editor.has_method("request_save"):
		_editor.call("request_save")


func undo() -> void:
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	if _editor != null and _editor.has_method("apply_comment_delete_locally"):
		_editor.call("apply_comment_delete_locally", _comment_id)
	OpBus.record_local_change(OpKinds.DELETE_COMMENT, {"comment_id": _comment_id}, board_id)
	if _editor != null and _editor.has_method("request_save"):
		_editor.call("request_save")


func record_op_forward() -> void:
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	OpBus.record_local_change(OpKinds.CREATE_COMMENT, {"comment_dict": _comment_dict.duplicate(true)}, board_id)


func rollback_local() -> void:
	if _editor != null and _editor.has_method("apply_comment_delete_locally"):
		_editor.call("apply_comment_delete_locally", _comment_id)


func primary_op_kind() -> String:
	return OpKinds.CREATE_COMMENT


func description() -> String:
	return "Add comment"


func comment_id() -> String:
	return _comment_id
