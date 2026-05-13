class_name RemoveStrokesCommand
extends HistoryCommand

var _editor: Node
var _snapshots: Array


func _init(editor: Node, stroke_dicts: Array) -> void:
	_editor = editor
	_snapshots = []
	for entry: Variant in stroke_dicts:
		if typeof(entry) == TYPE_DICTIONARY:
			_snapshots.append(AnnotationStroke.normalize((entry as Dictionary).duplicate(true)))


func do() -> void:
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	for stroke_dict: Dictionary in _snapshots:
		var stroke_id: String = String(stroke_dict.get(AnnotationStroke.FIELD_ID, ""))
		if stroke_id == "":
			continue
		if _editor != null and _editor.has_method("apply_stroke_delete_locally"):
			_editor.call("apply_stroke_delete_locally", stroke_id)
		OpBus.record_local_change(OpKinds.DELETE_STROKE, {"stroke_id": stroke_id}, board_id)
	if _editor != null and _editor.has_method("request_save"):
		_editor.call("request_save")


func undo() -> void:
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	for stroke_dict: Dictionary in _snapshots:
		if _editor != null and _editor.has_method("apply_stroke_create_locally"):
			_editor.call("apply_stroke_create_locally", stroke_dict)
		OpBus.record_local_change(OpKinds.CREATE_STROKE, {"stroke_dict": stroke_dict.duplicate(true)}, board_id)
	if _editor != null and _editor.has_method("request_save"):
		_editor.call("request_save")


func record_op_forward() -> void:
	var board_id: String = AppState.current_board.id if AppState.current_board != null else ""
	for stroke_dict: Dictionary in _snapshots:
		var stroke_id: String = String(stroke_dict.get(AnnotationStroke.FIELD_ID, ""))
		if stroke_id == "":
			continue
		OpBus.record_local_change(OpKinds.DELETE_STROKE, {"stroke_id": stroke_id}, board_id)


func rollback_local() -> void:
	for stroke_dict: Dictionary in _snapshots:
		if _editor != null and _editor.has_method("apply_stroke_create_locally"):
			_editor.call("apply_stroke_create_locally", stroke_dict)


func primary_op_kind() -> String:
	return OpKinds.DELETE_STROKE


func description() -> String:
	if _snapshots.size() == 1:
		return "Delete stroke"
	return "Delete %d strokes" % _snapshots.size()
