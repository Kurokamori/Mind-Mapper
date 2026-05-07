class_name MapModifyLayerPropertyCommand
extends HistoryCommand

var _editor: Node
var _layer_id: String
var _key: String
var _from_value: Variant
var _to_value: Variant


func _init(editor: Node, layer_id: String, key: String, from_value: Variant, to_value: Variant) -> void:
	_editor = editor
	_layer_id = layer_id
	_key = key
	_from_value = from_value
	_to_value = to_value


func do() -> void:
	if _editor != null:
		_editor.apply_layer_property(_layer_id, _key, _to_value)
		_record(_to_value)
		_editor.request_save()


func undo() -> void:
	if _editor != null:
		_editor.apply_layer_property(_layer_id, _key, _from_value)
		_record(_from_value)
		_editor.request_save()


func _record(value: Variant) -> void:
	if AppState.current_map_page == null:
		return
	OpBus.record_local_change(OpKinds.MAP_SET_LAYER_PROPERTY, {
		"map_id": AppState.current_map_page.id,
		"layer_id": _layer_id,
		"key": _key,
		"value": value,
	}, AppState.current_map_page.id)


func description() -> String:
	return "Layer %s" % _key
