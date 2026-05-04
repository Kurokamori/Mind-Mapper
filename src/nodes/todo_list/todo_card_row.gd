class_name TodoCardRow
extends PanelContainer

signal text_changed(card_id: String, new_text: String)
signal completed_toggled(card_id: String, value: bool)
signal delete_requested(card_id: String)
signal priority_changed(card_id: String, value: int)
signal due_changed(card_id: String, due_unix: int)

const NORMAL_BG: Color = Color(0.18, 0.20, 0.24, 1.0)
const COMPLETED_BG: Color = Color(0.14, 0.16, 0.18, 1.0)
const COMPLETED_FG: Color = Color(0.55, 0.60, 0.65, 1.0)
const NORMAL_FG: Color = Color(0.95, 0.96, 0.98, 1.0)
const OVERDUE_FG: Color = Color(1.0, 0.45, 0.45, 1.0)

@onready var _drag_handle: ColorRect = %DragHandle
@onready var _check: CheckBox = %Check
@onready var _text_edit: LineEdit = %TextEdit
@onready var _priority_btn: MenuButton = %PriorityButton
@onready var _due_btn: Button = %DueButton
@onready var _delete_button: Button = %DeleteButton

var card_id: String = ""
var owner_list_id: String = ""
var card_data: Dictionary = {}
var _suppress: bool = false


func bind(list_item_id: String, data: Dictionary) -> void:
	owner_list_id = list_item_id
	card_data = data.duplicate(true)
	card_id = String(card_data.get("id", ""))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 36)
	_apply_compact_button_styles()
	_apply_card_data()
	_check.toggled.connect(_on_check_toggled)
	_text_edit.text_changed.connect(_on_text_changed)
	_text_edit.text_submitted.connect(_on_text_submitted)
	_text_edit.focus_exited.connect(_on_text_focus_exited)
	_delete_button.pressed.connect(_on_delete_pressed)
	_setup_priority_menu()
	_due_btn.pressed.connect(_on_due_pressed)


func _apply_compact_button_styles() -> void:
	for btn: Button in [_priority_btn, _due_btn, _delete_button]:
		if btn == null:
			continue
		_install_compact_button_styles(btn)


func _install_compact_button_styles(btn: Button) -> void:
	var states: Array[String] = ["normal", "hover", "pressed", "disabled"]
	for state: String in states:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 4.0
		sb.content_margin_right = 4.0
		sb.content_margin_top = 2.0
		sb.content_margin_bottom = 2.0
		match state:
			"hover":
				sb.bg_color = Color(0.30, 0.32, 0.38, 0.9)
			"pressed":
				sb.bg_color = Color(0.36, 0.36, 0.44, 1.0)
			_:
				sb.bg_color = Color(0, 0, 0, 0)
		btn.add_theme_stylebox_override(state, sb)
	var focus_box: StyleBoxFlat = StyleBoxFlat.new()
	focus_box.draw_center = false
	focus_box.set_corner_radius_all(4)
	focus_box.set_border_width_all(1)
	focus_box.border_color = Color(0.5, 0.44, 0.61, 0.85)
	btn.add_theme_stylebox_override("focus", focus_box)


func update_data(data: Dictionary) -> void:
	card_data = data.duplicate(true)
	card_id = String(card_data.get("id", ""))
	_apply_card_data()


func _apply_card_data() -> void:
	if _check == null:
		return
	_suppress = true
	_check.button_pressed = bool(card_data.get("completed", false))
	_text_edit.text = String(card_data.get("text", ""))
	_apply_visual_style()
	_refresh_priority_label()
	_refresh_due_label()
	_suppress = false


func _setup_priority_menu() -> void:
	var pop: PopupMenu = _priority_btn.get_popup()
	pop.clear()
	pop.add_item("None", 0)
	pop.add_item("🟢 Low", 1)
	pop.add_item("🟡 Medium", 2)
	pop.add_item("🔴 High", 3)
	if not pop.id_pressed.is_connected(_on_priority_picked):
		pop.id_pressed.connect(_on_priority_picked)


func _on_priority_picked(id: int) -> void:
	emit_signal("priority_changed", card_id, id)


func _refresh_priority_label() -> void:
	var p: int = int(card_data.get("priority", 0))
	match p:
		3: _priority_btn.text = "🔴"
		2: _priority_btn.text = "🟡"
		1: _priority_btn.text = "🟢"
		_: _priority_btn.text = "—"


func _refresh_due_label() -> void:
	var due: int = int(card_data.get("due_unix", 0))
	if due <= 0:
		_due_btn.text = "📅"
		_due_btn.modulate = Color.WHITE
		return
	_due_btn.text = Time.get_date_string_from_unix_time(due)
	_due_btn.modulate = Color(1.0, 0.45, 0.45) if due < int(Time.get_unix_time_from_system()) else Color.WHITE


func _on_due_pressed() -> void:
	var dlg: AcceptDialog = AcceptDialog.new()
	dlg.title = "Set due date"
	dlg.add_cancel_button("Clear")
	var v: VBoxContainer = VBoxContainer.new()
	var lbl: Label = Label.new(); lbl.text = "Due date (YYYY-MM-DD):"; v.add_child(lbl)
	var le: LineEdit = LineEdit.new()
	var due: int = int(card_data.get("due_unix", 0))
	if due > 0:
		le.text = Time.get_date_string_from_unix_time(due)
	else:
		le.text = Time.get_date_string_from_system()
	v.add_child(le)
	dlg.add_child(v)
	add_child(dlg)
	dlg.confirmed.connect(func() -> void:
		var parts: PackedStringArray = le.text.strip_edges().split("-")
		if parts.size() != 3:
			dlg.queue_free()
			return
		var dt: Dictionary = {"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]), "hour": 23, "minute": 59, "second": 0}
		var t: int = int(Time.get_unix_time_from_datetime_dict(dt))
		emit_signal("due_changed", card_id, t)
		dlg.queue_free()
	)
	dlg.canceled.connect(func() -> void:
		emit_signal("due_changed", card_id, 0)
		dlg.queue_free()
	)
	dlg.popup_centered(Vector2i(280, 140))


func _apply_visual_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COMPLETED_BG if _check.button_pressed else NORMAL_BG
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(4)
	add_theme_stylebox_override("panel", sb)
	var fg: Color = COMPLETED_FG if _check.button_pressed else NORMAL_FG
	_text_edit.add_theme_color_override("font_color", fg)
	if _check.button_pressed:
		_text_edit.add_theme_constant_override("caret_blink", 0)


func _on_check_toggled(pressed: bool) -> void:
	if _suppress:
		return
	_apply_visual_style()
	emit_signal("completed_toggled", card_id, pressed)


func _on_text_changed(new_text: String) -> void:
	if _suppress:
		return
	emit_signal("text_changed", card_id, new_text)


func _on_text_submitted(new_text: String) -> void:
	if _suppress:
		return
	emit_signal("text_changed", card_id, new_text)
	_text_edit.release_focus()


func _on_text_focus_exited() -> void:
	if _suppress:
		return
	emit_signal("text_changed", card_id, _text_edit.text)


func _on_delete_pressed() -> void:
	emit_signal("delete_requested", card_id)


func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = String(card_data.get("text", ""))
	preview.add_theme_color_override("font_color", Color.WHITE)
	preview.modulate.a = 0.85
	set_drag_preview(preview)
	return {
		"kind": "todo_card",
		"source_list_id": owner_list_id,
		"card_id": card_id,
		"card_data": card_data.duplicate(true),
	}
