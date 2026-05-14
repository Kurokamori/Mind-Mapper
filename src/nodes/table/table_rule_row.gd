class_name TableRuleRow
extends PanelContainer

signal rule_changed(index: int, rule: Dictionary)
signal delete_requested(index: int)

@onready var _delete_btn: Button = %DeleteBtn
@onready var _scope_option: OptionButton = %ScopeOption
@onready var _column_spin: SpinBox = %ColumnSpin
@onready var _row_spin: SpinBox = %RowSpin
@onready var _op_option: OptionButton = %OpOption
@onready var _value_edit: LineEdit = %ValueEdit
@onready var _value2_edit: LineEdit = %Value2Edit
@onready var _case_check: CheckBox = %CaseCheck
@onready var _use_bg_check: CheckBox = %UseBgCheck
@onready var _bg_picker: ColorPickerButton = %BgPicker
@onready var _use_fg_check: CheckBox = %UseFgCheck
@onready var _fg_picker: ColorPickerButton = %FgPicker
@onready var _bold_check: CheckBox = %BoldCheck
@onready var _italic_check: CheckBox = %ItalicCheck
@onready var _header_check: CheckBox = %HeaderCheck

var _rule: Dictionary = {}
var _index: int = -1
var _suppress_signals: bool = false
var _max_columns: int = 100
var _max_rows: int = 100


func bind(index: int, rule: Dictionary, max_rows: int, max_columns: int) -> void:
	_index = index
	_rule = TableRule.normalize(rule)
	_max_rows = max(1, max_rows)
	_max_columns = max(1, max_columns)


func _ready() -> void:
	_populate_options()
	_apply_to_widgets()
	_connect_widgets()


func update_dimensions(max_rows: int, max_columns: int) -> void:
	_max_rows = max(1, max_rows)
	_max_columns = max(1, max_columns)
	_suppress_signals = true
	_column_spin.max_value = max(0, _max_columns - 1)
	_row_spin.max_value = max(0, _max_rows - 1)
	_column_spin.value = clamp(int(_rule.get("column", 0)), 0, max(0, _max_columns - 1))
	_row_spin.value = clamp(int(_rule.get("row", 0)), 0, max(0, _max_rows - 1))
	_suppress_signals = false


func set_index(index: int) -> void:
	_index = index


func current_rule() -> Dictionary:
	return _rule.duplicate(true)


func _populate_options() -> void:
	_scope_option.clear()
	for entry: Dictionary in TableRule.SCOPE_OPTIONS:
		_scope_option.add_item(String(entry["label"]))
		_scope_option.set_item_metadata(_scope_option.item_count - 1, String(entry["id"]))
	_op_option.clear()
	for entry: Dictionary in TableRule.OP_OPTIONS:
		_op_option.add_item(String(entry["label"]))
		_op_option.set_item_metadata(_op_option.item_count - 1, String(entry["id"]))


func _apply_to_widgets() -> void:
	_suppress_signals = true
	_scope_option.select(_index_for_option(_scope_option, String(_rule.get("scope", TableRule.SCOPE_ALL))))
	_op_option.select(_index_for_option(_op_option, String(_rule.get("op", TableRule.OP_CONTAINS))))
	_column_spin.max_value = max(0, _max_columns - 1)
	_row_spin.max_value = max(0, _max_rows - 1)
	_column_spin.value = clamp(int(_rule.get("column", 0)), 0, max(0, _max_columns - 1))
	_row_spin.value = clamp(int(_rule.get("row", 0)), 0, max(0, _max_rows - 1))
	_value_edit.text = String(_rule.get("value", ""))
	_value2_edit.text = String(_rule.get("value2", ""))
	_case_check.button_pressed = bool(_rule.get("case_sensitive", false))
	_use_bg_check.button_pressed = bool(_rule.get("use_bg", true))
	_use_fg_check.button_pressed = bool(_rule.get("use_fg", false))
	_bg_picker.color = ColorUtil.from_array(_rule.get("bg", null), Color(0.95, 0.83, 0.30, 1.0))
	_fg_picker.color = ColorUtil.from_array(_rule.get("fg", null), Color(0.10, 0.10, 0.12, 1.0))
	_bold_check.button_pressed = bool(_rule.get("bold", false))
	_italic_check.button_pressed = bool(_rule.get("italic", false))
	_header_check.button_pressed = bool(_rule.get("apply_to_header_row", false))
	_refresh_field_visibility()
	_suppress_signals = false


func _index_for_option(opt: OptionButton, target_id: String) -> int:
	for i in range(opt.item_count):
		if String(opt.get_item_metadata(i)) == target_id:
			return i
	return 0


func _connect_widgets() -> void:
	_delete_btn.pressed.connect(func() -> void: emit_signal("delete_requested", _index))
	_scope_option.item_selected.connect(_on_scope_changed)
	_op_option.item_selected.connect(_on_op_changed)
	_column_spin.value_changed.connect(_on_column_changed)
	_row_spin.value_changed.connect(_on_row_changed)
	_value_edit.text_changed.connect(_on_value_changed)
	_value2_edit.text_changed.connect(_on_value2_changed)
	_case_check.toggled.connect(_on_case_toggled)
	_use_bg_check.toggled.connect(_on_use_bg_toggled)
	_use_fg_check.toggled.connect(_on_use_fg_toggled)
	_bg_picker.color_changed.connect(_on_bg_color_changed)
	_fg_picker.color_changed.connect(_on_fg_color_changed)
	_bold_check.toggled.connect(_on_bold_toggled)
	_italic_check.toggled.connect(_on_italic_toggled)
	_header_check.toggled.connect(_on_header_toggled)


func _refresh_field_visibility() -> void:
	var scope: String = String(_rule.get("scope", TableRule.SCOPE_ALL))
	_column_spin.visible = scope == TableRule.SCOPE_COLUMN or scope == TableRule.SCOPE_CELL
	_row_spin.visible = scope == TableRule.SCOPE_ROW or scope == TableRule.SCOPE_CELL
	var op: String = String(_rule.get("op", TableRule.OP_CONTAINS))
	_value_edit.visible = TableRule.op_needs_value(op)
	_value2_edit.visible = TableRule.op_needs_value2(op)
	_bg_picker.disabled = not _use_bg_check.button_pressed
	_fg_picker.disabled = not _use_fg_check.button_pressed


func _emit_change() -> void:
	if _suppress_signals:
		return
	emit_signal("rule_changed", _index, _rule.duplicate(true))


func _on_scope_changed(idx: int) -> void:
	_rule["scope"] = String(_scope_option.get_item_metadata(idx))
	_refresh_field_visibility()
	_emit_change()


func _on_op_changed(idx: int) -> void:
	_rule["op"] = String(_op_option.get_item_metadata(idx))
	_refresh_field_visibility()
	_emit_change()


func _on_column_changed(value: float) -> void:
	_rule["column"] = int(value)
	_emit_change()


func _on_row_changed(value: float) -> void:
	_rule["row"] = int(value)
	_emit_change()


func _on_value_changed(value: String) -> void:
	_rule["value"] = value
	_emit_change()


func _on_value2_changed(value: String) -> void:
	_rule["value2"] = value
	_emit_change()


func _on_case_toggled(value: bool) -> void:
	_rule["case_sensitive"] = value
	_emit_change()


func _on_use_bg_toggled(value: bool) -> void:
	_rule["use_bg"] = value
	_bg_picker.disabled = not value
	_emit_change()


func _on_use_fg_toggled(value: bool) -> void:
	_rule["use_fg"] = value
	_fg_picker.disabled = not value
	_emit_change()


func _on_bg_color_changed(c: Color) -> void:
	_rule["bg"] = ColorUtil.to_array(c)
	_emit_change()


func _on_fg_color_changed(c: Color) -> void:
	_rule["fg"] = ColorUtil.to_array(c)
	_emit_change()


func _on_bold_toggled(value: bool) -> void:
	_rule["bold"] = value
	_emit_change()


func _on_italic_toggled(value: bool) -> void:
	_rule["italic"] = value
	_emit_change()


func _on_header_toggled(value: bool) -> void:
	_rule["apply_to_header_row"] = value
	_emit_change()
