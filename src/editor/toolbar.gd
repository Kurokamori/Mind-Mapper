class_name EditorToolbar
extends PanelContainer

signal action_requested(action: String, payload: Variant)

const ACTION_ADD: String = "add"
const ACTION_TOGGLE_INSPECTOR: String = "toggle_inspector"
const ACTION_TOGGLE_OUTLINER: String = "toggle_outliner"
const ACTION_TOGGLE_MINIMAP: String = "toggle_minimap"
const ACTION_OPEN_PALETTE: String = "open_palette"
const ACTION_UNDO: String = "undo"
const ACTION_REDO: String = "redo"
const ACTION_SAVE: String = "save"
const ACTION_BACK_TO_PROJECTS: String = "back_to_projects"
const ACTION_GROUP: String = "group"
const ACTION_EXPORT_PNG: String = "export_png"
const ACTION_TOGGLE_CONNECT: String = "toggle_connect"

const EXPORT_MODE_CURRENT: String = "current"
const EXPORT_MODE_UNFOLDED: String = "unfolded"

@onready var _project_label: Label = %ProjectLabel
@onready var _back_button: Button = %BackButton
@onready var _save_button: Button = %SaveButton
@onready var _add_menu_button: MenuButton = %AddMenuButton
@onready var _undo_button: Button = %UndoButton
@onready var _redo_button: Button = %RedoButton
@onready var _snap_button: Button = %SnapButton
@onready var _align_button: Button = %AlignButton
@onready var _inspector_button: Button = %InspectorButton
@onready var _outliner_button: Button = %OutlinerButton
@onready var _minimap_button: Button = %MinimapButton
@onready var _group_button: Button = %GroupButton
@onready var _connect_button: Button = %ConnectButton
@onready var _export_button: MenuButton = %ExportButton


func _ready() -> void:
	_back_button.pressed.connect(func() -> void: emit_signal("action_requested", ACTION_BACK_TO_PROJECTS, null))
	_save_button.pressed.connect(func() -> void: emit_signal("action_requested", ACTION_SAVE, null))
	_undo_button.pressed.connect(func() -> void: emit_signal("action_requested", ACTION_UNDO, null))
	_redo_button.pressed.connect(func() -> void: emit_signal("action_requested", ACTION_REDO, null))
	_snap_button.toggled.connect(_on_snap_toggled)
	_align_button.toggled.connect(_on_align_toggled)
	_inspector_button.toggled.connect(_on_inspector_toggled)
	_outliner_button.toggled.connect(_on_outliner_toggled)
	_minimap_button.toggled.connect(_on_minimap_toggled)
	_group_button.pressed.connect(func() -> void: emit_signal("action_requested", ACTION_GROUP, null))
	_connect_button.toggled.connect(func(pressed_state: bool) -> void: emit_signal("action_requested", ACTION_TOGGLE_CONNECT, pressed_state))
	_populate_export_menu()
	_populate_add_menu()
	History.changed.connect(_refresh_history_buttons)
	SnapService.changed.connect(_refresh_snap)
	AlignmentGuideService.changed.connect(_refresh_align)
	AppState.project_opened.connect(_on_project_opened)
	AppState.project_closed.connect(_on_project_closed)
	if AppState.current_project != null:
		_on_project_opened(AppState.current_project)
	_refresh_history_buttons()
	_refresh_snap()
	_refresh_align()


func _populate_add_menu() -> void:
	var popup: PopupMenu = _add_menu_button.get_popup()
	popup.clear()
	popup.add_item("Text", 0)
	popup.set_item_metadata(0, ItemRegistry.TYPE_TEXT)
	popup.add_item("Label", 1)
	popup.set_item_metadata(1, ItemRegistry.TYPE_LABEL)
	popup.add_item("Rich Text", 2)
	popup.set_item_metadata(2, ItemRegistry.TYPE_RICH_TEXT)
	popup.add_separator()
	popup.add_item("Image…", 4)
	popup.set_item_metadata(4, ItemRegistry.TYPE_IMAGE)
	popup.add_item("Sound…", 5)
	popup.set_item_metadata(5, ItemRegistry.TYPE_SOUND)
	popup.add_separator()
	popup.add_item("Primitive Shape", 7)
	popup.set_item_metadata(7, ItemRegistry.TYPE_PRIMITIVE)
	popup.add_item("Group Frame", 8)
	popup.set_item_metadata(8, ItemRegistry.TYPE_GROUP)
	popup.add_item("Timer", 9)
	popup.set_item_metadata(9, ItemRegistry.TYPE_TIMER)
	popup.add_separator()
	popup.add_item("Pinboard", 11)
	popup.set_item_metadata(11, ItemRegistry.TYPE_PINBOARD)
	popup.add_item("Subpage", 12)
	popup.set_item_metadata(12, ItemRegistry.TYPE_SUBPAGE)
	popup.add_separator()
	popup.add_item("Todo List", 14)
	popup.set_item_metadata(14, ItemRegistry.TYPE_TODO_LIST)
	popup.add_item("Block Stack", 15)
	popup.set_item_metadata(15, ItemRegistry.TYPE_BLOCK_STACK)
	if not popup.id_pressed.is_connected(_on_add_menu_id_pressed):
		popup.id_pressed.connect(_on_add_menu_id_pressed)


func _on_add_menu_id_pressed(id: int) -> void:
	var popup: PopupMenu = _add_menu_button.get_popup()
	var idx: int = popup.get_item_index(id)
	if idx < 0:
		return
	var type_id: String = String(popup.get_item_metadata(idx))
	emit_signal("action_requested", ACTION_ADD, type_id)


func _populate_export_menu() -> void:
	var popup: PopupMenu = _export_button.get_popup()
	popup.clear()
	popup.add_item("Current Board…", 0)
	popup.set_item_metadata(0, EXPORT_MODE_CURRENT)
	popup.add_item("Unfolded (all subpages)…", 1)
	popup.set_item_metadata(1, EXPORT_MODE_UNFOLDED)
	if not popup.id_pressed.is_connected(_on_export_menu_id_pressed):
		popup.id_pressed.connect(_on_export_menu_id_pressed)


func _on_export_menu_id_pressed(id: int) -> void:
	var popup: PopupMenu = _export_button.get_popup()
	var idx: int = popup.get_item_index(id)
	if idx < 0:
		return
	var mode: String = String(popup.get_item_metadata(idx))
	emit_signal("action_requested", ACTION_EXPORT_PNG, mode)


func _on_snap_toggled(pressed: bool) -> void:
	SnapService.set_enabled(pressed)


func _on_align_toggled(pressed: bool) -> void:
	AlignmentGuideService.set_enabled(pressed)


func _on_inspector_toggled(pressed: bool) -> void:
	emit_signal("action_requested", ACTION_TOGGLE_INSPECTOR, pressed)


func _on_outliner_toggled(pressed: bool) -> void:
	emit_signal("action_requested", ACTION_TOGGLE_OUTLINER, pressed)


func _on_minimap_toggled(pressed: bool) -> void:
	emit_signal("action_requested", ACTION_TOGGLE_MINIMAP, pressed)


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


func set_connect_pressed(pressed: bool) -> void:
	if _connect_button == null:
		return
	if _connect_button.button_pressed != pressed:
		_connect_button.set_pressed_no_signal(pressed)


func _refresh_snap() -> void:
	if _snap_button == null:
		return
	_snap_button.button_pressed = SnapService.enabled
	_snap_button.text = "Snap: On" if SnapService.enabled else "Snap: Off"


func _refresh_align() -> void:
	if _align_button == null:
		return
	_align_button.button_pressed = AlignmentGuideService.enabled
	_align_button.text = "Align: On" if AlignmentGuideService.enabled else "Align: Off"


func _refresh_history_buttons() -> void:
	if _undo_button != null:
		_undo_button.disabled = not History.can_undo()
	if _redo_button != null:
		_redo_button.disabled = not History.can_redo()


func _on_project_opened(project: Project) -> void:
	if _project_label != null and project != null:
		_project_label.text = project.name


func _on_project_closed() -> void:
	if _project_label != null:
		_project_label.text = ""
