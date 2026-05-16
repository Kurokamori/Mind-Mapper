extends Node

const FONT_MANIFEST_PATH: String = "res://assets/fonts/font_manifest.tres"
const CUSTOM_FONT_PRESET_ID: String = "__custom__"
const RICH_TEXT_VARIANT_SLOTS: Dictionary = {
	FontPreset.VARIANT_REGULAR: "normal_font",
	FontPreset.VARIANT_BOLD: "bold_font",
	FontPreset.VARIANT_ITALIC: "italics_font",
	FontPreset.VARIANT_BOLD_ITALIC: "bold_italics_font",
	FontPreset.VARIANT_MONO: "mono_font",
}
const DARK_THEME: Theme = preload("res://assets/ui/resources/dark_theme.tres")
const LIGHT_THEME: Theme = preload("res://assets/ui/resources/light_theme.tres")
const ROUNDED_COLOR_PICKER_SHADER: Shader = preload("res://src/util/rounded_color_picker.gdshader")
const ROUNDED_COLOR_PICKER_RADIUS: float = 6.0
const ROUNDED_COLOR_PICKER_APPLIED_META: String = "_rounded_color_picker_applied"
const PANEL_ALPHA: float = 0.75
const RELATIVE_FONT_SCALE_META: String = "_relative_font_scale"

const DARK_BG: Color = Color(0.085, 0.08, 0.105, 1.0)
const DARK_PANEL: Color = Color(0.11, 0.105, 0.135, 1.0)
const DARK_PANEL_INSET: Color = Color(0.135, 0.13, 0.165, 1.0)
const DARK_PANEL_TINT: Color = Color(0.115, 0.11, 0.14, 1.0)
const DARK_BTN: Color = Color(0.16, 0.155, 0.195, 1.0)
const DARK_BTN_HOVER: Color = Color(0.205, 0.195, 0.255, 1.0)
const DARK_BTN_PRESSED: Color = Color(0.235, 0.215, 0.29, 1.0)
const DARK_BTN_DISABLED: Color = Color(0.13, 0.125, 0.155, 1.0)
const DARK_INPUT: Color = Color(0.10, 0.095, 0.125, 1.0)
const DARK_INPUT_FOCUS: Color = Color(0.115, 0.105, 0.14, 1.0)
const DARK_INPUT_READONLY: Color = Color(0.085, 0.08, 0.10, 1.0)
const DARK_TAB_UNSEL: Color = Color(0.105, 0.10, 0.13, 1.0)
const DARK_TAB_DISABLED: Color = Color(0.10, 0.095, 0.12, 1.0)
const DARK_ITEM_HOVER: Color = Color(0.18, 0.17, 0.22, 1.0)
const DARK_ITEM_SELECTED_FOCUS: Color = Color(0.275, 0.25, 0.34, 1.0)
const DARK_GRAPH_PANEL_SEL: Color = Color(0.155, 0.15, 0.19, 1.0)
const DARK_GRAPH_TITLE: Color = Color(0.19, 0.175, 0.235, 1.0)
const DARK_GRAPH_TITLE_SEL: Color = Color(0.245, 0.22, 0.30, 1.0)
const DARK_GRAPHEDIT_BG: Color = Color(0.075, 0.07, 0.09, 1.0)
const DARK_SUBTLE: Color = Color(0.245, 0.235, 0.295, 1.0)
const DARK_SUBTLE_2: Color = Color(0.255, 0.245, 0.305, 1.0)
const DARK_SUBTLE_3: Color = Color(0.21, 0.20, 0.255, 1.0)
const DARK_BORDER_BRIGHT: Color = Color(0.27, 0.26, 0.32, 1.0)
const DARK_BORDER_INSET: Color = Color(0.20, 0.195, 0.235, 1.0)
const DARK_BORDER_HOVER: Color = Color(0.345, 0.31, 0.41, 1.0)
const DARK_FG: Color = Color(0.84, 0.82, 0.88, 1.0)
const DARK_FG_BRIGHT: Color = Color(0.86, 0.84, 0.90, 1.0)
const DARK_FG_HOVER: Color = Color(0.92, 0.90, 0.96, 1.0)
const DARK_FG_PRESSED: Color = Color(0.95, 0.93, 0.98, 1.0)
const DARK_FG_DIM: Color = Color(0.62, 0.60, 0.68, 1.0)
const DARK_FG_DIMMER: Color = Color(0.50, 0.48, 0.55, 1.0)
const DARK_FG_DISABLED: Color = Color(0.46, 0.44, 0.51, 1.0)
const DARK_ACCENT: Color = Color(0.50, 0.44, 0.61, 1.0)
const DARK_ACCENT_BRIGHT: Color = Color(0.55, 0.49, 0.65, 1.0)
const DARK_ACCENT_DIM: Color = Color(0.40, 0.36, 0.49, 1.0)
const LIGHT_ACCENT: Color = Color(0.55, 0.36, 0.18, 1.0)
const DARK_ICON: Color = Color(0.677, 0.672, 0.822, 1.0)
const LIGHT_ICON: Color = Color(0.332, 0.219, 0.146, 1.0)

signal theme_applied()
signal font_manifest_changed()
signal node_palette_changed(old_palette: Dictionary, new_palette: Dictionary)

var COLOR_PICKER_BUTTON_STATES: PackedStringArray = PackedStringArray(["normal", "hover", "pressed", "disabled", "focus"])

static var NODE_DARK: Dictionary = {
	"node_bg": Color(0.16, 0.17, 0.20, 1.0),
	"node_fg": Color(0.95, 0.96, 0.98, 1.0),
	"node_heading_bg": Color(0.32, 0.18, 0.42, 1.0),
	"node_heading_fg": Color(0.97, 0.97, 0.99, 1.0),
}
static var NODE_LIGHT: Dictionary = {
	"node_bg": Color(0.92, 0.94, 0.97, 1.0),
	"node_fg": Color(0.10, 0.11, 0.13, 1.0),
	"node_heading_bg": Color(0.78, 0.65, 0.92, 1.0),
	"node_heading_fg": Color(0.10, 0.11, 0.13, 1.0),
}

static var NODE_TYPE_HEADINGS: Dictionary = {
	"group": {
		"label": "Group",
		"dark_bg": Color(0.32, 0.18, 0.42, 1.0),
		"light_bg": Color(0.78, 0.65, 0.92, 1.0),
		"dark_fg": Color(0.97, 0.97, 0.99, 1.0),
		"light_fg": Color(0.10, 0.11, 0.13, 1.0),
	},
	"todo": {
		"label": "Todo List",
		"dark_bg": Color(0.22, 0.34, 0.50, 1.0),
		"light_bg": Color(0.55, 0.72, 0.92, 1.0),
		"dark_fg": Color(0.95, 0.97, 1.0, 1.0),
		"light_fg": Color(0.06, 0.10, 0.18, 1.0),
	},
	"block": {
		"label": "Block Stack",
		"dark_bg": Color(0.30, 0.20, 0.40, 1.0),
		"light_bg": Color(0.72, 0.58, 0.88, 1.0),
		"dark_fg": Color(0.95, 0.96, 0.99, 1.0),
		"light_fg": Color(0.10, 0.07, 0.16, 1.0),
	},
	"subpage": {
		"label": "Subpage",
		"dark_bg": Color(0.18, 0.24, 0.30, 1.0),
		"light_bg": Color(0.55, 0.78, 0.92, 1.0),
		"dark_fg": Color(0.95, 0.96, 0.99, 1.0),
		"light_fg": Color(0.06, 0.13, 0.20, 1.0),
	},
	"pinboard": {
		"label": "Pinboard",
		"dark_bg": Color(0.21, 0.29, 0.42, 1.0),
		"light_bg": Color(0.62, 0.78, 0.95, 1.0),
		"dark_fg": Color(0.95, 0.96, 0.99, 1.0),
		"light_fg": Color(0.06, 0.13, 0.22, 1.0),
	},
	"map_page": {
		"label": "Map Page",
		"dark_bg": Color(0.18, 0.32, 0.26, 1.0),
		"light_bg": Color(0.62, 0.86, 0.74, 1.0),
		"dark_fg": Color(0.95, 0.99, 0.96, 1.0),
		"light_fg": Color(0.06, 0.18, 0.13, 1.0),
	},
	"code": {
		"label": "Code",
		"dark_bg": Color(0.16, 0.18, 0.22, 1.0),
		"light_bg": Color(0.78, 0.82, 0.88, 1.0),
		"dark_fg": Color(0.78, 0.85, 0.95, 1.0),
		"light_fg": Color(0.10, 0.13, 0.20, 1.0),
	},
	"equation": {
		"label": "Equation",
		"dark_bg": Color(0.32, 0.40, 0.55, 1.0),
		"light_bg": Color(0.55, 0.68, 0.88, 1.0),
		"dark_fg": Color(0.95, 0.97, 1.0, 1.0),
		"light_fg": Color(0.06, 0.13, 0.22, 1.0),
	},
	"table": {
		"label": "Table",
		"dark_bg": Color(0.20, 0.30, 0.45, 1.0),
		"light_bg": Color(0.60, 0.75, 0.92, 1.0),
		"dark_fg": Color(0.95, 0.97, 1.0, 1.0),
		"light_fg": Color(0.06, 0.13, 0.22, 1.0),
	},
}

var _current_theme: Theme = null
var _font_manifest: FontManifest = null
var _custom_font_cache: Dictionary = {}
var _engine_fallback_font: Font = null
var _engine_fallback_font_size: int = 16
var _last_node_palette: Dictionary = {}


func _ready() -> void:
	_engine_fallback_font = ThemeDB.fallback_font
	_engine_fallback_font_size = ThemeDB.fallback_font_size
	_load_manifest()
	UserPrefs.theme_changed.connect(_apply_to_root)
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_apply_to_root")


func _exit_tree() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)
	if UserPrefs != null and UserPrefs.theme_changed.is_connected(_apply_to_root):
		UserPrefs.theme_changed.disconnect(_apply_to_root)
	if _engine_fallback_font != null:
		ThemeDB.fallback_font = _engine_fallback_font
	ThemeDB.fallback_font_size = _engine_fallback_font_size
	if tree != null and tree.root != null:
		tree.root.theme = null
	_current_theme = null
	_font_manifest = null
	_custom_font_cache.clear()
	_engine_fallback_font = null
	_last_node_palette.clear()


func _on_node_added(node: Node) -> void:
	if node is Window:
		WindowDpiScaler.attach(node as Window)
	if _current_theme == null:
		return
	if node is Window:
		var win: Window = node as Window
		win.theme = _current_theme
		win.propagate_notification(Control.NOTIFICATION_THEME_CHANGED)
	if node is MenuButton:
		_apply_theme_to_popup((node as MenuButton).get_popup(), _current_theme)
	elif node is OptionButton:
		_apply_theme_to_popup((node as OptionButton).get_popup(), _current_theme)
	elif node is PopupMenu:
		_apply_theme_to_popup(node as PopupMenu, _current_theme)
	var font: Font = active_font()
	if node is Control:
		_apply_font_override_to_control(node as Control, font)
		if (node is LineEdit or node is TextEdit) and not _is_inside_secondary_window(node):
			_apply_input_transparency(node as Control)
		if node is ColorPickerButton:
			_apply_rounded_color_picker(node as ColorPickerButton)
	if node is Window:
		_apply_font_override_to_window(node as Window, font)


func _load_manifest() -> void:
	if ResourceLoader.exists(FONT_MANIFEST_PATH):
		var res: Resource = ResourceLoader.load(FONT_MANIFEST_PATH)
		if res is FontManifest:
			_font_manifest = res as FontManifest
	if _font_manifest == null:
		_font_manifest = FontManifest.new()
		var fallback: FontPreset = FontPreset.new()
		fallback.id = "default"
		fallback.display_name = "System Default"
		fallback.font = null
		_font_manifest.presets = [fallback]
	emit_signal("font_manifest_changed")


func font_manifest() -> FontManifest:
	if _font_manifest == null:
		_load_manifest()
	return _font_manifest


func _apply_to_root() -> void:
	var theme: Theme = build_theme(UserPrefs.theme_mode, UserPrefs.theme_accent)
	_apply_font_to_theme(theme)
	_current_theme = theme
	var new_palette: Dictionary = node_palette()
	if not _last_node_palette.is_empty() and not _palette_equal(_last_node_palette, new_palette):
		emit_signal("node_palette_changed", _last_node_palette.duplicate(true), new_palette.duplicate(true))
	_last_node_palette = new_palette.duplicate(true)
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var root: Window = tree.root
	_sync_project_theme(theme)
	if root != null:
		WindowDpiScaler.attach(root, false)
		root.theme = null
		root.theme = theme
		_apply_to_windows(root, theme)
	var scene: Node = tree.current_scene
	if scene is Control:
		(scene as Control).theme = null
		(scene as Control).theme = theme
	if root != null:
		_force_theme_on_scene_roots(root, theme)
		_force_theme_on_button_popups(root, theme)
		_force_font_overrides(root, active_font())
		_force_input_transparency(root)
		_force_rounded_color_pickers(root)
		root.propagate_notification(Control.NOTIFICATION_THEME_CHANGED)
	emit_signal("theme_applied")


func _force_theme_on_button_popups(node: Node, theme: Theme) -> void:
	if node is MenuButton:
		var mb_popup: PopupMenu = (node as MenuButton).get_popup()
		_apply_theme_to_popup(mb_popup, theme)
	elif node is OptionButton:
		var ob_popup: PopupMenu = (node as OptionButton).get_popup()
		_apply_theme_to_popup(ob_popup, theme)
	elif node is PopupMenu:
		_apply_theme_to_popup(node as PopupMenu, theme)
	for child: Node in node.get_children():
		_force_theme_on_button_popups(child, theme)


func _apply_theme_to_popup(popup: PopupMenu, theme: Theme) -> void:
	if popup == null:
		return
	popup.theme = null
	popup.theme = theme
	var font: Font = active_font()
	var size: int = UserPrefs.font_size
	if font != null:
		popup.add_theme_font_override("font", font)
	else:
		popup.remove_theme_font_override("font")
	popup.add_theme_font_size_override("font_size", size)
	popup.add_theme_font_size_override("font_separator_size", size)
	var scaler: WindowDpiScaler = WindowDpiScaler.attach(popup)
	if scaler != null:
		scaler.refresh()
	if not popup.has_meta(&"_theme_manager_about_to_show_bound"):
		popup.set_meta(&"_theme_manager_about_to_show_bound", true)
		popup.about_to_popup.connect(_on_popup_about_to_show.bind(popup))
	popup.propagate_notification(Control.NOTIFICATION_THEME_CHANGED)
	popup.reset_size()


func _on_popup_about_to_show(popup: PopupMenu) -> void:
	if popup == null:
		return
	var scaler_v: Variant = popup.get_meta(WindowDpiScaler.META_MARKER, null) if popup.has_meta(WindowDpiScaler.META_MARKER) else null
	if scaler_v is WindowDpiScaler:
		(scaler_v as WindowDpiScaler).refresh()
	var font: Font = active_font()
	var size: int = UserPrefs.font_size
	if font != null:
		popup.add_theme_font_override("font", font)
	popup.add_theme_font_size_override("font_size", size)
	popup.add_theme_font_size_override("font_separator_size", size)
	popup.reset_size()


func _sync_project_theme(theme: Theme) -> void:
	var project_theme_path: String = String(ProjectSettings.get_setting("gui/theme/custom", ""))
	if project_theme_path == "":
		return
	if not ResourceLoader.exists(project_theme_path):
		return
	var project_theme: Resource = ResourceLoader.load(project_theme_path)
	if not (project_theme is Theme):
		return
	var pt: Theme = project_theme as Theme
	pt.clear()
	pt.merge_with(theme)


func _force_theme_on_scene_roots(node: Node, theme: Theme) -> void:
	for child: Node in node.get_children():
		if child is Control:
			var ctrl: Control = child as Control
			var parent: Node = ctrl.get_parent()
			if parent == null or not (parent is Control):
				ctrl.theme = null
				ctrl.theme = theme
		_force_theme_on_scene_roots(child, theme)


func _force_font_overrides(node: Node, font: Font) -> void:
	if node is Control:
		_apply_font_override_to_control(node as Control, font)
	if node is Window:
		_apply_font_override_to_window(node as Window, font)
	for child: Node in node.get_children():
		_force_font_overrides(child, font)


func _apply_font_override_to_control(ctrl: Control, font: Font) -> void:
	if ctrl is RichTextLabel:
		for variant_v: Variant in RICH_TEXT_VARIANT_SLOTS.keys():
			var variant: String = String(variant_v)
			var slot: String = String(RICH_TEXT_VARIANT_SLOTS[variant_v])
			var f: Font = active_font_for_variant(variant)
			if f != null:
				ctrl.add_theme_font_override(slot, f)
			else:
				ctrl.remove_theme_font_override(slot)
		_reapply_relative_font_size(ctrl)
		return
	if font != null:
		ctrl.add_theme_font_override("font", font)
	else:
		ctrl.remove_theme_font_override("font")
	_reapply_relative_font_size(ctrl)


func scaled_font_size(scale: float) -> int:
	var base: int = UserPrefs.font_size
	var sized: int = int(round(float(base) * scale))
	return max(1, sized)


func apply_relative_font_size(ctrl: Control, scale: float) -> void:
	if ctrl == null:
		return
	ctrl.set_meta(RELATIVE_FONT_SCALE_META, scale)
	_reapply_relative_font_size(ctrl)


func apply_relative_font_sizes(root: Node, mappings: Dictionary) -> void:
	if root == null:
		return
	for key_v: Variant in mappings.keys():
		var path: NodePath = NodePath(String(key_v))
		var raw_scale: Variant = mappings[key_v]
		if typeof(raw_scale) != TYPE_FLOAT and typeof(raw_scale) != TYPE_INT:
			continue
		var scale: float = float(raw_scale)
		var node: Node = root.get_node_or_null(path)
		if node is Control:
			apply_relative_font_size(node as Control, scale)


func clear_relative_font_size(ctrl: Control) -> void:
	if ctrl == null:
		return
	if ctrl.has_meta(RELATIVE_FONT_SCALE_META):
		ctrl.remove_meta(RELATIVE_FONT_SCALE_META)
	if ctrl is RichTextLabel:
		for variant_v: Variant in RICH_TEXT_VARIANT_SLOTS.keys():
			var slot: String = String(RICH_TEXT_VARIANT_SLOTS[variant_v])
			var size_slot: String = slot.replace("_font", "_font_size")
			ctrl.remove_theme_font_size_override(size_slot)
	else:
		ctrl.remove_theme_font_size_override("font_size")


func _reapply_relative_font_size(ctrl: Control) -> void:
	if ctrl == null or not ctrl.has_meta(RELATIVE_FONT_SCALE_META):
		return
	var raw: Variant = ctrl.get_meta(RELATIVE_FONT_SCALE_META)
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return
	var scale: float = float(raw)
	var sz: int = scaled_font_size(scale)
	if ctrl is RichTextLabel:
		ctrl.add_theme_font_size_override("normal_font_size", sz)
		ctrl.add_theme_font_size_override("bold_font_size", sz)
		ctrl.add_theme_font_size_override("italics_font_size", sz)
		ctrl.add_theme_font_size_override("bold_italics_font_size", sz)
		ctrl.add_theme_font_size_override("mono_font_size", sz)
	else:
		ctrl.add_theme_font_size_override("font_size", sz)


func _apply_font_override_to_window(win: Window, font: Font) -> void:
	if font != null:
		win.add_theme_font_override("title_font", font)
	else:
		win.remove_theme_font_override("title_font")


func _apply_to_windows(node: Node, theme: Theme) -> void:
	for child: Node in node.get_children():
		if child is Window:
			var win: Window = child as Window
			WindowDpiScaler.attach(win)
			win.theme = null
			win.theme = theme
			win.propagate_notification(Control.NOTIFICATION_THEME_CHANGED)
		_apply_to_windows(child, theme)


func current_theme() -> Theme:
	if _current_theme == null:
		_apply_to_root()
	return _current_theme


func refresh() -> void:
	_apply_to_root()


func dim_foreground_color() -> Color:
	var fg: Color = foreground_color()
	var panel: Color = panel_color()
	return fg.lerp(panel, 0.35)


func accent_dim_color() -> Color:
	return accent_color().lerp(panel_color(), 0.30)


func warning_color() -> Color:
	if UserPrefs.theme_mode == UserPrefs.THEME_LIGHT:
		return Color(0.78, 0.45, 0.10, 1.0)
	return Color(0.95, 0.78, 0.30, 1.0)


func info_color() -> Color:
	if UserPrefs.theme_mode == UserPrefs.THEME_LIGHT:
		return Color(0.18, 0.42, 0.78, 1.0)
	return Color(0.6, 0.85, 1.0, 1.0)


func selection_highlight_color() -> Color:
	var accent: Color = accent_color()
	if UserPrefs.theme_mode == UserPrefs.THEME_LIGHT:
		return accent.lerp(Color(0.0, 0.0, 0.0, 1.0), 0.15)
	return Color(0.95, 0.85, 0.30, 1.0)


func build_theme(mode: String, accent: Color) -> Theme:
	if mode == UserPrefs.THEME_IMPORTED:
		var imported: Theme = _load_imported_theme()
		if imported != null:
			var base_imported: Theme = DARK_THEME.duplicate(true) as Theme
			# Apply our design language to the dark base, then merge the imported
			# theme on top so any entry the user authored (panel/button styles,
			# colors, fonts, even variant overrides) wins over our defaults.
			ThemeVariants.apply_to_theme(base_imported, _palette_for_mode(mode), accent)
			base_imported.merge_with(imported)
			return base_imported
		push_warning("ThemeManager: imported theme unavailable; falling back to dark.")
	var src: Theme = DARK_THEME
	var src_accent: Color = DARK_ACCENT
	if mode == UserPrefs.THEME_LIGHT:
		src = LIGHT_THEME
		src_accent = LIGHT_ACCENT
	if src == null:
		push_warning("ThemeManager: theme resource not preloaded")
		return Theme.new()
	var theme: Theme = src.duplicate(true) as Theme
	if mode == UserPrefs.THEME_CUSTOM:
		_apply_custom_palette(theme, accent)
	elif accent != src_accent:
		_remap_theme(theme, _accent_remap(src_accent, accent))
	ThemeVariants.apply_to_theme(theme, _palette_for_mode(mode), accent)
	return theme


func _load_imported_theme() -> Theme:
	var path: String = UserPrefs.imported_theme_path
	if path == "":
		return null
	if not FileAccess.file_exists(path):
		return null
	var res: Resource = ResourceLoader.load(path, "Theme", ResourceLoader.CACHE_MODE_IGNORE)
	if res is Theme:
		return res as Theme
	return null


func import_theme_file(source_path: String) -> Dictionary:
	var result: Dictionary = ThemeImporter.import_file(source_path)
	if bool(result.get("ok", false)):
		UserPrefs.set_imported_theme(String(result.get("path", "")), String(result.get("label", "")))
		UserPrefs.set_theme_mode(UserPrefs.THEME_IMPORTED)
	return result


func clear_imported_theme() -> void:
	ThemeImporter.clear_active_theme()
	UserPrefs.clear_imported_theme()
	if UserPrefs.theme_mode == UserPrefs.THEME_IMPORTED:
		UserPrefs.set_theme_mode(UserPrefs.THEME_DARK)


func _accent_remap(src_accent: Color, dst_accent: Color) -> Dictionary:
	if src_accent == DARK_ACCENT:
		return {
			DARK_ACCENT: dst_accent,
			DARK_ACCENT_BRIGHT: dst_accent.lerp(Color.WHITE, 0.10),
			DARK_ACCENT_DIM: dst_accent.lerp(Color.BLACK, 0.20),
		}
	return {src_accent: dst_accent}


func _apply_custom_palette(theme: Theme, accent: Color) -> void:
	var bg: Color = UserPrefs.custom_bg
	var fg: Color = UserPrefs.custom_fg
	var panel: Color = UserPrefs.custom_panel
	var subtle: Color = UserPrefs.custom_subtle
	var fg_dim: Color = fg.lerp(panel, 0.45)
	var fg_dimmer: Color = fg.lerp(panel, 0.65)
	var fg_disabled: Color = fg.lerp(panel, 0.75)
	var fg_bright: Color = fg.lerp(Color.WHITE, 0.05)
	var fg_hover: Color = fg.lerp(Color.WHITE, 0.10)
	var fg_pressed: Color = fg.lerp(Color.WHITE, 0.18)

	var remap: Dictionary = {
		DARK_BG: bg,
		DARK_PANEL: panel,
		DARK_PANEL_INSET: panel.lerp(bg, 0.20),
		DARK_PANEL_TINT: panel.lerp(bg, 0.10),
		DARK_BTN: panel.lerp(fg, 0.06),
		DARK_BTN_HOVER: panel.lerp(accent, 0.18),
		DARK_BTN_PRESSED: panel.lerp(accent, 0.30),
		DARK_BTN_DISABLED: panel.lerp(bg, 0.40),
		DARK_INPUT: bg.lerp(panel, 0.35),
		DARK_INPUT_FOCUS: panel.lerp(bg, 0.10),
		DARK_INPUT_READONLY: bg.lerp(panel, 0.15),
		DARK_TAB_UNSEL: bg.lerp(panel, 0.55),
		DARK_TAB_DISABLED: bg.lerp(panel, 0.30),
		DARK_ITEM_HOVER: panel.lerp(fg, 0.10),
		DARK_ITEM_SELECTED_FOCUS: panel.lerp(accent, 0.40),
		DARK_GRAPH_PANEL_SEL: panel.lerp(bg, 0.10),
		DARK_GRAPH_TITLE: panel.lerp(fg, 0.12),
		DARK_GRAPH_TITLE_SEL: panel.lerp(accent, 0.30),
		DARK_GRAPHEDIT_BG: bg.lerp(Color.BLACK, 0.10),
		DARK_SUBTLE: subtle,
		DARK_SUBTLE_2: subtle.lerp(fg, 0.05),
		DARK_SUBTLE_3: subtle.lerp(bg, 0.10),
		DARK_BORDER_BRIGHT: subtle.lerp(fg, 0.10),
		DARK_BORDER_INSET: subtle.lerp(bg, 0.20),
		DARK_BORDER_HOVER: subtle.lerp(accent, 0.35),
		DARK_FG: fg,
		DARK_FG_BRIGHT: fg_bright,
		DARK_FG_HOVER: fg_hover,
		DARK_FG_PRESSED: fg_pressed,
		DARK_FG_DIM: fg_dim,
		DARK_FG_DIMMER: fg_dimmer,
		DARK_FG_DISABLED: fg_disabled,
		DARK_ACCENT: accent,
		DARK_ACCENT_BRIGHT: accent.lerp(Color.WHITE, 0.12),
		DARK_ACCENT_DIM: accent.lerp(Color.BLACK, 0.20),
	}
	_remap_theme(theme, remap)


func _remap_theme(theme: Theme, remap: Dictionary) -> void:
	for type_name: String in theme.get_type_list():
		for color_name: String in theme.get_color_list(type_name):
			var c: Color = theme.get_color(color_name, type_name)
			var mapped: Color = _lookup_remap(c, remap)
			if mapped != c:
				theme.set_color(color_name, type_name, mapped)
		for sb_name: String in theme.get_stylebox_list(type_name):
			var sb: StyleBox = theme.get_stylebox(sb_name, type_name)
			if sb is StyleBoxFlat:
				_remap_flat(sb as StyleBoxFlat, remap)


func _remap_flat(fb: StyleBoxFlat, remap: Dictionary) -> void:
	var new_bg: Color = _lookup_remap(fb.bg_color, remap)
	if new_bg != fb.bg_color:
		fb.bg_color = new_bg
	var new_border: Color = _lookup_remap(fb.border_color, remap)
	if new_border != fb.border_color:
		fb.border_color = new_border


func _lookup_remap(c: Color, remap: Dictionary) -> Color:
	if c.a < 0.001:
		return c
	var c_solid: Color = Color(c.r, c.g, c.b, 1.0)
	for src_v: Variant in remap.keys():
		var src: Color = src_v
		if c_solid.is_equal_approx(src):
			var dst: Color = remap[src_v]
			return Color(dst.r, dst.g, dst.b, c.a)
	return c


func _palette_for_mode(mode: String) -> Dictionary:
	if mode == UserPrefs.THEME_LIGHT:
		return {
			"bg": Color(0.95, 0.96, 0.98),
			"fg": Color(0.10, 0.11, 0.13),
			"panel": Color(0.90, 0.92, 0.95),
			"subtle": Color(0.72, 0.74, 0.80),
		}
	if mode == UserPrefs.THEME_CUSTOM:
		return {
			"bg": UserPrefs.custom_bg,
			"fg": UserPrefs.custom_fg,
			"panel": UserPrefs.custom_panel,
			"subtle": UserPrefs.custom_subtle,
		}
	return {
		"bg": Color(0.10, 0.11, 0.13),
		"fg": Color(0.92, 0.94, 0.97),
		"panel": Color(0.16, 0.17, 0.20),
		"subtle": Color(0.28, 0.30, 0.34),
	}


func _apply_font_to_theme(theme: Theme) -> void:
	var font: Font = active_font()
	var size: int = UserPrefs.font_size
	theme.default_font_size = size
	ThemeDB.fallback_font_size = size
	var font_classes: PackedStringArray = PackedStringArray([
		"Label", "Button", "MenuButton", "OptionButton", "CheckBox", "CheckButton",
		"ColorPickerButton", "LinkButton", "LineEdit", "TextEdit", "CodeEdit",
		"SpinBox", "ItemList", "Tree", "PopupMenu", "TabBar", "TabContainer",
		"AcceptDialog", "ConfirmationDialog", "FileDialog", "Window",
	])
	for cls: String in font_classes:
		theme.set_font_size("font_size", cls, size)
	theme.set_font_size("title_font_size", "Window", size)
	theme.set_font_size("font_separator_size", "PopupMenu", size)
	for variant_v: Variant in RICH_TEXT_VARIANT_SLOTS.keys():
		var slot: String = String(RICH_TEXT_VARIANT_SLOTS[variant_v])
		var size_slot: String = slot.replace("_font", "_font_size")
		theme.set_font_size(size_slot, "RichTextLabel", size)
	if font != null:
		theme.default_font = font
		ThemeDB.fallback_font = font
		for cls: String in font_classes:
			theme.set_font("font", cls, font)
		theme.set_font("title_font", "Window", font)
		for cls: String in PackedStringArray(["RichTextLabel"]):
			for variant_v: Variant in RICH_TEXT_VARIANT_SLOTS.keys():
				var variant: String = String(variant_v)
				var slot: String = String(RICH_TEXT_VARIANT_SLOTS[variant_v])
				var variant_font: Font = active_font_for_variant(variant)
				if variant_font == null:
					variant_font = font
				theme.set_font(slot, cls, variant_font)
	else:
		ThemeDB.fallback_font = _engine_fallback_font


## Walk the main-window subtree and give every text-input control a
## transparent background via per-control overrides. Descendants of
## secondary Window nodes (dialogs, popup menus, theme editor, etc.)
## are skipped so those inputs keep their themed backgrounds. Caret,
## selection, and focus-highlight styles are untouched.
func _force_input_transparency(node: Node) -> void:
	if node == null:
		return
	var tree: SceneTree = get_tree()
	var main_root: Window = null
	if tree != null:
		main_root = tree.root
	if node is Window and node != main_root:
		return
	if node is Control:
		_apply_input_transparency(node as Control)
	for child: Node in node.get_children():
		_force_input_transparency(child)


func _apply_input_transparency(ctrl: Control) -> void:
	if ctrl == null:
		return
	if not (ctrl is LineEdit or ctrl is TextEdit):
		return
	ctrl.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	ctrl.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	ctrl.add_theme_stylebox_override("read_only", StyleBoxEmpty.new())
	if ctrl is TextEdit:
		var transparent: Color = Color(0.0, 0.0, 0.0, 0.0)
		ctrl.add_theme_color_override("background_color", transparent)
		ctrl.add_theme_color_override("caret_background_color", transparent)


## Walks the tree and applies the empty-stylebox + rounded-corner shader
## treatment to every ColorPickerButton, so swatch buttons appear as a
## bare color chip with no button chrome.
func _force_rounded_color_pickers(node: Node) -> void:
	if node == null:
		return
	if node is ColorPickerButton:
		_apply_rounded_color_picker(node as ColorPickerButton)
	for child: Node in node.get_children():
		_force_rounded_color_pickers(child)


## Strips all five Button-state styleboxes (normal/hover/pressed/disabled/
## focus) on the given ColorPickerButton, then assigns a ShaderMaterial
## that masks the rectangular color preview into a rounded rect. The
## shader needs the button's current pixel size to compute corner
## distance, so the size uniform is refreshed on every resize.
func _apply_rounded_color_picker(btn: ColorPickerButton) -> void:
	if btn == null:
		return
	if btn.has_meta(ROUNDED_COLOR_PICKER_APPLIED_META):
		return
	btn.set_meta(ROUNDED_COLOR_PICKER_APPLIED_META, true)
	for state: String in COLOR_PICKER_BUTTON_STATES:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = ROUNDED_COLOR_PICKER_SHADER
	material.set_shader_parameter("corner_radius", ROUNDED_COLOR_PICKER_RADIUS)
	var initial_size: Vector2 = btn.size
	if initial_size.x <= 0.0 or initial_size.y <= 0.0:
		initial_size = Vector2(32.0, 32.0)
	material.set_shader_parameter("rect_size", initial_size)
	btn.material = material
	btn.resized.connect(func() -> void:
		var current_size: Vector2 = btn.size
		if current_size.x > 0.0 and current_size.y > 0.0:
			material.set_shader_parameter("rect_size", current_size)
	)


func _is_inside_secondary_window(node: Node) -> bool:
	var tree: SceneTree = get_tree()
	var main_root: Window = null
	if tree != null:
		main_root = tree.root
	var n: Node = node.get_parent()
	while n != null:
		if n is Window and n != main_root:
			return true
		n = n.get_parent()
	return false


func active_font() -> Font:
	return active_font_for_variant(FontPreset.VARIANT_REGULAR)


func active_font_for_variant(variant: String) -> Font:
	var custom_path: String = UserPrefs.get_custom_font_path_for_variant(variant)
	if custom_path != "":
		var loaded: Font = _load_custom_font(custom_path)
		if loaded != null:
			return loaded
	if variant != FontPreset.VARIANT_REGULAR:
		var regular_custom: String = UserPrefs.custom_font_path
		if regular_custom != "" and not _preset_has_variant(variant):
			var regular_loaded: Font = _load_custom_font(regular_custom)
			if regular_loaded != null:
				return regular_loaded
	var manifest: FontManifest = font_manifest()
	if manifest == null:
		return null
	var preset: FontPreset = manifest.find_by_id(UserPrefs.font_preset_id)
	if preset == null:
		preset = manifest.default_preset()
	if preset == null:
		return null
	var preset_font: Font = preset.font_for_variant(variant)
	if preset_font != null:
		return preset_font
	if variant != FontPreset.VARIANT_REGULAR:
		return preset.font
	return null


func _preset_has_variant(variant: String) -> bool:
	var manifest: FontManifest = font_manifest()
	if manifest == null:
		return false
	var preset: FontPreset = manifest.find_by_id(UserPrefs.font_preset_id)
	if preset == null:
		preset = manifest.default_preset()
	if preset == null:
		return false
	return preset.has_variant(variant)


func _load_custom_font(path: String) -> Font:
	if path == "":
		return null
	if _custom_font_cache.has(path):
		var cached: Variant = _custom_font_cache[path]
		if cached is Font:
			return cached as Font
	if not FileAccess.file_exists(path):
		return null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var loaded: Resource = ResourceLoader.load(path)
		if loaded is Font:
			_custom_font_cache[path] = loaded
			return loaded as Font
	var fs_path: String = ProjectSettings.globalize_path(path)
	var ff: FontFile = FontFile.new()
	var err: int = ff.load_dynamic_font(fs_path)
	if err != OK:
		err = ff.load_dynamic_font(path)
	if err != OK:
		return null
	_custom_font_cache[path] = ff
	return ff


func clear_custom_font_cache() -> void:
	_custom_font_cache.clear()


func install_custom_font(source_path: String) -> String:
	if source_path == "":
		return ""
	if not FileAccess.file_exists(source_path):
		return ""
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return ""
	if not dir.dir_exists("fonts"):
		var err: int = dir.make_dir_recursive("fonts")
		if err != OK:
			return ""
	var file_name: String = source_path.get_file()
	if file_name == "":
		return ""
	var dest_path: String = "user://fonts".path_join(file_name)
	var src_f: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if src_f == null:
		return ""
	var bytes: PackedByteArray = src_f.get_buffer(src_f.get_length())
	src_f.close()
	var dst_f: FileAccess = FileAccess.open(dest_path, FileAccess.WRITE)
	if dst_f == null:
		return ""
	dst_f.store_buffer(bytes)
	dst_f.close()
	clear_custom_font_cache()
	return dest_path


func background_color() -> Color:
	return _palette_for_mode(UserPrefs.theme_mode)["bg"]


func panel_color() -> Color:
	return _palette_for_mode(UserPrefs.theme_mode)["panel"]


func foreground_color() -> Color:
	return _palette_for_mode(UserPrefs.theme_mode)["fg"]


func subtle_color() -> Color:
	return _palette_for_mode(UserPrefs.theme_mode)["subtle"]


func node_palette() -> Dictionary:
	if UserPrefs.theme_mode == UserPrefs.THEME_LIGHT:
		return NODE_LIGHT.duplicate(true)
	if UserPrefs.theme_mode == UserPrefs.THEME_CUSTOM or UserPrefs.theme_mode == UserPrefs.THEME_IMPORTED:
		return {
			"node_bg": UserPrefs.custom_node_bg,
			"node_fg": UserPrefs.custom_node_fg,
			"node_heading_bg": UserPrefs.custom_node_heading_bg,
			"node_heading_fg": UserPrefs.custom_node_heading_fg,
		}
	return NODE_DARK.duplicate(true)


func node_bg_color() -> Color:
	return node_palette()["node_bg"]


func node_fg_color() -> Color:
	return node_palette()["node_fg"]


func node_heading_bg_color() -> Color:
	return node_palette()["node_heading_bg"]


func node_heading_fg_color() -> Color:
	return node_palette()["node_heading_fg"]


func node_card_bg_color() -> Color:
	return node_bg_color().lerp(node_fg_color(), 0.10)


func node_card_fg_color() -> Color:
	return node_fg_color()


func node_card_completed_bg_color() -> Color:
	if UserPrefs.theme_mode == UserPrefs.THEME_LIGHT:
		return node_card_bg_color().darkened(0.06)
	return node_card_bg_color().darkened(0.18)


func node_card_completed_fg_color() -> Color:
	return node_card_fg_color().lerp(node_card_bg_color(), 0.55)


func themed_color(dark: Color, light: Color) -> Color:
	if UserPrefs.theme_mode == UserPrefs.THEME_LIGHT:
		return light
	return dark


func node_type_ids() -> PackedStringArray:
	var ids: Array = NODE_TYPE_HEADINGS.keys()
	ids.sort()
	var out: PackedStringArray = PackedStringArray()
	for id_v: Variant in ids:
		out.append(String(id_v))
	return out


func node_type_label(type_id: String) -> String:
	var info: Dictionary = NODE_TYPE_HEADINGS.get(type_id, {})
	return String(info.get("label", type_id))


func heading_bg(type_id: String) -> Color:
	return _resolve_heading(type_id, "bg")


func heading_fg(type_id: String) -> Color:
	return _resolve_heading(type_id, "fg")


func _resolve_heading(type_id: String, slot: String) -> Color:
	var info: Dictionary = NODE_TYPE_HEADINGS.get(type_id, {})
	var dark: Color = info.get("dark_" + slot, Color(0.3, 0.3, 0.3, 1.0))
	var light: Color = info.get("light_" + slot, Color(0.7, 0.7, 0.7, 1.0))
	if UserPrefs.theme_mode == UserPrefs.THEME_CUSTOM or UserPrefs.theme_mode == UserPrefs.THEME_IMPORTED:
		var key: String = type_id + "_" + slot
		if UserPrefs.custom_node_headings.has(key):
			var raw: Variant = UserPrefs.custom_node_headings[key]
			if typeof(raw) == TYPE_COLOR:
				return raw
		return dark
	return themed_color(dark, light)


func default_heading_bg(type_id: String, mode: String) -> Color:
	var info: Dictionary = NODE_TYPE_HEADINGS.get(type_id, {})
	if mode == UserPrefs.THEME_LIGHT:
		return info.get("light_bg", Color(0.7, 0.7, 0.7, 1.0))
	return info.get("dark_bg", Color(0.3, 0.3, 0.3, 1.0))


func default_heading_fg(type_id: String, mode: String) -> Color:
	var info: Dictionary = NODE_TYPE_HEADINGS.get(type_id, {})
	if mode == UserPrefs.THEME_LIGHT:
		return info.get("light_fg", Color(0.1, 0.1, 0.1, 1.0))
	return info.get("dark_fg", Color(0.95, 0.95, 0.95, 1.0))


func _palette_equal(a: Dictionary, b: Dictionary) -> bool:
	for key: String in ["node_bg", "node_fg", "node_heading_bg", "node_heading_fg"]:
		if a.get(key, null) != b.get(key, null):
			return false
	return true


func accent_color() -> Color:
	return UserPrefs.theme_accent


## Base modulate used by white-source icon buttons (AutomaticButton with
## use_theme_icon_color = true). Returns a per-mode default for dark/light and
## the user-authored override for custom/imported. Per-state HSV effects from
## AutomaticButtonStateEffect compose on top of this base.
func icon_color() -> Color:
	if UserPrefs.theme_mode == UserPrefs.THEME_LIGHT:
		return LIGHT_ICON
	if UserPrefs.theme_mode == UserPrefs.THEME_CUSTOM or UserPrefs.theme_mode == UserPrefs.THEME_IMPORTED:
		return UserPrefs.custom_icon_color
	return DARK_ICON


func default_icon_color_for_mode(mode: String) -> Color:
	if mode == UserPrefs.THEME_LIGHT:
		return LIGHT_ICON
	return DARK_ICON


func translucent_panel_stylebox() -> StyleBoxFlat:
	var src: StyleBox = null
	if _current_theme != null and _current_theme.has_stylebox("panel", "PanelContainer"):
		src = _current_theme.get_stylebox("panel", "PanelContainer")
	var sb: StyleBoxFlat = null
	if src is StyleBoxFlat:
		sb = (src as StyleBoxFlat).duplicate() as StyleBoxFlat
	else:
		sb = StyleBoxFlat.new()
		sb.bg_color = panel_color()
		sb.border_color = subtle_color()
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(10)
	sb.bg_color.a = PANEL_ALPHA
	return sb


func apply_translucent_panel(ctrl: Control) -> void:
	if ctrl == null:
		return
	ctrl.add_theme_stylebox_override("panel", translucent_panel_stylebox())
