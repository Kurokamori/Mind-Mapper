class_name TodoCardRow
extends PanelContainer

signal text_changed(card_id: String, new_text: String)
signal completed_toggled(card_id: String, value: bool)
signal delete_requested(card_id: String)
signal priority_changed(card_id: String, value: int)
signal due_changed(card_id: String, due_unix: int)
signal expand_toggled(card_id: String, expanded: bool)
signal add_child_requested(card_id: String)
signal details_requested(card_id: String)
signal child_drop(target_card_id: String, source_list_id: String, source_card_id: String, source_card_data: Dictionary, insert_index: int)
signal child_drop_into_self(target_card_id: String, source_list_id: String, source_card_id: String, source_card_data: Dictionary)
signal edit_focus_changed(card_id: String, focused: bool)

const NORMAL_BG: Color = Color(0.18, 0.20, 0.24, 1.0)
const COMPLETED_BG: Color = Color(0.14, 0.16, 0.18, 1.0)
const COMPLETED_FG: Color = Color(0.55, 0.60, 0.65, 1.0)
const NORMAL_FG: Color = Color(0.95, 0.96, 0.98, 1.0)
const SELF_SCENE: String = "res://src/nodes/todo_list/todo_card_row.tscn"

@onready var _drag_handle: ColorRect = %DragHandle
@onready var _expand_button: Button = %ExpandButton
@onready var _check: CheckBox = %Check
@onready var _text_edit: LineEdit = %TextEdit
@onready var _details_button: AutomaticButton = %DetailsButton
@onready var _add_child_button: AutomaticButton = %AddChildButton
@onready var _priority_btn: MenuButton = %PriorityButton
@onready var _due_btn: AutomaticButton = %DueButton
@onready var _delete_button: AutomaticButton = %DeleteButton
@onready var _sub_row: HBoxContainer = %SubRow
@onready var _child_area: VBoxContainer = %ChildArea
@onready var _child_container: VBoxContainer = %ChildContainer
@onready var _child_drop_indicator: ColorRect = %ChildDropIndicator
@onready var _add_child_row_button: Button = %AddChildRowButton

var card_id: String = ""
var owner_list_id: String = ""
var card_data: Dictionary = {}
var palette_bg: Color = NORMAL_BG
var palette_fg: Color = NORMAL_FG
var palette_completed_bg: Color = COMPLETED_BG
var palette_completed_fg: Color = COMPLETED_FG
var _suppress: bool = false


func set_palette(bg: Color, fg: Color, completed_bg: Color = COMPLETED_BG, completed_fg: Color = COMPLETED_FG) -> void:
	palette_bg = bg
	palette_fg = fg
	palette_completed_bg = completed_bg
	palette_completed_fg = completed_fg
	if not is_inside_tree() or _check == null:
		return
	_apply_visual_style()
	for child in _child_container.get_children():
		if child is TodoCardRow:
			(child as TodoCardRow).set_palette(bg, fg, completed_bg, completed_fg)


func bind(list_item_id: String, data: Dictionary) -> void:
	owner_list_id = list_item_id
	card_data = TodoCardData.normalize(data)
	card_id = String(card_data.get("id", ""))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 36)
	_apply_compact_button_styles()
	_apply_card_data()
	_check.toggled.connect(_on_check_toggled)
	_text_edit.text_changed.connect(_on_text_changed)
	_text_edit.text_submitted.connect(_on_text_submitted)
	_text_edit.focus_entered.connect(_on_text_focus_entered)
	_text_edit.focus_exited.connect(_on_text_focus_exited)
	_delete_button.pressed.connect(_on_delete_pressed)
	_expand_button.pressed.connect(_on_expand_pressed)
	_add_child_button.pressed.connect(func() -> void: emit_signal("add_child_requested", card_id))
	_add_child_row_button.pressed.connect(func() -> void: emit_signal("add_child_requested", card_id))
	_details_button.pressed.connect(func() -> void: emit_signal("details_requested", card_id))
	_setup_priority_menu()
	_due_btn.pressed.connect(_on_due_pressed)


func _apply_compact_button_styles() -> void:
	for btn in [_priority_btn, _due_btn, _delete_button, _details_button, _add_child_button, _expand_button, _add_child_row_button]:
		if btn == null:
			continue
		_install_compact_button_styles(btn)


func _install_compact_button_styles(btn) -> void:
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
	card_data = TodoCardData.normalize(data)
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
	_refresh_expand_state()
	_refresh_details_indicator()
	_rebuild_children()
	_suppress = false


func _refresh_expand_state() -> void:
	var sub: Array = card_data.get("subcards", []) as Array
	var expanded: bool = bool(card_data.get("expanded", true))
	_expand_button.disabled = sub.size() == 0
	if sub.size() == 0:
		_expand_button.text = "·"
		_sub_row.visible = false
		return
	_expand_button.text = "▼" if expanded else "▶"
	_sub_row.visible = expanded


func _refresh_details_indicator() -> void:
	var details: Array = card_data.get("details", []) as Array
	var description: String = String(card_data.get("description", ""))
	var has_extra: bool = details.size() > 0 or description.strip_edges() != ""
	if has_extra:
		_details_button.text = ""
		_details_button.modulate = Color(1.0, 0.85, 0.45)
	else:
		_details_button.text = ""
		_details_button.modulate = Color.WHITE


func _rebuild_children() -> void:
	if _child_container == null:
		return
	for child in _child_container.get_children():
		if child == _child_drop_indicator:
			continue
		child.queue_free()
	var sub: Array = card_data.get("subcards", []) as Array
	for sc in sub:
		var row: TodoCardRow = (load(SELF_SCENE) as PackedScene).instantiate()
		row.bind(owner_list_id, sc)
		_child_container.add_child(row)
		row.set_palette(palette_bg, palette_fg, palette_completed_bg, palette_completed_fg)
		_forward_signals(row)
	_position_child_drop_indicator(-1)


func _forward_signals(row: TodoCardRow) -> void:
	row.text_changed.connect(func(cid: String, t: String) -> void: emit_signal("text_changed", cid, t))
	row.completed_toggled.connect(func(cid: String, v: bool) -> void: emit_signal("completed_toggled", cid, v))
	row.delete_requested.connect(func(cid: String) -> void: emit_signal("delete_requested", cid))
	row.priority_changed.connect(func(cid: String, v: int) -> void: emit_signal("priority_changed", cid, v))
	row.due_changed.connect(func(cid: String, t: int) -> void: emit_signal("due_changed", cid, t))
	row.expand_toggled.connect(func(cid: String, e: bool) -> void: emit_signal("expand_toggled", cid, e))
	row.add_child_requested.connect(func(cid: String) -> void: emit_signal("add_child_requested", cid))
	row.details_requested.connect(func(cid: String) -> void: emit_signal("details_requested", cid))
	row.child_drop.connect(func(tid: String, slid: String, scid: String, sdata: Dictionary, idx: int) -> void:
		emit_signal("child_drop", tid, slid, scid, sdata, idx)
	)
	row.child_drop_into_self.connect(func(tid: String, slid: String, scid: String, sdata: Dictionary) -> void:
		emit_signal("child_drop_into_self", tid, slid, scid, sdata)
	)
	row.edit_focus_changed.connect(func(cid: String, focused: bool) -> void: emit_signal("edit_focus_changed", cid, focused))


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
		_due_btn.text = ""
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
	var completed: bool = _check.button_pressed
	sb.bg_color = palette_completed_bg if completed else palette_bg
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(4)
	add_theme_stylebox_override("panel", sb)
	var fg: Color = palette_completed_fg if completed else palette_fg
	_text_edit.add_theme_color_override("font_color", fg)
	var empty_style: StyleBoxEmpty = StyleBoxEmpty.new()
	_text_edit.add_theme_stylebox_override("normal", empty_style)
	_text_edit.add_theme_stylebox_override("focus", empty_style)
	_text_edit.add_theme_stylebox_override("read_only", empty_style)
	_text_edit.add_theme_color_override("selection_color", Color(fg.r, fg.g, fg.b, 0.22))
	if completed:
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


func _on_text_focus_entered() -> void:
	emit_signal("edit_focus_changed", card_id, true)


func _on_text_focus_exited() -> void:
	emit_signal("edit_focus_changed", card_id, false)
	if _suppress:
		return
	emit_signal("text_changed", card_id, _text_edit.text)


func _on_delete_pressed() -> void:
	emit_signal("delete_requested", card_id)


func _on_expand_pressed() -> void:
	var sub: Array = card_data.get("subcards", []) as Array
	if sub.size() == 0:
		return
	var new_state: bool = not bool(card_data.get("expanded", true))
	card_data["expanded"] = new_state
	_refresh_expand_state()
	emit_signal("expand_toggled", card_id, new_state)


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


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data
	if String(d.get("kind", "")) != "todo_card":
		return false
	var src_id: String = String(d.get("card_id", ""))
	if src_id == card_id:
		return false
	if _is_descendant_id(src_id):
		return false
	var local_y: float = at_position.y
	if _is_main_row_zone(local_y):
		_position_child_drop_indicator(-1)
		return true
	_position_child_drop_indicator(_index_for_drop_y(local_y))
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	_position_child_drop_indicator(-1)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	if String(d.get("kind", "")) != "todo_card":
		return
	var src_id: String = String(d.get("card_id", ""))
	if src_id == card_id or _is_descendant_id(src_id):
		return
	var sdata: Dictionary = (d.get("card_data", {}) as Dictionary).duplicate(true)
	var slid: String = String(d.get("source_list_id", ""))
	if _is_main_row_zone(at_position.y):
		emit_signal("child_drop_into_self", card_id, slid, src_id, sdata)
		return
	var idx: int = _index_for_drop_y(at_position.y)
	emit_signal("child_drop", card_id, slid, src_id, sdata, idx)


func _is_main_row_zone(local_y: float) -> bool:
	if not _sub_row.visible:
		return true
	var threshold: float = _sub_row.position.y
	return local_y < threshold


func _index_for_drop_y(local_y: float) -> int:
	if _child_container == null:
		return (card_data.get("subcards", []) as Array).size()
	var container_local_y: float = local_y - _sub_row.position.y - _child_area.position.y - _child_container.position.y
	var idx: int = 0
	for child in _child_container.get_children():
		if child == _child_drop_indicator:
			continue
		if not (child is Control):
			continue
		var c: Control = child
		var center_y: float = c.position.y + c.size.y * 0.5
		if container_local_y < center_y:
			return idx
		idx += 1
	return idx


func _is_descendant_id(other_id: String) -> bool:
	var sub: Array = card_data.get("subcards", []) as Array
	return not TodoCardData.find_path(sub, other_id).is_empty()


func _position_child_drop_indicator(index: int) -> void:
	if _child_drop_indicator == null:
		return
	if index < 0:
		_child_drop_indicator.visible = false
		return
	_child_drop_indicator.visible = true
	var rows: Array = []
	for child in _child_container.get_children():
		if child != _child_drop_indicator and child is Control:
			rows.append(child)
	_child_container.move_child(_child_drop_indicator, min(index, rows.size()))
