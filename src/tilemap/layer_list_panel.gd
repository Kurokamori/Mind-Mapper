class_name LayerListPanel
extends DockablePanel

signal close_requested()
signal layer_selected(layer_id: String)
signal layer_visibility_toggled(layer_id: String, value: bool)
signal layer_locked_toggled(layer_id: String, value: bool)
signal layer_added()
signal layer_removed(layer_id: String)
signal layer_moved_up(layer_id: String)
signal layer_moved_down(layer_id: String)
signal layer_renamed(layer_id: String, new_name: String)
signal layer_tileset_chosen(layer_id: String, tileset_id: String)
signal layer_opacity_changed(layer_id: String, value: float)

@onready var _close_button: Button = %CloseButton
@onready var _list_root: VBoxContainer = %ListRoot
@onready var _add_button: AutomaticButton = %AddButton

var _selected_layer_id: String = ""
var _layers: Array = []
var _tilesets_lookup: Dictionary = {}


func _ready() -> void:
	super._ready()
	ThemeManager.theme_applied.connect(_apply_translucent_panel)
	_apply_translucent_panel()
	_close_button.pressed.connect(_on_close_pressed)
	_add_button.pressed.connect(_on_add_pressed)


func refresh(layers: Array, tilesets: Array, selected_id: String) -> void:
	_layers = layers
	_tilesets_lookup.clear()
	for ts: TileSetResource in tilesets:
		_tilesets_lookup[ts.id] = ts
	_selected_layer_id = selected_id
	_rebuild()


func selected_layer_id() -> String:
	return _selected_layer_id


func _rebuild() -> void:
	for child in _list_root.get_children():
		child.queue_free()
	if _layers.is_empty():
		var empty: Label = Label.new()
		empty.text = "No layers yet"
		empty.add_theme_color_override("font_color", ThemeManager.dim_foreground_color())
		_list_root.add_child(empty)
		return
	for i in range(_layers.size()):
		var layer: MapLayer = _layers[i]
		var row: LayerRow = LayerRow.new()
		_list_root.add_child(row)
		row.bind(layer, i, _layers.size(), _tilesets_lookup, layer.id == _selected_layer_id)
		row.selected.connect(_on_row_selected.bind(layer.id))
		row.visibility_toggled.connect(_on_row_visibility_toggled.bind(layer.id))
		row.moved_up.connect(_on_row_moved_up.bind(layer.id))
		row.moved_down.connect(_on_row_moved_down.bind(layer.id))
		row.removed.connect(_on_row_removed.bind(layer.id))
		row.renamed.connect(_on_row_renamed.bind(layer.id))
		row.tileset_chosen.connect(_on_row_tileset_chosen.bind(layer.id))
		row.opacity_changed.connect(_on_row_opacity_changed.bind(layer.id))


func _on_row_selected(layer_id: String) -> void:
	emit_signal("layer_selected", layer_id)


func _on_row_visibility_toggled(value: bool, layer_id: String) -> void:
	emit_signal("layer_visibility_toggled", layer_id, value)


func _on_row_moved_up(layer_id: String) -> void:
	emit_signal("layer_moved_up", layer_id)


func _on_row_moved_down(layer_id: String) -> void:
	emit_signal("layer_moved_down", layer_id)


func _on_row_removed(layer_id: String) -> void:
	emit_signal("layer_removed", layer_id)


func _on_row_renamed(new_name: String, layer_id: String) -> void:
	emit_signal("layer_renamed", layer_id, new_name)


func _on_row_tileset_chosen(tileset_id: String, layer_id: String) -> void:
	emit_signal("layer_tileset_chosen", layer_id, tileset_id)


func _on_row_opacity_changed(value: float, layer_id: String) -> void:
	emit_signal("layer_opacity_changed", layer_id, value)


func _on_add_pressed() -> void:
	emit_signal("layer_added")


func _on_close_pressed() -> void:
	emit_signal("close_requested")


func _apply_translucent_panel() -> void:
	ThemeManager.apply_translucent_panel(self)
