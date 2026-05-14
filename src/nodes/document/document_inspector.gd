class_name DocumentInspector
extends VBoxContainer

@onready var _title_edit: LineEdit = %TitleEdit
@onready var _font_size_spin: SpinBox = %FontSizeSpin
@onready var _title_font_size_spin: SpinBox = %TitleFontSizeSpin
@onready var _h1_font_size_spin: SpinBox = %H1FontSizeSpin
@onready var _h2_font_size_spin: SpinBox = %H2FontSizeSpin
@onready var _h3_font_size_spin: SpinBox = %H3FontSizeSpin
@onready var _h4_font_size_spin: SpinBox = %H4FontSizeSpin
@onready var _h5_font_size_spin: SpinBox = %H5FontSizeSpin
@onready var _h6_font_size_spin: SpinBox = %H6FontSizeSpin
@onready var _max_image_width_spin: SpinBox = %MaxImageWidthSpin
@onready var _bg_picker: ColorPickerButton = %BgPicker
@onready var _fg_picker: ColorPickerButton = %FgPicker
@onready var _open_editor_button: Button = %OpenEditorButton
@onready var _word_count_label: Label = %WordCountLabel

const SIZE_KEYS: Array[String] = [
	"font_size",
	"title_font_size",
	"h1_font_size",
	"h2_font_size",
	"h3_font_size",
	"h4_font_size",
	"h5_font_size",
	"h6_font_size",
	"max_image_width",
]

var _item: DocumentNode
var _editor: Node
var _binders: Dictionary = {}
var _suppress_signals: bool = false


func bind(item: DocumentNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	ThemeManager.apply_relative_font_sizes(self, {"Header": 1.15, "HelpLabel": 0.80, "WordCountLabel": 0.80})
	if _item == null:
		return
	_suppress_signals = true
	_title_edit.text = _item.title
	_font_size_spin.value = _item.font_size
	_title_font_size_spin.value = _item.title_font_size
	_h1_font_size_spin.value = _item.h1_font_size
	_h2_font_size_spin.value = _item.h2_font_size
	_h3_font_size_spin.value = _item.h3_font_size
	_h4_font_size_spin.value = _item.h4_font_size
	_h5_font_size_spin.value = _item.h5_font_size
	_h6_font_size_spin.value = _item.h6_font_size
	_max_image_width_spin.value = _item.max_image_width
	_bg_picker.color = _item.resolved_bg_color()
	_fg_picker.color = _item.resolved_fg_color()
	_suppress_signals = false
	_binders["title"] = PropertyBinder.new(_editor, _item, "title", _item.title)
	for size_key: String in SIZE_KEYS:
		_binders[size_key] = PropertyBinder.new(_editor, _item, size_key, int(_item.get(size_key)))
	_binders["bg_color"] = PropertyBinder.new(_editor, _item, "bg_color", ColorUtil.to_array(_item.resolved_bg_color()))
	_binders["fg_color"] = PropertyBinder.new(_editor, _item, "fg_color", ColorUtil.to_array(_item.resolved_fg_color()))
	_install_reset_button(_bg_picker, "bg_color", _item.resolved_bg_color)
	_install_reset_button(_fg_picker, "fg_color", _item.resolved_fg_color)
	_title_edit.text_changed.connect(_on_title_live)
	_title_edit.focus_exited.connect(_on_title_commit)
	_connect_size_spin(_font_size_spin, "font_size")
	_connect_size_spin(_title_font_size_spin, "title_font_size")
	_connect_size_spin(_h1_font_size_spin, "h1_font_size")
	_connect_size_spin(_h2_font_size_spin, "h2_font_size")
	_connect_size_spin(_h3_font_size_spin, "h3_font_size")
	_connect_size_spin(_h4_font_size_spin, "h4_font_size")
	_connect_size_spin(_h5_font_size_spin, "h5_font_size")
	_connect_size_spin(_h6_font_size_spin, "h6_font_size")
	_connect_size_spin(_max_image_width_spin, "max_image_width")
	_bg_picker.color_changed.connect(_on_bg_live)
	_bg_picker.popup_closed.connect(_on_bg_commit)
	_fg_picker.color_changed.connect(_on_fg_live)
	_fg_picker.popup_closed.connect(_on_fg_commit)
	_open_editor_button.pressed.connect(_on_open_editor_pressed)
	ThemeManager.theme_applied.connect(_on_theme_applied)
	ThemeManager.node_palette_changed.connect(func(_a: Dictionary, _b: Dictionary) -> void: _on_theme_applied())
	_refresh_stats()


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null


func _on_title_live(new_text: String) -> void:
	if _suppress_signals:
		return
	_binders["title"].live(new_text)


func _on_title_commit() -> void:
	if _suppress_signals:
		return
	_binders["title"].commit(_title_edit.text)


func _connect_size_spin(spin: SpinBox, key: String) -> void:
	spin.value_changed.connect(func(value: float) -> void:
		if _suppress_signals:
			return
		var v: int = int(value)
		_binders[key].live(v)
		_binders[key].commit(v)
	)


func _on_bg_live(c: Color) -> void:
	if _suppress_signals:
		return
	_binders["bg_color"].live(ColorUtil.to_array(c))


func _on_bg_commit() -> void:
	if _suppress_signals:
		return
	_binders["bg_color"].commit(ColorUtil.to_array(_bg_picker.color))


func _on_fg_live(c: Color) -> void:
	if _suppress_signals:
		return
	_binders["fg_color"].live(ColorUtil.to_array(c))


func _on_fg_commit() -> void:
	if _suppress_signals:
		return
	_binders["fg_color"].commit(ColorUtil.to_array(_fg_picker.color))


func _on_open_editor_pressed() -> void:
	if _item == null:
		return
	_item.begin_edit()


func _install_reset_button(picker: ColorPickerButton, slot: String, resolver: Callable) -> void:
	var row: HBoxContainer = picker.get_parent() as HBoxContainer
	if row == null:
		return
	var btn: Button = Button.new()
	btn.text = "↺"
	btn.tooltip_text = "Reset to theme default"
	btn.custom_minimum_size = Vector2(28, 0)
	row.add_child(btn)
	btn.pressed.connect(func() -> void:
		_binders[slot].live(null)
		_binders[slot].commit(null)
		picker.color = resolver.call()
	)


func _on_theme_applied() -> void:
	if _item == null:
		return
	_suppress_signals = true
	if not _item.bg_color_custom:
		_bg_picker.color = _item.resolved_bg_color()
	if not _item.fg_color_custom:
		_fg_picker.color = _item.resolved_fg_color()
	_suppress_signals = false


func _refresh_stats() -> void:
	if _item == null:
		return
	var raw: String = _item.markdown_text
	var word_count: int = 0
	var current_word_length: int = 0
	for i in range(raw.length()):
		var ch: String = raw[i]
		if ch == " " or ch == "\n" or ch == "\t" or ch == "\r":
			if current_word_length > 0:
				word_count += 1
				current_word_length = 0
		else:
			current_word_length += 1
	if current_word_length > 0:
		word_count += 1
	_word_count_label.text = "%d words • %d characters" % [word_count, raw.length()]
