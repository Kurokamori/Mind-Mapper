class_name TilemapToolbar
extends PanelContainer

signal action_requested(action: String, payload: Variant)

const ACTION_BACK_TO_PROJECTS: String = "back_to_projects"
const ACTION_SAVE: String = "save"
const ACTION_UNDO: String = "undo"
const ACTION_REDO: String = "redo"
const ACTION_SET_TOOL: String = "set_tool"
const ACTION_IMPORT_TILESET: String = "import_tileset"
const ACTION_NEW_TILESET_FROM_IMAGE: String = "new_tileset_from_image"
const ACTION_NEW_LAYER: String = "new_layer"
const ACTION_TOGGLE_TILESET_PALETTE: String = "toggle_tileset_palette"
const ACTION_TOGGLE_LAYER_PANEL: String = "toggle_layer_panel"
const ACTION_TOGGLE_INSPECTOR: String = "toggle_inspector"
const ACTION_TOGGLE_OUTLINER: String = "toggle_outliner"
const ACTION_EXPORT: String = "export"
const ACTION_ADD_OVERLAY: String = "add_overlay"
const ACTION_TILESET_SETUP: String = "tileset_setup"

const IMPORT_MENU_ID_TRES: int = 0
const IMPORT_MENU_ID_IMAGE: int = 1

@onready var _project_label: Label = %ProjectLabel
@onready var _back_button: Button = %BackButton
@onready var _save_button: Button = %SaveButton
@onready var _save_status: Label = %SaveStatusLabel
@onready var _undo_button: Button = %UndoButton
@onready var _redo_button: Button = %RedoButton
@onready var _paint_button: Button = %PaintButton
@onready var _erase_button: Button = %EraseButton
@onready var _fill_button: Button = %FillButton
@onready var _rect_button: Button = %RectButton
@onready var _pick_button: Button = %PickButton
@onready var _select_button: Button = %SelectButton
@onready var _import_button: MenuButton = %ImportButton
@onready var _add_overlay_button: MenuButton = %AddOverlayButton
@onready var _tileset_palette_button: Button = %TilesetPaletteButton
@onready var _layer_panel_button: Button = %LayerPanelButton
@onready var _inspector_button: Button = %InspectorButton
@onready var _outliner_button: Button = %OutlinerButton
@onready var _tileset_setup_button: Button = %TilesetSetupButton
@onready var _new_layer_button: Button = %NewLayerButton
@onready var _export_button: Button = %ExportButton

var _tool_buttons: Array[Button] = []
var _save_status_state: String = "saved"
var _last_saved_unix: int = 0
var _status_timer: Timer


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_undo_button.pressed.connect(_on_undo_pressed)
	_redo_button.pressed.connect(_on_redo_pressed)
	_new_layer_button.pressed.connect(_on_new_layer_pressed)
	_export_button.pressed.connect(_on_export_pressed)
	_tileset_setup_button.pressed.connect(_on_tileset_setup_pressed)
	_tool_buttons = [
		_paint_button, _erase_button, _fill_button, _rect_button, _pick_button, _select_button,
	]
	_paint_button.pressed.connect(_on_tool_pressed.bind(TileBrush.TOOL_PAINT))
	_erase_button.pressed.connect(_on_tool_pressed.bind(TileBrush.TOOL_ERASE))
	_fill_button.pressed.connect(_on_tool_pressed.bind(TileBrush.TOOL_FILL))
	_rect_button.pressed.connect(_on_tool_pressed.bind(TileBrush.TOOL_RECT))
	_pick_button.pressed.connect(_on_tool_pressed.bind(TileBrush.TOOL_PICK))
	_select_button.pressed.connect(_on_tool_pressed.bind(TileBrush.TOOL_SELECT))
	_tileset_palette_button.toggled.connect(_on_tileset_palette_toggled)
	_layer_panel_button.toggled.connect(_on_layer_panel_toggled)
	_inspector_button.toggled.connect(_on_inspector_toggled)
	_outliner_button.toggled.connect(_on_outliner_toggled)
	_populate_import_menu()
	_populate_overlay_menu()
	History.changed.connect(_refresh_history_buttons)
	AppState.project_opened.connect(_on_project_opened)
	AppState.project_closed.connect(_on_project_closed)
	AppState.save_state_changed.connect(_on_save_state_changed)
	if AppState.current_project != null:
		_on_project_opened(AppState.current_project)
	_refresh_history_buttons()
	_status_timer = Timer.new()
	_status_timer.one_shot = false
	_status_timer.wait_time = 1.0
	_status_timer.timeout.connect(_refresh_save_status)
	add_child(_status_timer)
	_status_timer.start()
	_refresh_save_status()
	highlight_tool(TileBrush.TOOL_PAINT)


func _populate_import_menu() -> void:
	var popup: PopupMenu = _import_button.get_popup()
	popup.clear()
	popup.add_item("Import Godot TileSet (.tres)…", IMPORT_MENU_ID_TRES)
	popup.add_item("New Tileset from Image…", IMPORT_MENU_ID_IMAGE)
	if not popup.id_pressed.is_connected(_on_import_menu_id_pressed):
		popup.id_pressed.connect(_on_import_menu_id_pressed)


func _populate_overlay_menu() -> void:
	var popup: PopupMenu = _add_overlay_button.get_popup()
	popup.clear()
	var entries: Array = [
		[ItemRegistry.TYPE_LABEL, "Label"],
		[ItemRegistry.TYPE_TEXT, "Text"],
		[ItemRegistry.TYPE_RICH_TEXT, "Rich Text"],
		[ItemRegistry.TYPE_IMAGE, "Image…"],
		[ItemRegistry.TYPE_SOUND, "Sound…"],
	]
	for i in range(entries.size()):
		popup.add_item(String(entries[i][1]), i)
		popup.set_item_metadata(i, String(entries[i][0]))
	if not popup.id_pressed.is_connected(_on_overlay_menu_id_pressed):
		popup.id_pressed.connect(_on_overlay_menu_id_pressed)


func _on_back_pressed() -> void:
	emit_signal("action_requested", ACTION_BACK_TO_PROJECTS, null)


func _on_save_pressed() -> void:
	emit_signal("action_requested", ACTION_SAVE, null)


func _on_undo_pressed() -> void:
	emit_signal("action_requested", ACTION_UNDO, null)


func _on_redo_pressed() -> void:
	emit_signal("action_requested", ACTION_REDO, null)


func _on_new_layer_pressed() -> void:
	emit_signal("action_requested", ACTION_NEW_LAYER, null)


func _on_export_pressed() -> void:
	emit_signal("action_requested", ACTION_EXPORT, null)


func _on_tileset_setup_pressed() -> void:
	emit_signal("action_requested", ACTION_TILESET_SETUP, null)


func _on_import_menu_id_pressed(id: int) -> void:
	match id:
		IMPORT_MENU_ID_TRES:
			emit_signal("action_requested", ACTION_IMPORT_TILESET, null)
		IMPORT_MENU_ID_IMAGE:
			emit_signal("action_requested", ACTION_NEW_TILESET_FROM_IMAGE, null)


func _on_overlay_menu_id_pressed(id: int) -> void:
	var popup: PopupMenu = _add_overlay_button.get_popup()
	var idx: int = popup.get_item_index(id)
	if idx < 0:
		return
	var type_id: String = String(popup.get_item_metadata(idx))
	emit_signal("action_requested", ACTION_ADD_OVERLAY, type_id)


func _on_tool_pressed(tool_id: String) -> void:
	highlight_tool(tool_id)
	emit_signal("action_requested", ACTION_SET_TOOL, tool_id)


func highlight_tool(tool_id: String) -> void:
	var by_id: Dictionary = {
		TileBrush.TOOL_PAINT: _paint_button,
		TileBrush.TOOL_ERASE: _erase_button,
		TileBrush.TOOL_FILL: _fill_button,
		TileBrush.TOOL_RECT: _rect_button,
		TileBrush.TOOL_PICK: _pick_button,
		TileBrush.TOOL_SELECT: _select_button,
	}
	for btn: Button in _tool_buttons:
		btn.button_pressed = false
	if by_id.has(tool_id):
		(by_id[tool_id] as Button).button_pressed = true


func set_panel_button_states(tileset_palette_visible: bool, layer_panel_visible: bool, inspector_visible: bool, outliner_visible: bool) -> void:
	_tileset_palette_button.button_pressed = tileset_palette_visible
	_layer_panel_button.button_pressed = layer_panel_visible
	_inspector_button.button_pressed = inspector_visible
	_outliner_button.button_pressed = outliner_visible


func _on_tileset_palette_toggled(p: bool) -> void:
	emit_signal("action_requested", ACTION_TOGGLE_TILESET_PALETTE, p)


func _on_layer_panel_toggled(p: bool) -> void:
	emit_signal("action_requested", ACTION_TOGGLE_LAYER_PANEL, p)


func _on_inspector_toggled(p: bool) -> void:
	emit_signal("action_requested", ACTION_TOGGLE_INSPECTOR, p)


func _on_outliner_toggled(p: bool) -> void:
	emit_signal("action_requested", ACTION_TOGGLE_OUTLINER, p)


func _on_project_opened(project: Project) -> void:
	_project_label.text = project.name


func _on_project_closed() -> void:
	_project_label.text = ""


func _on_save_state_changed(state: String, unix_time: int) -> void:
	_save_status_state = state
	if unix_time > 0:
		_last_saved_unix = unix_time
	_refresh_save_status()


func _refresh_save_status() -> void:
	if _save_status == null:
		return
	match _save_status_state:
		AppState.SAVE_STATE_DIRTY:
			_save_status.text = "Unsaved"
		AppState.SAVE_STATE_SAVING:
			_save_status.text = "Saving…"
		_:
			if _last_saved_unix > 0:
				var ago: int = int(Time.get_unix_time_from_system()) - _last_saved_unix
				if ago < 5:
					_save_status.text = "Saved"
				elif ago < 60:
					_save_status.text = "Saved %ds ago" % ago
				elif ago < 3600:
					_save_status.text = "Saved %dm ago" % (ago / 60)
				else:
					_save_status.text = "Saved %dh ago" % (ago / 3600)
			else:
				_save_status.text = ""


func _refresh_history_buttons() -> void:
	if _undo_button == null:
		return
	_undo_button.disabled = not History.can_undo()
	_redo_button.disabled = not History.can_redo()
