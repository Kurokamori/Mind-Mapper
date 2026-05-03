extends Window

@onready var _grid: GridContainer = %Grid
@onready var _dark_button: Button = %DarkButton
@onready var _light_button: Button = %LightButton
@onready var _clear_button: Button = %ClearButton
@onready var _close_button: Button = %CloseButton

var _bg_pickers: Dictionary = {}
var _fg_pickers: Dictionary = {}
var _suppress_signals: bool = false


func _ready() -> void:
	close_requested.connect(queue_free)
	_close_button.pressed.connect(queue_free)
	_dark_button.pressed.connect(_apply_dark_preset)
	_light_button.pressed.connect(_apply_light_preset)
	_clear_button.pressed.connect(_clear_overrides)
	_build_rows()
	UserPrefs.theme_changed.connect(_refresh_pickers)


func _build_rows() -> void:
	_clear_grid()
	_add_header_row()
	for type_id: String in ThemeManager.node_type_ids():
		_add_type_row(type_id)


func _clear_grid() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()
	_bg_pickers.clear()
	_fg_pickers.clear()


func _add_header_row() -> void:
	for label_text: String in ["Node type", "Heading bg", "Heading text", "Reset"]:
		var l: Label = Label.new()
		l.text = label_text
		l.add_theme_font_size_override("font_size", 12)
		_grid.add_child(l)


func _add_type_row(type_id: String) -> void:
	var name_label: Label = Label.new()
	name_label.text = ThemeManager.node_type_label(type_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(name_label)

	var bg_picker: ColorPickerButton = ColorPickerButton.new()
	bg_picker.custom_minimum_size = Vector2(110, 28)
	_grid.add_child(bg_picker)
	_bg_pickers[type_id] = bg_picker
	bg_picker.color_changed.connect(func(c: Color) -> void:
		if _suppress_signals: return
		UserPrefs.set_custom_node_heading(type_id + "_bg", c)
	)

	var fg_picker: ColorPickerButton = ColorPickerButton.new()
	fg_picker.custom_minimum_size = Vector2(110, 28)
	_grid.add_child(fg_picker)
	_fg_pickers[type_id] = fg_picker
	fg_picker.color_changed.connect(func(c: Color) -> void:
		if _suppress_signals: return
		UserPrefs.set_custom_node_heading(type_id + "_fg", c)
	)

	var reset_btn: Button = Button.new()
	reset_btn.text = "↺"
	reset_btn.tooltip_text = "Clear overrides for this type"
	reset_btn.custom_minimum_size = Vector2(32, 28)
	_grid.add_child(reset_btn)
	reset_btn.pressed.connect(func() -> void:
		UserPrefs.set_custom_node_heading(type_id + "_bg", null)
		UserPrefs.set_custom_node_heading(type_id + "_fg", null)
		_refresh_pickers()
	)

	_apply_pickers_for_type(type_id, bg_picker, fg_picker)


func _apply_pickers_for_type(type_id: String, bg_picker: ColorPickerButton, fg_picker: ColorPickerButton) -> void:
	var bg_key: String = type_id + "_bg"
	var fg_key: String = type_id + "_fg"
	var bg_value: Color
	var fg_value: Color
	if UserPrefs.custom_node_headings.has(bg_key):
		bg_value = UserPrefs.custom_node_headings[bg_key]
	else:
		bg_value = ThemeManager.default_heading_bg(type_id, UserPrefs.THEME_DARK)
	if UserPrefs.custom_node_headings.has(fg_key):
		fg_value = UserPrefs.custom_node_headings[fg_key]
	else:
		fg_value = ThemeManager.default_heading_fg(type_id, UserPrefs.THEME_DARK)
	bg_picker.color = bg_value
	fg_picker.color = fg_value


func _refresh_pickers() -> void:
	_suppress_signals = true
	for type_id: String in ThemeManager.node_type_ids():
		var bg_picker: ColorPickerButton = _bg_pickers.get(type_id, null)
		var fg_picker: ColorPickerButton = _fg_pickers.get(type_id, null)
		if bg_picker != null and fg_picker != null:
			_apply_pickers_for_type(type_id, bg_picker, fg_picker)
	_suppress_signals = false


func _apply_dark_preset() -> void:
	_apply_preset(UserPrefs.THEME_DARK)


func _apply_light_preset() -> void:
	_apply_preset(UserPrefs.THEME_LIGHT)


func _apply_preset(mode: String) -> void:
	var presets: Dictionary = {}
	for type_id: String in ThemeManager.node_type_ids():
		presets[type_id + "_bg"] = ThemeManager.default_heading_bg(type_id, mode)
		presets[type_id + "_fg"] = ThemeManager.default_heading_fg(type_id, mode)
	UserPrefs.apply_node_heading_preset(presets)
	_refresh_pickers()


func _clear_overrides() -> void:
	UserPrefs.clear_custom_node_headings()
	_refresh_pickers()
