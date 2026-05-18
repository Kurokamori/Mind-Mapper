class_name EquationInspector
extends VBoxContainer

@onready var _latex_edit: TextEdit = %LatexEdit
@onready var _font_size_spin: SpinBox = %FontSizeSpin
@onready var _mode_option: OptionButton = %ModeOption
@onready var _solved_preview: Label = %SolvedPreview
@onready var _formatted_preview: RichTextLabel = %FormattedPreview

var _item: EquationNode = null
var _editor: Node = null
var _binders: Dictionary = {}
var _suppress_signals: bool = false


func bind(item: EquationNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	ThemeManager.apply_relative_font_sizes(self, {"Header": 1.15})
	if _item == null:
		return
	_suppress_signals = true
	_latex_edit.text = _item.latex
	_font_size_spin.value = _item.font_size
	_mode_option.clear()
	_mode_option.add_item("Formatted / Solved", EquationNode.DisplayMode.FORMATTED)
	_mode_option.add_item("Raw LaTeX", EquationNode.DisplayMode.RAW)
	_mode_option.selected = 1 if _item.display_mode == EquationNode.DisplayMode.RAW else 0
	_suppress_signals = false
	_binders["latex"] = PropertyBinder.new(_editor, _item, "latex", _item.latex)
	_binders["font_size"] = PropertyBinder.new(_editor, _item, "font_size", _item.font_size)
	_binders["display_mode"] = PropertyBinder.new(_editor, _item, "display_mode", _item.display_mode)
	_latex_edit.text_changed.connect(_on_latex_changed)
	_latex_edit.focus_exited.connect(_on_latex_committed)
	_font_size_spin.value_changed.connect(_on_font_size_changed)
	_mode_option.item_selected.connect(_on_mode_selected)
	_refresh_previews()


func _on_latex_changed() -> void:
	if _suppress_signals:
		return
	_binders["latex"].live(_latex_edit.text)
	_refresh_previews()


func _on_latex_committed() -> void:
	if _suppress_signals:
		return
	_binders["latex"].commit(_latex_edit.text)
	_refresh_previews()


func _on_font_size_changed(value: float) -> void:
	if _suppress_signals:
		return
	var v: int = int(value)
	_binders["font_size"].live(v)
	_binders["font_size"].commit(v)
	_refresh_previews()


func _on_mode_selected(index: int) -> void:
	if _suppress_signals:
		return
	var v: int = EquationNode.DisplayMode.RAW if index == 1 else EquationNode.DisplayMode.FORMATTED
	_binders["display_mode"].live(v)
	_binders["display_mode"].commit(v)


func _refresh_previews() -> void:
	var src: String = _latex_edit.text
	if _formatted_preview != null:
		_formatted_preview.bbcode_enabled = true
		_formatted_preview.text = LatexRenderer.to_bbcode(src, int(_font_size_spin.value))
	if _solved_preview != null:
		var result: Dictionary = LatexSolver.try_solve(src)
		if bool(result.get("ok", false)):
			_solved_preview.text = "Solved: " + String(result.get("formatted", ""))
			_solved_preview.modulate = Color(0.20, 0.65, 0.30, 1.0)
		else:
			_solved_preview.text = "Solved: —"
			_solved_preview.modulate = Color(0.65, 0.65, 0.65, 1.0)


func _find_editor() -> Node:
	return EditorLocator.find_for(_item)
