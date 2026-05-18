class_name EditorToolbar
extends PanelContainer

signal action_requested(action: String, payload: Variant)

const ACTION_ADD: String = "add"
const ACTION_NEW_MAP_PAGE: String = "new_map_page"
const ACTION_IMPORT_TILESET: String = "import_tileset"
const ACTION_NEW_TILESET_FROM_IMAGE: String = "new_tileset_from_image"
const ACTION_TOGGLE_INSPECTOR: String = "toggle_inspector"
const ACTION_TOGGLE_OUTLINER: String = "toggle_outliner"
const ACTION_TOGGLE_MINIMAP: String = "toggle_minimap"
const ACTION_TOGGLE_TIMER_TRAY: String = "toggle_timer_tray"
const ACTION_TOGGLE_COMMENTS: String = "toggle_comments"
const ACTION_TOGGLE_CHAT: String = "toggle_chat"
const ACTION_TOGGLE_LAN_BROADCASTS: String = "toggle_lan_broadcasts"
const ACTION_OPEN_TODOS: String = "open_todos"
const ACTION_OPEN_PALETTE: String = "open_palette"
const ACTION_UNDO: String = "undo"
const ACTION_REDO: String = "redo"
const ACTION_SAVE: String = "save"
const ACTION_BACK_TO_PROJECTS: String = "back_to_projects"
const ACTION_GROUP: String = "group"
const ACTION_EXPORT: String = "export"
const ACTION_IMPORT: String = "import"
const ACTION_TOGGLE_CONNECT: String = "toggle_connect"
const ACTION_ARRANGE: String = "arrange"
const ACTION_SNAP_OPTION: String = "snap_option"
const ACTION_SET_GRID_SIZE: String = "set_grid_size"
const ACTION_TAG_FILTER: String = "tag_filter"
const ACTION_PRESENT: String = "present"
const ACTION_TEMPLATE: String = "template"
const ACTION_SETTINGS: String = "settings"
const ACTION_ANNOTATION_TOOL: String = "annotation_tool"
const ACTION_ANNOTATION_COLOR: String = "annotation_color"
const ACTION_ANNOTATION_WIDTH: String = "annotation_width"
const ACTION_CONNECTOR_TOOL: String = "connector_tool"
const ACTION_CONNECTOR_COLOR: String = "connector_color"
const ACTION_CONNECTOR_WIDTH: String = "connector_width"

const ANNOTATION_TOOL_NONE: String = "none"
const ANNOTATION_TOOL_PEN: String = "pen"
const ANNOTATION_TOOL_ERASER: String = "eraser"
const ANNOTATION_TOOL_SELECT: String = "select"

const CONNECTOR_TOOL_NONE: String = "none"
const CONNECTOR_TOOL_LINE: String = "line"
const CONNECTOR_TOOL_ARROW: String = "arrow"

const TILESETS_MENU_ID_NEW_MAP_PAGE: int = 0
const TILESETS_MENU_ID_IMPORT_TRES: int = 1
const TILESETS_MENU_ID_NEW_FROM_IMAGE: int = 2

const EXPORT_MODE_PNG_CURRENT: String = "png_current"
const EXPORT_MODE_PNG_UNFOLDED: String = "png_unfolded"
const EXPORT_MODE_SVG: String = "svg"
const EXPORT_MODE_PDF: String = "pdf"
const EXPORT_MODE_MARKDOWN: String = "markdown"
const EXPORT_MODE_HTML: String = "html"

const IMPORT_MODE_MARKDOWN: String = "markdown"
const IMPORT_MODE_JSON: String = "json"
const IMPORT_MODE_DOCUMENT: String = "document"
const IMPORT_MODE_IMAGE: String = "image"
const IMPORT_MODE_SOUND: String = "sound"

const IMPORT_MENU_SEPARATOR_TOKEN: String = "__sep__"

const ARRANGE_ALIGN_LEFT: String = "align_left"
const ARRANGE_ALIGN_RIGHT: String = "align_right"
const ARRANGE_ALIGN_TOP: String = "align_top"
const ARRANGE_ALIGN_BOTTOM: String = "align_bottom"
const ARRANGE_ALIGN_HCENTER: String = "align_hcenter"
const ARRANGE_ALIGN_VCENTER: String = "align_vcenter"
const ARRANGE_DISTRIBUTE_H: String = "distribute_h"
const ARRANGE_DISTRIBUTE_V: String = "distribute_v"
const ARRANGE_AS_GRID: String = "as_grid"
const ARRANGE_AS_GRID_COMPACT: String = "as_grid_compact"
const ARRANGE_BRING_FORWARD: String = "bring_forward"
const ARRANGE_BRING_TO_FRONT: String = "bring_to_front"
const ARRANGE_SEND_BACKWARD: String = "send_backward"
const ARRANGE_SEND_TO_BACK: String = "send_to_back"

const SNAP_OPT_ENABLED: String = "snap_enabled"
const SNAP_OPT_TO_GRID: String = "snap_to_grid"
const SNAP_OPT_TO_ITEMS: String = "snap_to_items"

const TEMPLATE_ACTION_SAVE_SELECTION: String = "template_save_selection"
const TEMPLATE_ACTION_INSERT: String = "template_insert"
const TEMPLATE_ACTION_DELETE: String = "template_delete"

const SETTINGS_ACTION_THEME: String = "settings_theme"
const SETTINGS_ACTION_KEYBINDINGS: String = "settings_keybindings"
const SETTINGS_ACTION_SNAPSHOTS: String = "settings_snapshots"

@onready var _project_label: Label = %ProjectLabel
@onready var _back_button: Button = %BackButton
@onready var _save_button: Button = %SaveButton
@onready var _save_status: Label = %SaveStatusLabel
@onready var _add_menu_button: MenuButton = %AddMenuButton
@onready var _undo_button: Button = %UndoButton
@onready var _redo_button: Button = %RedoButton
@onready var _snap_button: MenuButton = %SnapButton
@onready var _align_button: Button = %AlignButton
@onready var _arrange_button: MenuButton = %ArrangeButton
@onready var _inspector_button: Button = %InspectorButton
@onready var _outliner_button: Button = %OutlinerButton
@onready var _minimap_button: Button = %MinimapButton
@onready var _timer_tray_button: Button = %TimerTrayButton
@onready var _comments_button: Button = %CommentsButton
@onready var _chat_button: Button = %ChatButton
@onready var _lan_broadcasts_button: Button = %LanBroadcastsButton
@onready var _todos_button: Button = %TodosButton
@onready var _tag_filter_button: MenuButton = %TagFilterButton
@onready var _group_button: Button = %GroupButton
@onready var _present_button: Button = %PresentButton
@onready var _templates_button: MenuButton = %TemplatesButton
@onready var _import_button: MenuButton = %ImportButton
@onready var _export_button: MenuButton = %ExportButton
@onready var _settings_button: MenuButton = %SettingsButton
@onready var _tilesets_button: MenuButton = %TilesetsButton
@onready var _presence_strip: PresenceAvatarStrip = %PresenceStrip
@onready var _pen_button: Button = %PenButton
@onready var _eraser_button: Button = %EraserButton
@onready var _annotation_select_button: Button = %AnnotationSelectButton
@onready var _annotation_color_button: ColorPickerButton = %AnnotationColorButton
@onready var _annotation_width_spin: SpinBox = %AnnotationWidthSpin
@onready var _line_tool_button: Button = %LineToolButton
@onready var _arrow_tool_button: Button = %ArrowToolButton
@onready var _connector_color_button: ColorPickerButton = %ConnectorColorButton
@onready var _connector_width_spin: SpinBox = %ConnectorWidthSpin
@onready var _file_group_button: Button = %FileGroupButton
@onready var _edit_group_button: Button = %EditGroupButton
@onready var _draw_group_button: Button = %DrawGroupButton
@onready var _view_group_button: Button = %ViewGroupButton
@onready var _expansion_panel: PanelContainer = %ExpansionPanel
@onready var _file_margin: MarginContainer = %FileMargin
@onready var _edit_margin: MarginContainer = %EditMargin
@onready var _draw_margin: MarginContainer = %DrawMargin
@onready var _view_margin: MarginContainer = %ViewMargin

const GROUP_NONE: String = ""
const GROUP_FILE: String = "file"
const GROUP_EDIT: String = "edit"
const GROUP_DRAW: String = "draw"
const GROUP_VIEW: String = "view"

var _active_groups: Dictionary = {}

var _save_status_state: String = "saved"
var _last_saved_unix: int = 0
var _status_timer: Timer
var _current_tags: PackedStringArray = PackedStringArray()
var _selected_tag_filter: String = ""
var _edit_mode_enabled: bool = true
var _active_annotation_tool: String = ANNOTATION_TOOL_NONE
var _active_connector_tool: String = CONNECTOR_TOOL_NONE


func _ready() -> void:
	_back_button.pressed.connect(func() -> void: emit_signal("action_requested", ACTION_BACK_TO_PROJECTS, null))
	_save_button.pressed.connect(func() -> void: emit_signal("action_requested", ACTION_SAVE, null))
	_undo_button.pressed.connect(func() -> void: emit_signal("action_requested", ACTION_UNDO, null))
	_redo_button.pressed.connect(func() -> void: emit_signal("action_requested", ACTION_REDO, null))
	_align_button.toggled.connect(_on_align_toggled)
	_inspector_button.toggled.connect(_on_inspector_toggled)
	_outliner_button.toggled.connect(_on_outliner_toggled)
	_minimap_button.toggled.connect(_on_minimap_toggled)
	_timer_tray_button.toggled.connect(_on_timer_tray_toggled)
	_comments_button.toggled.connect(_on_comments_toggled)
	_chat_button.toggled.connect(_on_chat_toggled)
	_lan_broadcasts_button.toggled.connect(_on_lan_broadcasts_toggled)
	_todos_button.pressed.connect(func() -> void: emit_signal("action_requested", ACTION_OPEN_TODOS, null))
	_group_button.pressed.connect(func() -> void: emit_signal("action_requested", ACTION_GROUP, null))
	_present_button.pressed.connect(func() -> void: emit_signal("action_requested", ACTION_PRESENT, null))
	_pen_button.toggled.connect(func(pressed: bool) -> void: _on_annotation_tool_toggled(ANNOTATION_TOOL_PEN, pressed))
	_eraser_button.toggled.connect(func(pressed: bool) -> void: _on_annotation_tool_toggled(ANNOTATION_TOOL_ERASER, pressed))
	_annotation_select_button.toggled.connect(func(pressed: bool) -> void: _on_annotation_tool_toggled(ANNOTATION_TOOL_SELECT, pressed))
	_annotation_color_button.color_changed.connect(_on_annotation_color_changed)
	_annotation_width_spin.value_changed.connect(_on_annotation_width_changed)
	_line_tool_button.toggled.connect(func(pressed: bool) -> void: _on_connector_tool_toggled(CONNECTOR_TOOL_LINE, pressed))
	_arrow_tool_button.toggled.connect(func(pressed: bool) -> void: _on_connector_tool_toggled(CONNECTOR_TOOL_ARROW, pressed))
	_connector_color_button.color_changed.connect(_on_connector_color_changed)
	_connector_width_spin.value_changed.connect(_on_connector_width_changed)
	_populate_export_menu()
	_populate_import_menu()
	_populate_add_menu()
	_populate_snap_menu()
	_populate_arrange_menu()
	_populate_settings_menu()
	_populate_templates_menu([])
	_populate_tag_filter_menu(PackedStringArray())
	_populate_tilesets_menu()
	_file_group_button.toggled.connect(func(p: bool) -> void: _on_group_button_toggled(GROUP_FILE, p))
	_edit_group_button.toggled.connect(func(p: bool) -> void: _on_group_button_toggled(GROUP_EDIT, p))
	_draw_group_button.toggled.connect(func(p: bool) -> void: _on_group_button_toggled(GROUP_DRAW, p))
	_view_group_button.toggled.connect(func(p: bool) -> void: _on_group_button_toggled(GROUP_VIEW, p))
	_apply_active_groups()
	History.changed.connect(_refresh_history_buttons)
	SnapService.changed.connect(_refresh_snap)
	AlignmentGuideService.changed.connect(_refresh_align)
	AppState.project_opened.connect(_on_project_opened)
	AppState.project_closed.connect(_on_project_closed)
	AppState.save_state_changed.connect(_on_save_state_changed)
	if AppState.current_project != null:
		_on_project_opened(AppState.current_project)
	_refresh_history_buttons()
	_refresh_snap()
	_refresh_align()
	_status_timer = Timer.new()
	_status_timer.one_shot = false
	_status_timer.wait_time = 1.0
	_status_timer.timeout.connect(_refresh_save_status)
	add_child(_status_timer)
	_status_timer.start()
	ThemeManager.theme_applied.connect(_refresh_save_status)
	_refresh_save_status()


func set_edit_mode_enabled(enabled: bool) -> void:
	_edit_mode_enabled = enabled
	var disabled: bool = not enabled
	if _add_menu_button != null:
		_add_menu_button.disabled = disabled
	if _group_button != null:
		_group_button.disabled = disabled
	if _arrange_button != null:
		_arrange_button.disabled = disabled
	if _align_button != null:
		_align_button.disabled = disabled
	if _templates_button != null:
		_templates_button.disabled = disabled
	if _import_button != null:
		_import_button.disabled = disabled
	if _tilesets_button != null:
		_tilesets_button.disabled = disabled
	if _save_button != null:
		_save_button.disabled = disabled
	if _undo_button != null and disabled:
		_undo_button.disabled = true
	if _redo_button != null and disabled:
		_redo_button.disabled = true
	if not disabled:
		_refresh_history_buttons()


func _populate_add_menu() -> void:
	var popup: PopupMenu = _add_menu_button.get_popup()
	AddNodePopup.populate_into(popup)
	if not popup.id_pressed.is_connected(_on_add_menu_id_pressed):
		popup.id_pressed.connect(_on_add_menu_id_pressed)


func _on_add_menu_id_pressed(id: int) -> void:
	var popup: PopupMenu = _add_menu_button.get_popup()
	var token: String = AddNodePopup.type_for_id(popup, id)
	if token == "":
		return
	if token == AddNodePopup.MAP_PAGE_TOKEN:
		emit_signal("action_requested", ACTION_NEW_MAP_PAGE, null)
		return
	emit_signal("action_requested", ACTION_ADD, token)


func _populate_tilesets_menu() -> void:
	if _tilesets_button == null:
		return
	var popup: PopupMenu = _tilesets_button.get_popup()
	popup.clear()
	popup.add_item("New Map Page…", TILESETS_MENU_ID_NEW_MAP_PAGE)
	popup.add_separator()
	popup.add_item("Import Tileset (.tres)…", TILESETS_MENU_ID_IMPORT_TRES)
	popup.add_item("New Tileset from Image…", TILESETS_MENU_ID_NEW_FROM_IMAGE)
	if not popup.id_pressed.is_connected(_on_tilesets_menu_id_pressed):
		popup.id_pressed.connect(_on_tilesets_menu_id_pressed)


func _on_tilesets_menu_id_pressed(id: int) -> void:
	match id:
		TILESETS_MENU_ID_NEW_MAP_PAGE:
			emit_signal("action_requested", ACTION_NEW_MAP_PAGE, null)
		TILESETS_MENU_ID_IMPORT_TRES:
			emit_signal("action_requested", ACTION_IMPORT_TILESET, null)
		TILESETS_MENU_ID_NEW_FROM_IMAGE:
			emit_signal("action_requested", ACTION_NEW_TILESET_FROM_IMAGE, null)


func _populate_export_menu() -> void:
	var popup: PopupMenu = _export_button.get_popup()
	popup.clear()
	var entries: Array = [
		[EXPORT_MODE_PNG_CURRENT, "PNG — Current Board…"],
		[EXPORT_MODE_PNG_UNFOLDED, "PNG — Unfolded (all subpages)…"],
		[EXPORT_MODE_SVG, "SVG — Current Board…"],
		[EXPORT_MODE_PDF, "PDF — Unfolded…"],
		[EXPORT_MODE_MARKDOWN, "Markdown Outline…"],
		[EXPORT_MODE_HTML, "Interactive HTML (whole project)…"],
	]
	for i in range(entries.size()):
		popup.add_item(String(entries[i][1]), i)
		popup.set_item_metadata(i, String(entries[i][0]))
	if not popup.id_pressed.is_connected(_on_export_menu_id_pressed):
		popup.id_pressed.connect(_on_export_menu_id_pressed)


func _on_export_menu_id_pressed(id: int) -> void:
	var popup: PopupMenu = _export_button.get_popup()
	var idx: int = popup.get_item_index(id)
	if idx < 0:
		return
	emit_signal("action_requested", ACTION_EXPORT, String(popup.get_item_metadata(idx)))


func _populate_import_menu() -> void:
	var popup: PopupMenu = _import_button.get_popup()
	popup.clear()
	var entries: Array = [
		[IMPORT_MODE_MARKDOWN, "Markdown Outline…"],
		[IMPORT_MODE_JSON, "Project JSON…"],
		[IMPORT_MENU_SEPARATOR_TOKEN, ""],
		[IMPORT_MODE_DOCUMENT, "Document(s)…"],
		[IMPORT_MODE_IMAGE, "Image(s)…"],
		[IMPORT_MODE_SOUND, "Sound(s)…"],
	]
	var counter: int = 0
	for entry_v: Variant in entries:
		var entry: Array = entry_v
		var token: String = String(entry[0])
		var label: String = String(entry[1])
		if token == IMPORT_MENU_SEPARATOR_TOKEN:
			popup.add_separator()
		else:
			popup.add_item(label, counter)
			popup.set_item_metadata(popup.get_item_index(counter), token)
			counter += 1
	if not popup.id_pressed.is_connected(_on_import_menu_id_pressed):
		popup.id_pressed.connect(_on_import_menu_id_pressed)


func _on_import_menu_id_pressed(id: int) -> void:
	var popup: PopupMenu = _import_button.get_popup()
	var idx: int = popup.get_item_index(id)
	if idx < 0:
		return
	emit_signal("action_requested", ACTION_IMPORT, String(popup.get_item_metadata(idx)))


func _populate_snap_menu() -> void:
	var popup: PopupMenu = _snap_button.get_popup()
	popup.clear()
	popup.hide_on_checkable_item_selection = false
	popup.add_check_item("Snap Enabled", 100)
	popup.set_item_metadata(popup.get_item_index(100), SNAP_OPT_ENABLED)
	popup.add_check_item("Snap to Grid", 101)
	popup.set_item_metadata(popup.get_item_index(101), SNAP_OPT_TO_GRID)
	popup.add_check_item("Snap to Items", 102)
	popup.set_item_metadata(popup.get_item_index(102), SNAP_OPT_TO_ITEMS)
	popup.add_separator("Grid Size")
	for size in [8, 16, 24, 32, 48, 64]:
		var sid: int = 200 + int(size)
		popup.add_radio_check_item("%d px" % size, sid)
		popup.set_item_metadata(popup.get_item_index(sid), int(size))
	if not popup.id_pressed.is_connected(_on_snap_menu_id_pressed):
		popup.id_pressed.connect(_on_snap_menu_id_pressed)
	_refresh_snap_menu_checks()


func _on_snap_menu_id_pressed(id: int) -> void:
	var popup: PopupMenu = _snap_button.get_popup()
	var idx: int = popup.get_item_index(id)
	if idx < 0:
		return
	var meta: Variant = popup.get_item_metadata(idx)
	if typeof(meta) == TYPE_STRING:
		var key: String = String(meta)
		var current: bool = popup.is_item_checked(idx)
		emit_signal("action_requested", ACTION_SNAP_OPTION, {"key": key, "value": not current})
	elif typeof(meta) == TYPE_INT:
		emit_signal("action_requested", ACTION_SET_GRID_SIZE, int(meta))


func _populate_arrange_menu() -> void:
	var popup: PopupMenu = _arrange_button.get_popup()
	popup.clear()
	var entries: Array = [
		[ARRANGE_ALIGN_LEFT, "Align Left"],
		[ARRANGE_ALIGN_HCENTER, "Align Horizontal Center"],
		[ARRANGE_ALIGN_RIGHT, "Align Right"],
		[ARRANGE_ALIGN_TOP, "Align Top"],
		[ARRANGE_ALIGN_VCENTER, "Align Vertical Center"],
		[ARRANGE_ALIGN_BOTTOM, "Align Bottom"],
		["__sep__", ""],
		[ARRANGE_DISTRIBUTE_H, "Distribute Horizontally"],
		[ARRANGE_DISTRIBUTE_V, "Distribute Vertically"],
		[ARRANGE_AS_GRID, "Arrange as Grid"],
		[ARRANGE_AS_GRID_COMPACT, "Arrange as Grid (Compact)"],
		["__sep__", ""],
		[ARRANGE_BRING_FORWARD, "Bring Forward"],
		[ARRANGE_BRING_TO_FRONT, "Bring to Front"],
		[ARRANGE_SEND_BACKWARD, "Send Backward"],
		[ARRANGE_SEND_TO_BACK, "Send to Back"],
	]
	var counter: int = 0
	for e in entries:
		var key: String = String(e[0])
		if key == "__sep__":
			popup.add_separator()
		else:
			popup.add_item(String(e[1]), counter)
			popup.set_item_metadata(popup.get_item_index(counter), key)
			counter += 1
	if not popup.id_pressed.is_connected(_on_arrange_menu_id_pressed):
		popup.id_pressed.connect(_on_arrange_menu_id_pressed)


func _on_arrange_menu_id_pressed(id: int) -> void:
	var popup: PopupMenu = _arrange_button.get_popup()
	var idx: int = popup.get_item_index(id)
	if idx < 0:
		return
	emit_signal("action_requested", ACTION_ARRANGE, String(popup.get_item_metadata(idx)))


func _populate_settings_menu() -> void:
	var popup: PopupMenu = _settings_button.get_popup()
	popup.clear()
	var entries: Array = [
		[SETTINGS_ACTION_THEME, "Theme & Background…"],
		[SETTINGS_ACTION_KEYBINDINGS, "Keybindings…"],
		[SETTINGS_ACTION_SNAPSHOTS, "Snapshots…"],
	]
	for i in range(entries.size()):
		popup.add_item(String(entries[i][1]), i)
		popup.set_item_metadata(i, String(entries[i][0]))
	if not popup.id_pressed.is_connected(_on_settings_menu_id_pressed):
		popup.id_pressed.connect(_on_settings_menu_id_pressed)


func _on_settings_menu_id_pressed(id: int) -> void:
	var popup: PopupMenu = _settings_button.get_popup()
	var idx: int = popup.get_item_index(id)
	if idx < 0:
		return
	emit_signal("action_requested", ACTION_SETTINGS, String(popup.get_item_metadata(idx)))


func _populate_templates_menu(template_names: Array) -> void:
	var popup: PopupMenu = _templates_button.get_popup()
	popup.clear()
	popup.add_item("Save Selection as Template…", 0)
	popup.set_item_metadata(0, {"action": TEMPLATE_ACTION_SAVE_SELECTION})
	if template_names.size() > 0:
		popup.add_separator("Insert")
		var counter: int = 100
		for name in template_names:
			popup.add_item(String(name), counter)
			popup.set_item_metadata(popup.get_item_index(counter), {"action": TEMPLATE_ACTION_INSERT, "name": String(name)})
			counter += 1
		popup.add_separator("Delete")
		var dcounter: int = 200
		for name in template_names:
			popup.add_item("Delete: %s" % String(name), dcounter)
			popup.set_item_metadata(popup.get_item_index(dcounter), {"action": TEMPLATE_ACTION_DELETE, "name": String(name)})
			dcounter += 1
	if not popup.id_pressed.is_connected(_on_templates_menu_id_pressed):
		popup.id_pressed.connect(_on_templates_menu_id_pressed)


func update_template_list(names: Array) -> void:
	_populate_templates_menu(names)


func _on_templates_menu_id_pressed(id: int) -> void:
	var popup: PopupMenu = _templates_button.get_popup()
	var idx: int = popup.get_item_index(id)
	if idx < 0:
		return
	var meta: Variant = popup.get_item_metadata(idx)
	if typeof(meta) != TYPE_DICTIONARY:
		return
	emit_signal("action_requested", ACTION_TEMPLATE, meta)


func _populate_tag_filter_menu(tags: PackedStringArray) -> void:
	_current_tags = tags
	var popup: PopupMenu = _tag_filter_button.get_popup()
	popup.clear()
	popup.hide_on_checkable_item_selection = false
	popup.add_radio_check_item("(no filter)", 0)
	popup.set_item_metadata(0, "")
	popup.set_item_checked(0, _selected_tag_filter == "")
	var counter: int = 1
	for tag in tags:
		popup.add_radio_check_item(String(tag), counter)
		popup.set_item_metadata(popup.get_item_index(counter), String(tag))
		popup.set_item_checked(popup.get_item_index(counter), _selected_tag_filter == String(tag))
		counter += 1
	if not popup.id_pressed.is_connected(_on_tag_filter_id_pressed):
		popup.id_pressed.connect(_on_tag_filter_id_pressed)


func update_tag_filter_list(tags: PackedStringArray, selected: String) -> void:
	_selected_tag_filter = selected
	_populate_tag_filter_menu(tags)


func _on_tag_filter_id_pressed(id: int) -> void:
	var popup: PopupMenu = _tag_filter_button.get_popup()
	var idx: int = popup.get_item_index(id)
	if idx < 0:
		return
	var tag: String = String(popup.get_item_metadata(idx))
	_selected_tag_filter = tag
	_populate_tag_filter_menu(_current_tags)
	emit_signal("action_requested", ACTION_TAG_FILTER, tag)


func _on_align_toggled(pressed: bool) -> void:
	AlignmentGuideService.set_enabled(pressed)


func _on_inspector_toggled(pressed: bool) -> void:
	emit_signal("action_requested", ACTION_TOGGLE_INSPECTOR, pressed)


func _on_outliner_toggled(pressed: bool) -> void:
	emit_signal("action_requested", ACTION_TOGGLE_OUTLINER, pressed)


func _on_minimap_toggled(pressed: bool) -> void:
	emit_signal("action_requested", ACTION_TOGGLE_MINIMAP, pressed)


func _on_timer_tray_toggled(pressed: bool) -> void:
	emit_signal("action_requested", ACTION_TOGGLE_TIMER_TRAY, pressed)


func _on_comments_toggled(pressed: bool) -> void:
	emit_signal("action_requested", ACTION_TOGGLE_COMMENTS, pressed)


func _on_chat_toggled(pressed: bool) -> void:
	emit_signal("action_requested", ACTION_TOGGLE_CHAT, pressed)


func _on_lan_broadcasts_toggled(pressed: bool) -> void:
	emit_signal("action_requested", ACTION_TOGGLE_LAN_BROADCASTS, pressed)


func set_lan_broadcasts_pressed(pressed: bool) -> void:
	if _lan_broadcasts_button == null:
		return
	if _lan_broadcasts_button.button_pressed != pressed:
		_lan_broadcasts_button.set_pressed_no_signal(pressed)


func set_lan_broadcasts_count(count: int) -> void:
	if _lan_broadcasts_button == null:
		return
	if count <= 0:
		_lan_broadcasts_button.text = "LAN"
	else:
		_lan_broadcasts_button.text = "LAN (%d)" % count


func set_inspector_pressed(pressed: bool) -> void:
	if _inspector_button == null:
		return
	if _inspector_button.button_pressed != pressed:
		_inspector_button.set_pressed_no_signal(pressed)


func set_outliner_pressed(pressed: bool) -> void:
	if _outliner_button == null:
		return
	if _outliner_button.button_pressed != pressed:
		_outliner_button.set_pressed_no_signal(pressed)


func set_minimap_pressed(pressed: bool) -> void:
	if _minimap_button == null:
		return
	if _minimap_button.button_pressed != pressed:
		_minimap_button.set_pressed_no_signal(pressed)


func set_timer_tray_pressed(pressed: bool) -> void:
	if _timer_tray_button == null:
		return
	if _timer_tray_button.button_pressed != pressed:
		_timer_tray_button.set_pressed_no_signal(pressed)


func set_comments_pressed(pressed: bool) -> void:
	if _comments_button == null:
		return
	if _comments_button.button_pressed != pressed:
		_comments_button.set_pressed_no_signal(pressed)


func set_chat_pressed(pressed: bool) -> void:
	if _chat_button == null:
		return
	if _chat_button.button_pressed != pressed:
		_chat_button.set_pressed_no_signal(pressed)


func set_chat_unread_count(count: int) -> void:
	if _chat_button == null:
		return
	if count <= 0:
		_chat_button.text = "Chat"
	elif count > 99:
		_chat_button.text = "Chat (99+)"
	else:
		_chat_button.text = "Chat (%d)" % count

func _refresh_snap() -> void:
	_refresh_snap_menu_checks()
	if _snap_button != null:
		var bits: Array[String] = []
		bits.append("On" if SnapService.enabled else "Off")
		if SnapService.enabled:
			if SnapService.snap_to_grid:
				bits.append("grid %d" % SnapService.grid_size)
			if SnapService.snap_to_items:
				bits.append("items")
		_snap_button.text = "Snap: %s ▾" % ", ".join(bits)


func _refresh_snap_menu_checks() -> void:
	if _snap_button == null:
		return
	var popup: PopupMenu = _snap_button.get_popup()
	if popup.item_count == 0:
		return
	var idx_enabled: int = popup.get_item_index(100)
	var idx_grid: int = popup.get_item_index(101)
	var idx_items: int = popup.get_item_index(102)
	if idx_enabled >= 0:
		popup.set_item_checked(idx_enabled, SnapService.enabled)
	if idx_grid >= 0:
		popup.set_item_checked(idx_grid, SnapService.snap_to_grid)
	if idx_items >= 0:
		popup.set_item_checked(idx_items, SnapService.snap_to_items)
	for size in [8, 16, 24, 32, 48, 64]:
		var sidx: int = popup.get_item_index(200 + int(size))
		if sidx >= 0:
			popup.set_item_checked(sidx, SnapService.grid_size == int(size))


func _refresh_align() -> void:
	if _align_button == null:
		return
	_align_button.button_pressed = AlignmentGuideService.enabled
	_align_button.text = "Guides: On" if AlignmentGuideService.enabled else "Guides: Off"


func _refresh_history_buttons() -> void:
	if _undo_button != null:
		_undo_button.disabled = (not _edit_mode_enabled) or (not History.can_undo())
	if _redo_button != null:
		_redo_button.disabled = (not _edit_mode_enabled) or (not History.can_redo())


func _on_project_opened(project: Project) -> void:
	if _project_label != null and project != null:
		_project_label.text = project.name


func _on_project_closed() -> void:
	if _project_label != null:
		_project_label.text = ""


func _on_save_state_changed(state: String, unix_time: int) -> void:
	_save_status_state = state
	if state == "saved" and unix_time > 0:
		_last_saved_unix = unix_time
	_refresh_save_status()


func _refresh_save_status() -> void:
	if _save_status == null:
		return
	match _save_status_state:
		"dirty":
			_save_status.text = "● Unsaved"
			_save_status.add_theme_color_override("font_color", ThemeManager.warning_color())
		"saving":
			_save_status.text = "Saving…"
			_save_status.add_theme_color_override("font_color", ThemeManager.info_color())
		"saved":
			if _last_saved_unix == 0:
				_save_status.text = "Saved"
			else:
				var delta: int = int(Time.get_unix_time_from_system()) - _last_saved_unix
				_save_status.text = "Saved %s ago" % _format_delta(delta)
			_save_status.add_theme_color_override("font_color", ThemeManager.dim_foreground_color())
		_:
			_save_status.text = ""


func presence_strip() -> PresenceAvatarStrip:
	return _presence_strip


func _on_annotation_tool_toggled(tool_name: String, pressed: bool) -> void:
	if pressed:
		_active_annotation_tool = tool_name
		_sync_annotation_tool_buttons()
		emit_signal("action_requested", ACTION_ANNOTATION_TOOL, tool_name)
	else:
		if _active_annotation_tool != tool_name:
			return
		_active_annotation_tool = ANNOTATION_TOOL_NONE
		_sync_annotation_tool_buttons()
		emit_signal("action_requested", ACTION_ANNOTATION_TOOL, ANNOTATION_TOOL_NONE)


func _sync_annotation_tool_buttons() -> void:
	if _pen_button != null:
		_pen_button.set_pressed_no_signal(_active_annotation_tool == ANNOTATION_TOOL_PEN)
	if _eraser_button != null:
		_eraser_button.set_pressed_no_signal(_active_annotation_tool == ANNOTATION_TOOL_ERASER)
	if _annotation_select_button != null:
		_annotation_select_button.set_pressed_no_signal(_active_annotation_tool == ANNOTATION_TOOL_SELECT)


func annotation_tool() -> String:
	return _active_annotation_tool


func annotation_color() -> Color:
	if _annotation_color_button == null:
		return AnnotationStroke.DEFAULT_COLOR
	return _annotation_color_button.color


func annotation_width() -> float:
	if _annotation_width_spin == null:
		return AnnotationStroke.DEFAULT_WIDTH
	return AnnotationStroke.clamp_width(float(_annotation_width_spin.value))


func set_annotation_tool(tool_name: String) -> void:
	_active_annotation_tool = tool_name
	_sync_annotation_tool_buttons()


func _on_annotation_color_changed(color: Color) -> void:
	emit_signal("action_requested", ACTION_ANNOTATION_COLOR, color)


func _on_annotation_width_changed(value: float) -> void:
	emit_signal("action_requested", ACTION_ANNOTATION_WIDTH, AnnotationStroke.clamp_width(value))


func _on_connector_tool_toggled(tool_name: String, pressed: bool) -> void:
	if pressed:
		_active_connector_tool = tool_name
		_sync_connector_tool_buttons()
		emit_signal("action_requested", ACTION_CONNECTOR_TOOL, tool_name)
	else:
		if _active_connector_tool != tool_name:
			return
		_active_connector_tool = CONNECTOR_TOOL_NONE
		_sync_connector_tool_buttons()
		emit_signal("action_requested", ACTION_CONNECTOR_TOOL, CONNECTOR_TOOL_NONE)


func _sync_connector_tool_buttons() -> void:
	if _line_tool_button != null:
		_line_tool_button.set_pressed_no_signal(_active_connector_tool == CONNECTOR_TOOL_LINE)
	if _arrow_tool_button != null:
		_arrow_tool_button.set_pressed_no_signal(_active_connector_tool == CONNECTOR_TOOL_ARROW)


func connector_tool() -> String:
	return _active_connector_tool


func set_connector_tool(tool_name: String) -> void:
	_active_connector_tool = tool_name
	_sync_connector_tool_buttons()


func connector_color() -> Color:
	if _connector_color_button == null:
		return ConnectorNode.DEFAULT_COLOR
	return _connector_color_button.color


func connector_width() -> float:
	if _connector_width_spin == null:
		return ConnectorNode.DEFAULT_WIDTH
	return clamp(float(_connector_width_spin.value), ConnectorNode.MIN_WIDTH, ConnectorNode.MAX_WIDTH)


func _on_connector_color_changed(color: Color) -> void:
	emit_signal("action_requested", ACTION_CONNECTOR_COLOR, color)


func _on_connector_width_changed(value: float) -> void:
	var w: float = clamp(value, ConnectorNode.MIN_WIDTH, ConnectorNode.MAX_WIDTH)
	emit_signal("action_requested", ACTION_CONNECTOR_WIDTH, w)


func _format_delta(seconds: int) -> String:
	if seconds < 5:
		return "now"
	if seconds < 60:
		return "%ds" % seconds
	if seconds < 3600:
		return "%dm" % (seconds / 60)
	return "%dh" % (seconds / 3600)


func _on_group_button_toggled(group: String, pressed: bool) -> void:
	if pressed:
		_active_groups[group] = true
	else:
		_active_groups.erase(group)
	_apply_active_groups()


func _apply_active_groups() -> void:
	var groups: Dictionary = {
		GROUP_FILE: [_file_margin, _file_group_button],
		GROUP_EDIT: [_edit_margin, _edit_group_button],
		GROUP_DRAW: [_draw_margin, _draw_group_button],
		GROUP_VIEW: [_view_margin, _view_group_button],
	}
	for key_v: Variant in groups.keys():
		var key: String = key_v
		var entry: Array = groups[key_v]
		var container: MarginContainer = entry[0]
		var btn: Button = entry[1]
		var is_active: bool = _active_groups.has(key)
		if container != null:
			container.visible = is_active
		if btn != null and btn.button_pressed != is_active:
			btn.set_pressed_no_signal(is_active)
	if _expansion_panel != null:
		_expansion_panel.visible = not _active_groups.is_empty()


func collapse_groups() -> void:
	_active_groups.clear()
	_apply_active_groups()


func active_groups() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key_v: Variant in _active_groups.keys():
		result.append(String(key_v))
	return result
