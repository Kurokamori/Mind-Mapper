class_name EquationInspector
extends VBoxContainer

@onready var _latex_edit: TextEdit = %LatexEdit
@onready var _font_size_spin: SpinBox = %FontSizeSpin

var _item: EquationNode = null
var _editor: Node = null
var _binders: Dictionary = {}
var _suppress_signals: bool = false


func bind(item: EquationNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	if _item == null:
		return
	_suppress_signals = true
	_latex_edit.text = _item.latex
	_font_size_spin.value = _item.font_size
	_suppress_signals = false
	_binders["latex"] = PropertyBinder.new(_editor, _item, "latex", _item.latex)
	_binders["font_size"] = PropertyBinder.new(_editor, _item, "font_size", _item.font_size)
	_latex_edit.text_changed.connect(_on_latex_changed)
	_latex_edit.focus_exited.connect(_on_latex_committed)
	_font_size_spin.value_changed.connect(_on_font_size_changed)


func _on_latex_changed() -> void:
	if _suppress_signals:
		return
	_binders["latex"].live(_latex_edit.text)


func _on_latex_committed() -> void:
	if _suppress_signals:
		return
	_binders["latex"].commit(_latex_edit.text)


func _on_font_size_changed(value: float) -> void:
	if _suppress_signals:
		return
	var v: int = int(value)
	_binders["font_size"].live(v)
	_binders["font_size"].commit(v)


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null
