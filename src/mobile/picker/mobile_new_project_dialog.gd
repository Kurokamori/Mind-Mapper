class_name MobileNewProjectDialog
extends ConfirmationDialog

signal confirmed_with_name(project_name: String)

@onready var _name_edit: LineEdit = %NewProjectNameEdit


func _ready() -> void:
	confirmed.connect(_on_confirmed)
	get_cancel_button().pressed.connect(queue_free)


func _on_confirmed() -> void:
	confirmed_with_name.emit(_name_edit.text)
	queue_free()
