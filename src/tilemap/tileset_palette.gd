class_name TilesetPalette
extends DockablePanel

signal close_requested()
signal tileset_chosen(tileset_id: String)
signal tile_chosen(tileset_id: String, atlas_coord: Vector2i, alternative: int)
signal terrain_chosen(tileset_id: String, terrain_set: int, terrain_index: int)

const CHIP_PIXEL_SIZE: int = 32

@onready var _close_button: Button = %CloseButton
@onready var _tileset_option: OptionButton = %TilesetOption
@onready var _delete_tileset_button: Button = %DeleteTilesetButton
@onready var _tab_container: TabContainer = %TabContainer
@onready var _tile_grid_root: Control = %TileGridRoot
@onready var _terrain_list_root: Control = %TerrainListRoot
@onready var _info_label: Label = %InfoLabel

var _tilesets: Array = []
var _current_tileset_id: String = ""
var _current_tileset: TileSetResource = null
var _selected_atlas_coord: Vector2i = Vector2i(-1, -1)
var _selected_terrain_set: int = -1
var _selected_terrain_index: int = -1


func _ready() -> void:
	super._ready()
	ThemeManager.apply_relative_font_size(_info_label, 0.85)
	ThemeManager.theme_applied.connect(_apply_translucent_panel)
	_apply_translucent_panel()
	_close_button.pressed.connect(_on_close_pressed)
	_tileset_option.item_selected.connect(_on_tileset_option_selected)
	_delete_tileset_button.pressed.connect(_on_delete_tileset_pressed)


func refresh_tilesets(tilesets: Array, preferred_id: String) -> void:
	_tilesets = tilesets
	_tileset_option.clear()
	if tilesets.is_empty():
		_tileset_option.add_item("(no tilesets)")
		_tileset_option.disabled = true
		_delete_tileset_button.disabled = true
		_clear_grids()
		_current_tileset_id = ""
		_current_tileset = null
		_info_label.text = "Import a Godot TileSet (.tres) or create one from an image to begin."
		return
	_tileset_option.disabled = false
	_delete_tileset_button.disabled = false
	var preferred_index: int = 0
	for i in range(tilesets.size()):
		var ts: TileSetResource = tilesets[i]
		_tileset_option.add_item(ts.name, i)
		_tileset_option.set_item_metadata(i, ts.id)
		if preferred_id != "" and ts.id == preferred_id:
			preferred_index = i
	_tileset_option.select(preferred_index)
	_select_tileset_by_index(preferred_index)


func current_tileset_id() -> String:
	return _current_tileset_id


func current_tileset() -> TileSetResource:
	return _current_tileset


func _on_tileset_option_selected(index: int) -> void:
	_select_tileset_by_index(index)


func _select_tileset_by_index(index: int) -> void:
	if index < 0 or index >= _tilesets.size():
		_current_tileset_id = ""
		_current_tileset = null
		_clear_grids()
		return
	var ts: TileSetResource = _tilesets[index]
	_current_tileset_id = ts.id
	_current_tileset = ts
	_rebuild_tile_grid()
	_rebuild_terrain_list()
	_info_label.text = "%s · %d×%d tiles · %d×%d px" % [
		ts.name, ts.atlas_columns, ts.atlas_rows, ts.tile_size.x, ts.tile_size.y,
	]
	emit_signal("tileset_chosen", ts.id)


func _on_delete_tileset_pressed() -> void:
	if _current_tileset_id == "":
		return
	emit_signal("tileset_chosen", "__delete__:" + _current_tileset_id)


func _clear_grids() -> void:
	for child in _tile_grid_root.get_children():
		child.queue_free()
	for child in _terrain_list_root.get_children():
		child.queue_free()


func _rebuild_tile_grid() -> void:
	for child in _tile_grid_root.get_children():
		child.queue_free()
	if _current_tileset == null:
		return
	if AppState.current_project == null:
		return
	var tex: ImageTexture = _current_tileset.texture_for_project(AppState.current_project.folder_path)
	if tex == null:
		var placeholder: Label = Label.new()
		placeholder.text = "No texture loaded"
		_tile_grid_root.add_child(placeholder)
		return
	var grid: GridContainer = GridContainer.new()
	grid.columns = max(1, _current_tileset.atlas_columns)
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	_tile_grid_root.add_child(grid)
	for y in range(_current_tileset.atlas_rows):
		for x in range(_current_tileset.atlas_columns):
			var coord: Vector2i = Vector2i(x, y)
			var btn: Button = Button.new()
			btn.toggle_mode = true
			btn.focus_mode = Control.FOCUS_NONE
			btn.custom_minimum_size = Vector2(CHIP_PIXEL_SIZE, CHIP_PIXEL_SIZE)
			btn.set_meta("atlas_coord", coord)
			var icon_tex: AtlasTexture = AtlasTexture.new()
			icon_tex.atlas = tex
			icon_tex.region = _current_tileset.texture_pixel_size_for(coord)
			btn.icon = icon_tex
			btn.expand_icon = true
			btn.tooltip_text = "Tile (%d, %d)" % [coord.x, coord.y]
			if not _current_tileset.has_tile(coord):
				btn.modulate = Color(1, 1, 1, 0.35)
			btn.pressed.connect(_on_tile_button_pressed.bind(coord, btn))
			grid.add_child(btn)


func _rebuild_terrain_list() -> void:
	for child in _terrain_list_root.get_children():
		child.queue_free()
	if _current_tileset == null:
		return
	for ts_idx in range(_current_tileset.terrain_sets.size()):
		var ts: Dictionary = _current_tileset.terrain_sets[ts_idx]
		var ts_label: Label = Label.new()
		ts_label.text = "Terrain Set %d (%s)" % [ts_idx, _terrain_set_mode_name(int(ts.get("mode", 0)))]
		_terrain_list_root.add_child(ts_label)
		var terrains: Array = ts.get("terrains", [])
		for t_idx in range(terrains.size()):
			var t: Dictionary = terrains[t_idx]
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			var swatch: ColorRect = ColorRect.new()
			swatch.custom_minimum_size = Vector2(20, 20)
			var col_arr: Variant = t.get("color", [1.0, 1.0, 1.0, 1.0])
			var col: Color = Color(1, 1, 1, 1)
			if typeof(col_arr) == TYPE_ARRAY and (col_arr as Array).size() >= 3:
				var arr: Array = col_arr
				var a: float = 1.0 if arr.size() < 4 else float(arr[3])
				col = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
			swatch.color = col
			row.add_child(swatch)
			var btn: Button = Button.new()
			btn.toggle_mode = true
			btn.text = String(t.get("name", "Terrain %d" % t_idx))
			btn.focus_mode = Control.FOCUS_NONE
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.pressed.connect(_on_terrain_pressed.bind(ts_idx, t_idx, btn))
			row.add_child(btn)
			_terrain_list_root.add_child(row)


func _terrain_set_mode_name(mode: int) -> String:
	match mode:
		TileSetResource.TERRAIN_MODE_MATCH_CORNERS:
			return "match corners"
		TileSetResource.TERRAIN_MODE_MATCH_SIDES:
			return "match sides"
	return "match corners and sides"


func _on_tile_button_pressed(coord: Vector2i, btn: Button) -> void:
	for child in _tile_grid_root.get_children():
		if child is GridContainer:
			for sub in (child as GridContainer).get_children():
				if sub is Button and sub != btn:
					(sub as Button).button_pressed = false
	btn.button_pressed = true
	_selected_atlas_coord = coord
	_selected_terrain_set = -1
	_selected_terrain_index = -1
	emit_signal("tile_chosen", _current_tileset_id, coord, 0)


func _on_terrain_pressed(ts_idx: int, t_idx: int, btn: Button) -> void:
	for child in _terrain_list_root.get_children():
		if child is HBoxContainer:
			for sub in (child as HBoxContainer).get_children():
				if sub is Button and sub != btn:
					(sub as Button).button_pressed = false
	btn.button_pressed = true
	_selected_atlas_coord = Vector2i(-1, -1)
	_selected_terrain_set = ts_idx
	_selected_terrain_index = t_idx
	emit_signal("terrain_chosen", _current_tileset_id, ts_idx, t_idx)


func _on_close_pressed() -> void:
	emit_signal("close_requested")


func _apply_translucent_panel() -> void:
	ThemeManager.apply_translucent_panel(self)
