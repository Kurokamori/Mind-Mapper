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
		_editor.apply_object_position(String(e.get("id", "")), Vector2(float(to_arr[0]), float(to_arr[1])))
	_editor.request_save()


func undo() -> void:
	if _editor == null:
		return
	for e in _entries:
		var from_arr: Array = e.get("from", [0, 0])
		_editor.apply_object_position(String(e.get("id", "")), Vector2(float(from_arr[0]), float(from_arr[1])))
	_editor.request_save()


func description() -> String:
	return "Move objects"
