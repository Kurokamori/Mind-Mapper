class_name MapMoveObjectsCommand
extends HistoryCommand

## Single-step move (or batch move) of overlay objects on a MapPage. Entries
## are { id: String, from: [x, y], to: [x, y] }.

var _editor: Node
var _entries: Array


func _init(editor: Node, entries: Array) -> void:
	_editor = editor
	_entries = entries.duplicate(true)


func do() -> void:
	if _editor == null:
		return
	for e in _entries:
		var to_arr: Array = e.get("to", [0, 0])
		var oid: String = String(e.get("id", ""))
		_editor.apply_object_position(oid, Vector2(float(to_arr[0]), float(to_arr[1])))
		_record(oid, to_arr)
	_editor.request_save()


func undo() -> void:
	if _editor == null:
		return
	for e in _entries:
		var from_arr: Array = e.get("from", [0, 0])
		var oid: String = String(e.get("id", ""))
		_editor.apply_object_position(oid, Vector2(float(from_arr[0]), float(from_arr[1])))
		_record(oid, from_arr)
	_editor.request_save()


func _record(object_id: String, position_arr: Array) -> void:
	if AppState.current_map_page == null or object_id == "":
		return
	OpBus.record_local_change(OpKinds.MAP_MOVE_OBJECT, {
		"map_id": AppState.current_map_page.id,
		"object_id": object_id,
		"position": [float(position_arr[0]), float(position_arr[1])],
	}, AppState.current_map_page.id)


func description() -> String:
	return "Move objects"
