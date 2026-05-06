class_name Bootstrap
extends Control

const SPLASH_SCENE := preload("res://src/editor/auxilary/splash.tscn")
const PROJECT_MANAGER_SCENE := preload("res://src/project_manager/project_manager_screen.tscn")
const EDITOR_SCENE := preload("res://src/editor/editor.tscn")
const TILEMAP_EDITOR_SCENE := preload("res://src/tilemap/tilemap_editor.tscn")

var _current: Node = null


func _ready() -> void:
	AppState.current_page_kind_changed.connect(_on_page_kind_changed)
	_show_splash()


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
	if AppState.current_project == null:
		return
	if _current == null:
		return
	if _current is ProjectManagerScreen or _current is Splash:
		return
	_show_editor_for_current_kind()
