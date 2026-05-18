class_name BlockStackInspector
extends VBoxContainer

@onready var _title_edit: LineEdit = %TitleEdit
@onready var _bg_picker: ColorPickerButton = %BgPicker
@onready var _accent_picker: ColorPickerButton = %AccentPicker
@onready var _header_fg_picker: ColorPickerButton = %HeaderFgPicker
@onready var _count_label: Label = %CountLabel
@onready var _multiline_check: CheckBox = %MultilineCheck
@onready var _plain_text_edit_button: Button = %PlainTextEditButton

var _item: BlockStackNode
var _editor: Node
var _binders: Dictionary = {}
var _suppress_signals: bool = false


func bind(item: BlockStackNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	ThemeManager.apply_relative_font_sizes(self, {"Header": 1.15, "Hint": 0.80})
	if _item == null:
		return
	_suppress_signals = true
	_title_edit.text = _item.title
	_bg_picker.color = _item.resolved_bg_color()
	_accent_picker.color = _item.resolved_accent_color()
	_header_fg_picker.color = _item.resolved_header_fg_color()
	_count_label.text = "%d block%s" % [_item.blocks.size(), "" if _item.blocks.size() == 1 else "s"]
	_multiline_check.button_pressed = _item.multiline_text
	_suppress_signals = false
	_binders["title"] = PropertyBinder.new(_editor, _item, "title", _item.title)
	_binders["multiline_text"] = PropertyBinder.new(_editor, _item, "multiline_text", _item.multiline_text)
	_multiline_check.toggled.connect(func(p: bool) -> void:
		if _suppress_signals: return
		_binders["multiline_text"].live(p)
		_binders["multiline_text"].commit(p)
	)
	_binders["bg_color"] = PropertyBinder.new(_editor, _item, "bg_color", ColorUtil.to_array(_item.resolved_bg_color()))
	_binders["accent_color"] = PropertyBinder.new(_editor, _item, "accent_color", ColorUtil.to_array(_item.resolved_accent_color()))
	_binders["header_fg_color"] = PropertyBinder.new(_editor, _item, "header_fg_color", ColorUtil.to_array(_item.resolved_header_fg_color()))
	_title_edit.text_changed.connect(func(t: String) -> void: _binders["title"].live(t))
	_title_edit.focus_exited.connect(func() -> void: _binders["title"].commit(_title_edit.text))
	_title_edit.text_submitted.connect(func(t: String) -> void: _binders["title"].commit(t))
	_install_color_picker(_bg_picker, "bg_color", _item.resolved_bg_color)
	_install_color_picker(_accent_picker, "accent_color", _item.resolved_accent_color)
	_install_color_picker(_header_fg_picker, "header_fg_color", _item.resolved_header_fg_color)
	_plain_text_edit_button.pressed.connect(_on_plain_text_edit_pressed)
	ThemeManager.theme_applied.connect(_on_theme_applied)
	ThemeManager.node_palette_changed.connect(func(_a: Dictionary, _b: Dictionary) -> void: _on_theme_applied())


func _install_color_picker(picker: ColorPickerButton, slot: String, resolver: Callable) -> void:
	picker.color_changed.connect(func(c: Color) -> void:
		if _suppress_signals: return
		_binders[slot].live(ColorUtil.to_array(c))
	)
	picker.popup_closed.connect(func() -> void:
		if _suppress_signals: return
		_binders[slot].commit(ColorUtil.to_array(picker.color))
	)
	var row: HBoxContainer = picker.get_parent() as HBoxContainer
	if row != null:
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
	if not _item.accent_color_custom:
		_accent_picker.color = _item.resolved_accent_color()
	if not _item.header_fg_color_custom:
		_header_fg_picker.color = _item.resolved_header_fg_color()
	_suppress_signals = false


func _find_editor() -> Node:
	return EditorLocator.find_for(_item)


func _on_plain_text_edit_pressed() -> void:
	if _item == null:
		return
	var dlg_scene: PackedScene = preload("res://src/editor/dialogs/plain_text_outline_dialog.tscn")
	var dlg: PlainTextOutlineDialog = dlg_scene.instantiate()
	var initial: String = PlainTextOutline.encode_blocks(_item.blocks)
	var hint: String = "One entry per line. '-' is top level, '--' is indent 1, up to '-------' for indent 6."
	dlg.bind("Edit %s as plain text" % _item.title, initial, hint)
	get_tree().root.add_child(dlg)
	dlg.applied.connect(_on_plain_text_applied)
	PopupSizer.popup_fit(dlg, {"preferred": Vector2i(560, 520)})


func _on_plain_text_applied(text: String) -> void:
	if _item == null:
		return
	var before: Array = _item.blocks.duplicate(true)
	var parsed: Array = PlainTextOutline.decode_blocks(text, before)
	if JSON.stringify(parsed) == JSON.stringify(_item.blocks):
		return
	var binder: PropertyBinder = PropertyBinder.new(_editor, _item, "blocks", before)
	binder.live(parsed)
	binder.commit(parsed)
	_count_label.text = "%d block%s" % [parsed.size(), "" if parsed.size() == 1 else "s"]
