class_name MapLayerCommand
extends HistoryCommand

## Add / remove / reorder MapLayer in a MapPage.

const KIND_ADD: String = "add"
const KIND_REMOVE: String = "remove"
const KIND_REORDER: String = "reorder"

var _editor: Node
var _kind: String
var _layer_dict: Dictionary
var _layer_id: String
var _from_index: int
var _to_index: int


static func make_add(editor: Node, layer_dict: Dictionary, target_index: int) -> MapLayerCommand:
	var c: MapLayerCommand = MapLayerCommand.new()
	c._editor = editor
	c._kind = KIND_ADD
	c._layer_dict = layer_dict.duplicate(true)
	c._layer_id = String(layer_dict.get("id", ""))
	c._to_index = target_index
	return c


static func make_remove(editor: Node, layer_dict: Dictionary, source_index: int) -> MapLayerCommand:
	var c: MapLayerCommand = MapLayerCommand.new()
	c._editor = editor
	c._kind = KIND_REMOVE
	c._layer_dict = layer_dict.duplicate(true)
	c._layer_id = String(layer_dict.get("id", ""))
	c._from_index = source_index
	return c


static func make_reorder(editor: Node, layer_id: String, from_index: int, to_index: int) -> MapLayerCommand:
	var c: MapLayerCommand = MapLayerCommand.new()
	c._editor = editor
	c._kind = KIND_REORDER
	c._layer_id = layer_id
	c._from_index = from_index
	c._to_index = to_index
	return c


func do() -> void:
	if _editor == null:
		return
	match _kind:
		KIND_ADD:
			_editor.insert_layer_from_dict(_layer_dict, _to_index)
		KIND_REMOVE:
			_editor.remove_layer_by_id(_layer_id)
		KIND_REORDER:
			_editor.reorder_layer(_layer_id, _to_index)
	_editor.request_save()


func undo() -> void:
	if _editor == null:
		return
	match _kind:
		KIND_ADD:
			_editor.remove_layer_by_id(_layer_id)
		KIND_REMOVE:
			_editor.insert_layer_from_dict(_layer_dict, _from_index)
		KIND_REORDER:
			_editor.reorder_layer(_layer_id, _from_index)
	_editor.request_save()


func description() -> String:
	return "Layer " + _kind
