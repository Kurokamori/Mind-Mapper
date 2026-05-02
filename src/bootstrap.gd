class_name Bootstrap
extends Control

const PROJECT_MANAGER_SCENE := preload("res://src/project_manager/project_manager_screen.tscn")
const EDITOR_SCENE := preload("res://src/editor/editor.tscn")

var _current: Node = null


func _ready() -> void:
	_show_project_manager()


func _show_project_manager() -> void:
	_replace_with(PROJECT_MANAGER_SCENE.instantiate())
	if _current is ProjectManagerScreen:
		(_current as ProjectManagerScreen).project_chosen.connect(_on_project_chosen)


func _show_editor() -> void:
	_replace_with(EDITOR_SCENE.instantiate())
	if _current is Editor:
		(_current as Editor).back_to_projects_requested.connect(_on_back_to_projects)


func _replace_with(new_node: Node) -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	_current = new_node
	add_child(new_node)


func _on_project_chosen(project: Project) -> void:
	AppState.open_project(project)
	_show_editor()


func _on_back_to_projects() -> void:
	AppState.close_project()
	_show_project_manager()
