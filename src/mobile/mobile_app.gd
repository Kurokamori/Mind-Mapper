class_name MobileApp
extends Control

const VIEW_PICKER: String = "picker"
const VIEW_BOARD: String = "board"
const VIEW_MAP: String = "map"

@onready var _content_stack: Control = %ContentStack
@onready var _project_picker: MobileProjectPicker = %ProjectPicker
@onready var _board_view: MobileBoardView = %BoardView
@onready var _map_view: MobileMapView = %MapView
@onready var _toolbar: MobileToolbar = %Toolbar
@onready var _toolbar_handle: Button = %ToolbarHandle
@onready var _bottom_sheet: MobileBottomSheet = %BottomSheet
@onready var _toast_layer: MobileToastLayer = %ToastLayer
@onready var _breadcrumb: MobileBreadcrumbBar = %Breadcrumb
@onready var _zoom_overlay: MobileZoomOverlay = %ZoomOverlay
@onready var _edit_action_bar: MobileEditActionBar = %EditActionBar

var _active_view: String = VIEW_PICKER
var _project: Project = null


func _ready() -> void:
	_project_picker.project_opened.connect(_on_picker_project_opened)
	_project_picker.toast_requested.connect(_show_toast)
	_toolbar.action_requested.connect(_on_toolbar_action)
	_toolbar_handle.pressed.connect(_toggle_toolbar)
	_board_view.item_tapped.connect(_on_item_tapped)
	_board_view.empty_tapped.connect(_on_empty_tapped)
	_board_view.navigate_requested.connect(_on_navigate_requested)
	_board_view.comments_changed.connect(_on_board_data_changed)
	_board_view.todo_payload_changed.connect(_on_todo_payload_changed)
	_board_view.mode_changed.connect(_on_board_mode_changed)
	_board_view.selection_changed.connect(_on_board_selection_changed)
	_board_view.connection_tapped.connect(_on_board_connection_tapped)
	_board_view.request_item_type_picker.connect(_on_board_request_type_picker)
	_map_view.map_tapped.connect(_on_empty_tapped)
	_breadcrumb.crumb_selected.connect(_on_breadcrumb_crumb_selected)
	_bottom_sheet.bind_board_view(_board_view)
	_bottom_sheet.item_type_chosen.connect(_on_bottom_sheet_item_type_chosen)
	_bottom_sheet.connection_deleted.connect(_on_bottom_sheet_connection_deleted)
	_bottom_sheet.board_settings_changed.connect(_on_bottom_sheet_board_settings_changed)
	_bottom_sheet.arrange_action_chosen.connect(_on_bottom_sheet_arrange_action)
	_bottom_sheet.navigate_to_item_requested.connect(_navigate_to_item)
	_zoom_overlay.zoom_in_requested.connect(_on_zoom_in_requested)
	_zoom_overlay.zoom_out_requested.connect(_on_zoom_out_requested)
	_zoom_overlay.fit_requested.connect(_on_zoom_fit_requested)
	_zoom_overlay.visible = false
	_edit_action_bar.action_requested.connect(_on_edit_action)
	_edit_action_bar.annotation_color_picked.connect(_on_annotation_color_picked)
	_edit_action_bar.annotation_width_picked.connect(_on_annotation_width_picked)
	History.changed.connect(_on_history_changed)
	set_process(true)
	AppState.project_opened.connect(_on_project_opened)
	AppState.project_closed.connect(_on_project_closed)
	AppState.current_board_changed.connect(_on_current_board_changed)
	AppState.current_map_page_changed.connect(_on_current_map_page_changed)
	AppState.current_page_kind_changed.connect(_on_current_page_kind_changed)
	_show_view(VIEW_PICKER)
	_toolbar.visible = false
	_toolbar_handle.visible = false
	_edit_action_bar.visible = false


func _on_picker_project_opened(project: Project, source: String, remote_label: String) -> void:
	_project = project
	AppState.open_project(project)
	_toolbar.set_project_label(project.name, source, remote_label)
	_toolbar.visible = false
	_toolbar_handle.visible = true
	_show_view(VIEW_BOARD)


func _on_project_opened(_project: Project) -> void:
	_breadcrumb.refresh()


func _on_project_closed() -> void:
	_project = null
	_toolbar.visible = false
	_toolbar_handle.visible = false
	_breadcrumb.clear()
	_bottom_sheet.dismiss()
	_edit_action_bar.visible = false
	_board_view.set_mode(MobileBoardView.MODE_VIEW)
	_show_view(VIEW_PICKER)
	_project_picker.refresh()


func _on_current_board_changed(_board: Board) -> void:
	if AppState.current_page_kind != AppState.PAGE_KIND_BOARD:
		return
	_board_view.bind_board(AppState.current_project, AppState.current_board)
	_breadcrumb.refresh()
	_sync_history_state()


func _on_current_map_page_changed(_page: MapPage) -> void:
	if AppState.current_page_kind != AppState.PAGE_KIND_MAP:
		return
	_map_view.bind_map_page(AppState.current_project, AppState.current_map_page)
	_breadcrumb.refresh()


func _on_current_page_kind_changed(kind: String) -> void:
	match kind:
		AppState.PAGE_KIND_BOARD:
			_show_view(VIEW_BOARD)
			if AppState.current_project != null and AppState.current_board != null:
				_board_view.bind_board(AppState.current_project, AppState.current_board)
		AppState.PAGE_KIND_MAP:
			_show_view(VIEW_MAP)
			if AppState.current_project != null and AppState.current_map_page != null:
				_map_view.bind_map_page(AppState.current_project, AppState.current_map_page)
			_board_view.set_mode(MobileBoardView.MODE_VIEW)
			_edit_action_bar.visible = false


func _on_toolbar_action(action: String, payload: Variant = null) -> void:
	match action:
		MobileToolbar.ACTION_BACK_TO_PROJECTS:
			AppState.close_project()
		MobileToolbar.ACTION_FRAME_ALL:
			if _active_view == VIEW_BOARD:
				_board_view.frame_all_items()
			elif _active_view == VIEW_MAP:
				_map_view.frame_all()
		MobileToolbar.ACTION_TOGGLE_BOARDS:
			_open_board_browser()
		MobileToolbar.ACTION_TOGGLE_MAPS:
			_open_map_browser()
		MobileToolbar.ACTION_TOGGLE_COMMENTS:
			_open_board_comments_panel()
		MobileToolbar.ACTION_NAVIGATE_BACK:
			if not AppState.navigate_back():
				_show_toast("info", "Nothing to go back to")
		MobileToolbar.ACTION_TOGGLE_EDIT:
			_toggle_edit_mode()
		MobileToolbar.ACTION_TOGGLE_OUTLINER:
			if AppState.current_project != null:
				_bottom_sheet.show_outliner(AppState.current_project)
		MobileToolbar.ACTION_CLOSE_TOOLBAR:
			_toolbar.visible = false
		MobileToolbar.ACTION_DRAW_PEN:
			_on_toolbar_draw_tool(MobileBoardView.MODE_PEN, bool(payload))
		MobileToolbar.ACTION_DRAW_ERASER:
			_on_toolbar_draw_tool(MobileBoardView.MODE_ERASER, bool(payload))
		MobileToolbar.ACTION_DRAW_PICK:
			_on_toolbar_draw_tool(MobileBoardView.MODE_CONNECT, bool(payload))
		MobileToolbar.ACTION_DRAW_COLOR:
			if typeof(payload) == TYPE_COLOR:
				_board_view.set_annotation_color(payload)
		MobileToolbar.ACTION_DRAW_WIDTH:
			if typeof(payload) == TYPE_FLOAT or typeof(payload) == TYPE_INT:
				_board_view.set_annotation_width(float(payload))
		MobileToolbar.ACTION_FILE_TEMPLATES:
			_show_toast("info", "Templates — open from desktop for now")
		MobileToolbar.ACTION_FILE_TILESETS:
			_show_toast("info", "Maps & Tilesets — manage from desktop for now")
		MobileToolbar.ACTION_FILE_IMPORT:
			_show_toast("info", "Import — use desktop")
		MobileToolbar.ACTION_FILE_EXPORT:
			_show_toast("info", "Export — use desktop")
		MobileToolbar.ACTION_FILE_SETTINGS:
			_show_toast("info", "Settings — open theme dialog from desktop for now")


func _on_toolbar_draw_tool(mode: String, enable: bool) -> void:
	if not enable:
		if _board_view.current_mode() == mode:
			_board_view.set_mode(MobileBoardView.MODE_EDIT)
		return
	if _board_view.current_mode() == MobileBoardView.MODE_VIEW:
		_enter_edit_mode()
	_board_view.set_mode(mode)


func _on_edit_action(action: String) -> void:
	match action:
		MobileEditActionBar.ACTION_ADD:
			var center_world: Vector2 = _board_view.camera_node().position
			_bottom_sheet.show_item_type_picker(center_world)
		MobileEditActionBar.ACTION_UNDO:
			_board_view.undo()
		MobileEditActionBar.ACTION_REDO:
			_board_view.redo()
		MobileEditActionBar.ACTION_TOGGLE_CONNECT:
			_set_mode_toggle(MobileBoardView.MODE_CONNECT)
		MobileEditActionBar.ACTION_TOGGLE_PEN:
			_set_mode_toggle(MobileBoardView.MODE_PEN)
		MobileEditActionBar.ACTION_TOGGLE_ERASER:
			_set_mode_toggle(MobileBoardView.MODE_ERASER)
		MobileEditActionBar.ACTION_DELETE:
			_board_view.delete_selected()
		MobileEditActionBar.ACTION_DUPLICATE:
			_board_view.duplicate_selected()
		MobileEditActionBar.ACTION_TOGGLE_LOCK:
			_board_view.toggle_lock_for_selected()
		MobileEditActionBar.ACTION_EXIT_EDIT:
			_exit_edit_mode()
		MobileEditActionBar.ACTION_BOARD_SETTINGS:
			if AppState.current_project != null and AppState.current_board != null:
				_bottom_sheet.show_board_settings(AppState.current_project, AppState.current_board)
		MobileEditActionBar.ACTION_ARRANGE:
			_bottom_sheet.show_arrange(_board_view.selected_item_ids().size())
		MobileEditActionBar.ACTION_SNAP:
			_bottom_sheet.show_snap_settings()


func _on_annotation_color_picked(color: Color) -> void:
	_board_view.set_annotation_color(color)


func _on_annotation_width_picked(width: float) -> void:
	_board_view.set_annotation_width(width)


func _set_mode_toggle(target_mode: String) -> void:
	if _board_view.current_mode() == target_mode:
		_board_view.set_mode(MobileBoardView.MODE_EDIT)
		return
	_board_view.set_mode(target_mode)


func _toggle_edit_mode() -> void:
	if _active_view != VIEW_BOARD:
		return
	if _board_view.current_mode() == MobileBoardView.MODE_VIEW:
		_enter_edit_mode()
	else:
		_exit_edit_mode()


func _enter_edit_mode() -> void:
	_board_view.set_mode(MobileBoardView.MODE_EDIT)
	_edit_action_bar.visible = true
	_toolbar.set_edit_state(true)
	_toolbar.visible = false
	_sync_history_state()
	_sync_selection_state()


func _exit_edit_mode() -> void:
	_board_view.set_mode(MobileBoardView.MODE_VIEW)
	_board_view.clear_selection()
	_edit_action_bar.visible = false
	_toolbar.set_edit_state(false)


func _on_board_mode_changed(mode: String) -> void:
	_edit_action_bar.set_mode(mode)
	_edit_action_bar.visible = mode != MobileBoardView.MODE_VIEW
	_toolbar.set_draw_tool(_draw_tool_for_mode(mode))
	_sync_selection_state()


func _draw_tool_for_mode(mode: String) -> String:
	match mode:
		MobileBoardView.MODE_PEN:
			return MobileToolbar.DRAW_TOOL_PEN
		MobileBoardView.MODE_ERASER:
			return MobileToolbar.DRAW_TOOL_ERASER
		MobileBoardView.MODE_CONNECT:
			return MobileToolbar.DRAW_TOOL_PICK
		_:
			return MobileToolbar.DRAW_TOOL_NONE


func _on_board_selection_changed(_ids: Array) -> void:
	_sync_selection_state()


func _on_board_request_type_picker(world_position: Vector2) -> void:
	_bottom_sheet.show_item_type_picker(world_position)


func _on_board_connection_tapped(connection_id: String) -> void:
	if AppState.current_project == null or AppState.current_board == null:
		return
	_bottom_sheet.show_connection_editor(AppState.current_project, AppState.current_board, connection_id)


func _on_bottom_sheet_item_type_chosen(type_id: String, world_position: Vector2) -> void:
	if not _board_view.create_item_at(type_id, world_position):
		_show_toast("warning", "Could not create item")


func _on_bottom_sheet_connection_deleted(_connection_id: String) -> void:
	_board_view.clear_selection()


func _on_bottom_sheet_board_settings_changed() -> void:
	_breadcrumb.refresh()


func _on_bottom_sheet_arrange_action(action: String) -> void:
	match action:
		MobileArrangeSheet.ACTION_GROUP:
			if not _board_view.group_selected():
				_show_toast("info", "Nothing to group")
		MobileArrangeSheet.ACTION_ALIGN_LEFT, \
		MobileArrangeSheet.ACTION_ALIGN_HCENTER, \
		MobileArrangeSheet.ACTION_ALIGN_RIGHT, \
		MobileArrangeSheet.ACTION_ALIGN_TOP, \
		MobileArrangeSheet.ACTION_ALIGN_VCENTER, \
		MobileArrangeSheet.ACTION_ALIGN_BOTTOM:
			_board_view.align_selected(action)
		MobileArrangeSheet.ACTION_DISTRIBUTE_H:
			_board_view.distribute_selected(true)
		MobileArrangeSheet.ACTION_DISTRIBUTE_V:
			_board_view.distribute_selected(false)
		MobileArrangeSheet.ACTION_BRING_FORWARD:
			_board_view.reorder_selected(ReorderItemsCommand.DIR_BRING_FORWARD)
		MobileArrangeSheet.ACTION_BRING_TO_FRONT:
			_board_view.reorder_selected(ReorderItemsCommand.DIR_BRING_TO_FRONT)
		MobileArrangeSheet.ACTION_SEND_BACKWARD:
			_board_view.reorder_selected(ReorderItemsCommand.DIR_SEND_BACKWARD)
		MobileArrangeSheet.ACTION_SEND_TO_BACK:
			_board_view.reorder_selected(ReorderItemsCommand.DIR_SEND_TO_BACK)


func _on_history_changed() -> void:
	_sync_history_state()


func _sync_history_state() -> void:
	_edit_action_bar.set_history_state(History.can_undo(), History.can_redo())


func _sync_selection_state() -> void:
	var ids: Array[String] = _board_view.selected_item_ids()
	_edit_action_bar.set_selection_state(ids.size(), _board_view.selected_connection_id())
	_bottom_sheet.arrange_selection_changed(ids.size())


func _toggle_toolbar() -> void:
	_toolbar.visible = not _toolbar.visible


func _on_item_tapped(item_id: String) -> void:
	if AppState.current_board == null or AppState.current_project == null:
		return
	var item_dict: Dictionary = _board_view.find_item_dict(item_id)
	if item_dict.is_empty():
		return
	_bottom_sheet.show_item(AppState.current_project, AppState.current_board, item_dict)


func _on_empty_tapped() -> void:
	_bottom_sheet.dismiss()


func _on_navigate_requested(target_kind: String, target_id: String) -> void:
	match target_kind:
		BoardItem.LINK_KIND_BOARD:
			AppState.navigate_to_board(target_id)
		BoardItem.LINK_KIND_MAP_PAGE:
			AppState.navigate_to_map_page(target_id)
		BoardItem.LINK_KIND_ITEM:
			_navigate_to_item(target_id)
		_:
			_show_toast("warning", "Unknown link target")


func _navigate_to_item(item_id: String) -> void:
	if item_id == "":
		return
	if AppState.current_board != null:
		var local: BoardItem = _board_view.find_item_node(item_id)
		if local != null:
			_board_view.focus_item(item_id)
			return
	var hit: Dictionary = ProjectIndex.find_item(item_id)
	if hit.is_empty():
		_show_toast("warning", "Target item not found")
		return
	var board_id: String = String(hit.get("board_id", ""))
	if board_id == "":
		_show_toast("warning", "Target item is detached")
		return
	_board_view.set_pending_focus_item(item_id)
	if not AppState.navigate_to_board(board_id):
		_board_view.set_pending_focus_item("")
		_show_toast("warning", "Could not navigate to target board")


func _on_board_data_changed() -> void:
	if AppState.current_board != null:
		AppState.emit_signal("board_modified", AppState.current_board.id)


func _on_todo_payload_changed(item_id: String) -> void:
	_bottom_sheet.notify_item_payload_changed(item_id)


func _on_breadcrumb_crumb_selected(kind: String, target_id: String) -> void:
	if kind == AppState.PAGE_KIND_BOARD:
		AppState.navigate_to_board(target_id)
	elif kind == AppState.PAGE_KIND_MAP:
		AppState.navigate_to_map_page(target_id)


func _open_board_browser() -> void:
	if AppState.current_project == null:
		return
	_bottom_sheet.show_board_browser(AppState.current_project)


func _open_map_browser() -> void:
	if AppState.current_project == null:
		return
	_bottom_sheet.show_map_browser(AppState.current_project)


func _open_board_comments_panel() -> void:
	if AppState.current_project == null or AppState.current_board == null:
		return
	_bottom_sheet.show_board_comments(AppState.current_project, AppState.current_board)


func _show_view(name: String) -> void:
	_active_view = name
	_project_picker.visible = name == VIEW_PICKER
	_board_view.visible = name == VIEW_BOARD
	_map_view.visible = name == VIEW_MAP
	_zoom_overlay.visible = name == VIEW_BOARD or name == VIEW_MAP
	_toolbar.set_edit_button_visible(name == VIEW_BOARD)
	if name != VIEW_BOARD:
		_edit_action_bar.visible = false
	_apply_active_camera_current()


func _apply_active_camera_current() -> void:
	var board_cam: MobileCameraController = _board_view.get_node_or_null("World/Camera") as MobileCameraController
	var map_cam: MobileCameraController = _map_view.get_node_or_null("World/Camera") as MobileCameraController
	if _active_view == VIEW_BOARD:
		if map_cam != null:
			map_cam.enabled = false
		if board_cam != null:
			board_cam.enabled = true
			board_cam.make_current()
		return
	if _active_view == VIEW_MAP:
		if board_cam != null:
			board_cam.enabled = false
		if map_cam != null:
			map_cam.enabled = true
			map_cam.make_current()
		return
	if board_cam != null:
		board_cam.enabled = false
	if map_cam != null:
		map_cam.enabled = false


func _on_zoom_in_requested() -> void:
	var camera: MobileCameraController = _active_camera()
	if camera == null:
		return
	camera.zoom_in()


func _on_zoom_out_requested() -> void:
	var camera: MobileCameraController = _active_camera()
	if camera == null:
		return
	camera.zoom_out()


func _on_zoom_fit_requested() -> void:
	if _active_view == VIEW_BOARD:
		_board_view.frame_all_items()
	elif _active_view == VIEW_MAP:
		_map_view.frame_all()


func _active_camera() -> MobileCameraController:
	if _active_view == VIEW_BOARD:
		return _board_view.get_node("World/Camera") as MobileCameraController
	if _active_view == VIEW_MAP:
		return _map_view.get_node("World/Camera") as MobileCameraController
	return null


func _process(_delta: float) -> void:
	if not _zoom_overlay.visible:
		return
	var camera: MobileCameraController = _active_camera()
	if camera != null:
		_zoom_overlay.update_zoom(camera.zoom.x)


func _show_toast(severity: String, message: String) -> void:
	if _toast_layer != null:
		_toast_layer.toast(severity, message)
