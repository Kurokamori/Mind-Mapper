class_name TimerInspector
extends VBoxContainer

@onready var _label_edit: LineEdit = %LabelEdit
@onready var _hours_spin: SpinBox = %HoursSpin
@onready var _minutes_spin: SpinBox = %MinutesSpin
@onready var _seconds_spin: SpinBox = %SecondsSpin

var _item: TimerNode
var _editor: Node
var _binders: Dictionary = {}
var _suppress_signals: bool = false


func bind(item: TimerNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	if _item == null:
		return
	_suppress_signals = true
	_label_edit.text = _item.label_text
	var total: int = int(_item.initial_duration_sec)
	@warning_ignore("integer_division")
	_hours_spin.value = float(total / 3600)
	@warning_ignore("integer_division")
	_minutes_spin.value = float((total % 3600) / 60)
	_seconds_spin.value = float(total % 60)
	_suppress_signals = false
	_binders["label_text"] = PropertyBinder.new(_editor, _item, "label_text", _item.label_text)
	_binders["initial_duration_sec"] = PropertyBinder.new(_editor, _item, "initial_duration_sec", _item.initial_duration_sec)
	_label_edit.text_changed.connect(func(t: String) -> void: _binders["label_text"].live(t))
	_label_edit.focus_exited.connect(func() -> void: _binders["label_text"].commit(_label_edit.text))
	_label_edit.text_submitted.connect(func(t: String) -> void: _binders["label_text"].commit(t))
	_hours_spin.value_changed.connect(_on_duration_part_changed)
	_minutes_spin.value_changed.connect(_on_duration_part_changed)
	_seconds_spin.value_changed.connect(_on_duration_part_changed)


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null


func _current_total_seconds() -> float:
	return _hours_spin.value * 3600.0 + _minutes_spin.value * 60.0 + _seconds_spin.value


func _on_duration_part_changed(_v: float) -> void:
	if _suppress_signals:
		return
	var total: float = _current_total_seconds()
	_binders["initial_duration_sec"].live(total)
	_binders["initial_duration_sec"].commit(total)
