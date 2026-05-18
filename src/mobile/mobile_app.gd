class_name MobileApp
extends Control

const VIEW_PICKER: String = "picker"
const VIEW_BOARD: String = "board"
const VIEW_MAP: String = "map"

const BASE_VIEWPORT_SIZE: Vector2 = Vector2(1280.0, 800.0)
const PORTRAIT_CONTENT_SCALE: float = BASE_VIEWPORT_SIZE.x / BASE_VIEWPORT_SIZE.y
const LANDSCAPE_CONTENT_SCALE: float = 1.0
const MOBILE_DEFAULT_UI_ZOOM: float = 1.5

const THEME_DIALOG_SCENE: PackedScene = preload("res://src/editor/dialogs/theme_dialog.tscn")
const KEYBINDINGS_DIALOG_SCENE: PackedScene = preload("res://src/editor/dialogs/keybindings_dialog.tscn")
const IMPORT_DIALOG_SCENE: PackedScene = preload("res://src/mobile/dialogs/mobile_import_dialog.tscn")
const EXPORT_DIALOG_SCENE: PackedScene = preload("res://src/mobile/dialogs/mobile_export_dialog.tscn")
const EMBED_CHOICE_DIALOG_SCENE: PackedScene = preload("res://src/mobile/dialogs/mobile_embed_choice_dialog.tscn")

const IMPORT_BATCH_NODE_SIZE_IMAGE: Vector2 = Vector2(240.0, 180.0)
const IMPORT_BATCH_NODE_SIZE_SOUND: Vector2 = Vector2(280.0, 110.0)
const IMPORT_BATCH_NODE_SIZE_DOCUMENT: Vector2 = Vector2(320.0, 260.0)
const IMPORT_BATCH_GAP: float = 24.0
const IMPORT_BATCH_MAX_COLS: int = 4

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
@onready var _view_mode_toggle: MobileViewModeToggle = %ViewModeToggle
@onready var _nodes_lock_toggle: MobileNodesLockToggle = %NodesLockToggle
@onready var _edit_action_bar: MobileEditActionBar = %EditActionBar
@onready var _safe_area: MobileSafeArea = %SafeArea
@onready var _loading_view: LoadingView = %LoadingView
@onready var _top_bar: VBoxContainer = $CanvasLayer/TopBar
@onready var _handle_anchor: Control = $CanvasLayer/HandleAnchor
@onready var _zoom_overlay_anchor: Control = $CanvasLayer/ZoomOverlayAnchor
@onready var _view_mode_toggle_anchor: Control = $CanvasLayer/ViewModeToggleAnchor
@onready var _nodes_lock_toggle_anchor: Control = $CanvasLayer/NodesLockToggleAnchor

const TOP_BAR_BASE_OFFSET: float = 8.0
const HANDLE_BASE_TOP: float = 8.0
const HANDLE_BASE_WIDTH: float = 64.0
const HANDLE_BASE_RIGHT_MARGIN: float = 8.0
const ZOOM_BASE_RIGHT_MARGIN: float = 16.0
const ZOOM_BASE_BOTTOM_MARGIN: float = 16.0
const ZOOM_BASE_WIDTH: float = 72.0
const ZOOM_BASE_HEIGHT: float = 244.0
const EDIT_BAR_BASE_HEIGHT: float = 148.0
const VIEW_TOGGLE_BASE_WIDTH: float = 148.0
const VIEW_TOGGLE_BASE_HEIGHT: float = 56.0
const VIEW_TOGGLE_GAP_TO_ZOOM: float = 8.0
const NODES_LOCK_BASE_WIDTH: float = 168.0
const NODES_LOCK_BASE_HEIGHT: float = 56.0
const NODES_LOCK_GAP_TO_VIEW_TOGGLE: float = 8.0
const BOTTOM_OVERLAY_EDIT_GAP: float = 8.0
const PICKER_BASE_MARGIN_TOP: float = 45.0
const PICKER_BASE_MARGIN_SIDE: float = 15.0
const PICKER_BASE_MARGIN_BOTTOM: float = 15.0

var _active_view: String = VIEW_PICKER
var _project: Project = null
var _safe_inset_top: float = 0.0
var _safe_inset_right: float = 0.0
var _safe_inset_bottom: float = 0.0
var _safe_inset_left: float = 0.0
var _reconnect_orchestrator: MobileReconnectOrchestrator = null

const STICKY_RECONNECT_TOAST_ID: String = "mobile_reconnect_status"


func _ready() -> void:
	_project_picker.project_opened.connect(_on_picker_project_opened)
	_project_picker.toast_requested.connect(_show_toast)
	_project_picker.loading_requested.connect(_on_loading_requested)
	_project_picker.loading_progress.connect(_on_loading_progress)
	_project_picker.loading_dismissed.connect(_on_loading_dismissed)
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
	_view_mode_toggle.toggle_requested.connect(_on_view_mode_toggle_requested)
	_view_mode_toggle.set_edit_active(false)
	_view_mode_toggle_anchor.visible = false
	_nodes_lock_toggle.toggle_requested.connect(_on_nodes_lock_toggle_requested)
	_nodes_lock_toggle.set_locked(_board_view.nodes_locked())
	_nodes_lock_toggle_anchor.visible = false
	_board_view.nodes_lock_changed.connect(_on_board_nodes_lock_changed)
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
	get_viewport().size_changed.connect(_apply_orientation_scale)
	if UserPrefs != null:
		if not UserPrefs.has_explicit_ui_zoom():
			UserPrefs.ui_zoom = MOBILE_DEFAULT_UI_ZOOM
		if not UserPrefs.ui_zoom_changed.is_connected(_on_user_ui_zoom_changed):
			UserPrefs.ui_zoom_changed.connect(_on_user_ui_zoom_changed)
	_apply_orientation_scale()
	get_tree().root.gui_embed_subwindows = true
	_safe_area.insets_changed.connect(_on_safe_area_insets_changed)
	_safe_area.force_refresh()
	_install_reconnect_orchestrator()


func _install_reconnect_orchestrator() -> void:
	_reconnect_orchestrator = MobileReconnectOrchestrator.new()
	_reconnect_orchestrator.name = "ReconnectOrchestrator"
	add_child(_reconnect_orchestrator)
	if _project_picker != null:
		_reconnect_orchestrator.bind_lan_sync_client(_project_picker.lan_sync_client())
	_reconnect_orchestrator.attempt_started.connect(_on_reconnect_attempt_started)
	_reconnect_orchestrator.reconnect_succeeded.connect(_on_reconnect_succeeded)
	_reconnect_orchestrator.reconnect_failed.connect(_on_reconnect_failed)
	_reconnect_orchestrator.reconnect_skipped.connect(_on_reconnect_skipped)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_on_app_paused()
		NOTIFICATION_APPLICATION_RESUMED:
			_on_app_resumed()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			pass


func _on_app_paused() -> void:
	if _reconnect_orchestrator == null:
		return
	_reconnect_orchestrator.notify_suspended()


func _on_app_resumed() -> void:
	if _reconnect_orchestrator == null:
		return
	if not _reconnect_orchestrator.has_anything_to_reconnect():
		return
	_reconnect_orchestrator.start_reconnect()


func _on_reconnect_attempt_started(attempt: int, max_attempts: int) -> void:
	if _toast_layer == null:
		return
	_toast_layer.show_sticky(
		STICKY_RECONNECT_TOAST_ID,
		"info",
		"Reconnecting… (%d / %d)" % [attempt, max_attempts],
	)


func _on_reconnect_succeeded(scopes: Array) -> void:
	if _toast_layer != null:
		_toast_layer.dismiss_sticky(STICKY_RECONNECT_TOAST_ID)
	var label: String = _describe_scopes(scopes)
	_show_toast("success", "Reconnected%s" % ("" if label == "" else " (%s)" % label))


func _on_reconnect_failed(_scopes: Array, reason: String) -> void:
	if _toast_layer != null:
		_toast_layer.dismiss_sticky(STICKY_RECONNECT_TOAST_ID)
	var detail: String = "" if reason == "" else " — %s" % reason
	_show_toast("warning", "Reconnect failed%s" % detail)


func _on_reconnect_skipped() -> void:
	if _toast_layer != null:
		_toast_layer.dismiss_sticky(STICKY_RECONNECT_TOAST_ID)


func _describe_scopes(scopes: Array) -> String:
	var parts: Array = []
	for scope_v: Variant in scopes:
		var scope: String = String(scope_v)
		match scope:
			MobileReconnectOrchestrator.SCOPE_MULTIPLAYER:
				parts.append("session")
			MobileReconnectOrchestrator.SCOPE_LAN_SYNC:
				parts.append("LAN sync")
			_:
				parts.append(scope)
	if parts.is_empty():
		return ""
	return ", ".join(PackedStringArray(parts))


func _apply_orientation_scale() -> void:
	var root_window: Window = get_tree().root
	if root_window == null:
		return
	var window_size: Vector2i = root_window.size
	if window_size.x <= 0 or window_size.y <= 0:
		return
	var is_portrait: bool = window_size.y > window_size.x
	var base_factor: float = PORTRAIT_CONTENT_SCALE if is_portrait else LANDSCAPE_CONTENT_SCALE
	var target_factor: float = base_factor * _effective_ui_zoom()
	if not is_equal_approx(root_window.content_scale_factor, target_factor):
		root_window.content_scale_factor = target_factor


func _effective_ui_zoom() -> float:
	if UserPrefs == null:
		return MOBILE_DEFAULT_UI_ZOOM
	var z: float = UserPrefs.ui_zoom
	if z <= 0.0:
		return MOBILE_DEFAULT_UI_ZOOM
	return z


func _on_user_ui_zoom_changed(_value: float) -> void:
	_apply_orientation_scale()


func _on_safe_area_insets_changed(top: float, right: float, bottom: float, left: float) -> void:
	if _top_bar != null:
		_top_bar.offset_left = TOP_BAR_BASE_OFFSET + left
		_top_bar.offset_right = -TOP_BAR_BASE_OFFSET - right
		_top_bar.offset_top = TOP_BAR_BASE_OFFSET + top
	if _handle_anchor != null:
		_handle_anchor.offset_top = HANDLE_BASE_TOP + top
		_handle_anchor.offset_right = -HANDLE_BASE_RIGHT_MARGIN - right
		_handle_anchor.offset_left = _handle_anchor.offset_right - HANDLE_BASE_WIDTH
		_handle_anchor.offset_bottom = _handle_anchor.offset_top + 56.0
	_safe_inset_top = top
	_safe_inset_right = right
	_safe_inset_bottom = bottom
	_safe_inset_left = left
	_apply_bottom_overlay_layout()
	if _edit_action_bar != null:
		_edit_action_bar.offset_top = -EDIT_BAR_BASE_HEIGHT - bottom
		_edit_action_bar.offset_left = left
		_edit_action_bar.offset_right = -right
		_edit_action_bar.offset_bottom = -bottom
	_apply_picker_insets(top, right, bottom, left)
	_apply_bottom_sheet_insets(right, bottom, left)


func _apply_bottom_overlay_layout() -> void:
	var edit_visible: bool = _edit_action_bar != null and _edit_action_bar.visible
	var bottom_clearance: float = ZOOM_BASE_BOTTOM_MARGIN + _safe_inset_bottom
	if edit_visible:
		bottom_clearance = EDIT_BAR_BASE_HEIGHT + _safe_inset_bottom + BOTTOM_OVERLAY_EDIT_GAP
	if _zoom_overlay_anchor != null:
		_zoom_overlay_anchor.offset_right = -ZOOM_BASE_RIGHT_MARGIN - _safe_inset_right
		_zoom_overlay_anchor.offset_left = _zoom_overlay_anchor.offset_right - ZOOM_BASE_WIDTH - 16.0
		_zoom_overlay_anchor.offset_bottom = -bottom_clearance
		_zoom_overlay_anchor.offset_top = _zoom_overlay_anchor.offset_bottom - ZOOM_BASE_HEIGHT
	if _view_mode_toggle_anchor != null and _zoom_overlay_anchor != null:
		_view_mode_toggle_anchor.offset_right = _zoom_overlay_anchor.offset_left - VIEW_TOGGLE_GAP_TO_ZOOM
		_view_mode_toggle_anchor.offset_left = _view_mode_toggle_anchor.offset_right - VIEW_TOGGLE_BASE_WIDTH
		_view_mode_toggle_anchor.offset_bottom = -bottom_clearance
		_view_mode_toggle_anchor.offset_top = _view_mode_toggle_anchor.offset_bottom - VIEW_TOGGLE_BASE_HEIGHT
	if _nodes_lock_toggle_anchor != null and _view_mode_toggle_anchor != null:
		_nodes_lock_toggle_anchor.offset_right = _view_mode_toggle_anchor.offset_left - NODES_LOCK_GAP_TO_VIEW_TOGGLE
		_nodes_lock_toggle_anchor.offset_left = _nodes_lock_toggle_anchor.offset_right - NODES_LOCK_BASE_WIDTH
		_nodes_lock_toggle_anchor.offset_bottom = -bottom_clearance
		_nodes_lock_toggle_anchor.offset_top = _nodes_lock_toggle_anchor.offset_bottom - NODES_LOCK_BASE_HEIGHT


func _apply_bottom_sheet_insets(right: float, bottom: float, left: float) -> void:
	if _bottom_sheet == null:
		return
	var content_root: MarginContainer = _bottom_sheet.get_node_or_null("LayoutColumn/ContentRoot") as MarginContainer
	if content_root == null:
		return
	content_root.add_theme_constant_override("margin_left", int(8.0 + left))
	content_root.add_theme_constant_override("margin_right", int(8.0 + right))
	content_root.add_theme_constant_override("margin_bottom", int(8.0 + bottom))


func _apply_picker_insets(top: float, right: float, bottom: float, left: float) -> void:
	if _project_picker == null:
		return
	var margin: MarginContainer = _project_picker.get_node_or_null("MarginContainer") as MarginContainer
	if margin == null:
		return
	margin.add_theme_constant_override("margin_top", int(PICKER_BASE_MARGIN_TOP + top))
	margin.add_theme_constant_override("margin_left", int(PICKER_BASE_MARGIN_SIDE + left))
	margin.add_theme_constant_override("margin_right", int(PICKER_BASE_MARGIN_SIDE + right))
	margin.add_theme_constant_override("margin_bottom", int(PICKER_BASE_MARGIN_BOTTOM + bottom))


func _on_picker_project_opened(project: Project, source: String, remote_label: String) -> void:
	var project_name: String = project.name if project != null else "project"
	_show_loading("Opening %s…" % project_name, "Loading boards and items")
	await get_tree().process_frame
	_project = project
	AppState.open_project(project)
	_toolbar.set_project_label(project.name, source, remote_label)
	_toolbar.visible = false
	_toolbar_handle.visible = true
	_show_view(VIEW_BOARD)
	await get_tree().process_frame
	_hide_loading()


func _on_loading_requested(title: String, subtitle: String) -> void:
	_show_loading(title, subtitle)


func _on_loading_progress(subtitle: String) -> void:
	if _loading_view != null and _loading_view.is_active():
		_loading_view.set_subtitle(subtitle)


func _on_loading_dismissed() -> void:
	_hide_loading()


func _show_loading(title: String, subtitle: String) -> void:
	if _loading_view != null:
		_loading_view.show_loading(title, subtitle)


func _hide_loading() -> void:
	if _loading_view != null:
		_loading_view.hide_loading()


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
			_open_import_dialog()
		MobileToolbar.ACTION_FILE_EXPORT:
			_open_export_dialog()
		MobileToolbar.ACTION_OPEN_THEME:
			_open_theme_dialog()
		MobileToolbar.ACTION_OPEN_KEYBINDINGS:
			_open_keybindings_dialog()
		MobileToolbar.ACTION_OPEN_MULTIPLAYER:
			_open_multiplayer_sheet()


func _open_theme_dialog() -> void:
	var dlg: Window = THEME_DIALOG_SCENE.instantiate()
	add_child(dlg)
	PopupSizer.popup_fit(dlg, {"preferred": Vector2i(880, 680)})


func _open_multiplayer_sheet() -> void:
	if AppState.current_project == null:
		_show_toast("warning", "Open a project first")
		return
	_bottom_sheet.show_multiplayer()


func _open_keybindings_dialog() -> void:
	var dlg: Window = KEYBINDINGS_DIALOG_SCENE.instantiate()
	add_child(dlg)
	PopupSizer.popup_fit(dlg, {"preferred": Vector2i(880, 680)})


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
	_view_mode_toggle.set_edit_active(mode != MobileBoardView.MODE_VIEW)
	_apply_bottom_overlay_layout()
	_sync_selection_state()


func _on_view_mode_toggle_requested() -> void:
	_toggle_edit_mode()


func _on_nodes_lock_toggle_requested() -> void:
	if _board_view == null:
		return
	_board_view.set_nodes_locked(not _board_view.nodes_locked())


func _on_board_nodes_lock_changed(locked: bool) -> void:
	if _nodes_lock_toggle != null:
		_nodes_lock_toggle.set_locked(locked)
	if locked:
		_show_toast("info", "Nodes locked — interactions only")
	else:
		_show_toast("info", "Nodes unlocked")


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
	_view_mode_toggle_anchor.visible = name == VIEW_BOARD
	_nodes_lock_toggle_anchor.visible = name == VIEW_BOARD
	_toolbar.set_edit_button_visible(name == VIEW_BOARD)
	if name != VIEW_BOARD:
		_edit_action_bar.visible = false
	_apply_bottom_overlay_layout()
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


# ---------------------------------------------------------------------------
# Import / Export
# ---------------------------------------------------------------------------

func _open_import_dialog() -> void:
	if AppState.current_project == null or AppState.current_board == null:
		_show_toast("warning", "Open a board first")
		return
	var dlg: MobileImportDialog = IMPORT_DIALOG_SCENE.instantiate()
	add_child(dlg)
	dlg.mode_chosen.connect(_on_import_mode_chosen)
	PopupSizer.popup_fit(dlg, {"preferred": Vector2i(640, 520)})


func _on_import_mode_chosen(mode: String) -> void:
	var picker: MobileFilePicker = MobileFilePicker.new()
	add_child(picker)
	var title: String = "Import"
	var filters: PackedStringArray = PackedStringArray()
	var multi: bool = false
	match mode:
		MobileImportDialog.MODE_MARKDOWN:
			title = "Import Markdown Outline"
			filters = PackedStringArray(["*.md ; Markdown", "*.txt ; Text"])
		MobileImportDialog.MODE_JSON:
			title = "Import Project JSON"
			filters = PackedStringArray(["*.json ; JSON"])
		MobileImportDialog.MODE_DOCUMENT:
			title = "Import Document(s)"
			filters = PackedStringArray([
				"*.md, *.markdown ; Markdown",
				"*.txt ; Plain Text",
				"*.rtf ; Rich Text Format",
				"*.docx ; Word Document",
				"*.pdf ; PDF",
			])
			multi = true
		MobileImportDialog.MODE_IMAGE:
			title = "Import Image(s)"
			filters = PackedStringArray([
				"*.png ; PNG Image",
				"*.jpg, *.jpeg ; JPEG Image",
				"*.webp ; WebP Image",
				"*.bmp ; BMP Image",
				"*.tga ; TGA Image",
				"*.svg ; SVG Image",
			])
			multi = true
		MobileImportDialog.MODE_SOUND:
			title = "Import Sound(s)"
			filters = PackedStringArray([
				"*.mp3 ; MP3",
				"*.ogg ; Ogg Vorbis",
				"*.wav ; WAV",
			])
			multi = true
		_:
			picker.queue_free()
			return
	picker.files_chosen.connect(func(paths: PackedStringArray) -> void:
		_on_import_files_chosen(mode, paths)
		picker.queue_free()
	)
	picker.pick_cancelled.connect(func() -> void: picker.queue_free())
	picker.pick_error.connect(func(msg: String) -> void:
		_show_toast("warning", "File picker error: %s" % msg)
		picker.queue_free()
	)
	if multi:
		picker.pick_multi(title, filters)
	else:
		picker.pick_single(title, filters)


func _on_import_files_chosen(mode: String, paths: PackedStringArray) -> void:
	if paths.is_empty():
		return
	if AppState.current_project == null or AppState.current_board == null:
		return
	match mode:
		MobileImportDialog.MODE_MARKDOWN:
			_run_simple_text_import(paths[0], BoardImporter.new(_board_view), "markdown")
		MobileImportDialog.MODE_JSON:
			_run_simple_text_import(paths[0], BoardImporter.new(_board_view), "json")
		MobileImportDialog.MODE_DOCUMENT:
			_import_document_batch(paths)
		MobileImportDialog.MODE_IMAGE:
			_prompt_embed_choice(
				"Embed images into the project, or keep them linked to the original files?",
				func(embed: bool) -> void: _import_image_batch(paths, embed),
			)
		MobileImportDialog.MODE_SOUND:
			_prompt_embed_choice(
				"Embed audio into the project, or keep it linked to the original files?",
				func(embed: bool) -> void: _import_sound_batch(paths, embed),
			)


func _run_simple_text_import(path: String, importer: BoardImporter, mode: String) -> void:
	var ok: bool = importer.import_file(path, mode)
	if ok:
		_show_toast("info", "Imported %s" % path.get_file())
	else:
		_show_toast("warning", "Import failed: %s" % path.get_file())


func _import_document_batch(paths: PackedStringArray) -> void:
	if paths.is_empty() or AppState.current_board == null:
		return
	var anchor: Vector2 = _drop_anchor_world()
	var size_v: Vector2 = IMPORT_BATCH_NODE_SIZE_DOCUMENT
	var item_dicts: Array = []
	for i in range(paths.size()):
		var path: String = paths[i]
		var result: DocumentImporter.ImportResult = DocumentImporter.import_to_markdown(path)
		var title_text: String = path.get_file().get_basename()
		if title_text == "":
			title_text = "Untitled Document"
		var markdown_text: String = ""
		if result.ok:
			markdown_text = result.markdown
			if markdown_text.strip_edges() == "":
				markdown_text = "# %s\n" % title_text
		else:
			markdown_text = "# %s\n\n*(Import failed: %s)*\n" % [title_text, result.error_message]
		var pos: Vector2 = _grid_position_for_batch(anchor, i, paths.size(), size_v)
		item_dicts.append({
			"id": Uuid.v4(),
			"type": ItemRegistry.TYPE_DOCUMENT,
			"position": [pos.x, pos.y],
			"size": [size_v.x, size_v.y],
			"title": title_text,
			"markdown_text": markdown_text,
			"font_size": DocumentNode.DEFAULT_FONT_SIZE,
		})
	if item_dicts.is_empty():
		return
	History.push(AddItemsCommand.new(_board_view, item_dicts))
	_show_toast("info", "Imported %d document(s)" % item_dicts.size())


func _import_image_batch(paths: PackedStringArray, embed: bool) -> void:
	if paths.is_empty() or AppState.current_board == null:
		return
	var anchor: Vector2 = _drop_anchor_world()
	var size_v: Vector2 = IMPORT_BATCH_NODE_SIZE_IMAGE
	var item_dicts: Array = []
	for i in range(paths.size()):
		var path: String = paths[i]
		var pos: Vector2 = _grid_position_for_batch(anchor, i, paths.size(), size_v)
		var d: Dictionary = {
			"id": Uuid.v4(),
			"type": ItemRegistry.TYPE_IMAGE,
			"position": [pos.x, pos.y],
			"size": [size_v.x, size_v.y],
		}
		_apply_asset_source(d, path, embed, ImageNode.SourceMode.EMBEDDED, ImageNode.SourceMode.LINKED)
		item_dicts.append(d)
	if item_dicts.is_empty():
		return
	History.push(AddItemsCommand.new(_board_view, item_dicts))
	_show_toast("info", "Imported %d image(s)" % item_dicts.size())


func _import_sound_batch(paths: PackedStringArray, embed: bool) -> void:
	if paths.is_empty() or AppState.current_board == null:
		return
	var anchor: Vector2 = _drop_anchor_world()
	var size_v: Vector2 = IMPORT_BATCH_NODE_SIZE_SOUND
	var item_dicts: Array = []
	for i in range(paths.size()):
		var path: String = paths[i]
		var pos: Vector2 = _grid_position_for_batch(anchor, i, paths.size(), size_v)
		var d: Dictionary = {
			"id": Uuid.v4(),
			"type": ItemRegistry.TYPE_SOUND,
			"position": [pos.x, pos.y],
			"display_label": path.get_file(),
		}
		_apply_asset_source(d, path, embed, SoundNode.SourceMode.EMBEDDED, SoundNode.SourceMode.LINKED)
		item_dicts.append(d)
	if item_dicts.is_empty():
		return
	History.push(AddItemsCommand.new(_board_view, item_dicts))
	_show_toast("info", "Imported %d sound(s)" % item_dicts.size())


func _apply_asset_source(d: Dictionary, source_path: String, embed: bool, embedded_mode: int, linked_mode: int) -> void:
	if embed and AppState.current_project != null:
		var copied: String = AppState.current_project.copy_asset_into_project(source_path)
		if copied != "":
			d["source_mode"] = embedded_mode
			d["asset_name"] = copied
			d["source_path"] = ""
			return
	d["source_mode"] = linked_mode
	d["source_path"] = source_path
	d["asset_name"] = ""


func _prompt_embed_choice(prompt: String, on_choice: Callable) -> void:
	var dlg: MobileEmbedChoiceDialog = EMBED_CHOICE_DIALOG_SCENE.instantiate()
	add_child(dlg)
	dlg.configure(prompt)
	dlg.choice_made.connect(func(embed: bool) -> void: on_choice.call(embed))
	PopupSizer.popup_fit(dlg, {"preferred": Vector2i(520, 280)})


func _drop_anchor_world() -> Vector2:
	if _board_view != null:
		var cam: MobileCameraController = _board_view.camera_node()
		if cam != null:
			return cam.position
	return Vector2.ZERO


func _grid_position_for_batch(anchor: Vector2, index: int, count: int, item_size: Vector2) -> Vector2:
	var clamped_count: int = max(1, count)
	var cols: int = clampi(clamped_count, 1, IMPORT_BATCH_MAX_COLS)
	@warning_ignore("integer_division")
	var row: int = index / cols
	var col: int = index % cols
	var rows: int = int(ceil(float(clamped_count) / float(cols)))
	var total_w: float = float(cols) * (item_size.x + IMPORT_BATCH_GAP) - IMPORT_BATCH_GAP
	var total_h: float = float(rows) * (item_size.y + IMPORT_BATCH_GAP) - IMPORT_BATCH_GAP
	var origin_x: float = anchor.x - total_w / 2.0
	var origin_y: float = anchor.y - total_h / 2.0
	return Vector2(origin_x + float(col) * (item_size.x + IMPORT_BATCH_GAP), origin_y + float(row) * (item_size.y + IMPORT_BATCH_GAP))


func _open_export_dialog() -> void:
	if AppState.current_project == null or AppState.current_board == null:
		_show_toast("warning", "Open a board first")
		return
	var dlg: MobileExportDialog = EXPORT_DIALOG_SCENE.instantiate()
	add_child(dlg)
	dlg.mode_chosen.connect(_on_export_mode_chosen)
	PopupSizer.popup_fit(dlg, {"preferred": Vector2i(640, 520)})


func _on_export_mode_chosen(mode: String) -> void:
	if AppState.current_project == null or AppState.current_board == null:
		return
	if OS.get_name() == "Android":
		OS.request_permissions()
	var ext: String = ""
	var title: String = "Export"
	match mode:
		MobileExportDialog.MODE_PNG_CURRENT:
			ext = "png"; title = "Export current board as PNG"
		MobileExportDialog.MODE_PNG_UNFOLDED:
			ext = "png"; title = "Export unfolded as PNG"
		MobileExportDialog.MODE_SVG:
			ext = "svg"; title = "Export current board as SVG"
		MobileExportDialog.MODE_PDF:
			ext = "pdf"; title = "Export unfolded as PDF"
		MobileExportDialog.MODE_MARKDOWN:
			ext = "md"; title = "Export board as Markdown"
		MobileExportDialog.MODE_HTML:
			ext = "html"; title = "Export interactive HTML"
		_:
			return
	var board_name: String = AppState.current_board.name
	if board_name == "":
		board_name = "board"
	var default_name: String = "%s.%s" % [board_name.replace(" ", "_"), ext]
	var filters: PackedStringArray = PackedStringArray(["*.%s ; %s" % [ext, ext.to_upper()]])
	var saver: MobileFileSaver = MobileFileSaver.new()
	add_child(saver)
	saver.save_path_chosen.connect(func(path: String) -> void:
		_run_export(mode, path)
		saver.queue_free()
	)
	saver.save_cancelled.connect(func() -> void: saver.queue_free())
	saver.save_error.connect(func(msg: String) -> void:
		_show_toast("warning", "Save dialog error: %s" % msg)
		saver.queue_free()
	)
	saver.save_as(title, default_name, ext, filters)


func _run_export(mode: String, path: String) -> void:
	if AppState.current_project == null or AppState.current_board == null:
		_show_toast("warning", "Export failed: no current board")
		return
	_board_view.request_save()
	var board: Board = AppState.current_board
	push_warning("[MobileExport] mode=%s path=%s items=%d" % [mode, path, board.items.size()])
	if board.items.is_empty() and mode != MobileExportDialog.MODE_HTML:
		_show_toast("warning", "Board is empty — nothing to export")
		return
	var ok: bool = await _try_export(mode, board, path)
	push_warning("[MobileExport] primary result mode=%s ok=%s file_exists=%s" % [mode, str(ok), str(FileAccess.file_exists(path))])
	if ok:
		_show_toast("info", "Exported to %s" % path.get_file())
		return
	var fallback_path: String = _build_fallback_export_path(path)
	push_warning("[MobileExport] retrying via fallback path: %s" % fallback_path)
	var fallback_ok: bool = await _try_export(mode, board, fallback_path)
	push_warning("[MobileExport] fallback result ok=%s file_exists=%s" % [str(fallback_ok), str(FileAccess.file_exists(fallback_path))])
	if not fallback_ok:
		_show_toast("warning", "Export failed: %s" % path.get_file())
		return
	if _copy_bytes_to_user_path(fallback_path, path):
		push_warning("[MobileExport] copied fallback bytes to %s" % path)
		DirAccess.remove_absolute(fallback_path)
		_show_toast("info", "Exported to %s" % path.get_file())
		return
	_show_toast("info", "Saved to app folder — opening share sheet")
	_share_or_reveal(fallback_path)


func _share_or_reveal(absolute_path: String) -> void:
	if absolute_path == "":
		return
	var os_name: String = OS.get_name()
	if os_name == "Android":
		var err: Error = OS.shell_open(absolute_path)
		if err != OK:
			push_warning("[MobileExport] shell_open failed for %s (err=%d)" % [absolute_path, err])
		return
	OS.shell_show_in_file_manager(absolute_path)


func _copy_bytes_to_user_path(source_path: String, dest_path: String) -> bool:
	if not FileAccess.file_exists(source_path):
		return false
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(source_path)
	if bytes.is_empty():
		return false
	var f: FileAccess = FileAccess.open(dest_path, FileAccess.WRITE)
	if f == null:
		push_warning("[MobileExport] FileAccess.open failed for %s (err=%d)" % [dest_path, FileAccess.get_open_error()])
		return false
	f.store_buffer(bytes)
	f.close()
	return FileAccess.file_exists(dest_path) or dest_path.begins_with("content://")


func _try_export(mode: String, board: Board, path: String) -> bool:
	var exporter: BoardExporter = BoardExporter.new(self)
	match mode:
		MobileExportDialog.MODE_PNG_CURRENT:
			return await exporter.export_board(board, path)
		MobileExportDialog.MODE_PNG_UNFOLDED:
			return await exporter.export_unfolded(board, AppState.current_project, path)
		MobileExportDialog.MODE_SVG:
			return exporter.export_svg(
				board,
				_board_view.all_items(),
				_board_view.get_connections(),
				AppState.current_project,
				path,
			)
		MobileExportDialog.MODE_PDF:
			return await exporter.export_pdf(board, AppState.current_project, path)
		MobileExportDialog.MODE_MARKDOWN:
			return exporter.export_markdown(board, AppState.current_project, path)
		MobileExportDialog.MODE_HTML:
			return exporter.export_html(AppState.current_project, path)
	return false


func _build_fallback_export_path(original_path: String) -> String:
	var exports_root: String = ProjectSettings.globalize_path("user://exports")
	if exports_root == "":
		exports_root = OS.get_user_data_dir().path_join("exports")
	exports_root = exports_root.replace("\\", "/")
	if not DirAccess.dir_exists_absolute(exports_root):
		DirAccess.make_dir_recursive_absolute(exports_root)
	var file_name: String = original_path.get_file()
	if file_name == "":
		file_name = "export.bin"
	return exports_root.path_join(file_name)
