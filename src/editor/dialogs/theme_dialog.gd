extends Window

var FONT_FILTERS: PackedStringArray = PackedStringArray([
	"*.ttf ; TrueType Font",
	"*.otf ; OpenType Font",
	"*.woff ; Web Open Font Format",
	"*.woff2 ; Web Open Font Format 2",
])

var THEME_FILTERS: PackedStringArray = PackedStringArray([
	"*.tres ; Godot Theme Resource",
])

const IMPORT_STATUS_HINT: String = "Only self-contained .tres themes (PNG/JPEG textures only) are accepted."
const IMPORT_STATUS_OK: String = "Theme imported successfully."

@onready var _mode_dark: CheckBox = %ModeDark
@onready var _mode_light: CheckBox = %ModeLight
@onready var _mode_custom: CheckBox = %ModeCustom
@onready var _mode_imported: CheckBox = %ModeImported
@onready var _imported_section: VBoxContainer = %ImportedSection
@onready var _imported_path_label: Label = %ImportedPathLabel
@onready var _imported_browse_btn: Button = %ImportedBrowseButton
@onready var _imported_clear_btn: Button = %ImportedClearButton
@onready var _imported_status_label: Label = %ImportedStatusLabel
@onready var _accent_picker: ColorPickerButton = %AccentPicker
@onready var _custom_palette_section: VBoxContainer = %CustomPaletteSection
@onready var _app_palette_group: VBoxContainer = %AppPaletteGroup
@onready var _node_palette_group: VBoxContainer = %NodePaletteGroup
@onready var _bg_picker: ColorPickerButton = %BgPicker
@onready var _fg_picker: ColorPickerButton = %FgPicker
@onready var _panel_picker: ColorPickerButton = %PanelPicker
@onready var _subtle_picker: ColorPickerButton = %SubtlePicker
@onready var _node_bg_picker: ColorPickerButton = %NodeBgPicker
@onready var _node_fg_picker: ColorPickerButton = %NodeFgPicker
@onready var _node_heading_bg_picker: ColorPickerButton = %NodeHeadingBgPicker
@onready var _node_heading_fg_picker: ColorPickerButton = %NodeHeadingFgPicker
@onready var _per_type_headings_button: Button = %PerTypeHeadingsButton
@onready var _font_preset_option: OptionButton = %FontPresetOption
@onready var _board_image_path_label: Label = %BoardImagePathLabel
@onready var _board_image_browse: Button = %BoardImageBrowse
@onready var _board_image_clear: Button = %BoardImageClear
@onready var _board_image_mode: OptionButton = %BoardImageMode
@onready var _board_bg_color_picker: ColorPickerButton = %BoardBgColorPicker
@onready var _board_bg_color_clear: Button = %BoardBgColorClear
@onready var _custom_font_path: LineEdit = %CustomFontPath
@onready var _browse_font_btn: Button = %BrowseFontButton
@onready var _clear_font_btn: Button = %ClearFontButton
@onready var _bold_font_path: LineEdit = %BoldFontPath
@onready var _browse_bold_btn: Button = %BrowseBoldFontButton
@onready var _clear_bold_btn: Button = %ClearBoldFontButton
@onready var _italic_font_path: LineEdit = %ItalicFontPath
@onready var _browse_italic_btn: Button = %BrowseItalicFontButton
@onready var _clear_italic_btn: Button = %ClearItalicFontButton
@onready var _bold_italic_font_path: LineEdit = %BoldItalicFontPath
@onready var _browse_bold_italic_btn: Button = %BrowseBoldItalicFontButton
@onready var _clear_bold_italic_btn: Button = %ClearBoldItalicFontButton
@onready var _mono_font_path: LineEdit = %MonoFontPath
@onready var _browse_mono_btn: Button = %BrowseMonoFontButton
@onready var _clear_mono_btn: Button = %ClearMonoFontButton
@onready var _font_size_spin: SpinBox = %FontSizeSpin
@onready var _ui_zoom_spin: SpinBox = %UiZoomSpin
@onready var _ui_zoom_reset_btn: Button = %UiZoomResetButton
@onready var _close_btn: Button = %CloseButton
@onready var _reset_btn: Button = %ResetButton

var _file_dialog: FileDialog = null
var _file_dialog_variant: String = FontPreset.VARIANT_REGULAR
var _image_file_dialog: FileDialog = null
var _theme_file_dialog: FileDialog = null
var _board: Board = null


func bind(board: Board) -> void:
	_board = board


func _ready() -> void:
	close_requested.connect(queue_free)
	_close_btn.pressed.connect(queue_free)
	_reset_btn.pressed.connect(_on_reset)

	_accent_picker.color = UserPrefs.theme_accent
	_accent_picker.color_changed.connect(_on_accent_changed)

	_mode_dark.button_pressed = UserPrefs.theme_mode == UserPrefs.THEME_DARK
	_mode_light.button_pressed = UserPrefs.theme_mode == UserPrefs.THEME_LIGHT
	_mode_custom.button_pressed = UserPrefs.theme_mode == UserPrefs.THEME_CUSTOM
	_mode_imported.button_pressed = UserPrefs.theme_mode == UserPrefs.THEME_IMPORTED
	_mode_dark.toggled.connect(_on_mode_dark_toggled)
	_mode_light.toggled.connect(_on_mode_light_toggled)
	_mode_custom.toggled.connect(_on_mode_custom_toggled)
	_mode_imported.toggled.connect(_on_mode_imported_toggled)
	_imported_browse_btn.pressed.connect(_on_imported_browse)
	_imported_clear_btn.pressed.connect(_on_imported_clear)
	_refresh_imported_path_label()
	_imported_status_label.text = IMPORT_STATUS_HINT

	_bg_picker.color = UserPrefs.custom_bg
	_fg_picker.color = UserPrefs.custom_fg
	_panel_picker.color = UserPrefs.custom_panel
	_subtle_picker.color = UserPrefs.custom_subtle
	_bg_picker.color_changed.connect(UserPrefs.set_custom_bg)
	_fg_picker.color_changed.connect(UserPrefs.set_custom_fg)
	_panel_picker.color_changed.connect(UserPrefs.set_custom_panel)
	_subtle_picker.color_changed.connect(UserPrefs.set_custom_subtle)
	_node_bg_picker.color = UserPrefs.custom_node_bg
	_node_fg_picker.color = UserPrefs.custom_node_fg
	_node_heading_bg_picker.color = UserPrefs.custom_node_heading_bg
	_node_heading_fg_picker.color = UserPrefs.custom_node_heading_fg
	_node_bg_picker.color_changed.connect(UserPrefs.set_custom_node_bg)
	_node_fg_picker.color_changed.connect(UserPrefs.set_custom_node_fg)
	_node_heading_bg_picker.color_changed.connect(UserPrefs.set_custom_node_heading_bg)
	_node_heading_fg_picker.color_changed.connect(UserPrefs.set_custom_node_heading_fg)
	_per_type_headings_button.pressed.connect(_open_per_type_headings_dialog)

	_populate_font_presets()
	_font_preset_option.item_selected.connect(_on_font_preset_selected)

	_custom_font_path.text = UserPrefs.custom_font_path
	_browse_font_btn.pressed.connect(_on_browse_regular_font)
	_clear_font_btn.pressed.connect(_on_clear_regular_font)

	_bold_font_path.text = UserPrefs.custom_font_bold_path
	_browse_bold_btn.pressed.connect(_on_browse_bold_font)
	_clear_bold_btn.pressed.connect(_on_clear_bold_font)

	_italic_font_path.text = UserPrefs.custom_font_italic_path
	_browse_italic_btn.pressed.connect(_on_browse_italic_font)
	_clear_italic_btn.pressed.connect(_on_clear_italic_font)

	_bold_italic_font_path.text = UserPrefs.custom_font_bold_italic_path
	_browse_bold_italic_btn.pressed.connect(_on_browse_bold_italic_font)
	_clear_bold_italic_btn.pressed.connect(_on_clear_bold_italic_font)

	_mono_font_path.text = UserPrefs.custom_font_mono_path
	_browse_mono_btn.pressed.connect(_on_browse_mono_font)
	_clear_mono_btn.pressed.connect(_on_clear_mono_font)

	_font_size_spin.value = float(UserPrefs.font_size)
	_font_size_spin.value_changed.connect(_on_font_size_changed)

	_ui_zoom_spin.min_value = UserPrefs.UI_ZOOM_MIN
	_ui_zoom_spin.max_value = UserPrefs.UI_ZOOM_MAX
	_ui_zoom_spin.value = UserPrefs.ui_zoom
	_ui_zoom_spin.value_changed.connect(_on_ui_zoom_changed)
	_ui_zoom_reset_btn.pressed.connect(_on_ui_zoom_reset)

	_board_image_mode.add_item("Tile", 0)
	_board_image_mode.add_item("Stretch", 1)
	_board_image_mode.add_item("Center", 2)
	if _board != null:
		_board_image_mode.select(_board.background_image_mode)
	_board_image_mode.item_selected.connect(_on_board_image_mode_changed)
	_board_image_browse.pressed.connect(_on_board_image_browse)
	_board_image_clear.pressed.connect(_on_board_image_clear)
	_refresh_board_image_label()
	_refresh_board_bg_color_picker()
	_board_bg_color_picker.color_changed.connect(_on_board_bg_color_changed)
	_board_bg_color_clear.pressed.connect(_on_board_bg_color_clear)
	_update_custom_section_visibility()


func _open_per_type_headings_dialog() -> void:
	var scene: PackedScene = preload("res://src/editor/dialogs/custom_node_headings_dialog.tscn")
	var dlg: Window = scene.instantiate()
	add_child(dlg)
	dlg.popup_centered()


func _refresh_board_image_label() -> void:
	if _board == null or _board.background_image_asset == "":
		_board_image_path_label.text = "(no image)"
	else:
		_board_image_path_label.text = _board.background_image_asset


func _on_board_image_browse() -> void:
	if _image_file_dialog != null and is_instance_valid(_image_file_dialog):
		_image_file_dialog.queue_free()
	_image_file_dialog = FileDialog.new()
	_image_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_image_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_image_file_dialog.filters = PackedStringArray([
		"*.png ; PNG",
		"*.jpg, *.jpeg ; JPEG",
		"*.webp ; WebP",
	])
	_image_file_dialog.title = "Choose background image"
	_image_file_dialog.size = Vector2i(720, 480)
	_image_file_dialog.file_selected.connect(_on_board_image_picked)
	_image_file_dialog.close_requested.connect(_image_file_dialog.queue_free)
	_image_file_dialog.canceled.connect(_image_file_dialog.queue_free)
	add_child(_image_file_dialog)
	_image_file_dialog.popup_centered_ratio(0.7)


func _on_board_image_picked(path: String) -> void:
	if _board == null or AppState.current_project == null:
		return
	var asset_name: String = AppState.current_project.copy_asset_into_project(path)
	if asset_name == "":
		return
	_board.background_image_asset = asset_name
	_persist_board()
	_refresh_board_image_label()
	if _image_file_dialog != null:
		_image_file_dialog.queue_free()


func _on_board_image_clear() -> void:
	if _board == null:
		return
	_board.background_image_asset = ""
	_persist_board()
	_refresh_board_image_label()


func _on_board_image_mode_changed(idx: int) -> void:
	if _board == null:
		return
	_board.background_image_mode = idx
	_persist_board()


func _refresh_board_bg_color_picker() -> void:
	if _board != null and _board.has_background_color_override():
		_board_bg_color_picker.color = _board.background_color_override
	else:
		_board_bg_color_picker.color = ThemeManager.background_color()


func _on_board_bg_color_changed(c: Color) -> void:
	if _board == null:
		return
	_board.background_color_override = Color(c.r, c.g, c.b, 1.0)
	_persist_board()


func _on_board_bg_color_clear() -> void:
	if _board == null:
		return
	_board.background_color_override = Color(0.0, 0.0, 0.0, 0.0)
	_persist_board()
	_refresh_board_bg_color_picker()


func _persist_board() -> void:
	if _board == null or AppState.current_project == null:
		return
	AppState.current_project.write_board(_board)
	if AppState.current_board != null and AppState.current_board.id == _board.id:
		AppState.emit_signal("current_board_changed", _board)


func _populate_font_presets() -> void:
	_font_preset_option.clear()
	var manifest: FontManifest = ThemeManager.font_manifest()
	if manifest == null:
		return
	var presets: Array[FontPreset] = manifest.font_presets()
	var selected_index: int = 0
	for i: int in range(presets.size()):
		var preset: FontPreset = presets[i]
		var label: String = preset.display_name if preset.display_name != "" else preset.id
		_font_preset_option.add_item(label, i)
		_font_preset_option.set_item_metadata(i, preset.id)
		if preset.id == UserPrefs.font_preset_id:
			selected_index = i
	if _font_preset_option.item_count > 0:
		_font_preset_option.select(selected_index)


func _on_mode_dark_toggled(pressed: bool) -> void:
	if pressed:
		UserPrefs.set_theme_mode(UserPrefs.THEME_DARK)
	_update_custom_section_visibility()


func _on_mode_light_toggled(pressed: bool) -> void:
	if pressed:
		UserPrefs.set_theme_mode(UserPrefs.THEME_LIGHT)
	_update_custom_section_visibility()


func _on_mode_custom_toggled(pressed: bool) -> void:
	if pressed:
		UserPrefs.set_theme_mode(UserPrefs.THEME_CUSTOM)
	_update_custom_section_visibility()


func _on_mode_imported_toggled(pressed: bool) -> void:
	if pressed:
		if UserPrefs.imported_theme_path == "" or not FileAccess.file_exists(UserPrefs.imported_theme_path):
			_imported_status_label.text = "Import a .tres theme to activate this mode."
		else:
			UserPrefs.set_theme_mode(UserPrefs.THEME_IMPORTED)
	_update_custom_section_visibility()


func _update_custom_section_visibility() -> void:
	var is_custom: bool = UserPrefs.theme_mode == UserPrefs.THEME_CUSTOM
	var is_imported: bool = _mode_imported != null and _mode_imported.button_pressed
	var show_app_palette: bool = is_custom
	var show_node_palette: bool = is_custom or is_imported
	if _app_palette_group != null:
		_app_palette_group.visible = show_app_palette
	if _node_palette_group != null:
		_node_palette_group.visible = show_node_palette
	if _custom_palette_section != null:
		_custom_palette_section.visible = show_app_palette or show_node_palette
	if _imported_section != null:
		_imported_section.visible = is_imported
	if show_app_palette or show_node_palette:
		self.size.x = 750
	else:
		self.size.x = 425


func _on_imported_browse() -> void:
	if _theme_file_dialog != null and is_instance_valid(_theme_file_dialog):
		_theme_file_dialog.queue_free()
	_theme_file_dialog = FileDialog.new()
	_theme_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_theme_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_theme_file_dialog.filters = THEME_FILTERS
	_theme_file_dialog.title = "Import Godot theme (.tres)"
	_theme_file_dialog.size = Vector2i(720, 480)
	_theme_file_dialog.file_selected.connect(_on_theme_file_selected)
	_theme_file_dialog.close_requested.connect(_theme_file_dialog.queue_free)
	_theme_file_dialog.canceled.connect(_theme_file_dialog.queue_free)
	add_child(_theme_file_dialog)
	_theme_file_dialog.popup_centered()


func _on_theme_file_selected(path: String) -> void:
	var result: Dictionary = ThemeManager.import_theme_file(path)
	if bool(result.get("ok", false)):
		_imported_status_label.text = IMPORT_STATUS_OK
		_mode_imported.button_pressed = true
	else:
		_imported_status_label.text = "Import failed: %s" % String(result.get("error", "Unknown error."))
	_refresh_imported_path_label()
	_update_custom_section_visibility()
	if _theme_file_dialog != null:
		_theme_file_dialog.queue_free()


func _on_imported_clear() -> void:
	ThemeManager.clear_imported_theme()
	_imported_status_label.text = IMPORT_STATUS_HINT
	_refresh_imported_path_label()
	_mode_dark.button_pressed = UserPrefs.theme_mode == UserPrefs.THEME_DARK
	_mode_light.button_pressed = UserPrefs.theme_mode == UserPrefs.THEME_LIGHT
	_mode_custom.button_pressed = UserPrefs.theme_mode == UserPrefs.THEME_CUSTOM
	_mode_imported.button_pressed = UserPrefs.theme_mode == UserPrefs.THEME_IMPORTED
	_update_custom_section_visibility()


func _refresh_imported_path_label() -> void:
	if UserPrefs.imported_theme_label != "":
		_imported_path_label.text = UserPrefs.imported_theme_label
	elif UserPrefs.imported_theme_path != "":
		_imported_path_label.text = UserPrefs.imported_theme_path.get_file()
	else:
		_imported_path_label.text = "(no theme imported)"


func _on_accent_changed(c: Color) -> void:
	UserPrefs.set_theme_accent(c)


func _on_font_preset_selected(index: int) -> void:
	var meta: Variant = _font_preset_option.get_item_metadata(index)
	var preset_id: String = String(meta) if meta != null else ""
	UserPrefs.set_font_preset_id(preset_id)


func _on_font_size_changed(value: float) -> void:
	UserPrefs.set_font_size(int(value))


func _on_ui_zoom_changed(value: float) -> void:
	UserPrefs.set_ui_zoom(value)


func _on_ui_zoom_reset() -> void:
	UserPrefs.set_ui_zoom(UserPrefs.UI_ZOOM_DEFAULT)
	if _ui_zoom_spin != null:
		_ui_zoom_spin.set_value_no_signal(UserPrefs.ui_zoom)


func _on_browse_regular_font() -> void:
	_open_font_picker(FontPreset.VARIANT_REGULAR)


func _on_browse_bold_font() -> void:
	_open_font_picker(FontPreset.VARIANT_BOLD)


func _on_browse_italic_font() -> void:
	_open_font_picker(FontPreset.VARIANT_ITALIC)


func _on_browse_bold_italic_font() -> void:
	_open_font_picker(FontPreset.VARIANT_BOLD_ITALIC)


func _on_browse_mono_font() -> void:
	_open_font_picker(FontPreset.VARIANT_MONO)


func _on_clear_regular_font() -> void:
	_clear_variant(FontPreset.VARIANT_REGULAR)


func _on_clear_bold_font() -> void:
	_clear_variant(FontPreset.VARIANT_BOLD)


func _on_clear_italic_font() -> void:
	_clear_variant(FontPreset.VARIANT_ITALIC)


func _on_clear_bold_italic_font() -> void:
	_clear_variant(FontPreset.VARIANT_BOLD_ITALIC)


func _on_clear_mono_font() -> void:
	_clear_variant(FontPreset.VARIANT_MONO)


func _open_font_picker(variant: String) -> void:
	_file_dialog_variant = variant
	if _file_dialog != null and is_instance_valid(_file_dialog):
		_file_dialog.queue_free()
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = FONT_FILTERS
	_file_dialog.title = "Select %s font file" % _variant_label(variant)
	_file_dialog.size = Vector2i(720, 480)
	_file_dialog.file_selected.connect(_on_font_file_selected)
	_file_dialog.close_requested.connect(_file_dialog.queue_free)
	_file_dialog.canceled.connect(_file_dialog.queue_free)
	add_child(_file_dialog)
	_file_dialog.popup_centered()


func _on_font_file_selected(path: String) -> void:
	var installed: String = ThemeManager.install_custom_font(path)
	if installed == "":
		return
	UserPrefs.set_custom_font_path_for_variant(_file_dialog_variant, installed)
	_set_variant_path_text(_file_dialog_variant, installed)


func _clear_variant(variant: String) -> void:
	UserPrefs.set_custom_font_path_for_variant(variant, "")
	_set_variant_path_text(variant, "")
	ThemeManager.clear_custom_font_cache()


func _set_variant_path_text(variant: String, value: String) -> void:
	match variant:
		FontPreset.VARIANT_BOLD:
			_bold_font_path.text = value
		FontPreset.VARIANT_ITALIC:
			_italic_font_path.text = value
		FontPreset.VARIANT_BOLD_ITALIC:
			_bold_italic_font_path.text = value
		FontPreset.VARIANT_MONO:
			_mono_font_path.text = value
		_:
			_custom_font_path.text = value


func _variant_label(variant: String) -> String:
	match variant:
		FontPreset.VARIANT_BOLD:
			return "bold"
		FontPreset.VARIANT_ITALIC:
			return "italic"
		FontPreset.VARIANT_BOLD_ITALIC:
			return "bold italic"
		FontPreset.VARIANT_MONO:
			return "monospace"
		_:
			return "regular"


func _on_reset() -> void:
	UserPrefs.set_theme_mode(UserPrefs.THEME_DARK)
	UserPrefs.set_theme_accent(Color(0.35, 0.7, 1.0))
	UserPrefs.set_custom_bg(Color(0.10, 0.11, 0.13))
	UserPrefs.set_custom_fg(Color(0.92, 0.94, 0.97))
	UserPrefs.set_custom_panel(Color(0.16, 0.17, 0.20))
	UserPrefs.set_custom_subtle(Color(0.28, 0.30, 0.34))
	UserPrefs.set_custom_node_bg(Color(0.16, 0.17, 0.20, 1.0))
	UserPrefs.set_custom_node_fg(Color(0.95, 0.96, 0.98, 1.0))
	UserPrefs.set_custom_node_heading_bg(Color(0.32, 0.18, 0.42, 1.0))
	UserPrefs.set_custom_node_heading_fg(Color(0.97, 0.97, 0.99, 1.0))
	UserPrefs.clear_custom_node_headings()
	UserPrefs.set_font_preset_id("default")
	UserPrefs.set_custom_font_path("")
	UserPrefs.set_custom_font_bold_path("")
	UserPrefs.set_custom_font_italic_path("")
	UserPrefs.set_custom_font_bold_italic_path("")
	UserPrefs.set_custom_font_mono_path("")
	UserPrefs.set_font_size(14)
	UserPrefs.set_ui_zoom(UserPrefs.UI_ZOOM_DEFAULT)
	if _ui_zoom_spin != null:
		_ui_zoom_spin.set_value_no_signal(UserPrefs.ui_zoom)
	_accent_picker.color = UserPrefs.theme_accent
	_bg_picker.color = UserPrefs.custom_bg
	_fg_picker.color = UserPrefs.custom_fg
	_panel_picker.color = UserPrefs.custom_panel
	_subtle_picker.color = UserPrefs.custom_subtle
	_node_bg_picker.color = UserPrefs.custom_node_bg
	_node_fg_picker.color = UserPrefs.custom_node_fg
	_node_heading_bg_picker.color = UserPrefs.custom_node_heading_bg
	_node_heading_fg_picker.color = UserPrefs.custom_node_heading_fg
	_mode_dark.button_pressed = true
	_custom_font_path.text = ""
	_bold_font_path.text = ""
	_italic_font_path.text = ""
	_bold_italic_font_path.text = ""
	_mono_font_path.text = ""
	_font_size_spin.value = float(UserPrefs.font_size)
	_populate_font_presets()
	_mode_imported.button_pressed = false
	_imported_status_label.text = IMPORT_STATUS_HINT
	_refresh_imported_path_label()
	_update_custom_section_visibility()
