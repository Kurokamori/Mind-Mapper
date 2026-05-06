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
	_editor.request_save()


func undo() -> void:
	if _editor == null:
		return
	_editor.apply_layer_cells(_layer_id, _before_cells)
	_editor.request_save()


func description() -> String:
	return "Paint cells"
