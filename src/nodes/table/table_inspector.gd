class_name TableInspector
extends VBoxContainer

const RULE_ROW_SCENE: PackedScene = preload("res://src/nodes/table/table_rule_row.tscn")
const ALIGNMENT_PICKER_SCENE: PackedScene = preload("res://src/nodes/table/cell_alignment_picker.tscn")

@onready var _title_edit: LineEdit = %TitleEdit
@onready var _dimensions_label: Label = %DimensionsLabel
@onready var _rows_spin: SpinBox = %RowsSpin
@onready var _cols_spin: SpinBox = %ColsSpin
@onready var _header_row_check: CheckBox = %HeaderRowCheck
@onready var _alignments_container: HBoxContainer = %AlignmentsContainer
@onready var _row_alignments_container: HBoxContainer = %RowAlignmentsContainer
@onready var _axis_action_label: Label = %AxisActionLabel
@onready var _axis_insert_before_btn: Button = %AxisInsertBeforeBtn
@onready var _axis_insert_after_btn: Button = %AxisInsertAfterBtn
@onready var _axis_delete_btn: Button = %AxisDeleteBtn
@onready var _rules_container: VBoxContainer = %RulesContainer
@onready var _add_rule_btn: Button = %AddRuleBtn
@onready var _bg_picker: ColorPickerButton = %BgPicker
@onready var _bg_reset: Button = %BgReset
@onready var _accent_picker: ColorPickerButton = %AccentPicker
@onready var _accent_reset: Button = %AccentReset
@onready var _header_fg_picker: ColorPickerButton = %HeaderFgPicker
@onready var _header_fg_reset: Button = %HeaderFgReset
@onready var _grid_line_picker: ColorPickerButton = %GridLinePicker
@onready var _grid_line_reset: Button = %GridLineReset
@onready var _cell_row_spin: SpinBox = %CellRowSpin
@onready var _cell_col_spin: SpinBox = %CellColSpin
@onready var _cell_alignment_slot: Control = %CellAlignmentSlot
@onready var _cell_use_bg: CheckBox = %CellUseBg
@onready var _cell_bg_picker: ColorPickerButton = %CellBgPicker
@onready var _cell_use_fg: CheckBox = %CellUseFg
@onready var _cell_fg_picker: ColorPickerButton = %CellFgPicker
@onready var _cell_bold: CheckBox = %CellBold
@onready var _cell_italic: CheckBox = %CellItalic
@onready var _cell_clear: Button = %CellClear

var _item: TableNode = null
var _suppress_signals: bool = false
var _title_before_edit: String = ""
var _suppress_cell_signals: bool = false
var _cell_alignment_picker: CellAlignmentPicker = null


func bind(item: TableNode) -> void:
	_item = item


func _ready() -> void:
	ThemeManager.apply_relative_font_sizes(self, {"Header": 1.15})
	if _item == null:
		return
	_install_cell_alignment_picker()
	_suppress_signals = true
	_title_edit.text = _item.title
	_title_before_edit = _item.title
	_rows_spin.value = _item.rows
	_cols_spin.value = _item.cols
	_header_row_check.button_pressed = _item.has_header_row
	_refresh_dimensions_label()
	_rebuild_alignments()
	_rebuild_row_alignments()
	_rebuild_rule_rows()
	_refresh_color_pickers()
	_refresh_axis_action_state()
	_suppress_signals = false
	_title_edit.text_changed.connect(_on_title_changed)
	_title_edit.text_submitted.connect(_on_title_submitted)
	_rows_spin.value_changed.connect(_on_rows_changed)
	_cols_spin.value_changed.connect(_on_cols_changed)
	_header_row_check.toggled.connect(_on_header_row_toggled)
	_add_rule_btn.pressed.connect(_on_add_rule_pressed)
	_bg_picker.color_changed.connect(_on_bg_changed)
	_bg_reset.pressed.connect(_on_bg_reset_pressed)
	_accent_picker.color_changed.connect(_on_accent_changed)
	_accent_reset.pressed.connect(_on_accent_reset_pressed)
	_header_fg_picker.color_changed.connect(_on_header_fg_changed)
	_header_fg_reset.pressed.connect(_on_header_fg_reset_pressed)
	_grid_line_picker.color_changed.connect(_on_grid_line_changed)
	_grid_line_reset.pressed.connect(_on_grid_line_reset_pressed)
	_axis_insert_before_btn.pressed.connect(_on_axis_insert_before_pressed)
	_axis_insert_after_btn.pressed.connect(_on_axis_insert_after_pressed)
	_axis_delete_btn.pressed.connect(_on_axis_delete_pressed)
	_refresh_cell_format_section()
	_cell_row_spin.value_changed.connect(_on_cell_target_row_changed)
	_cell_col_spin.value_changed.connect(_on_cell_target_col_changed)
	_cell_use_bg.toggled.connect(_on_cell_use_bg_toggled)
	_cell_bg_picker.color_changed.connect(_on_cell_bg_changed)
	_cell_use_fg.toggled.connect(_on_cell_use_fg_toggled)
	_cell_fg_picker.color_changed.connect(_on_cell_fg_changed)
	_cell_bold.toggled.connect(_on_cell_bold_toggled)
	_cell_italic.toggled.connect(_on_cell_italic_toggled)
	_cell_clear.pressed.connect(_on_cell_clear_pressed)
	_item.active_cell_changed.connect(_on_active_cell_changed)
	_item.axis_selection_changed.connect(_on_axis_selection_changed)


func _install_cell_alignment_picker() -> void:
	if _cell_alignment_slot == null:
		return
	_cell_alignment_picker = ALIGNMENT_PICKER_SCENE.instantiate()
	_cell_alignment_picker.allow_inherit = true
	_cell_alignment_picker.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_cell_alignment_picker.position = Vector2.ZERO
	_cell_alignment_slot.add_child(_cell_alignment_picker)
	_cell_alignment_picker.alignment_changed.connect(_on_cell_alignment_changed)


func _refresh_dimensions_label() -> void:
	_dimensions_label.text = "%d × %d" % [_item.rows, _item.cols]


func _refresh_color_pickers() -> void:
	_bg_picker.color = _item.bg_color if _item.bg_color_custom else _item._resolved_bg()
	_accent_picker.color = _item.accent_color if _item.accent_color_custom else _item._resolved_accent()
	_header_fg_picker.color = _item.header_fg_color if _item.header_fg_color_custom else _item._resolved_header_fg()
	_grid_line_picker.color = _item.grid_line_color if _item.grid_line_color_custom else _item._resolved_grid_line()


func _on_title_changed(value: String) -> void:
	if _suppress_signals or _item == null:
		return
	_item.title = value
	if _item._title_label != null:
		_item._title_label.text = value


func _on_title_submitted(value: String) -> void:
	if _suppress_signals or _item == null:
		return
	if value == _title_before_edit:
		return
	var editor: Node = _item._find_editor()
	if editor != null:
		History.push(ModifyPropertyCommand.new(editor, _item.item_id, "title", _title_before_edit, value))
	_title_before_edit = value


func _on_rows_changed(value: float) -> void:
	if _suppress_signals or _item == null:
		return
	var new_rows: int = max(1, int(value))
	if new_rows == _item.rows:
		return
	_item.commit_dimensions(new_rows, _item.cols)
	_refresh_dimensions_label()
	_rebuild_alignments()
	_rebuild_row_alignments()
	_update_rule_rows_dimensions()
	_refresh_cell_format_section()
	_refresh_axis_action_state()


func _on_cols_changed(value: float) -> void:
	if _suppress_signals or _item == null:
		return
	var new_cols: int = max(1, int(value))
	if new_cols == _item.cols:
		return
	_item.commit_dimensions(_item.rows, new_cols)
	_refresh_dimensions_label()
	_rebuild_alignments()
	_rebuild_row_alignments()
	_update_rule_rows_dimensions()
	_refresh_cell_format_section()
	_refresh_axis_action_state()


func _on_header_row_toggled(value: bool) -> void:
	if _suppress_signals or _item == null:
		return
	_item.set_has_header_row(value)


func _rebuild_alignments() -> void:
	if _alignments_container == null or _item == null:
		return
	for child in _alignments_container.get_children():
		child.queue_free()
	for c in range(_item.cols):
		var col_index: int = c
		var card: PanelContainer = _make_axis_card("Col %d" % c)
		var card_vbox: VBoxContainer = card.get_child(0) as VBoxContainer
		var picker: CellAlignmentPicker = ALIGNMENT_PICKER_SCENE.instantiate()
		picker.allow_inherit = false
		picker.set_alignment(_item.col_align_at(c), _item.col_valign_at(c), false)
		picker.alignment_changed.connect(func(h: int, v: int, _inh: bool) -> void:
			if _suppress_signals or _item == null:
				return
			_item.set_col_align(col_index, h)
			_item.set_col_valign(col_index, v))
		card_vbox.add_child(picker)
		var width_row: HBoxContainer = HBoxContainer.new()
		width_row.add_theme_constant_override("separation", 4)
		var width_label: Label = Label.new()
		width_label.text = "W:"
		width_row.add_child(width_label)
		var width_spin: SpinBox = SpinBox.new()
		width_spin.min_value = 0.0
		width_spin.max_value = 2000.0
		width_spin.step = 10.0
		width_spin.suffix = "px"
		width_spin.value = _item.column_width_at(c)
		width_spin.tooltip_text = "Column width in pixels (0 = auto)"
		width_spin.custom_minimum_size = Vector2(78, 0)
		width_spin.value_changed.connect(func(v: float) -> void: _on_column_width_changed(col_index, v))
		width_row.add_child(width_spin)
		var reset_btn: Button = Button.new()
		reset_btn.text = "Auto"
		reset_btn.tooltip_text = "Reset column width to auto"
		reset_btn.focus_mode = Control.FOCUS_NONE
		reset_btn.pressed.connect(func() -> void: _on_column_width_reset(col_index))
		width_row.add_child(reset_btn)
		card_vbox.add_child(width_row)
		var select_btn: Button = Button.new()
		select_btn.text = "Select column"
		select_btn.focus_mode = Control.FOCUS_NONE
		select_btn.tooltip_text = "Select this column on the canvas"
		select_btn.pressed.connect(func() -> void:
			if _item == null:
				return
			_item.select_column(col_index))
		card_vbox.add_child(select_btn)
		_alignments_container.add_child(card)


func _rebuild_row_alignments() -> void:
	if _row_alignments_container == null or _item == null:
		return
	for child in _row_alignments_container.get_children():
		child.queue_free()
	for r in range(_item.rows):
		var row_index: int = r
		var card: PanelContainer = _make_axis_card("Row %d" % r)
		var card_vbox: VBoxContainer = card.get_child(0) as VBoxContainer
		var picker: CellAlignmentPicker = ALIGNMENT_PICKER_SCENE.instantiate()
		picker.allow_inherit = true
		var h_initial: int = _item.row_align_at(r)
		var v_initial: int = _item.row_valign_at(r)
		var h_inherit: bool = h_initial == TableNode.ALIGN_INHERIT
		var v_inherit: bool = v_initial == TableNode.ALIGN_INHERIT
		var fully_inherit: bool = h_inherit and v_inherit
		var h_for_picker: int = TableNode.ALIGN_LEFT if h_inherit else h_initial
		var v_for_picker: int = TableNode.VALIGN_MIDDLE if v_inherit else v_initial
		picker.set_alignment(h_for_picker, v_for_picker, fully_inherit)
		picker.alignment_changed.connect(func(h: int, v: int, is_inherit_value: bool) -> void:
			if _suppress_signals or _item == null:
				return
			if is_inherit_value:
				_item.set_row_align(row_index, TableNode.ALIGN_INHERIT)
				_item.set_row_valign(row_index, TableNode.ALIGN_INHERIT)
			else:
				_item.set_row_align(row_index, h)
				_item.set_row_valign(row_index, v))
		card_vbox.add_child(picker)
		var select_btn: Button = Button.new()
		select_btn.text = "Select row"
		select_btn.focus_mode = Control.FOCUS_NONE
		select_btn.tooltip_text = "Select this row on the canvas"
		select_btn.pressed.connect(func() -> void:
			if _item == null:
				return
			_item.select_row(row_index))
		card_vbox.add_child(select_btn)
		_row_alignments_container.add_child(card)


func _make_axis_card(label_text: String) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.04)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(1, 1, 1, 0.08)
	card.add_theme_stylebox_override("panel", sb)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.modulate = Color(1, 1, 1, 0.85)
	vbox.add_child(lbl)
	return card


func _on_column_width_changed(column: int, value: float) -> void:
	if _suppress_signals or _item == null:
		return
	if is_equal_approx(value, _item.column_width_at(column)):
		return
	_item.set_column_width(column, value)


func _on_column_width_reset(column: int) -> void:
	if _item == null:
		return
	_item.reset_column_width(column)
	_rebuild_alignments()


func _rebuild_rule_rows() -> void:
	if _rules_container == null or _item == null:
		return
	for child in _rules_container.get_children():
		child.queue_free()
	for i in range(_item.rules.size()):
		_instantiate_rule_row(i, _item.rules[i])


func _instantiate_rule_row(index: int, rule: Dictionary) -> void:
	var row: TableRuleRow = RULE_ROW_SCENE.instantiate()
	row.bind(index, rule, _item.rows, _item.cols)
	row.rule_changed.connect(_on_rule_changed)
	row.delete_requested.connect(_on_rule_delete_requested)
	_rules_container.add_child(row)


func _update_rule_rows_dimensions() -> void:
	for child in _rules_container.get_children():
		if child is TableRuleRow:
			(child as TableRuleRow).update_dimensions(_item.rows, _item.cols)


func _on_rule_changed(index: int, rule: Dictionary) -> void:
	if _item == null:
		return
	if index < 0 or index >= _item.rules.size():
		return
	var new_rules: Array = _item.rules.duplicate(true)
	new_rules[index] = rule
	_item.replace_rules(new_rules)


func _on_rule_delete_requested(index: int) -> void:
	if _item == null:
		return
	if index < 0 or index >= _item.rules.size():
		return
	var new_rules: Array = _item.rules.duplicate(true)
	new_rules.remove_at(index)
	_item.replace_rules(new_rules)
	_rebuild_rule_rows()


func _on_add_rule_pressed() -> void:
	if _item == null:
		return
	var new_rules: Array = _item.rules.duplicate(true)
	new_rules.append(TableRule.make_default())
	_item.replace_rules(new_rules)
	_rebuild_rule_rows()


func _on_bg_changed(c: Color) -> void:
	if _suppress_signals or _item == null:
		return
	_apply_color("bg_color", c)


func _on_accent_changed(c: Color) -> void:
	if _suppress_signals or _item == null:
		return
	_apply_color("accent_color", c)


func _on_header_fg_changed(c: Color) -> void:
	if _suppress_signals or _item == null:
		return
	_apply_color("header_fg_color", c)


func _on_grid_line_changed(c: Color) -> void:
	if _suppress_signals or _item == null:
		return
	_apply_color("grid_line_color", c)


func _on_bg_reset_pressed() -> void:
	_reset_color("bg_color")


func _on_accent_reset_pressed() -> void:
	_reset_color("accent_color")


func _on_header_fg_reset_pressed() -> void:
	_reset_color("header_fg_color")


func _on_grid_line_reset_pressed() -> void:
	_reset_color("grid_line_color")


func _apply_color(key: String, value: Color) -> void:
	var editor: Node = _item._find_editor()
	var before: Variant = null
	var before_custom: bool = bool(_item.get(key + "_custom"))
	if before_custom:
		before = ColorUtil.to_array(_item.get(key))
	if editor != null:
		History.push(ModifyPropertyCommand.new(editor, _item.item_id, key, before, ColorUtil.to_array(value)))
	else:
		_item.apply_typed_property(key, ColorUtil.to_array(value))


func _refresh_cell_format_section() -> void:
	if _item == null:
		return
	_suppress_cell_signals = true
	_cell_row_spin.max_value = max(0, _item.rows - 1)
	_cell_col_spin.max_value = max(0, _item.cols - 1)
	var active: Vector2i = _item.active_cell()
	_cell_row_spin.value = active.x
	_cell_col_spin.value = active.y
	var fmt: Dictionary = _item.get_cell_format(active.x, active.y)
	_cell_use_bg.button_pressed = bool(fmt.get("use_bg", false))
	_cell_use_fg.button_pressed = bool(fmt.get("use_fg", false))
	_cell_bg_picker.color = ColorUtil.from_array(fmt.get("bg", null), Color(1, 1, 1, 1))
	_cell_fg_picker.color = ColorUtil.from_array(fmt.get("fg", null), Color(0, 0, 0, 1))
	_cell_bold.button_pressed = bool(fmt.get("bold", false))
	_cell_italic.button_pressed = bool(fmt.get("italic", false))
	_cell_bg_picker.disabled = not _cell_use_bg.button_pressed
	_cell_fg_picker.disabled = not _cell_use_fg.button_pressed
	if _cell_alignment_picker != null:
		var h_value: int = int(fmt.get("align_h", TableNode.ALIGN_INHERIT))
		var v_value: int = int(fmt.get("align_v", TableNode.ALIGN_INHERIT))
		var h_inherit: bool = h_value == TableNode.ALIGN_INHERIT
		var v_inherit: bool = v_value == TableNode.ALIGN_INHERIT
		var fully_inherit: bool = h_inherit and v_inherit
		var h_for_picker: int = _item.effective_h_align_at(active.x, active.y) if h_inherit else h_value
		var v_for_picker: int = _item.effective_v_align_at(active.x, active.y) if v_inherit else v_value
		_cell_alignment_picker.set_alignment(h_for_picker, v_for_picker, fully_inherit)
	_suppress_cell_signals = false


func _build_active_cell_format() -> Dictionary:
	var align_h: int = TableNode.ALIGN_INHERIT
	var align_v: int = TableNode.ALIGN_INHERIT
	if _cell_alignment_picker != null and not _cell_alignment_picker.current_is_inherit():
		align_h = _cell_alignment_picker.current_h()
		align_v = _cell_alignment_picker.current_v()
	return {
		"use_bg": _cell_use_bg.button_pressed,
		"bg": ColorUtil.to_array(_cell_bg_picker.color),
		"use_fg": _cell_use_fg.button_pressed,
		"fg": ColorUtil.to_array(_cell_fg_picker.color),
		"bold": _cell_bold.button_pressed,
		"italic": _cell_italic.button_pressed,
		"align_h": align_h,
		"align_v": align_v,
	}


func _commit_active_cell_format() -> void:
	if _item == null:
		return
	var active: Vector2i = _item.active_cell()
	_item.set_cell_format(active.x, active.y, _build_active_cell_format())


func _on_active_cell_changed(_r: int, _c: int) -> void:
	_refresh_cell_format_section()


func _on_axis_selection_changed(_axis: String, _index: int) -> void:
	_refresh_axis_action_state()


func _on_cell_target_row_changed(value: float) -> void:
	if _suppress_cell_signals or _item == null:
		return
	_item.set_active_cell(int(value), int(_cell_col_spin.value))


func _on_cell_target_col_changed(value: float) -> void:
	if _suppress_cell_signals or _item == null:
		return
	_item.set_active_cell(int(_cell_row_spin.value), int(value))


func _on_cell_use_bg_toggled(value: bool) -> void:
	if _suppress_cell_signals:
		return
	_cell_bg_picker.disabled = not value
	_commit_active_cell_format()


func _on_cell_use_fg_toggled(value: bool) -> void:
	if _suppress_cell_signals:
		return
	_cell_fg_picker.disabled = not value
	_commit_active_cell_format()


func _on_cell_bg_changed(_c: Color) -> void:
	if _suppress_cell_signals:
		return
	if not _cell_use_bg.button_pressed:
		_cell_use_bg.button_pressed = true
		_cell_bg_picker.disabled = false
	_commit_active_cell_format()


func _on_cell_fg_changed(_c: Color) -> void:
	if _suppress_cell_signals:
		return
	if not _cell_use_fg.button_pressed:
		_cell_use_fg.button_pressed = true
		_cell_fg_picker.disabled = false
	_commit_active_cell_format()


func _on_cell_bold_toggled(_value: bool) -> void:
	if _suppress_cell_signals:
		return
	_commit_active_cell_format()


func _on_cell_italic_toggled(_value: bool) -> void:
	if _suppress_cell_signals:
		return
	_commit_active_cell_format()


func _on_cell_alignment_changed(_h: int, _v: int, _is_inherit_value: bool) -> void:
	if _suppress_cell_signals:
		return
	_commit_active_cell_format()


func _on_cell_clear_pressed() -> void:
	if _item == null:
		return
	var active: Vector2i = _item.active_cell()
	_item.clear_cell_format(active.x, active.y)
	_refresh_cell_format_section()


func _refresh_axis_action_state() -> void:
	if _item == null:
		return
	var axis: String = _item.selected_axis()
	var index: int = _item.selected_axis_index()
	var has_selection: bool = axis != "" and index >= 0
	_axis_insert_before_btn.disabled = not has_selection
	_axis_insert_after_btn.disabled = not has_selection
	_axis_delete_btn.disabled = not has_selection
	if not has_selection:
		_axis_action_label.text = "Selection: none — click a row/column edge"
		_axis_insert_before_btn.text = "Insert ↑"
		_axis_insert_after_btn.text = "Insert ↓"
		_axis_delete_btn.text = "Delete row"
		return
	if axis == TableNode.AXIS_ROW:
		_axis_action_label.text = "Selected row: %d" % index
		_axis_insert_before_btn.text = "Insert ↑"
		_axis_insert_after_btn.text = "Insert ↓"
		_axis_delete_btn.text = "Delete row"
		_axis_delete_btn.disabled = _item.rows <= 1
	else:
		_axis_action_label.text = "Selected col: %d" % index
		_axis_insert_before_btn.text = "Insert ←"
		_axis_insert_after_btn.text = "Insert →"
		_axis_delete_btn.text = "Delete col"
		_axis_delete_btn.disabled = _item.cols <= 1


func _on_axis_insert_before_pressed() -> void:
	if _item == null:
		return
	var axis: String = _item.selected_axis()
	var index: int = _item.selected_axis_index()
	if index < 0:
		return
	if axis == TableNode.AXIS_ROW:
		_item.insert_row_at(index)
	elif axis == TableNode.AXIS_COL:
		_item.insert_col_at(index)
	_post_axis_change()


func _on_axis_insert_after_pressed() -> void:
	if _item == null:
		return
	var axis: String = _item.selected_axis()
	var index: int = _item.selected_axis_index()
	if index < 0:
		return
	if axis == TableNode.AXIS_ROW:
		_item.insert_row_at(index + 1)
	elif axis == TableNode.AXIS_COL:
		_item.insert_col_at(index + 1)
	_post_axis_change()


func _on_axis_delete_pressed() -> void:
	if _item == null:
		return
	var axis: String = _item.selected_axis()
	var index: int = _item.selected_axis_index()
	if index < 0:
		return
	if axis == TableNode.AXIS_ROW:
		_item.delete_row_at(index)
	elif axis == TableNode.AXIS_COL:
		_item.delete_col_at(index)
	_post_axis_change()


func _post_axis_change() -> void:
	_suppress_signals = true
	_rows_spin.value = _item.rows
	_cols_spin.value = _item.cols
	_suppress_signals = false
	_refresh_dimensions_label()
	_rebuild_alignments()
	_rebuild_row_alignments()
	_update_rule_rows_dimensions()
	_refresh_cell_format_section()
	_refresh_axis_action_state()


func _reset_color(key: String) -> void:
	var editor: Node = _item._find_editor()
	var before: Variant = null
	var before_custom: bool = bool(_item.get(key + "_custom"))
	if before_custom:
		before = ColorUtil.to_array(_item.get(key))
	if editor != null:
		History.push(ModifyPropertyCommand.new(editor, _item.item_id, key, before, null))
	else:
		_item.apply_typed_property(key, null)
	_refresh_color_pickers()
