class_name TableInspector
extends VBoxContainer

const RULE_ROW_SCENE: PackedScene = preload("res://src/nodes/table/table_rule_row.tscn")

@onready var _title_edit: LineEdit = %TitleEdit
@onready var _dimensions_label: Label = %DimensionsLabel
@onready var _rows_spin: SpinBox = %RowsSpin
@onready var _cols_spin: SpinBox = %ColsSpin
@onready var _header_row_check: CheckBox = %HeaderRowCheck
@onready var _alignments_container: VBoxContainer = %AlignmentsContainer
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


func bind(item: TableNode) -> void:
	_item = item


func _ready() -> void:
	ThemeManager.apply_relative_font_sizes(self, {"Header": 1.15})
	if _item == null:
		return
	_suppress_signals = true
	_title_edit.text = _item.title
	_title_before_edit = _item.title
	_rows_spin.value = _item.rows
	_cols_spin.value = _item.cols
	_header_row_check.button_pressed = _item.has_header_row
	_refresh_dimensions_label()
	_rebuild_alignments()
	_rebuild_rule_rows()
	_refresh_color_pickers()
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
	_update_rule_rows_dimensions()
	_refresh_cell_format_section()


func _on_cols_changed(value: float) -> void:
	if _suppress_signals or _item == null:
		return
	var new_cols: int = max(1, int(value))
	if new_cols == _item.cols:
		return
	_item.commit_dimensions(_item.rows, new_cols)
	_refresh_dimensions_label()
	_rebuild_alignments()
	_update_rule_rows_dimensions()
	_refresh_cell_format_section()


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
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var lbl: Label = Label.new()
		lbl.text = "Col %d" % c
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var opt: OptionButton = OptionButton.new()
		opt.add_item("Left")
		opt.set_item_metadata(0, TableNode.ALIGN_LEFT)
		opt.add_item("Center")
		opt.set_item_metadata(1, TableNode.ALIGN_CENTER)
		opt.add_item("Right")
		opt.set_item_metadata(2, TableNode.ALIGN_RIGHT)
		opt.select(_alignment_to_option_index(_item._effective_col_align(c)))
		var col_index: int = c
		opt.item_selected.connect(func(idx: int) -> void: _on_alignment_changed(col_index, int(opt.get_item_metadata(idx))))
		row.add_child(opt)
		var width_spin: SpinBox = SpinBox.new()
		width_spin.min_value = 0.0
		width_spin.max_value = 2000.0
		width_spin.step = 10.0
		width_spin.suffix = "px"
		width_spin.value = _item.column_width_at(c)
		width_spin.tooltip_text = "Column width in pixels (0 = auto)"
		width_spin.custom_minimum_size = Vector2(96, 0)
		width_spin.value_changed.connect(func(v: float) -> void: _on_column_width_changed(col_index, v))
		row.add_child(width_spin)
		var reset_btn: Button = Button.new()
		reset_btn.text = "Auto"
		reset_btn.tooltip_text = "Reset column width to auto"
		reset_btn.pressed.connect(func() -> void: _on_column_width_reset(col_index))
		row.add_child(reset_btn)
		_alignments_container.add_child(row)


func _alignment_to_option_index(align_id: int) -> int:
	match align_id:
		TableNode.ALIGN_CENTER:
			return 1
		TableNode.ALIGN_RIGHT:
			return 2
	return 0


func _on_alignment_changed(column: int, value: int) -> void:
	if _suppress_signals or _item == null:
		return
	_item.set_col_align(column, value)


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
	_suppress_cell_signals = false


func _build_active_cell_format() -> Dictionary:
	return {
		"use_bg": _cell_use_bg.button_pressed,
		"bg": ColorUtil.to_array(_cell_bg_picker.color),
		"use_fg": _cell_use_fg.button_pressed,
		"fg": ColorUtil.to_array(_cell_fg_picker.color),
		"bold": _cell_bold.button_pressed,
		"italic": _cell_italic.button_pressed,
	}


func _commit_active_cell_format() -> void:
	if _item == null:
		return
	var active: Vector2i = _item.active_cell()
	_item.set_cell_format(active.x, active.y, _build_active_cell_format())


func _on_active_cell_changed(_r: int, _c: int) -> void:
	_refresh_cell_format_section()


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


func _on_cell_clear_pressed() -> void:
	if _item == null:
		return
	var active: Vector2i = _item.active_cell()
	_item.clear_cell_format(active.x, active.y)
	_refresh_cell_format_section()


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
