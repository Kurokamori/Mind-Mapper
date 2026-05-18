class_name MobileBottomSheet
extends PanelContainer

signal item_type_chosen(type_id: String, world_position: Vector2)
signal connection_deleted(connection_id: String)
signal board_settings_changed()
signal arrange_action_chosen(action: String)
signal navigate_to_item_requested(item_id: String)

const MODE_HIDDEN: String = "hidden"
const MODE_ITEM: String = "item"
const MODE_BOARDS: String = "boards"
const MODE_MAPS: String = "maps"
const MODE_BOARD_COMMENTS: String = "board_comments"
const MODE_TYPE_PICKER: String = "type_picker"
const MODE_CONNECTION: String = "connection"
const MODE_BOARD_SETTINGS: String = "board_settings"
const MODE_OUTLINER: String = "outliner"
const MODE_SNAP: String = "snap"
const MODE_ARRANGE: String = "arrange"
const MODE_MULTIPLAYER: String = "multiplayer"

const ITEM_PAGE_SCENE: PackedScene = preload("res://src/mobile/sheets/mobile_item_sheet.tscn")
const BOARDS_PAGE_SCENE: PackedScene = preload("res://src/mobile/sheets/mobile_board_browser_sheet.tscn")
const MAPS_PAGE_SCENE: PackedScene = preload("res://src/mobile/sheets/mobile_map_browser_sheet.tscn")
const COMMENTS_PAGE_SCENE: PackedScene = preload("res://src/mobile/sheets/mobile_board_comments_sheet.tscn")
const TYPE_PICKER_PAGE_SCENE: PackedScene = preload("res://src/mobile/sheets/mobile_item_type_picker_sheet.tscn")
const CONNECTION_PAGE_SCENE: PackedScene = preload("res://src/mobile/sheets/mobile_connection_sheet.tscn")
const BOARD_SETTINGS_PAGE_SCENE: PackedScene = preload("res://src/mobile/sheets/mobile_board_settings_sheet.tscn")
const OUTLINER_PAGE_SCENE: PackedScene = preload("res://src/mobile/sheets/mobile_outliner_sheet.tscn")
const SNAP_PAGE_SCENE: PackedScene = preload("res://src/mobile/sheets/mobile_snap_settings_sheet.tscn")
const ARRANGE_PAGE_SCENE: PackedScene = preload("res://src/mobile/sheets/mobile_arrange_sheet.tscn")
const MULTIPLAYER_PAGE_SCENE: PackedScene = preload("res://src/mobile/sheets/mobile_multiplayer_sheet.tscn")

@onready var _header_label: Label = %HeaderLabel
@onready var _close_button: Button = %CloseSheetButton
@onready var _content_root: Control = %ContentRoot
@onready var _drag_handle_button: Button = %DragHandleButton

var _mode: String = MODE_HIDDEN
var _current_page: Control = null
var _project: Project = null
var _board: Board = null
var _focused_item_id: String = ""
var _board_view: MobileBoardView = null
var _pending_create_world_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_close_button.pressed.connect(dismiss)
	_drag_handle_button.pressed.connect(dismiss)
	visible = false


func bind_board_view(view: MobileBoardView) -> void:
	_board_view = view


func dismiss() -> void:
	_clear_content()
	_mode = MODE_HIDDEN
	visible = false


func show_item(project: Project, board: Board, item_dict: Dictionary) -> void:
	_project = project
	_board = board
	_focused_item_id = String(item_dict.get("id", ""))
	_clear_content()
	var page: MobileItemSheet = ITEM_PAGE_SCENE.instantiate()
	_current_page = page
	_content_root.add_child(page)
	page.bind_item(project, board, item_dict, _board_view)
	page.comments_changed.connect(_on_child_comments_changed)
	page.todo_payload_changed.connect(_on_child_todo_changed)
	page.navigate_requested.connect(_on_child_navigate_requested)
	_header_label.text = page.computed_title()
	_mode = MODE_ITEM
	visible = true


func notify_item_payload_changed(item_id: String) -> void:
	if _mode != MODE_ITEM or _current_page == null:
		return
	if item_id != _focused_item_id:
		return
	if _current_page is MobileItemSheet and _board_view != null:
		var refreshed: Dictionary = _board_view.find_item_dict(item_id)
		(_current_page as MobileItemSheet).refresh_with(_board, refreshed)


func show_board_browser(project: Project) -> void:
	_project = project
	_clear_content()
	var page: MobileBoardBrowserSheet = BOARDS_PAGE_SCENE.instantiate()
	_current_page = page
	_content_root.add_child(page)
	page.bind(project)
	page.board_chosen.connect(_on_board_chosen)
	_header_label.text = "Boards"
	_mode = MODE_BOARDS
	visible = true


func show_map_browser(project: Project) -> void:
	_project = project
	_clear_content()
	var page: MobileMapBrowserSheet = MAPS_PAGE_SCENE.instantiate()
	_current_page = page
	_content_root.add_child(page)
	page.bind(project)
	page.map_chosen.connect(_on_map_chosen)
	_header_label.text = "Maps"
	_mode = MODE_MAPS
	visible = true


func show_board_comments(project: Project, board: Board) -> void:
	_project = project
	_board = board
	_clear_content()
	var page: MobileBoardCommentsSheet = COMMENTS_PAGE_SCENE.instantiate()
	_current_page = page
	_content_root.add_child(page)
	page.bind(project, board, _board_view)
	page.comments_changed.connect(_on_child_comments_changed)
	_header_label.text = "Comments on '%s'" % board.name
	_mode = MODE_BOARD_COMMENTS
	visible = true


func show_item_type_picker(world_position: Vector2) -> void:
	_pending_create_world_pos = world_position
	_clear_content()
	var page: MobileItemTypePickerSheet = TYPE_PICKER_PAGE_SCENE.instantiate()
	_current_page = page
	_content_root.add_child(page)
	page.type_chosen.connect(_on_item_type_chosen)
	_header_label.text = "Add item"
	_mode = MODE_TYPE_PICKER
	visible = true


func show_connection_editor(project: Project, board: Board, connection_id: String) -> void:
	_project = project
	_board = board
	_clear_content()
	var page: MobileConnectionSheet = CONNECTION_PAGE_SCENE.instantiate()
	_current_page = page
	_content_root.add_child(page)
	page.bind_connection(_board_view, connection_id)
	page.connection_deleted.connect(_on_connection_deleted)
	_header_label.text = "Connection"
	_mode = MODE_CONNECTION
	visible = true


func show_board_settings(project: Project, board: Board) -> void:
	_project = project
	_board = board
	_clear_content()
	var page: MobileBoardSettingsSheet = BOARD_SETTINGS_PAGE_SCENE.instantiate()
	_current_page = page
	_content_root.add_child(page)
	page.bind(project, board, _board_view)
	page.settings_changed.connect(_on_board_settings_changed)
	_header_label.text = "Board settings"
	_mode = MODE_BOARD_SETTINGS
	visible = true


func show_outliner(project: Project) -> void:
	_project = project
	_clear_content()
	var page: MobileOutlinerSheet = OUTLINER_PAGE_SCENE.instantiate()
	_current_page = page
	_content_root.add_child(page)
	page.bind(project)
	page.board_chosen.connect(_on_outliner_board_chosen)
	page.map_chosen.connect(_on_outliner_map_chosen)
	_header_label.text = "Outliner"
	_mode = MODE_OUTLINER
	visible = true


func show_snap_settings() -> void:
	_clear_content()
	var page: MobileSnapSettingsSheet = SNAP_PAGE_SCENE.instantiate()
	_current_page = page
	_content_root.add_child(page)
	_header_label.text = "Snap & grid"
	_mode = MODE_SNAP
	visible = true


func show_arrange(selection_count: int) -> void:
	_clear_content()
	var page: MobileArrangeSheet = ARRANGE_PAGE_SCENE.instantiate()
	_current_page = page
	_content_root.add_child(page)
	page.update_selection_state(selection_count)
	page.action_chosen.connect(_on_arrange_action_chosen)
	_header_label.text = "Arrange"
	_mode = MODE_ARRANGE
	visible = true


func show_multiplayer() -> void:
	_clear_content()
	var page: MobileMultiplayerSheet = MULTIPLAYER_PAGE_SCENE.instantiate()
	_current_page = page
	_content_root.add_child(page)
	_header_label.text = "Multiplayer"
	_mode = MODE_MULTIPLAYER
	visible = true


func arrange_selection_changed(selection_count: int) -> void:
	if _mode != MODE_ARRANGE or _current_page == null:
		return
	(_current_page as MobileArrangeSheet).update_selection_state(selection_count)


func _clear_content() -> void:
	if _current_page != null:
		_current_page.queue_free()
		_current_page = null
	for child: Node in _content_root.get_children():
		child.queue_free()


func _on_board_chosen(board_id: String) -> void:
	AppState.navigate_to_board(board_id)
	dismiss()


func _on_map_chosen(map_id: String) -> void:
	AppState.navigate_to_map_page(map_id)
	dismiss()


func _on_child_comments_changed() -> void:
	pass


func _on_child_todo_changed(_item_id: String) -> void:
	pass


func _on_child_navigate_requested(target_kind: String, target_id: String) -> void:
	match target_kind:
		BoardItem.LINK_KIND_BOARD:
			AppState.navigate_to_board(target_id)
			dismiss()
		BoardItem.LINK_KIND_MAP_PAGE:
			AppState.navigate_to_map_page(target_id)
			dismiss()
		BoardItem.LINK_KIND_ITEM:
			navigate_to_item_requested.emit(target_id)
			dismiss()


func _on_item_type_chosen(type_id: String) -> void:
	item_type_chosen.emit(type_id, _pending_create_world_pos)
	dismiss()


func _on_connection_deleted(connection_id: String) -> void:
	connection_deleted.emit(connection_id)
	dismiss()


func _on_board_settings_changed() -> void:
	board_settings_changed.emit()


func _on_outliner_board_chosen(board_id: String) -> void:
	AppState.navigate_to_board(board_id)
	dismiss()


func _on_outliner_map_chosen(map_id: String) -> void:
	AppState.navigate_to_map_page(map_id)
	dismiss()


func _on_arrange_action_chosen(action: String) -> void:
	arrange_action_chosen.emit(action)
