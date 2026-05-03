class_name ProjectManagerScreen
extends Control

signal project_chosen(project: Project)

@onready var _grid_container: VBoxContainer = %GridContainer
@onready var _empty_label: Label = %EmptyLabel
@onready var _new_button: Button = %NewButton
@onready var _open_button: Button = %OpenButton
@onready var _create_dialog: FileDialog = %CreateDialog
@onready var _open_dialog: FileDialog = %OpenDialog
@onready var _name_dialog: AcceptDialog = %NameDialog
@onready var _name_edit: LineEdit = %NameEdit

var _pending_create_folder: String = ""


func _ready() -> void:
	_name_dialog.add_cancel_button("Cancel")
	_new_button.pressed.connect(_on_new_pressed)
	_open_button.pressed.connect(_on_open_pressed)
	_create_dialog.dir_selected.connect(_on_create_folder_chosen)
	_open_dialog.dir_selected.connect(_on_open_folder_chosen)
	_name_dialog.confirmed.connect(_on_create_confirmed)
	ProjectStore.recent_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	for child in _grid_container.get_children():
		child.queue_free()
	var entries: Array = ProjectStore.recent()
	_empty_label.visible = entries.is_empty()
	for entry in entries:
		var card: ProjectCard = ProjectCard.create()
		card.bind(entry)
		card.open_requested.connect(_on_card_open)
		card.forget_requested.connect(_on_card_forget)
		_grid_container.add_child(card)


func _on_new_pressed() -> void:
	_create_dialog.popup_centered_ratio(0.7)


func _on_open_pressed() -> void:
	_open_dialog.popup_centered_ratio(0.7)


func _on_create_folder_chosen(folder: String) -> void:
	_pending_create_folder = folder
	_name_edit.text = ""
	_name_dialog.popup_centered()
	_name_edit.grab_focus()


func _on_create_confirmed() -> void:
	var name_str: String = _name_edit.text.strip_edges()
	if name_str == "":
		name_str = "Untitled Project"
	if _pending_create_folder == "":
		return
	var project: Project = ProjectStore.create_project(_pending_create_folder, name_str)
	_pending_create_folder = ""
	if project != null:
		emit_signal("project_chosen", project)


func _on_open_folder_chosen(folder: String) -> void:
	var project: Project = ProjectStore.open_project(folder)
	if project != null:
		emit_signal("project_chosen", project)


func _on_card_open(folder: String) -> void:
	var project: Project = ProjectStore.open_project(folder)
	if project != null:
		emit_signal("project_chosen", project)


func _on_card_forget(folder: String) -> void:
	ProjectStore.forget(folder)
