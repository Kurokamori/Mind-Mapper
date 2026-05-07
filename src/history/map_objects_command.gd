class_name MapObjectsCommand
extends HistoryCommand

## Add / remove overlay objects on a MapPage. Each entry is a full object
## dict so undo can re-instantiate or remove with full fidelity.

const KIND_ADD: String = "add"
const KIND_REMOVE: String = "remove"

var _editor: Node
var _kind: String
var _entries: Array


static func make_add(editor: Node, object_dicts: Array) -> MapObjectsCommand:
	var c: MapObjectsCommand = MapObjectsCommand.new()
	c._editor = editor
	c._kind = KIND_ADD
	c._entries = object_dicts.duplicate(true)
	return c


static func make_remove(editor: Node, object_dicts: Array) -> MapObjectsCommand:
	var c: MapObjectsCommand = MapObjectsCommand.new()
	c._editor = editor
	c._kind = KIND_REMOVE
	c._entries = object_dicts.duplicate(true)
	return c


func do() -> void:
	if _editor == null:
		return
	match _kind:
		KIND_ADD:
			for d in _entries:
				_editor.spawn_object_from_dict(d)
				_record_add(d)
		KIND_REMOVE:
			for d in _entries:
				_editor.remove_object_by_id(String(d.get("id", "")))
				_record_remove(String(d.get("id", "")))
	_editor.request_save()


func undo() -> void:
	if _editor == null:
		return
	match _kind:
		KIND_ADD:
			for d in _entries:
				_editor.remove_object_by_id(String(d.get("id", "")))
				_record_remove(String(d.get("id", "")))
		KIND_REMOVE:
			for d in _entries:
				_editor.spawn_object_from_dict(d)
				_record_add(d)
	_editor.request_save()


func _map_id() -> String:
	if AppState.current_map_page == null:
		return ""
	return AppState.current_map_page.id


func _record_add(d: Dictionary) -> void:
	var mid: String = _map_id()
	if mid == "":
		return
	OpBus.record_local_change(OpKinds.MAP_ADD_OBJECT, {
		"map_id": mid,
		"object": d.duplicate(true),
	}, mid)


func _record_remove(object_id: String) -> void:
	var mid: String = _map_id()
	if mid == "" or object_id == "":
		return
	OpBus.record_local_change(OpKinds.MAP_REMOVE_OBJECT, {
		"map_id": mid,
		"object_id": object_id,
	}, mid)


func description() -> String:
	return "Object " + _kind
