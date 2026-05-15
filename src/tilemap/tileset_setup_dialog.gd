class_name TilesetSetupDialog
extends ConfirmationDialog

signal apply_requested(updated: Dictionary)

@onready var _name_edit: LineEdit = %NameEdit
@onready var _tile_w_spin: SpinBox = %TileWSpin
@onready var _tile_h_spin: SpinBox = %TileHSpin
@onready var _margin_x_spin: SpinBox = %MarginXSpin
@onready var _margin_y_spin: SpinBox = %MarginYSpin
@onready var _sep_x_spin: SpinBox = %SepXSpin
@onready var _sep_y_spin: SpinBox = %SepYSpin
@onready var _terrains_root: VBoxContainer = %TerrainsRoot
@onready var _add_terrain_button: Button = %AddTerrainButton
@onready var _info_label: Label = %InfoLabel

var _tileset: TileSetResource = null
var _terrain_rows: Array = []
var _from_godot_tres: bool = false


func _ready() -> void:
	add_cancel_button("Cancel")
	confirmed.connect(_on_confirmed)
	ThemeManager.apply_relative_font_size(_info_label, 0.85)
	_add_terrain_button.pressed.connect(_on_add_terrain_pressed)


func bind_tileset(ts: TileSetResource) -> void:
	_tileset = ts
	if ts == null:
		return
	_name_edit.text = ts.name
	_tile_w_spin.value = ts.tile_size.x
	_tile_h_spin.value = ts.tile_size.y
	_margin_x_spin.value = ts.margins.x
	_margin_y_spin.value = ts.margins.y
	_sep_x_spin.value = ts.separation.x
	_sep_y_spin.value = ts.separation.y
	_from_godot_tres = ts.origin_kind == "godot_tres"
	_tile_w_spin.editable = not _from_godot_tres
	_tile_h_spin.editable = not _from_godot_tres
	_margin_x_spin.editable = not _from_godot_tres
	_margin_y_spin.editable = not _from_godot_tres
	_sep_x_spin.editable = not _from_godot_tres
	_sep_y_spin.editable = not _from_godot_tres
	_add_terrain_button.disabled = _from_godot_tres
	if _from_godot_tres:
		_info_label.text = "Imported from a Godot .tres — atlas dimensions and terrains are read-only."
	else:
		_info_label.text = "Configure how the source image is sliced into tiles. Add terrains so autotile painting can pick the right tile."
	_rebuild_terrains_list()


func open() -> void:
	PopupSizer.popup_fit(self, {"preferred": Vector2i(640, 520)})
	_name_edit.grab_focus()


func _rebuild_terrains_list() -> void:
	for child in _terrains_root.get_children():
		child.queue_free()
	_terrain_rows.clear()
	if _tileset == null:
		return
	for ts_idx in range(_tileset.terrain_sets.size()):
		var ts: Dictionary = _tileset.terrain_sets[ts_idx]
		var ts_label: Label = Label.new()
		ts_label.text = "Terrain Set %d" % ts_idx
		_terrains_root.add_child(ts_label)
		var terrains: Array = ts.get("terrains", [])
		for t_idx in range(terrains.size()):
			var t: Dictionary = terrains[t_idx]
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			var name_field: LineEdit = LineEdit.new()
			name_field.text = String(t.get("name", "Terrain"))
			name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_field.editable = not _from_godot_tres
			row.add_child(name_field)
			var color_picker: ColorPickerButton = ColorPickerButton.new()
			color_picker.custom_minimum_size = Vector2(60, 0)
			var col_arr: Variant = t.get("color", [1.0, 1.0, 1.0, 1.0])
			var col: Color = Color(1, 1, 1, 1)
			if typeof(col_arr) == TYPE_ARRAY and (col_arr as Array).size() >= 3:
				var arr: Array = col_arr
				var a: float = 1.0 if arr.size() < 4 else float(arr[3])
				col = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
			color_picker.color = col
			color_picker.disabled = _from_godot_tres
			row.add_child(color_picker)
			var del_btn: Button = Button.new()
			del_btn.text = "Remove"
			del_btn.disabled = _from_godot_tres
			del_btn.pressed.connect(_on_remove_terrain.bind(ts_idx, t_idx))
			row.add_child(del_btn)
			_terrains_root.add_child(row)
			_terrain_rows.append({
				"terrain_set": ts_idx,
				"terrain": t_idx,
				"name_field": name_field,
				"color_picker": color_picker,
			})


func _on_add_terrain_pressed() -> void:
	if _tileset == null or _from_godot_tres:
		return
	if _tileset.terrain_sets.is_empty():
		_tileset.ensure_terrain_set(0)
	_tileset.add_terrain(0, "Terrain %d" % _tileset.terrain_count(0), Color(0.6, 0.6, 0.6, 1.0))
	_rebuild_terrains_list()


func _on_remove_terrain(ts_idx: int, t_idx: int) -> void:
	if _tileset == null or _from_godot_tres:
		return
	_tileset.remove_terrain(ts_idx, t_idx)
	_rebuild_terrains_list()


func _on_confirmed() -> void:
	if _tileset == null:
		return
	var updated: Dictionary = {
		"name": _name_edit.text.strip_edges(),
		"tile_size": Vector2i(int(_tile_w_spin.value), int(_tile_h_spin.value)),
		"margins": Vector2i(int(_margin_x_spin.value), int(_margin_y_spin.value)),
		"separation": Vector2i(int(_sep_x_spin.value), int(_sep_y_spin.value)),
		"terrains_by_set": _collect_terrains_from_rows(),
		"is_godot_origin": _from_godot_tres,
	}
	emit_signal("apply_requested", updated)


func _collect_terrains_from_rows() -> Dictionary:
	var by_set: Dictionary = {}
	for entry_v: Variant in _terrain_rows:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var ts_idx: int = int(entry.get("terrain_set", 0))
		var bucket_v: Variant = by_set.get(ts_idx, null)
		var bucket: Array = []
		if typeof(bucket_v) == TYPE_ARRAY:
			bucket = bucket_v
		var name_field: LineEdit = entry.get("name_field", null) as LineEdit
		var color_picker: ColorPickerButton = entry.get("color_picker", null) as ColorPickerButton
		if name_field == null or color_picker == null:
			continue
		var color: Color = color_picker.color
		bucket.append({
			"name": name_field.text.strip_edges(),
			"color": [color.r, color.g, color.b, color.a],
		})
		by_set[ts_idx] = bucket
	return by_set
