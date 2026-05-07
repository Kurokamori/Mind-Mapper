class_name DeleteCommentCommand
extends HistoryCommand

var _editor: Node
var _comment_id: String
var _snapshot: Dictionary


func _init(editor: Node, comment_id: String, snapshot: Dictionary) -> void:
	_editor = editor
	_comment_id = comment_id
	_snapshot = CommentData.normalize(snapshot.duplicate(true))


func do() -> void:
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	if _editor != null and _editor.has_method("apply_comment_delete_locally"):
		_editor.call("apply_comment_delete_locally", _comment_id)
	OpBus.record_local_change(OpKinds.DELETE_COMMENT, {"comment_id": _comment_id}, board_id)
	if _editor != null and _editor.has_method("request_save"):
		_editor.call("request_save")


func undo() -> void:
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	if _editor != null and _editor.has_method("apply_comment_create_locally"):
		_editor.call("apply_comment_create_locally", _snapshot)
	OpBus.record_local_change(OpKinds.CREATE_COMMENT, {"comment_dict": _snapshot.duplicate(true)}, board_id)
	if _editor != null and _editor.has_method("request_save"):
		_editor.call("request_save")


func record_op_forward() -> void:
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	OpBus.record_local_change(OpKinds.DELETE_COMMENT, {"comment_id": _comment_id}, board_id)


func rollback_local() -> void:
	if _editor != null and _editor.has_method("apply_comment_create_locally"):
		_editor.call("apply_comment_create_locally", _snapshot)


func primary_op_kind() -> String:
	return OpKinds.DELETE_COMMENT


func description() -> String:
	return "Delete comment"
