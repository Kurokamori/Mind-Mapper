class_name TodoCardDetailDialog
extends Window

signal applied(card_id: String, updated: Dictionary)

const FIELD_SCENE: PackedScene = preload("res://src/nodes/todo_list/todo_card_detail_field.tscn")

@onready var _title_edit: LineEdit = %TitleEdit
@onready var _completed_check: CheckBox = %CompletedCheck
@onready var _priority_button: MenuButton = %PriorityButton
@onready var _due_edit: LineEdit = %DueEdit
@onready var _due_clear_button: Button = %DueClearButton
@onready var _description_edit: TextEdit = %DescriptionEdit
@onready var _fields_container: VBoxContainer = %FieldsContainer
@onready var _add_field_button: Button = %AddFieldButton
@onready var _ok_button: Button = %OkButton
@onready var _cancel_button: Button = %CancelButton
@onready var _stats_label: Label = %StatsLabel

var card_id: String = ""
var _working: Dictionary = {}


func bind(card: Dictionary) -> void:
	_working = TodoCardData.normalize(card)
	card_id = String(_working.get("id", ""))


func _ready() -> void:
	close_requested.connect(_on_cancel)
	_title_edit.text = String(_working.get("text", ""))
	_completed_check.button_pressed = bool(_working.get("completed", false))
	_due_edit.text = _format_due(int(_working.get("due_unix", 0)))
	_description_edit.text = String(_working.get("description", ""))
	_setup_priority_menu()
	_refresh_priority_label()
	_refresh_stats()
	_rebuild_fields()
	_add_field_button.pressed.connect(_on_add_field)
	_ok_button.pressed.connect(_on_ok)
	_cancel_button.pressed.connect(_on_cancel)
	_due_clear_button.pressed.connect(func() -> void: _due_edit.text = "")


func _format_due(due_unix: int) -> String:
	if due_unix <= 0:
		return ""
	return Time.get_date_string_from_unix_time(due_unix)


func _parse_due(text: String) -> int:
	var trimmed: String = text.strip_edges()
	if trimmed == "":
		return 0
	var parts: PackedStringArray = trimmed.split("-")
	if parts.size() != 3:
		return 0
	var dt: Dictionary = {
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
		"hour": 23,
		"minute": 59,
		"second": 0,
	}
	return int(Time.get_unix_time_from_datetime_dict(dt))


func _setup_priority_menu() -> void:
	var pop: PopupMenu = _priority_button.get_popup()
	pop.clear()
	pop.add_item("None", 0)
	pop.add_item("🟢 Low", 1)
	pop.add_item("🟡 Medium", 2)
	pop.add_item("🔴 High", 3)
	if not pop.id_pressed.is_connected(_on_priority_picked):
		pop.id_pressed.connect(_on_priority_picked)


func _on_priority_picked(id: int) -> void:
	_working["priority"] = id
	_refresh_priority_label()


func _refresh_priority_label() -> void:
	var p: int = int(_working.get("priority", 0))
	match p:
		3: _priority_button.text = "🔴 High"
		2: _priority_button.text = "🟡 Medium"
		1: _priority_button.text = "🟢 Low"
		_: _priority_button.text = "None"


func _refresh_stats() -> void:
	var sub: Array = _working.get("subcards", []) as Array
	var v: Vector2i = TodoCardData.count_completed(sub)
	_stats_label.text = "Sub-items: %d / %d completed" % [v.x, v.y]


func _rebuild_fields() -> void:
	for child in _fields_container.get_children():
		child.queue_free()
	var details: Array = _working.get("details", []) as Array
	for d in details:
		var field: TodoCardDetailField = FIELD_SCENE.instantiate()
		_fields_container.add_child(field)
		field.bind(d)
		field.changed.connect(_on_field_changed)
		field.removed.connect(_on_field_removed)
		field.move_requested.connect(_on_field_move)


func _on_add_field() -> void:
	var details: Array = (_working.get("details", []) as Array).duplicate(true)
	details.append(TodoCardData.make_default_detail())
	_working["details"] = details
	_rebuild_fields()


func _on_field_changed(field_id: String, header: String, content: String) -> void:
	var details: Array = (_working.get("details", []) as Array).duplicate(true)
	for i in range(details.size()):
		var d: Dictionary = details[i]
		if String(d.get("id", "")) == field_id:
			d["header"] = header
			d["content"] = content
			details[i] = d
			break
	_working["details"] = details


func _on_field_removed(field_id: String) -> void:
	var details: Array = (_working.get("details", []) as Array).duplicate(true)
	var keep: Array = []
	for d in details:
		if String(d.get("id", "")) != field_id:
			keep.append(d)
	_working["details"] = keep
	_rebuild_fields()


func _on_field_move(field_id: String, direction: int) -> void:
	var details: Array = (_working.get("details", []) as Array).duplicate(true)
	var idx: int = -1
	for i in range(details.size()):
		if String(details[i].get("id", "")) == field_id:
			idx = i
			break
	if idx < 0:
		return
	var target: int = idx + direction
	if target < 0 or target >= details.size():
		return
	var tmp: Dictionary = details[idx]
	details[idx] = details[target]
	details[target] = tmp
	_working["details"] = details
	_rebuild_fields()


func _on_ok() -> void:
	_working["text"] = _title_edit.text
	_working["completed"] = _completed_check.button_pressed
	_working["description"] = _description_edit.text
	var due: int = _parse_due(_due_edit.text)
	if due > 0:
		_working["due_unix"] = due
	else:
		_working.erase("due_unix")
	emit_signal("applied", card_id, _working.duplicate(true))
	queue_free()


func _on_cancel() -> void:
	queue_free()
