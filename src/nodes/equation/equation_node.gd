class_name EquationNode
extends BoardItem

const HEADER_HEIGHT: float = 24.0
const PADDING: Vector2 = Vector2(10, 8)
const DARK_HEADER_BG: Color = Color(0.32, 0.40, 0.55, 1.0)
const LIGHT_HEADER_BG: Color = Color(0.55, 0.68, 0.88, 1.0)
const DARK_HEADER_FG: Color = Color(0.95, 0.97, 1.0, 1.0)
const LIGHT_HEADER_FG: Color = Color(0.06, 0.13, 0.22, 1.0)
const PREVIEW_BG: Color = Color(0.95, 0.95, 0.97, 1.0)
const PREVIEW_FG: Color = Color(0.05, 0.05, 0.10, 1.0)
const DARK_BORDER: Color = Color(0.55, 0.60, 0.68, 1.0)
const LIGHT_BORDER: Color = Color(0.62, 0.66, 0.74, 1.0)

@export var latex: String = "E = mc^2"
@export var font_size: int = 22

@onready var _preview: Label = %Preview
@onready var _source_label: Label = %SourceLabel
@onready var _edit: TextEdit = %TextEdit

var _pre_edit: String = ""


func _ready() -> void:
	super._ready()
	ThemeManager.theme_applied.connect(_refresh_visuals)
	ThemeManager.node_palette_changed.connect(func(_a: Dictionary, _b: Dictionary) -> void: _refresh_visuals())
	_layout()
	_refresh_visuals()
	_edit.focus_exited.connect(_commit_text)
	SelectionBus.selection_changed.connect(_on_selection_changed)


func default_size() -> Vector2:
	return Vector2(280, 120)


func display_name() -> String:
	return "Equation"


func _draw_body() -> void:
	_draw_rounded_panel(
		PREVIEW_BG,
		ThemeManager.themed_color(DARK_BORDER, LIGHT_BORDER),
		HEADER_HEIGHT,
		ThemeManager.heading_bg("equation"),
	)


func _refresh_visuals() -> void:
	if _preview != null:
		_preview.text = render_preview(latex)
		_preview.add_theme_font_size_override("font_size", font_size)
		_preview.add_theme_color_override("font_color", PREVIEW_FG)
	if _source_label != null:
		_source_label.text = " " + latex
		_source_label.add_theme_color_override("font_color", ThemeManager.heading_fg("equation"))
	queue_redraw()


func _on_selection_changed(selected: Array) -> void:
	if is_editing() and not selected.has(self):
		end_edit()


func _layout() -> void:
	if _source_label != null:
		_source_label.position = Vector2(4, 4)
		_source_label.size = Vector2(size.x - 8, HEADER_HEIGHT - 8)
	if _preview != null:
		_preview.position = PADDING + Vector2(0, HEADER_HEIGHT)
		_preview.size = size - Vector2(PADDING.x * 2, HEADER_HEIGHT + PADDING.y * 2)
	if _edit != null:
		_edit.position = PADDING + Vector2(0, HEADER_HEIGHT)
		_edit.size = size - Vector2(PADDING.x * 2, HEADER_HEIGHT + PADDING.y * 2)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _on_edit_begin() -> void:
	_pre_edit = latex
	_edit.text = latex
	_preview.visible = false
	_edit.visible = true
	_edit.grab_focus()
	_edit.select_all()


func _on_edit_end() -> void:
	var new_text: String = _edit.text
	_edit.release_focus()
	_edit.visible = false
	_preview.visible = true
	if new_text != _pre_edit:
		var editor: Node = _find_editor()
		if editor != null:
			History.push(ModifyPropertyCommand.new(editor, item_id, "latex", _pre_edit, new_text))
		else:
			latex = new_text
			_refresh_visuals()
	else:
		_refresh_visuals()


func _commit_text() -> void:
	if is_editing():
		end_edit()


func _gui_input(event: InputEvent) -> void:
	if is_editing():
		return
	super._gui_input(event)


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null


func serialize_payload() -> Dictionary:
	return {"latex": latex, "font_size": font_size}


func deserialize_payload(d: Dictionary) -> void:
	latex = String(d.get("latex", latex))
	font_size = int(d.get("font_size", font_size))
	if _preview != null:
		_refresh_visuals()


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"latex":
			latex = String(value)
			_refresh_visuals()
		"font_size":
			font_size = int(value)
			_refresh_visuals()


static func render_preview(src: String) -> String:
	var s: String = src
	var subs: Dictionary = {
		"\\alpha": "α", "\\beta": "β", "\\gamma": "γ", "\\delta": "δ",
		"\\epsilon": "ε", "\\zeta": "ζ", "\\eta": "η", "\\theta": "θ",
		"\\iota": "ι", "\\kappa": "κ", "\\lambda": "λ", "\\mu": "μ",
		"\\nu": "ν", "\\xi": "ξ", "\\pi": "π", "\\rho": "ρ", "\\sigma": "σ",
		"\\tau": "τ", "\\upsilon": "υ", "\\phi": "φ", "\\chi": "χ",
		"\\psi": "ψ", "\\omega": "ω",
		"\\Alpha": "Α", "\\Beta": "Β", "\\Gamma": "Γ", "\\Delta": "Δ",
		"\\Theta": "Θ", "\\Lambda": "Λ", "\\Pi": "Π", "\\Sigma": "Σ",
		"\\Phi": "Φ", "\\Psi": "Ψ", "\\Omega": "Ω",
		"\\infty": "∞", "\\sum": "∑", "\\prod": "∏", "\\int": "∫",
		"\\partial": "∂", "\\nabla": "∇", "\\sqrt": "√",
		"\\leq": "≤", "\\geq": "≥", "\\neq": "≠", "\\approx": "≈",
		"\\equiv": "≡", "\\pm": "±", "\\mp": "∓", "\\times": "×",
		"\\div": "÷", "\\cdot": "·", "\\rightarrow": "→", "\\leftarrow": "←",
		"\\Rightarrow": "⇒", "\\Leftarrow": "⇐", "\\in": "∈", "\\notin": "∉",
		"\\subset": "⊂", "\\supset": "⊃", "\\cup": "∪", "\\cap": "∩",
	}
	for k in subs.keys():
		s = s.replace(String(k), String(subs[k]))
	s = _replace_super_sub(s, "^", ["⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"])
	s = _replace_super_sub(s, "_", ["₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉"])
	return s


static func _replace_super_sub(s: String, marker: String, table: Array) -> String:
	var out: String = ""
	var i: int = 0
	while i < s.length():
		var ch: String = s.substr(i, 1)
		if ch == marker and i + 1 < s.length():
			var next: String = s.substr(i + 1, 1)
			if next == "{":
				var end: int = s.find("}", i + 2)
				if end >= 0:
					var content: String = s.substr(i + 2, end - i - 2)
					out += _convert_chars(content, table)
					i = end + 1
					continue
			if next.is_valid_int():
				var digit: int = int(next)
				out += String(table[digit])
				i += 2
				continue
		out += ch
		i += 1
	return out


static func _convert_chars(s: String, table: Array) -> String:
	var out: String = ""
	for i in range(s.length()):
		var ch: String = s.substr(i, 1)
		if ch.is_valid_int():
			out += String(table[int(ch)])
		else:
			out += ch
	return out


func build_inspector() -> Control:
	var v: VBoxContainer = VBoxContainer.new()
	var lbl: Label = Label.new(); lbl.text = "LaTeX source"; v.add_child(lbl)
	var ed: TextEdit = TextEdit.new(); ed.text = latex; ed.custom_minimum_size = Vector2(0, 80); v.add_child(ed)
	var editor: Node = _find_editor()
	ed.focus_exited.connect(func() -> void:
		if ed.text == latex: return
		if editor == null:
			latex = ed.text
			_refresh_visuals()
			return
		History.push(ModifyPropertyCommand.new(editor, item_id, "latex", latex, ed.text))
	)
	return v
