class_name CodeInspector
extends VBoxContainer

@onready var _language_option: OptionButton = %LanguageOption
@onready var _font_size_spin: SpinBox = %FontSizeSpin
@onready var _code_edit: CodeEdit = %CodeEdit

var _item: CodeNode = null
var _editor: Node = null
var _binders: Dictionary = {}
var _suppress_signals: bool = false


func bind(item: CodeNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	if _item == null:
		return
	_suppress_signals = true
	_language_option.clear()
	for i: int in range(CodeNode.LANGUAGES.size()):
		_language_option.add_item(CodeNode.LANGUAGES[i], i)
		if CodeNode.LANGUAGES[i] == _item.language:
			_language_option.select(i)
	_font_size_spin.value = _item.font_size
	_code_edit.text = _item.code
	_suppress_signals = false
	_binders["language"] = PropertyBinder.new(_editor, _item, "language", _item.language)
	_binders["font_size"] = PropertyBinder.new(_editor, _item, "font_size", _item.font_size)
	_binders["code"] = PropertyBinder.new(_editor, _item, "code", _item.code)
	_language_option.item_selected.connect(_on_language_selected)
	_font_size_spin.value_changed.connect(_on_font_size_changed)
	_code_edit.text_changed.connect(_on_code_changed)
	_code_edit.focus_exited.connect(_on_code_committed)


func _on_language_selected(index: int) -> void:
	if _suppress_signals:
		return
	if index < 0 or index >= CodeNode.LANGUAGES.size():
		return
	var lang: String = CodeNode.LANGUAGES[index]
	_binders["language"].live(lang)
	_binders["language"].commit(lang)


func _on_font_size_changed(value: float) -> void:
	if _suppress_signals:
		return
	var v: int = int(value)
	_binders["font_size"].live(v)
	_binders["font_size"].commit(v)


func _on_code_changed() -> void:
	if _suppress_signals:
		return
	_binders["code"].live(_code_edit.text)


func _on_code_committed() -> void:
	if _suppress_signals:
		return
	_binders["code"].commit(_code_edit.text)


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null
