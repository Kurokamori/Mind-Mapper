class_name TableInspector
extends VBoxContainer

@onready var _dimensions_label: Label = %DimensionsLabel
@onready var _rows_spin: SpinBox = %RowsSpin
@onready var _cols_spin: SpinBox = %ColsSpin

var _item: TableNode = null
var _suppress_signals: bool = false


func bind(item: TableNode) -> void:
	_item = item


func _ready() -> void:
	if _item == null:
		return
	_suppress_signals = true
	_rows_spin.value = _item.rows
	_cols_spin.value = _item.cols
	_refresh_dimensions_label()
	_suppress_signals = false
	_rows_spin.value_changed.connect(_on_rows_changed)
	_cols_spin.value_changed.connect(_on_cols_changed)


func _on_rows_changed(value: float) -> void:
	if _suppress_signals or _item == null:
		return
	var new_rows: int = max(1, int(value))
	if new_rows == _item.rows:
		return
	_item.commit_dimensions(new_rows, _item.cols)
	_refresh_dimensions_label()


func _on_cols_changed(value: float) -> void:
	if _suppress_signals or _item == null:
		return
	var new_cols: int = max(1, int(value))
	if new_cols == _item.cols:
		return
	_item.commit_dimensions(_item.rows, new_cols)
	_refresh_dimensions_label()


func _refresh_dimensions_label() -> void:
	if _item == null:
		return
	_dimensions_label.text = "%d × %d" % [_item.rows, _item.cols]
