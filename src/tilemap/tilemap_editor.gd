class_name TilemapEditor
extends Control

signal back_to_projects_requested()

const SAVE_DEBOUNCE_SEC: float = 0.5

@onready var _world: Node2D = %World
@onready var _camera: EditorCameraController = %Camera
@onready var _bg: ColorRect = %Background
@onready var _layers_root: Node2D = %LayersRoot
@onready var _objects_root: Control = %ObjectsRoot
@onready var _grid_overlay: TileGridOverlay = %GridOverlay
@onready var _toolbar: TilemapToolbar = %Toolbar
@onready var _breadcrumb: BreadcrumbBar = %BreadcrumbBar
@onready var _outliner: BoardOutliner = %BoardOutliner
@onready var _tileset_palette: TilesetPalette = %TilesetPalette
@onready var _layer_panel: LayerListPanel = %LayerListPanel
@onready var _inspector: InspectorPanel = %InspectorPanel
@onready var _new_map_dialog: NewMapDialog = %NewMapDialog
@onready var _import_tileset_dialog: ImportTilesetDialog = %ImportTilesetDialog
@onready var _new_tileset_image_dialog: NewTilesetFromImageDialog = %NewTilesetFromImageDialog
@onready var _tileset_setup_dialog: TilesetSetupDialog = %TilesetSetupDialog
@onready var _export_dialog: ExportMapDialog = %ExportMapDialog
@onready var _confirm_dialog: ConfirmationDialog = %ConfirmDialog
@onready var _info_dialog: AcceptDialog = %InfoDialog
@onready var _image_dialog: FileDialog = %ImageDialog
@onready var _sound_dialog: FileDialog = %SoundDialog

const OVERLAY_SCENE: PackedScene = preload("res://src/tilemap/overlay_object.tscn")

var _tilesets: Dictionary = {}
var _tileset_order: Array[String] = []
var _layer_renderers: Dictionary = {}
var _overlay_objects: Dictionary = {}
var _brush: TileBrush = TileBrush.new()
var _selected_layer_id: String = ""
var _save_timer: Timer
var _painting_active: bool = false
var _painting_tool: String = ""
var _painting_cells_dirty: Dictionary = {}
var _painting_before_state: Dictionary = {}
var _rect_anchor_cell: Vector2i = Vector2i.ZERO
var _rect_active: bool = false
var _selected_object_id: String = ""
var _object_drag_active: bool = false
var _object_drag_offset: Vector2 = Vector2.ZERO
var _object_drag_start_pos: Vector2 = Vector2.ZERO
var _pending_overlay_type: String = ""
var _pending_overlay_world: Vector2 = Vector2.ZERO
var _pending_image_path: String = ""
var _pending_sound_path: String = ""
var _confirm_action: String = ""
var _confirm_payload: Variant = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_camera.make_current()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE_SEC
	_save_timer.timeout.connect(_perform_save)
	add_child(_save_timer)
	_toolbar.action_requested.connect(_on_toolbar_action)
	_tileset_palette.tileset_chosen.connect(_on_tileset_chosen)
	_tileset_palette.tile_chosen.connect(_on_tile_chosen)
	_tileset_palette.terrain_chosen.connect(_on_terrain_chosen)
	_tileset_palette.close_requested.connect(_on_tileset_palette_close)
	_layer_panel.layer_selected.connect(_on_layer_selected)
	_layer_panel.layer_visibility_toggled.connect(_on_layer_visibility_toggled)
	_layer_panel.layer_added.connect(_on_layer_added)
	_layer_panel.layer_removed.connect(_on_layer_removed_requested)
	_layer_panel.layer_moved_up.connect(_on_layer_moved_up)
	_layer_panel.layer_moved_down.connect(_on_layer_moved_down)
	_layer_panel.layer_renamed.connect(_on_layer_renamed)
	_layer_panel.layer_tileset_chosen.connect(_on_layer_tileset_chosen)
	_layer_panel.layer_opacity_changed.connect(_on_layer_opacity_changed)
	_layer_panel.close_requested.connect(_on_layer_panel_close)
	_outliner.close_requested.connect(_on_outliner_close)
	_outliner.new_map_page_requested.connect(_on_outliner_new_map_page_requested)
	_inspector.close_requested.connect(_on_inspector_close)
	_new_map_dialog.map_created.connect(_on_new_map_created)
	_import_tileset_dialog.tileset_import_requested.connect(_on_tileset_import_requested)
	_new_tileset_image_dialog.tileset_creation_requested.connect(_on_tileset_creation_from_image_requested)
	_tileset_setup_dialog.apply_requested.connect(_on_tileset_setup_applied)
	_export_dialog.export_requested.connect(_on_export_requested)
	_confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
	_image_dialog.file_selected.connect(_on_image_overlay_chosen)
	_sound_dialog.file_selected.connect(_on_sound_overlay_chosen)
	History.changed.connect(_on_history_changed)
	AppState.before_navigation.connect(_perform_save)
	AppState.current_map_page_changed.connect(_on_map_page_changed)
	AppState.current_page_kind_changed.connect(_on_page_kind_changed)
	if AppState.current_map_page != null:
		_on_map_page_changed(AppState.current_map_page)
	OpBus.bind_map_editor(self)
	AppState.tileset_changed.connect(_on_tileset_changed)
	tree_exited.connect(_on_tree_exited)


func _on_tree_exited() -> void:
	OpBus.unbind_map_editor()


func _on_tileset_changed(tileset_id: String) -> void:
	if AppState.current_map_page == null:
		return
	_load_tilesets()
	_refresh_tileset_palette()
	for layer: MapLayer in AppState.current_map_page.layers:
		if layer.tileset_id == tileset_id:
			_apply_layer_renderer_binding(layer)
	_refresh_layer_panel()


func apply_remote_map_op(op: Op) -> void:
	if op == null or AppState.current_map_page == null:
		return
	if op.board_id != "" and op.board_id != AppState.current_map_page.id:
		return
	match op.kind:
		OpKinds.SET_MAP_PROPERTY:
			_apply_remote_set_map_property(op)
		OpKinds.MAP_INSERT_LAYER:
			var layer_dict_raw: Variant = op.payload.get("layer", null)
			if typeof(layer_dict_raw) == TYPE_DICTIONARY:
				insert_layer_from_dict(layer_dict_raw, int(op.payload.get("index", AppState.current_map_page.layers.size())))
		OpKinds.MAP_REMOVE_LAYER:
			remove_layer_by_id(String(op.payload.get("layer_id", "")))
		OpKinds.MAP_REORDER_LAYER:
			reorder_layer(String(op.payload.get("layer_id", "")), int(op.payload.get("index", 0)))
		OpKinds.MAP_SET_LAYER_PROPERTY:
			apply_layer_property(String(op.payload.get("layer_id", "")), String(op.payload.get("key", "")), op.payload.get("value", null))
		OpKinds.MAP_SET_LAYER_CELLS:
			_apply_remote_layer_cells(op)
		OpKinds.MAP_ADD_OBJECT:
			var obj_dict_raw: Variant = op.payload.get("object", null)
			if typeof(obj_dict_raw) == TYPE_DICTIONARY:
				spawn_object_from_dict(obj_dict_raw)
		OpKinds.MAP_REMOVE_OBJECT:
			remove_object_by_id(String(op.payload.get("object_id", "")))
		OpKinds.MAP_MOVE_OBJECT:
			var pos_raw: Variant = op.payload.get("position", null)
			if typeof(pos_raw) == TYPE_ARRAY and (pos_raw as Array).size() >= 2:
				var arr: Array = pos_raw
				apply_object_position(String(op.payload.get("object_id", "")), Vector2(float(arr[0]), float(arr[1])))
		OpKinds.MAP_SET_OBJECT_PROPERTY:
			var raw_value: Variant = op.payload.get("value", null)
			if typeof(raw_value) == TYPE_ARRAY and (raw_value as Array).size() == 2 and (op.payload.get("key", "") == "position"):
				raw_value = Vector2(float((raw_value as Array)[0]), float((raw_value as Array)[1]))
			apply_object_property(String(op.payload.get("object_id", "")), String(op.payload.get("key", "")), raw_value)


func _apply_remote_set_map_property(op: Op) -> void:
	var key: String = String(op.payload.get("key", ""))
	if key == "" or AppState.current_map_page == null:
		return
	if not (op.payload as Dictionary).has("value"):
		return
	var value: Variant = op.payload["value"]
	match key:
		"name":
			AppState.current_map_page.name = String(value)
			AppState.emit_signal("navigation_changed")
		"tile_size":
			if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
				var arr: Array = value
				AppState.current_map_page.tile_size = Vector2i(int(arr[0]), int(arr[1]))
				_grid_overlay.set_tile_size(AppState.current_map_page.tile_size)
				_rebuild_layer_renderers(AppState.current_map_page)
		"background_color":
			if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 3:
				var arr_bg: Array = value
				var a: float = 1.0 if arr_bg.size() < 4 else float(arr_bg[3])
				AppState.current_map_page.background_color = Color(float(arr_bg[0]), float(arr_bg[1]), float(arr_bg[2]), a)
				_apply_background_color(AppState.current_map_page)
	request_save()


func _apply_remote_layer_cells(op: Op) -> void:
	var layer_id: String = String(op.payload.get("layer_id", ""))
	if layer_id == "" or AppState.current_map_page == null:
		return
	var cells_raw: Variant = op.payload.get("cells", null)
	if typeof(cells_raw) != TYPE_ARRAY:
		return
	var cells_state: Dictionary = {}
	for entry_v: Variant in (cells_raw as Array):
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var coord_raw: Variant = entry.get("coord", null)
		if typeof(coord_raw) != TYPE_ARRAY or (coord_raw as Array).size() < 2:
			continue
		var coord: Vector2i = Vector2i(int((coord_raw as Array)[0]), int((coord_raw as Array)[1]))
		if entry.get("erased", false):
			cells_state[coord] = null
			continue
		var atlas_raw: Variant = entry.get("atlas", null)
		if typeof(atlas_raw) != TYPE_ARRAY or (atlas_raw as Array).size() < 3:
			continue
		var atlas_arr: Array = atlas_raw
		cells_state[coord] = Vector3i(int(atlas_arr[0]), int(atlas_arr[1]), int(atlas_arr[2]))
	apply_layer_cells(layer_id, cells_state)
	request_save()


func _on_page_kind_changed(kind: String) -> void:
	visible = kind == AppState.PAGE_KIND_MAP


func _on_map_page_changed(page: MapPage) -> void:
	if page == null:
		return
	_painting_active = false
	_clear_overlay_state()
	_clear_layer_renderers()
	_load_tilesets()
	_apply_background_color(page)
	_grid_overlay.set_tile_size(page.tile_size)
	_rebuild_layer_renderers(page)
	_rebuild_overlay_objects(page)
	if page.layers.size() > 0:
		_selected_layer_id = (page.layers[0] as MapLayer).id
	else:
		_selected_layer_id = ""
	if page.camera_zoom > 0.0:
		_camera.zoom = Vector2(page.camera_zoom, page.camera_zoom)
	else:
		_camera.zoom = Vector2.ONE
	_apply_initial_map_camera_position(page)
	_refresh_layer_panel()
	_refresh_tileset_palette()
	_toolbar.highlight_tool(_brush.tool)
	_breadcrumb.queue_redraw()


func _apply_background_color(page: MapPage) -> void:
	if _bg != null:
		_bg.color = page.background_color


func _compute_map_content_bbox(page: MapPage) -> Rect2:
	var has_any: bool = false
	var min_p: Vector2 = Vector2.ZERO
	var max_p: Vector2 = Vector2.ZERO
	for entry_v: Variant in page.objects:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry_v
		var pos_raw: Variant = d.get("position", null)
		var size_raw: Variant = d.get("size", null)
		if typeof(pos_raw) != TYPE_ARRAY or (pos_raw as Array).size() < 2:
			continue
		var pos_arr: Array = pos_raw
		var obj_pos: Vector2 = Vector2(float(pos_arr[0]), float(pos_arr[1]))
		var obj_size: Vector2 = Vector2(128.0, 64.0)
		if typeof(size_raw) == TYPE_ARRAY and (size_raw as Array).size() >= 2:
			var size_arr: Array = size_raw
			obj_size = Vector2(float(size_arr[0]), float(size_arr[1]))
		var p0: Vector2 = obj_pos
		var p1: Vector2 = obj_pos + obj_size
		if not has_any:
			min_p = p0
			max_p = p1
			has_any = true
		else:
			min_p.x = min(min_p.x, p0.x)
			min_p.y = min(min_p.y, p0.y)
			max_p.x = max(max_p.x, p1.x)
			max_p.y = max(max_p.y, p1.y)
	var tile_w: float = float(page.tile_size.x)
	var tile_h: float = float(page.tile_size.y)
	for layer_v: Variant in page.layers:
		var layer: MapLayer = layer_v
		if layer == null or layer.cells.is_empty():
			continue
		var used: Rect2i = layer.used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			continue
		var p0: Vector2 = Vector2(float(used.position.x) * tile_w, float(used.position.y) * tile_h)
		var p1: Vector2 = p0 + Vector2(float(used.size.x) * tile_w, float(used.size.y) * tile_h)
		if not has_any:
			min_p = p0
			max_p = p1
			has_any = true
		else:
			min_p.x = min(min_p.x, p0.x)
			min_p.y = min(min_p.y, p0.y)
			max_p.x = max(max_p.x, p1.x)
			max_p.y = max(max_p.y, p1.y)
	if not has_any:
		return Rect2()
	return Rect2(min_p, max_p - min_p)


func _apply_initial_map_camera_position(page: MapPage) -> void:
	if _camera == null:
		return
	var bbox: Rect2 = _compute_map_content_bbox(page)
	if bbox.size == Vector2.ZERO:
		_camera.position = page.camera_position
		return
	var saved_in_content: bool = bbox.grow(max(bbox.size.x, bbox.size.y) * 0.5).has_point(page.camera_position)
	if saved_in_content:
		_camera.position = page.camera_position
	else:
		_camera.position = bbox.position + bbox.size * 0.5


func _clear_layer_renderers() -> void:
	for renderer_v: Variant in _layer_renderers.values():
		var renderer: TileLayerRenderer = renderer_v
		if is_instance_valid(renderer):
			renderer.queue_free()
	_layer_renderers.clear()


func _clear_overlay_state() -> void:
	for child in _objects_root.get_children():
		child.queue_free()
	_overlay_objects.clear()
	_selected_object_id = ""


func _load_tilesets() -> void:
	_tilesets.clear()
	_tileset_order.clear()
	if AppState.current_project == null:
		return
	for entry_v: Variant in AppState.current_project.list_tilesets():
		var entry: Dictionary = entry_v
		var ts_id: String = String(entry.get("id", ""))
		var ts: TileSetResource = AppState.current_project.read_tileset(ts_id)
		if ts == null:
			continue
		_tilesets[ts_id] = ts
		_tileset_order.append(ts_id)


func _rebuild_layer_renderers(page: MapPage) -> void:
	for layer: MapLayer in page.layers:
		_spawn_layer_renderer(layer)


func _spawn_layer_renderer(layer: MapLayer) -> TileLayerRenderer:
	var renderer: TileLayerRenderer = TileLayerRenderer.new()
	_layers_root.add_child(renderer)
	var ts: TileSetResource = _tilesets.get(layer.tileset_id, null)
	var project_root: String = AppState.current_project.folder_path if AppState.current_project != null else ""
	renderer.bind_layer(layer, ts, AppState.current_map_page.tile_size, project_root)
	_layer_renderers[layer.id] = renderer
	return renderer


func _rebuild_overlay_objects(page: MapPage) -> void:
	for obj_v: Variant in page.objects:
		if typeof(obj_v) != TYPE_DICTIONARY:
			continue
		var obj: Dictionary = obj_v
		_spawn_overlay_node(obj)


func _spawn_overlay_node(obj: Dictionary) -> Control:
	var inst: OverlayObject = OVERLAY_SCENE.instantiate()
	_objects_root.add_child(inst)
	inst.bind_object(obj)
	_overlay_objects[String(obj.get("id", ""))] = inst
	return inst


func _refresh_layer_panel() -> void:
	if AppState.current_map_page == null:
		return
	var ts_arr: Array = []
	for ts_id: String in _tileset_order:
		ts_arr.append(_tilesets[ts_id])
	_layer_panel.refresh(AppState.current_map_page.layers, ts_arr, _selected_layer_id)


func _refresh_tileset_palette() -> void:
	var ts_arr: Array = []
	for ts_id: String in _tileset_order:
		ts_arr.append(_tilesets[ts_id])
	var preferred: String = _brush.tileset_id
	if preferred == "" and not _tileset_order.is_empty():
		preferred = _tileset_order[0]
	_tileset_palette.refresh_tilesets(ts_arr, preferred)


func _on_history_changed() -> void:
	pass


func _on_toolbar_action(action: String, payload: Variant) -> void:
	match action:
		TilemapToolbar.ACTION_BACK_TO_PROJECTS:
			_perform_save()
			emit_signal("back_to_projects_requested")
		TilemapToolbar.ACTION_SAVE:
			_perform_save()
		TilemapToolbar.ACTION_UNDO:
			History.undo()
		TilemapToolbar.ACTION_REDO:
			History.redo()
		TilemapToolbar.ACTION_SET_TOOL:
			_brush.tool = String(payload)
		TilemapToolbar.ACTION_IMPORT_TILESET:
			_import_tileset_dialog.open()
		TilemapToolbar.ACTION_NEW_TILESET_FROM_IMAGE:
			_new_tileset_image_dialog.open()
		TilemapToolbar.ACTION_NEW_LAYER:
			_on_layer_added()
		TilemapToolbar.ACTION_TOGGLE_TILESET_PALETTE:
			_tileset_palette.visible = bool(payload)
		TilemapToolbar.ACTION_TOGGLE_LAYER_PANEL:
			_layer_panel.visible = bool(payload)
		TilemapToolbar.ACTION_TOGGLE_INSPECTOR:
			_inspector.visible = bool(payload)
		TilemapToolbar.ACTION_TOGGLE_OUTLINER:
			_outliner.visible = bool(payload)
		TilemapToolbar.ACTION_EXPORT:
			_open_export_dialog()
		TilemapToolbar.ACTION_TILESET_SETUP:
			_open_tileset_setup_dialog()
		TilemapToolbar.ACTION_ADD_OVERLAY:
			_begin_add_overlay(String(payload))


func open_new_map_dialog() -> void:
	_new_map_dialog.open()


func _on_outliner_new_map_page_requested() -> void:
	open_new_map_dialog()


func _on_new_map_created(map_name: String, tile_size: Vector2i) -> void:
	if AppState.current_project == null:
		return
	var page: MapPage = AppState.current_project.create_map_page(map_name, tile_size)
	if page == null:
		return
	_broadcast_create_map_page(page)
	AppState.emit_signal("map_page_modified", page.id)
	AppState.navigate_to_map_page(page.id)


func _broadcast_create_map_page(page: MapPage) -> void:
	if page == null or not OpBus.has_project() or OpBus.is_applying_remote():
		return
	OpBus.record_local_change(OpKinds.CREATE_MAP_PAGE, {
		"map_id": page.id,
		"name": page.name,
		"tile_size": [page.tile_size.x, page.tile_size.y],
		"page": page.to_dict(),
	}, "")


func _broadcast_tileset_upsert(ts: TileSetResource, kind: String) -> void:
	if ts == null or ts.id == "" or not OpBus.has_project() or OpBus.is_applying_remote():
		return
	OpBus.record_local_change(kind, {
		"tileset_id": ts.id,
		"tileset": ts.to_dict(),
	}, "")


func _broadcast_tileset_delete(tileset_id: String) -> void:
	if tileset_id == "" or not OpBus.has_project() or OpBus.is_applying_remote():
		return
	OpBus.record_local_change(OpKinds.DELETE_TILESET, {
		"tileset_id": tileset_id,
	}, "")


func _on_tileset_import_requested(name_str: String, tres_path: String, godot_root: String) -> void:
	var result: TilesetImporter.ImportResult = TilesetImporter.import_from_tres(AppState.current_project, name_str, tres_path, godot_root)
	if not result.ok:
		_show_info(result.error_message)
		return
	_after_tileset_added(result.tileset)
	_show_info("Imported tileset '%s' with %d tiles." % [result.tileset.name, result.tile_count])


func _on_tileset_creation_from_image_requested(name_str: String, image_source_path: String, tile_size: Vector2i, margins: Vector2i, separation: Vector2i) -> void:
	var result: TilesetImporter.ImportResult = TilesetImporter.create_from_image(AppState.current_project, name_str, image_source_path, tile_size, margins, separation)
	if not result.ok:
		_show_info(result.error_message)
		return
	_after_tileset_added(result.tileset)


func _after_tileset_added(ts: TileSetResource) -> void:
	_load_tilesets()
	_brush.tileset_id = ts.id
	_refresh_tileset_palette()
	_refresh_layer_panel()


func _on_tileset_chosen(tileset_id: String) -> void:
	if tileset_id.begins_with("__delete__:"):
		var ts_id: String = tileset_id.substr("__delete__:".length())
		_request_delete_tileset(ts_id)
		return
	_brush.tileset_id = tileset_id
	if AppState.current_map_page != null and _selected_layer_id != "":
		var layer: MapLayer = AppState.current_map_page.find_layer(_selected_layer_id)
		if layer != null and layer.tileset_id == "":
			layer.tileset_id = tileset_id
			_apply_layer_renderer_binding(layer)
			_refresh_layer_panel()
			request_save()


func _request_delete_tileset(tileset_id: String) -> void:
	_confirm_action = "delete_tileset"
	_confirm_payload = tileset_id
	_confirm_dialog.dialog_text = "Delete this tileset? Layers using it will be unbound. Painted cells remain but won't render until re-bound."
	_confirm_dialog.popup_centered()


func _on_confirm_dialog_confirmed() -> void:
	match _confirm_action:
		"delete_tileset":
			var ts_id: String = String(_confirm_payload)
			if AppState.current_project != null:
				AppState.current_project.delete_tileset(ts_id)
				_broadcast_tileset_delete(ts_id)
				if AppState.current_map_page != null:
					for layer: MapLayer in AppState.current_map_page.layers:
						if layer.tileset_id == ts_id:
							layer.tileset_id = ""
							_apply_layer_renderer_binding(layer)
				_load_tilesets()
				if _brush.tileset_id == ts_id:
					_brush.clear()
				_refresh_tileset_palette()
				_refresh_layer_panel()
				request_save()
		"delete_layer":
			var layer_id: String = String(_confirm_payload)
			_remove_layer_via_history(layer_id)
		"remove_object":
			var obj_id: String = String(_confirm_payload)
			_remove_object_via_history(obj_id)
	_confirm_action = ""
	_confirm_payload = null


func _on_tile_chosen(tileset_id: String, atlas_coord: Vector2i, alternative: int) -> void:
	_brush.set_atlas_tile(tileset_id, atlas_coord, alternative)


func _on_terrain_chosen(tileset_id: String, terrain_set: int, terrain_index: int) -> void:
	_brush.set_terrain(tileset_id, terrain_set, terrain_index)


func _on_layer_selected(layer_id: String) -> void:
	_selected_layer_id = layer_id
	_refresh_layer_panel()


func _on_layer_visibility_toggled(layer_id: String, value: bool) -> void:
	History.push(MapModifyLayerPropertyCommand.new(self, layer_id, "visible", not value, value))


func _on_layer_added() -> void:
	if AppState.current_map_page == null:
		return
	var new_layer: MapLayer = MapLayer.make_new(Uuid.v4(), "Layer %d" % (AppState.current_map_page.layers.size() + 1))
	new_layer.tileset_id = _brush.tileset_id
	if new_layer.tileset_id == "" and not _tileset_order.is_empty():
		new_layer.tileset_id = _tileset_order[0]
	History.push(MapLayerCommand.make_add(self, new_layer.to_dict(), AppState.current_map_page.layers.size()))


func _on_layer_removed_requested(layer_id: String) -> void:
	if AppState.current_map_page == null or AppState.current_map_page.layers.size() <= 1:
		return
	_confirm_action = "delete_layer"
	_confirm_payload = layer_id
	_confirm_dialog.dialog_text = "Delete this layer and all its painted cells?"
	_confirm_dialog.popup_centered()


func _remove_layer_via_history(layer_id: String) -> void:
	if AppState.current_map_page == null:
		return
	var idx: int = AppState.current_map_page.layer_index_of(layer_id)
	if idx < 0:
		return
	var layer: MapLayer = AppState.current_map_page.layers[idx]
	History.push(MapLayerCommand.make_remove(self, layer.to_dict(), idx))


func _on_layer_moved_up(layer_id: String) -> void:
	if AppState.current_map_page == null:
		return
	var idx: int = AppState.current_map_page.layer_index_of(layer_id)
	if idx <= 0:
		return
	History.push(MapLayerCommand.make_reorder(self, layer_id, idx, idx - 1))


func _on_layer_moved_down(layer_id: String) -> void:
	if AppState.current_map_page == null:
		return
	var idx: int = AppState.current_map_page.layer_index_of(layer_id)
	if idx < 0 or idx >= AppState.current_map_page.layers.size() - 1:
		return
	History.push(MapLayerCommand.make_reorder(self, layer_id, idx, idx + 1))


func _on_layer_renamed(layer_id: String, new_name: String) -> void:
	if AppState.current_map_page == null:
		return
	var layer: MapLayer = AppState.current_map_page.find_layer(layer_id)
	if layer == null:
		return
	if new_name == "" or layer.name == new_name:
		return
	History.push(MapModifyLayerPropertyCommand.new(self, layer_id, "name", layer.name, new_name))


func _on_layer_tileset_chosen(layer_id: String, tileset_id: String) -> void:
	if AppState.current_map_page == null:
		return
	var layer: MapLayer = AppState.current_map_page.find_layer(layer_id)
	if layer == null or layer.tileset_id == tileset_id:
		return
	History.push(MapModifyLayerPropertyCommand.new(self, layer_id, "tileset_id", layer.tileset_id, tileset_id))


func _on_layer_opacity_changed(layer_id: String, value: float) -> void:
	if AppState.current_map_page == null:
		return
	var layer: MapLayer = AppState.current_map_page.find_layer(layer_id)
	if layer == null or abs(layer.opacity - value) < 0.001:
		return
	History.push(MapModifyLayerPropertyCommand.new(self, layer_id, "opacity", layer.opacity, value))


func _on_outliner_close() -> void:
	_outliner.visible = false


func _on_inspector_close() -> void:
	_inspector.visible = false


func _on_layer_panel_close() -> void:
	_layer_panel.visible = false


func _on_tileset_palette_close() -> void:
	_tileset_palette.visible = false


func apply_layer_cells(layer_id: String, cells_state: Dictionary) -> void:
	if AppState.current_map_page == null:
		return
	var layer: MapLayer = AppState.current_map_page.find_layer(layer_id)
	if layer == null:
		return
	for coord_v: Variant in cells_state.keys():
		var coord: Vector2i = coord_v
		var data_v: Variant = cells_state[coord]
		if typeof(data_v) == TYPE_VECTOR3I:
			var data: Vector3i = data_v
			if data.x < 0 or data.y < 0:
				layer.erase_cell(coord)
			else:
				layer.cells[coord] = data
		elif data_v == null:
			layer.erase_cell(coord)
	var renderer: TileLayerRenderer = _layer_renderers.get(layer_id, null)
	if renderer != null:
		renderer.refresh()


func apply_layer_property(layer_id: String, key: String, value: Variant) -> void:
	if AppState.current_map_page == null:
		return
	var layer: MapLayer = AppState.current_map_page.find_layer(layer_id)
	if layer == null:
		return
	match key:
		"visible":
			layer.visible = bool(value)
		"opacity":
			layer.opacity = float(value)
		"name":
			layer.name = String(value)
		"tileset_id":
			layer.tileset_id = String(value)
		"locked":
			layer.locked = bool(value)
	_apply_layer_renderer_binding(layer)
	_refresh_layer_panel()


func _apply_layer_renderer_binding(layer: MapLayer) -> void:
	var renderer: TileLayerRenderer = _layer_renderers.get(layer.id, null)
	if renderer == null:
		return
	var ts: TileSetResource = _tilesets.get(layer.tileset_id, null)
	var project_root: String = AppState.current_project.folder_path if AppState.current_project != null else ""
	renderer.bind_layer(layer, ts, AppState.current_map_page.tile_size, project_root)


func insert_layer_from_dict(d: Dictionary, target_index: int) -> void:
	if AppState.current_map_page == null:
		return
	var layer: MapLayer = MapLayer.from_dict(d)
	var clamped: int = clamp(target_index, 0, AppState.current_map_page.layers.size())
	AppState.current_map_page.layers.insert(clamped, layer)
	_spawn_layer_renderer(layer)
	_selected_layer_id = layer.id
	_refresh_layer_panel()


func remove_layer_by_id(layer_id: String) -> void:
	if AppState.current_map_page == null:
		return
	AppState.current_map_page.remove_layer(layer_id)
	var renderer_v: Variant = _layer_renderers.get(layer_id, null)
	if renderer_v != null:
		var renderer: TileLayerRenderer = renderer_v
		if is_instance_valid(renderer):
			renderer.queue_free()
		_layer_renderers.erase(layer_id)
	if _selected_layer_id == layer_id:
		_selected_layer_id = ""
		if AppState.current_map_page.layers.size() > 0:
			_selected_layer_id = (AppState.current_map_page.layers[0] as MapLayer).id
	_refresh_layer_panel()


func reorder_layer(layer_id: String, new_index: int) -> void:
	if AppState.current_map_page == null:
		return
	AppState.current_map_page.move_layer(layer_id, new_index)
	for child in _layers_root.get_children():
		child.queue_free()
	_layer_renderers.clear()
	for layer: MapLayer in AppState.current_map_page.layers:
		_spawn_layer_renderer(layer)
	_refresh_layer_panel()


func spawn_object_from_dict(d: Dictionary) -> void:
	if AppState.current_map_page == null:
		return
	var obj_id: String = String(d.get("id", ""))
	if obj_id == "":
		obj_id = Uuid.v4()
		d["id"] = obj_id
	for i in range(AppState.current_map_page.objects.size()):
		var existing_v: Variant = AppState.current_map_page.objects[i]
		if typeof(existing_v) == TYPE_DICTIONARY and String((existing_v as Dictionary).get("id", "")) == obj_id:
			AppState.current_map_page.objects[i] = d.duplicate(true)
			var existing_node_v: Variant = _overlay_objects.get(obj_id, null)
			if existing_node_v != null and is_instance_valid(existing_node_v):
				(existing_node_v as Control).queue_free()
				_overlay_objects.erase(obj_id)
			_spawn_overlay_node(d)
			return
	AppState.current_map_page.objects.append(d.duplicate(true))
	_spawn_overlay_node(d)


func remove_object_by_id(object_id: String) -> void:
	if AppState.current_map_page == null:
		return
	for i in range(AppState.current_map_page.objects.size() - 1, -1, -1):
		var entry_v: Variant = AppState.current_map_page.objects[i]
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		if String((entry_v as Dictionary).get("id", "")) == object_id:
			AppState.current_map_page.objects.remove_at(i)
			break
	var node_v: Variant = _overlay_objects.get(object_id, null)
	if node_v != null and is_instance_valid(node_v):
		(node_v as Control).queue_free()
	_overlay_objects.erase(object_id)
	if _selected_object_id == object_id:
		_selected_object_id = ""


func apply_object_position(object_id: String, world_pos: Vector2) -> void:
	if AppState.current_map_page == null:
		return
	for entry_v: Variant in AppState.current_map_page.objects:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry_v
		if String(d.get("id", "")) == object_id:
			d["position"] = [world_pos.x, world_pos.y]
			break
	var node_v: Variant = _overlay_objects.get(object_id, null)
	if node_v != null and is_instance_valid(node_v):
		(node_v as OverlayObject).set_world_position(world_pos)


func apply_object_property(object_id: String, key: String, value: Variant) -> void:
	if AppState.current_map_page == null:
		return
	for entry_v: Variant in AppState.current_map_page.objects:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry_v
		if String(d.get("id", "")) == object_id:
			d[key] = value
			break
	var node_v: Variant = _overlay_objects.get(object_id, null)
	if node_v != null and is_instance_valid(node_v):
		(node_v as OverlayObject).refresh()


func request_save() -> void:
	AppState.mark_dirty()
	if _save_timer != null:
		if _save_timer.time_left > 0.0:
			_save_timer.stop()
		_save_timer.start()


func _perform_save() -> void:
	if AppState.current_map_page == null:
		return
	AppState.current_map_page.camera_position = _camera.position
	AppState.current_map_page.camera_zoom = _camera.zoom.x
	AppState.save_current_map_page()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb_w: InputEventMouseButton = event as InputEventMouseButton
		if mb_w.pressed and (mb_w.button_index == MOUSE_BUTTON_WHEEL_UP or mb_w.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if _is_canvas_hovered():
				var factor: float = EditorCameraController.ZOOM_STEP if mb_w.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / EditorCameraController.ZOOM_STEP
				_camera.zoom_at_screen(mb_w.position, factor)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if not _is_canvas_hovered():
					return
				_handle_left_press(mb)
			else:
				_handle_left_release(mb)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if not _is_canvas_hovered():
				return
			_handle_right_press(mb)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_left_press(mb: InputEventMouseButton) -> void:
	var world_pos: Vector2 = _camera.screen_to_world(mb.position)
	var hit_object: OverlayObject = _overlay_at_world(world_pos)
	if hit_object != null and _brush.tool == TileBrush.TOOL_SELECT:
		_select_overlay(hit_object)
		_object_drag_active = true
		_object_drag_offset = world_pos - hit_object.world_position()
		_object_drag_start_pos = hit_object.world_position()
		get_viewport().set_input_as_handled()
		return
	if AppState.current_map_page == null:
		return
	var cell: Vector2i = TileLayerRenderer.world_to_cell(world_pos, AppState.current_map_page.tile_size)
	match _brush.tool:
		TileBrush.TOOL_PAINT, TileBrush.TOOL_ERASE:
			_begin_paint_stroke(_brush.tool)
			_apply_brush_at_cell(cell)
			get_viewport().set_input_as_handled()
		TileBrush.TOOL_FILL:
			_perform_fill(cell)
			get_viewport().set_input_as_handled()
		TileBrush.TOOL_RECT:
			_rect_anchor_cell = cell
			_rect_active = true
			_grid_overlay.set_rect_preview(Rect2i(cell, Vector2i.ONE))
			get_viewport().set_input_as_handled()
		TileBrush.TOOL_PICK:
			_pick_at_cell(cell)
			get_viewport().set_input_as_handled()
		TileBrush.TOOL_SELECT:
			_clear_object_selection()
			get_viewport().set_input_as_handled()


func _handle_left_release(_mb: InputEventMouseButton) -> void:
	if _painting_active:
		_commit_paint_stroke()
	if _rect_active:
		_finish_rect()
	if _object_drag_active:
		_finish_object_drag()


func _handle_right_press(mb: InputEventMouseButton) -> void:
	var world_pos: Vector2 = _camera.screen_to_world(mb.position)
	var hit_object: OverlayObject = _overlay_at_world(world_pos)
	if hit_object != null:
		_request_remove_object(hit_object.object_id())
		get_viewport().set_input_as_handled()
		return
	if AppState.current_map_page == null:
		return
	if _selected_layer_id == "":
		return
	var cell: Vector2i = TileLayerRenderer.world_to_cell(world_pos, AppState.current_map_page.tile_size)
	_begin_paint_stroke(TileBrush.TOOL_ERASE)
	_apply_brush_at_cell(cell)
	get_viewport().set_input_as_handled()


func _handle_mouse_motion(motion: InputEventMouseMotion) -> void:
	var world_pos: Vector2 = _camera.screen_to_world(motion.position)
	if AppState.current_map_page == null:
		return
	var cell: Vector2i = TileLayerRenderer.world_to_cell(world_pos, AppState.current_map_page.tile_size)
	_update_brush_preview(cell)
	if _painting_active:
		_apply_brush_at_cell(cell)
	if _rect_active:
		var minx: int = min(_rect_anchor_cell.x, cell.x)
		var miny: int = min(_rect_anchor_cell.y, cell.y)
		var maxx: int = max(_rect_anchor_cell.x, cell.x)
		var maxy: int = max(_rect_anchor_cell.y, cell.y)
		_grid_overlay.set_rect_preview(Rect2i(Vector2i(minx, miny), Vector2i(maxx - minx + 1, maxy - miny + 1)))
	if _object_drag_active and _selected_object_id != "":
		var obj_node: OverlayObject = _overlay_objects.get(_selected_object_id, null)
		if obj_node != null:
			obj_node.set_world_position(world_pos - _object_drag_offset)


func _update_brush_preview(cell: Vector2i) -> void:
	if _brush.tool == TileBrush.TOOL_PICK or _brush.tool == TileBrush.TOOL_SELECT:
		_grid_overlay.clear_preview()
		return
	if not _brush.is_paintable() and _brush.tool != TileBrush.TOOL_ERASE:
		_grid_overlay.clear_preview()
		return
	var ts: TileSetResource = _tilesets.get(_brush.tileset_id, null)
	var preview_coord: Vector2i = _brush.atlas_coord
	if _brush.mode == TileBrush.MODE_TERRAIN and ts != null:
		preview_coord = AutotileEngine.pick_tile_for_terrain(
			ts, _brush.terrain_set, _brush.terrain_index, cell, _terrain_at_callable_for_layer(_selected_layer_id, ts, _brush.terrain_set)
		)
	var project_root: String = AppState.current_project.folder_path if AppState.current_project != null else ""
	_grid_overlay.set_brush_preview([cell], preview_coord, ts, project_root)


func _begin_paint_stroke(tool: String) -> void:
	if AppState.current_map_page == null or _selected_layer_id == "":
		return
	_painting_active = true
	_painting_tool = tool
	_painting_cells_dirty = {}
	_painting_before_state = {}


func _commit_paint_stroke() -> void:
	if not _painting_active:
		return
	_painting_active = false
	if _painting_cells_dirty.is_empty():
		return
	History.push_already_done(MapSetCellsCommand.new(self, _selected_layer_id, _painting_before_state, _painting_cells_dirty))
	request_save()
	_painting_cells_dirty = {}
	_painting_before_state = {}


func _finish_rect() -> void:
	_rect_active = false
	if AppState.current_map_page == null or _selected_layer_id == "":
		_grid_overlay.preview_rect_active = false
		return
	var rect: Rect2i = _grid_overlay.preview_rect
	_grid_overlay.preview_rect_active = false
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var layer: MapLayer = AppState.current_map_page.find_layer(_selected_layer_id)
	if layer == null:
		return
	var before: Dictionary = {}
	var after: Dictionary = {}
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var coord: Vector2i = Vector2i(x, y)
			before[coord] = _capture_cell(layer, coord)
			after[coord] = _resolve_brush_for_cell(layer, coord)
	History.push(MapSetCellsCommand.new(self, _selected_layer_id, before, after))


func _finish_object_drag() -> void:
	_object_drag_active = false
	if _selected_object_id == "":
		return
	var node: OverlayObject = _overlay_objects.get(_selected_object_id, null)
	if node == null:
		return
	var to_pos: Vector2 = node.world_position()
	if to_pos == _object_drag_start_pos:
		return
	History.push_already_done(MapMoveObjectsCommand.new(self, [{
		"id": _selected_object_id,
		"from": [_object_drag_start_pos.x, _object_drag_start_pos.y],
		"to": [to_pos.x, to_pos.y],
	}]))
	for entry_v: Variant in AppState.current_map_page.objects:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry_v
		if String(d.get("id", "")) == _selected_object_id:
			d["position"] = [to_pos.x, to_pos.y]
			break


func _apply_brush_at_cell(cell: Vector2i) -> void:
	if AppState.current_map_page == null or _selected_layer_id == "":
		return
	if _painting_cells_dirty.has(cell):
		return
	var layer: MapLayer = AppState.current_map_page.find_layer(_selected_layer_id)
	if layer == null:
		return
	var before_value: Variant = _capture_cell(layer, cell)
	var after_value: Variant = null
	if _painting_tool == TileBrush.TOOL_ERASE:
		after_value = Vector3i(-1, -1, 0)
	else:
		after_value = _resolve_brush_for_cell(layer, cell)
	_painting_before_state[cell] = before_value
	_painting_cells_dirty[cell] = after_value
	_apply_value_immediately(layer, cell, after_value)
	if _brush.mode == TileBrush.MODE_TERRAIN and _painting_tool == TileBrush.TOOL_PAINT:
		_repaint_neighbours_for_terrain(layer, cell)


func _capture_cell(layer: MapLayer, cell: Vector2i) -> Vector3i:
	if layer.has_cell(cell):
		var data: Vector3i = layer.cells[cell]
		return data
	return Vector3i(-1, -1, 0)


func _resolve_brush_for_cell(layer: MapLayer, cell: Vector2i) -> Vector3i:
	var ts: TileSetResource = _tilesets.get(layer.tileset_id, null)
	if ts == null and _brush.tileset_id != "":
		ts = _tilesets.get(_brush.tileset_id, null)
	if ts == null:
		return Vector3i(-1, -1, 0)
	if _brush.mode == TileBrush.MODE_TERRAIN:
		var picked: Vector2i = AutotileEngine.pick_tile_for_terrain(
			ts, _brush.terrain_set, _brush.terrain_index, cell, _terrain_at_callable_for_layer(_selected_layer_id, ts, _brush.terrain_set)
		)
		if picked.x < 0:
			return Vector3i(-1, -1, 0)
		return Vector3i(picked.x, picked.y, 0)
	if _brush.mode == TileBrush.MODE_ATLAS_TILE and _brush.atlas_coord.x >= 0:
		return Vector3i(_brush.atlas_coord.x, _brush.atlas_coord.y, _brush.alternative)
	return Vector3i(-1, -1, 0)


func _apply_value_immediately(layer: MapLayer, cell: Vector2i, value: Variant) -> void:
	if typeof(value) == TYPE_VECTOR3I:
		var v: Vector3i = value
		if v.x < 0 or v.y < 0:
			layer.erase_cell(cell)
		else:
			layer.cells[cell] = v
	var renderer: TileLayerRenderer = _layer_renderers.get(layer.id, null)
	if renderer != null:
		renderer.queue_redraw()


func _repaint_neighbours_for_terrain(layer: MapLayer, target_cell: Vector2i) -> void:
	var ts: TileSetResource = _tilesets.get(layer.tileset_id, null)
	if ts == null:
		return
	for nbr_v: Variant in AutotileEngine.collect_neighbours(target_cell):
		var nbr: Vector2i = nbr_v
		if not layer.has_cell(nbr):
			continue
		var nbr_terrain: int = ts.tile_terrain(Vector2i(layer.cells[nbr].x, layer.cells[nbr].y))
		if nbr_terrain < 0:
			continue
		var picked: Vector2i = AutotileEngine.pick_tile_for_terrain(
			ts, _brush.terrain_set, nbr_terrain, nbr,
			_terrain_at_callable_for_layer(_selected_layer_id, ts, _brush.terrain_set)
		)
		if picked.x < 0:
			continue
		var current: Vector3i = layer.cells[nbr]
		if current.x == picked.x and current.y == picked.y:
			continue
		if not _painting_before_state.has(nbr):
			_painting_before_state[nbr] = current
		var new_value: Vector3i = Vector3i(picked.x, picked.y, 0)
		_painting_cells_dirty[nbr] = new_value
		layer.cells[nbr] = new_value
	var renderer: TileLayerRenderer = _layer_renderers.get(layer.id, null)
	if renderer != null:
		renderer.queue_redraw()


func _terrain_at_callable_for_layer(layer_id: String, ts: TileSetResource, terrain_set: int) -> Callable:
	if AppState.current_map_page == null:
		return Callable()
	var layer: MapLayer = AppState.current_map_page.find_layer(layer_id)
	if layer == null:
		return Callable()
	var snapshot: Dictionary = AutotileEngine.snapshot_layer_terrains(layer, ts, terrain_set)
	for coord_v: Variant in _painting_cells_dirty.keys():
		var coord: Vector2i = coord_v
		var data_v: Variant = _painting_cells_dirty[coord]
		if typeof(data_v) != TYPE_VECTOR3I:
			continue
		var data: Vector3i = data_v
		if data.x < 0:
			snapshot.erase(coord)
			continue
		if not ts.has_tile(Vector2i(data.x, data.y)):
			snapshot.erase(coord)
			continue
		if ts.tile_terrain_set(Vector2i(data.x, data.y)) != terrain_set:
			snapshot.erase(coord)
			continue
		snapshot[coord] = ts.tile_terrain(Vector2i(data.x, data.y))
	return func(c: Vector2i) -> int:
		if snapshot.has(c):
			return int(snapshot[c])
		return AutotileEngine.TERRAIN_NONE


func _perform_fill(start_cell: Vector2i) -> void:
	if AppState.current_map_page == null or _selected_layer_id == "":
		return
	var layer: MapLayer = AppState.current_map_page.find_layer(_selected_layer_id)
	if layer == null:
		return
	var before: Dictionary = {}
	var after: Dictionary = {}
	var visited: Dictionary = {}
	var queue: Array = [start_cell]
	var origin: Vector3i = _capture_cell(layer, start_cell)
	var max_cells: int = 4096
	var bounds: Rect2i = _viewport_cell_bounds()
	while not queue.is_empty():
		var c_v: Variant = queue.pop_back()
		var c: Vector2i = c_v
		if visited.has(c):
			continue
		if not bounds.has_point(c):
			continue
		visited[c] = true
		var current: Vector3i = _capture_cell(layer, c)
		if current != origin:
			continue
		before[c] = current
		after[c] = _resolve_brush_for_cell(layer, c)
		if before.size() > max_cells:
			break
		queue.append(c + Vector2i(1, 0))
		queue.append(c + Vector2i(-1, 0))
		queue.append(c + Vector2i(0, 1))
		queue.append(c + Vector2i(0, -1))
	if before.is_empty():
		return
	History.push(MapSetCellsCommand.new(self, _selected_layer_id, before, after))


func _viewport_cell_bounds() -> Rect2i:
	if AppState.current_map_page == null:
		return Rect2i(Vector2i(-256, -256), Vector2i(512, 512))
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Rect2i(Vector2i(-256, -256), Vector2i(512, 512))
	var vp_size: Vector2 = viewport.get_visible_rect().size
	var world_size: Vector2 = vp_size / _camera.zoom
	var top_left: Vector2 = _camera.position - world_size * 0.5
	var bottom_right: Vector2 = _camera.position + world_size * 0.5
	var t: Vector2i = AppState.current_map_page.tile_size
	if t.x <= 0 or t.y <= 0:
		t = Vector2i(16, 16)
	var min_cell: Vector2i = Vector2i(int(floor(top_left.x / float(t.x))) - 4, int(floor(top_left.y / float(t.y))) - 4)
	var max_cell: Vector2i = Vector2i(int(floor(bottom_right.x / float(t.x))) + 4, int(floor(bottom_right.y / float(t.y))) + 4)
	return Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE)


func _pick_at_cell(cell: Vector2i) -> void:
	if AppState.current_map_page == null:
		return
	for layer: MapLayer in AppState.current_map_page.layers:
		if not layer.visible:
			continue
		if not layer.has_cell(cell):
			continue
		var data: Vector3i = layer.cells[cell]
		if data.x < 0 or data.y < 0:
			continue
		_brush.set_atlas_tile(layer.tileset_id, Vector2i(data.x, data.y), data.z)
		_selected_layer_id = layer.id
		_refresh_layer_panel()
		return


func _begin_add_overlay(type_id: String) -> void:
	if AppState.current_map_page == null:
		return
	_pending_overlay_type = type_id
	if type_id == ItemRegistry.TYPE_IMAGE:
		_image_dialog.popup_centered_ratio(0.7)
	elif type_id == ItemRegistry.TYPE_SOUND:
		_sound_dialog.popup_centered_ratio(0.7)
	else:
		_create_overlay_at_camera_center()


func _on_image_overlay_chosen(path: String) -> void:
	if path == "" or AppState.current_project == null:
		return
	var copied: String = AppState.current_project.copy_asset_into_project(path)
	if copied == "":
		return
	_pending_image_path = path
	var d: Dictionary = _build_overlay_dict(ItemRegistry.TYPE_IMAGE, _camera.position - Vector2(120, 90), Vector2(240, 180))
	d["asset_name"] = copied
	d["source_path"] = ""
	d["source_mode"] = 1
	History.push(MapObjectsCommand.make_add(self, [d]))


func _on_sound_overlay_chosen(path: String) -> void:
	if path == "" or AppState.current_project == null:
		return
	var copied: String = AppState.current_project.copy_asset_into_project(path)
	if copied == "":
		return
	_pending_sound_path = path
	var d: Dictionary = _build_overlay_dict(ItemRegistry.TYPE_SOUND, _camera.position - Vector2(80, 30), Vector2(160, 60))
	d["asset_name"] = copied
	d["source_path"] = ""
	d["display_label"] = path.get_file()
	History.push(MapObjectsCommand.make_add(self, [d]))


func _create_overlay_at_camera_center() -> void:
	var size: Vector2 = Vector2(160, 60)
	var pos: Vector2 = _camera.position - size * 0.5
	var d: Dictionary = _build_overlay_dict(_pending_overlay_type, pos, size)
	History.push(MapObjectsCommand.make_add(self, [d]))


func _build_overlay_dict(type_id: String, pos: Vector2, size: Vector2) -> Dictionary:
	var defaults: Dictionary = ItemRegistry.default_payload(type_id)
	var d: Dictionary = {
		"id": Uuid.v4(),
		"type": type_id,
		"position": [pos.x, pos.y],
		"size": [size.x, size.y],
	}
	for k in defaults.keys():
		d[k] = defaults[k]
	return d


func _request_remove_object(object_id: String) -> void:
	_confirm_action = "remove_object"
	_confirm_payload = object_id
	_confirm_dialog.dialog_text = "Remove this overlay object?"
	_confirm_dialog.popup_centered()


func _remove_object_via_history(object_id: String) -> void:
	if AppState.current_map_page == null:
		return
	for entry_v: Variant in AppState.current_map_page.objects:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		if String((entry_v as Dictionary).get("id", "")) == object_id:
			History.push(MapObjectsCommand.make_remove(self, [(entry_v as Dictionary)]))
			return


func _overlay_at_world(world_pos: Vector2) -> OverlayObject:
	var hit: OverlayObject = null
	for child in _objects_root.get_children():
		if child is OverlayObject:
			var node: OverlayObject = child
			var rect: Rect2 = Rect2(node.world_position(), node.world_size())
			if rect.has_point(world_pos):
				hit = node
	return hit


func _select_overlay(node: OverlayObject) -> void:
	for child in _objects_root.get_children():
		if child is OverlayObject:
			(child as OverlayObject).set_selected_state(child == node)
	_selected_object_id = node.object_id() if node != null else ""


func _clear_object_selection() -> void:
	for child in _objects_root.get_children():
		if child is OverlayObject:
			(child as OverlayObject).set_selected_state(false)
	_selected_object_id = ""


func _open_export_dialog() -> void:
	if AppState.current_map_page == null:
		_show_info("Open a map page first.")
		return
	if AppState.current_map_page.layers.is_empty():
		_show_info("This map has no layers.")
		return
	_export_dialog.open()


func _on_export_requested(output_dir: String, godot_root: String, mode: String) -> void:
	if AppState.current_map_page == null or AppState.current_project == null:
		return
	var request: TscnMapExporter.ExportRequest = TscnMapExporter.ExportRequest.new()
	request.page = AppState.current_map_page
	request.project = AppState.current_project
	request.godot_project_root = godot_root
	request.output_dir = output_dir
	request.mode = mode
	for ts_id: String in AppState.current_map_page.tilesets_used():
		var ts: TileSetResource = _tilesets.get(ts_id, null)
		if ts == null:
			ts = AppState.current_project.read_tileset(ts_id)
		if ts != null:
			request.tilesets[ts_id] = ts
	var result: TscnMapExporter.ExportResult = TscnMapExporter.export_map(request)
	if result.ok:
		_show_info("Exported %d file(s) to %s" % [result.written_paths.size(), output_dir])
	else:
		_show_info("Export failed: " + result.error_message)


func _open_tileset_setup_dialog() -> void:
	var ts_id: String = _brush.tileset_id
	if ts_id == "" and not _tileset_order.is_empty():
		ts_id = _tileset_order[0]
	if ts_id == "":
		_show_info("No tileset selected.")
		return
	var ts: TileSetResource = _tilesets.get(ts_id, null)
	if ts == null:
		return
	_tileset_setup_dialog.bind_tileset(ts)
	_tileset_setup_dialog.open()


func _on_tileset_setup_applied(updated: Dictionary) -> void:
	if AppState.current_project == null:
		return
	var ts_id: String = _brush.tileset_id
	if ts_id == "" and not _tileset_order.is_empty():
		ts_id = _tileset_order[0]
	var ts: TileSetResource = _tilesets.get(ts_id, null)
	if ts == null:
		return
	ts.name = String(updated.get("name", ts.name))
	if not bool(updated.get("is_godot_origin", false)):
		ts.tile_size = updated.get("tile_size", ts.tile_size)
		ts.margins = updated.get("margins", ts.margins)
		ts.separation = updated.get("separation", ts.separation)
		var img: Image = ts.image_for_project(AppState.current_project.folder_path)
		if img != null:
			ts.recompute_atlas_dimensions(img.get_width(), img.get_height())
		ts.atlas_tiles.clear()
		for y in range(ts.atlas_rows):
			for x in range(ts.atlas_columns):
				ts.ensure_tile(Vector2i(x, y))
		ts.terrain_sets.clear()
		var terrains_by_set: Dictionary = updated.get("terrains_by_set", {})
		for ts_idx_v: Variant in terrains_by_set.keys():
			var ts_idx: int = int(ts_idx_v)
			ts.ensure_terrain_set(ts_idx)
			var terrains: Array = terrains_by_set[ts_idx_v]
			var entry: Dictionary = ts.terrain_sets[ts_idx]
			entry["terrains"] = terrains
	AppState.current_project.write_tileset(ts)
	_broadcast_tileset_upsert(ts, OpKinds.UPDATE_TILESET)
	ts.clear_image_cache()
	_load_tilesets()
	_refresh_tileset_palette()
	_refresh_layer_panel()
	for layer: MapLayer in AppState.current_map_page.layers:
		_apply_layer_renderer_binding(layer)


func _show_info(text: String) -> void:
	_info_dialog.dialog_text = text
	_info_dialog.popup_centered()


func _is_canvas_hovered() -> bool:
	if not is_visible_in_tree():
		return false
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return false
	var rect: Rect2 = get_global_rect()
	var mouse_global: Vector2 = viewport.get_mouse_position()
	if not rect.has_point(mouse_global):
		return false
	var hovered: Control = viewport.gui_get_hovered_control()
	if hovered == null or hovered == self:
		return true
	var node: Node = hovered
	while node != null:
		if node is OverlayObject:
			return true
		if node == self:
			return false
		node = node.get_parent()
	return false
