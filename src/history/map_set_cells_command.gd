class_name MapSetCellsCommand
extends HistoryCommand

## Atomic paint/erase operation on a single MapLayer.
##
## Stores the cells' before-state and after-state so undo restores exactly
## what was overwritten. `before_cells` and `after_cells` are dictionaries
## keyed by Vector2i grid coords; absence of a key means "cell empty".
## Cell values are Vector3i(atlas_x, atlas_y, alternative).

var _editor: Node
var _layer_id: String
var _before_cells: Dictionary
var _after_cells: Dictionary


func _init(editor: Node, layer_id: String, before_cells: Dictionary, after_cells: Dictionary) -> void:
	_editor = editor
	_layer_id = layer_id
	_before_cells = before_cells.duplicate(true)
	_after_cells = after_cells.duplicate(true)


func do() -> void:
	if _editor == null:
		return
	_editor.apply_layer_cells(_layer_id, _after_cells)
	_record(_after_cells, _before_cells)
	_editor.request_save()


func undo() -> void:
	if _editor == null:
		return
	_editor.apply_layer_cells(_layer_id, _before_cells)
	_record(_before_cells, _after_cells)
	_editor.request_save()


func description() -> String:
	return "Paint cells"


func _record(state_after: Dictionary, state_before: Dictionary) -> void:
	if AppState.current_map_page == null:
		return
	var cells_payload: Array = []
	var keys: Dictionary = {}
	for k_v: Variant in state_after.keys():
		keys[k_v] = true
	for k_v: Variant in state_before.keys():
		keys[k_v] = true
	for coord_v: Variant in keys.keys():
		var coord: Vector2i = coord_v
		if state_after.has(coord):
			var atlas_v: Variant = state_after[coord]
			if typeof(atlas_v) == TYPE_VECTOR3I:
				var atlas: Vector3i = atlas_v
				cells_payload.append({
					"coord": [coord.x, coord.y],
					"atlas": [atlas.x, atlas.y, atlas.z],
				})
			else:
				cells_payload.append({
					"coord": [coord.x, coord.y],
					"erased": true,
				})
		else:
			cells_payload.append({
				"coord": [coord.x, coord.y],
				"erased": true,
			})
	OpBus.record_local_change(OpKinds.MAP_SET_LAYER_CELLS, {
		"map_id": AppState.current_map_page.id,
		"layer_id": _layer_id,
		"cells": cells_payload,
	}, AppState.current_map_page.id)
