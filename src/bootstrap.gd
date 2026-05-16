class_name Bootstrap
extends Control

const SPLASH_SCENE := preload("res://src/editor/auxilary/splash.tscn")
const PROJECT_MANAGER_SCENE := preload("res://src/project_manager/project_manager_screen.tscn")
const EDITOR_SCENE := preload("res://src/editor/editor.tscn")
const TILEMAP_EDITOR_SCENE := preload("res://src/tilemap/tilemap_editor.tscn")
const MOBILE_APP_SCENE := preload("res://src/mobile/mobile_app.tscn")
const MOBILE_CLI_FLAG: String = "--mobile"
const MOBILE_ENV_VAR: String = "MM_MOBILE"

var _current: Node = null


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	AppState.current_page_kind_changed.connect(_on_page_kind_changed)
	if _is_mobile_runtime():
		_apply_mobile_window_mode()
		_show_mobile_app()
		return
	_show_splash()


func _apply_mobile_window_mode() -> void:
	var platform: String = OS.get_name()
	if platform == "Android" or platform == "iOS":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	var size: Vector2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(Vector2i.ZERO)


static func _is_mobile_runtime() -> bool:
	var platform: String = OS.get_name()
	if platform == "Android" or platform == "iOS":
		return true
	if OS.get_environment(MOBILE_ENV_VAR) != "":
		return true
	for arg: String in OS.get_cmdline_user_args():
		if arg == MOBILE_CLI_FLAG:
			return true
	for arg: String in OS.get_cmdline_args():
		if arg == MOBILE_CLI_FLAG:
			return true
	return false


func _show_mobile_app() -> void:
	_replace_with(MOBILE_APP_SCENE.instantiate())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_shutdown_and_quit()


func _shutdown_and_quit() -> void:
	if _current != null:
		var parent: Node = _current.get_parent()
		if parent != null:
			parent.remove_child(_current)
		_current.free()
		_current = null
	get_tree().quit()


func _show_splash() -> void:
	var splash := SPLASH_SCENE.instantiate() as Splash
	_replace_with(splash)
	splash.finished.connect(_on_splash_finished)


func _show_project_manager() -> void:
	_replace_with(PROJECT_MANAGER_SCENE.instantiate())
	if _current is ProjectManagerScreen:
		(_current as ProjectManagerScreen).project_chosen.connect(_on_project_chosen)


func _show_editor_for_current_kind() -> void:
	if AppState.current_page_kind == AppState.PAGE_KIND_MAP:
		_show_tilemap_editor()
	else:
		_show_board_editor()


func _show_board_editor() -> void:
	if _current is Editor:
		return
	_replace_with(EDITOR_SCENE.instantiate())
	if _current is Editor:
		(_current as Editor).back_to_projects_requested.connect(_on_back_to_projects)


func _show_tilemap_editor() -> void:
	if _current is TilemapEditor:
		return
	_replace_with(TILEMAP_EDITOR_SCENE.instantiate())
	if _current is TilemapEditor:
		(_current as TilemapEditor).back_to_projects_requested.connect(_on_back_to_projects)


func _replace_with(new_node: Node) -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	_current = new_node
	add_child(new_node)
	ThemeManager.call_deferred("refresh")


func _on_splash_finished() -> void:
	_show_project_manager()


func _on_project_chosen(project: Project) -> void:
	AppState.open_project(project)
	_show_editor_for_current_kind()


func _on_back_to_projects() -> void:
	AppState.close_project()
	_show_project_manager()


func _on_page_kind_changed(_kind: String) -> void:
	if _is_mobile_runtime():
		return
	if AppState.current_project == null:
		return
	if _current == null:
		return
	if _current is ProjectManagerScreen or _current is Splash:
		return
	if _current is MobileApp:
		return
	_show_editor_for_current_kind()
