class_name MobileBoardBrowserSheet
extends Control

signal board_chosen(board_id: String)

@onready var _filter_edit: LineEdit = %BoardFilterEdit
@onready var _scroll: ScrollContainer = %BoardBrowserScroll
@onready var _list_root: VBoxContainer = %BoardList

var _project: Project = null
var _filter_text: String = ""


func _ready() -> void:
	_filter_edit.text_changed.connect(_on_filter_changed)


func bind(project: Project) -> void:
	_project = project
	_rebuild()


func _on_filter_changed(text: String) -> void:
	_filter_text = text.strip_edges().to_lower()
	_rebuild()


func _rebuild() -> void:
	for child: Node in _list_root.get_children():
		child.queue_free()
	if _project == null:
		return
	var boards: Array = _project.list_boards()
	for entry_v: Variant in boards:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var name_text: String = String(entry.get("name", ""))
		if _filter_text != "" and not name_text.to_lower().contains(_filter_text):
			continue
		var board_id: String = String(entry.get("id", ""))
		var btn: Button = Button.new()
		btn.text = name_text
		btn.custom_minimum_size = Vector2(0, 56)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func() -> void: board_chosen.emit(board_id))
		_list_root.add_child(btn)
