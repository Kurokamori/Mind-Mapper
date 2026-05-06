extends Node

const PREFS_PATH: String = "user://ui_prefs.json"
const FORMAT_VERSION: int = 2

const THEME_DARK: String = "dark"
const THEME_LIGHT: String = "light"
const THEME_CUSTOM: String = "custom"
const THEME_IMPORTED: String = "imported"

signal changed()
signal theme_changed()
signal keybindings_changed()

var outliner_visible: bool = true
var minimap_visible: bool = true
var minimap_position: Vector2 = Vector2.ZERO
var minimap_position_set: bool = false
var snap_enabled: bool = false
var snap_to_grid: bool = true
var snap_to_items: bool = false
var grid_size: int = 16
var theme_mode: String = THEME_DARK
var theme_accent: Color = Color(0.35, 0.7, 1.0)
var custom_bg: Color = Color(0.10, 0.11, 0.13)
var custom_fg: Color = Color(0.92, 0.94, 0.97)
var custom_panel: Color = Color(0.16, 0.17, 0.20)
var custom_subtle: Color = Color(0.28, 0.30, 0.34)
var custom_node_bg: Color = Color(0.16, 0.17, 0.20, 1.0)
var custom_node_fg: Color = Color(0.95, 0.96, 0.98, 1.0)
var custom_node_heading_bg: Color = Color(0.32, 0.18, 0.42, 1.0)
var custom_node_heading_fg: Color = Color(0.97, 0.97, 0.99, 1.0)
var custom_node_headings: Dictionary = {}
var imported_theme_path: String = ""
var imported_theme_label: String = ""
var font_preset_id: String = "default"
var custom_font_path: String = ""
var custom_font_bold_path: String = ""
var custom_font_italic_path: String = ""
var custom_font_bold_italic_path: String = ""
var custom_font_mono_path: String = ""
var font_size: int = 14
var keybindings: Dictionary = {}
var _outliner_collapsed_by_project: Dictionary = {}
var _panel_layouts: Dictionary = {}
var _loaded: bool = false


func get_panel_layout(panel_id: String) -> Dictionary:
	if panel_id == "":
		return {}
	var entry: Variant = _panel_layouts.get(panel_id, null)
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	return (entry as Dictionary).duplicate(true)


func set_panel_layout(panel_id: String, data: Dictionary) -> void:
	if panel_id == "":
		return
	_panel_layouts[panel_id] = data.duplicate(true)
	_save()


func _ready() -> void:
	_load()
	_apply_snap_to_service()


func is_board_collapsed(project_id: String, board_id: String) -> bool:
	if project_id == "" or board_id == "":
		return false
	var entry: Variant = _outliner_collapsed_by_project.get(project_id, null)
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	return bool((entry as Dictionary).get(board_id, false))


func set_board_collapsed(project_id: String, board_id: String, collapsed: bool) -> void:
	if project_id == "" or board_id == "":
		return
	var entry: Dictionary = _outliner_collapsed_by_project.get(project_id, {})
	if collapsed:
		entry[board_id] = true
	else:
		entry.erase(board_id)
	if entry.is_empty():
		_outliner_collapsed_by_project.erase(project_id)
	else:
		_outliner_collapsed_by_project[project_id] = entry
	_save()


func set_outliner_visible(value: bool) -> void:
	if outliner_visible == value:
		return
	outliner_visible = value
	_save()
	emit_signal("changed")


func set_minimap_visible(value: bool) -> void:
	if minimap_visible == value:
		return
	minimap_visible = value
	_save()
	emit_signal("changed")


func set_minimap_position(value: Vector2) -> void:
	minimap_position = value
	minimap_position_set = true
	_save()


func set_snap_state(p_enabled: bool, p_to_grid: bool, p_to_items: bool, p_grid_size: int) -> void:
	snap_enabled = p_enabled
	snap_to_grid = p_to_grid
	snap_to_items = p_to_items
	grid_size = max(1, p_grid_size)
	_save()


func set_theme_mode(value: String) -> void:
	if theme_mode == value:
		return
	theme_mode = value
	_save()
	emit_signal("theme_changed")


func set_theme_accent(value: Color) -> void:
	if theme_accent == value:
		return
	theme_accent = value
	_save()
	emit_signal("theme_changed")


func set_custom_bg(value: Color) -> void:
	if custom_bg == value:
		return
	custom_bg = value
	_save()
	emit_signal("theme_changed")


func set_custom_fg(value: Color) -> void:
	if custom_fg == value:
		return
	custom_fg = value
	_save()
	emit_signal("theme_changed")


func set_custom_panel(value: Color) -> void:
	if custom_panel == value:
		return
	custom_panel = value
	_save()
	emit_signal("theme_changed")


func set_custom_subtle(value: Color) -> void:
	if custom_subtle == value:
		return
	custom_subtle = value
	_save()
	emit_signal("theme_changed")


func set_custom_node_bg(value: Color) -> void:
	if custom_node_bg == value:
		return
	custom_node_bg = value
	_save()
	emit_signal("theme_changed")


func set_custom_node_fg(value: Color) -> void:
	if custom_node_fg == value:
		return
	custom_node_fg = value
	_save()
	emit_signal("theme_changed")


func set_custom_node_heading_bg(value: Color) -> void:
	if custom_node_heading_bg == value:
		return
	custom_node_heading_bg = value
	_save()
	emit_signal("theme_changed")


func set_custom_node_heading_fg(value: Color) -> void:
	if custom_node_heading_fg == value:
		return
	custom_node_heading_fg = value
	_save()
	emit_signal("theme_changed")


func set_custom_node_heading(key: String, value: Variant) -> void:
	if key == "":
		return
	if value == null:
		if not custom_node_headings.has(key):
			return
		custom_node_headings.erase(key)
	else:
		var color: Color = value if typeof(value) == TYPE_COLOR else Color(0, 0, 0, 1)
		if custom_node_headings.has(key) and custom_node_headings[key] == color:
			return
		custom_node_headings[key] = color
	_save()
	emit_signal("theme_changed")


func clear_custom_node_headings() -> void:
	if custom_node_headings.is_empty():
		return
	custom_node_headings.clear()
	_save()
	emit_signal("theme_changed")


func apply_node_heading_preset(presets: Dictionary) -> void:
	for key: Variant in presets.keys():
		var k: String = String(key)
		var raw: Variant = presets[key]
		if typeof(raw) == TYPE_COLOR:
			custom_node_headings[k] = raw
	_save()
	emit_signal("theme_changed")


func set_imported_theme(path: String, label: String) -> void:
	var changed: bool = false
	if imported_theme_path != path:
		imported_theme_path = path
		changed = true
	if imported_theme_label != label:
		imported_theme_label = label
		changed = true
	if not changed:
		return
	_save()
	emit_signal("theme_changed")


func clear_imported_theme() -> void:
	if imported_theme_path == "" and imported_theme_label == "":
		return
	imported_theme_path = ""
	imported_theme_label = ""
	_save()
	emit_signal("theme_changed")


func set_font_preset_id(value: String) -> void:
	if font_preset_id == value:
		return
	font_preset_id = value
	_save()
	emit_signal("theme_changed")


func set_custom_font_path(value: String) -> void:
	if custom_font_path == value:
		return
	custom_font_path = value
	_save()
	emit_signal("theme_changed")


func set_custom_font_bold_path(value: String) -> void:
	if custom_font_bold_path == value:
		return
	custom_font_bold_path = value
	_save()
	emit_signal("theme_changed")


func set_custom_font_italic_path(value: String) -> void:
	if custom_font_italic_path == value:
		return
	custom_font_italic_path = value
	_save()
	emit_signal("theme_changed")


func set_custom_font_bold_italic_path(value: String) -> void:
	if custom_font_bold_italic_path == value:
		return
	custom_font_bold_italic_path = value
	_save()
	emit_signal("theme_changed")


func set_custom_font_mono_path(value: String) -> void:
	if custom_font_mono_path == value:
		return
	custom_font_mono_path = value
	_save()
	emit_signal("theme_changed")


func get_custom_font_path_for_variant(variant: String) -> String:
	match variant:
		FontPreset.VARIANT_BOLD:
			return custom_font_bold_path
		FontPreset.VARIANT_ITALIC:
			return custom_font_italic_path
		FontPreset.VARIANT_BOLD_ITALIC:
			return custom_font_bold_italic_path
		FontPreset.VARIANT_MONO:
			return custom_font_mono_path
		_:
			return custom_font_path


func set_custom_font_path_for_variant(variant: String, value: String) -> void:
	match variant:
		FontPreset.VARIANT_BOLD:
			set_custom_font_bold_path(value)
		FontPreset.VARIANT_ITALIC:
			set_custom_font_italic_path(value)
		FontPreset.VARIANT_BOLD_ITALIC:
			set_custom_font_bold_italic_path(value)
		FontPreset.VARIANT_MONO:
			set_custom_font_mono_path(value)
		_:
			set_custom_font_path(value)


func set_font_size(value: int) -> void:
	var clamped: int = clamp(value, 8, 48)
	if font_size == clamped:
		return
	font_size = clamped
	_save()
	emit_signal("theme_changed")


func set_keybinding(action_id: String, event: Variant) -> void:
	if action_id == "":
		return
	if event == null:
		keybindings.erase(action_id)
	else:
		keybindings[action_id] = _serialize_keybinding(event)
	_save()
	emit_signal("keybindings_changed")


func reset_keybindings() -> void:
	keybindings.clear()
	_save()
	emit_signal("keybindings_changed")


func _serialize_keybinding(event: Variant) -> Dictionary:
	if event is InputEventKey:
		var k: InputEventKey = event
		return {
			"keycode": int(k.physical_keycode if k.physical_keycode != 0 else k.keycode),
			"shift": k.shift_pressed,
			"ctrl": k.ctrl_pressed or k.meta_pressed,
			"alt": k.alt_pressed,
		}
	if typeof(event) == TYPE_DICTIONARY:
		return event
	return {}


func _apply_snap_to_service() -> void:
	if has_node("/root/SnapService"):
		var svc: Node = get_node("/root/SnapService")
		if svc.has_method("load_from_prefs"):
			svc.load_from_prefs(snap_enabled, snap_to_grid, snap_to_items, grid_size)


func _load() -> void:
	if not FileAccess.file_exists(PREFS_PATH):
		_loaded = true
		return
	var f: FileAccess = FileAccess.open(PREFS_PATH, FileAccess.READ)
	if f == null:
		_loaded = true
		return
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		_loaded = true
		return
	var data: Dictionary = parsed
	outliner_visible = bool(data.get("outliner_visible", outliner_visible))
	minimap_visible = bool(data.get("minimap_visible", minimap_visible))
	var pos_raw: Variant = data.get("minimap_position", null)
	if typeof(pos_raw) == TYPE_ARRAY and (pos_raw as Array).size() >= 2:
		var arr: Array = pos_raw
		minimap_position = Vector2(float(arr[0]), float(arr[1]))
		minimap_position_set = true
	snap_enabled = bool(data.get("snap_enabled", snap_enabled))
	snap_to_grid = bool(data.get("snap_to_grid", snap_to_grid))
	snap_to_items = bool(data.get("snap_to_items", snap_to_items))
	grid_size = int(data.get("grid_size", grid_size))
	theme_mode = String(data.get("theme_mode", theme_mode))
	var accent_raw: Variant = data.get("theme_accent", null)
	if typeof(accent_raw) == TYPE_ARRAY and (accent_raw as Array).size() >= 3:
		var arr: Array = accent_raw
		var a: float = 1.0 if arr.size() < 4 else float(arr[3])
		theme_accent = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
	custom_bg = _read_color(data.get("custom_bg", null), custom_bg)
	custom_fg = _read_color(data.get("custom_fg", null), custom_fg)
	custom_panel = _read_color(data.get("custom_panel", null), custom_panel)
	custom_subtle = _read_color(data.get("custom_subtle", null), custom_subtle)
	custom_node_bg = _read_color(data.get("custom_node_bg", null), custom_node_bg)
	custom_node_fg = _read_color(data.get("custom_node_fg", null), custom_node_fg)
	custom_node_heading_bg = _read_color(data.get("custom_node_heading_bg", null), custom_node_heading_bg)
	custom_node_heading_fg = _read_color(data.get("custom_node_heading_fg", null), custom_node_heading_fg)
	custom_node_headings.clear()
	var headings_raw: Variant = data.get("custom_node_headings", {})
	if typeof(headings_raw) == TYPE_DICTIONARY:
		for key_v: Variant in (headings_raw as Dictionary).keys():
			var arr_v: Variant = (headings_raw as Dictionary)[key_v]
			if typeof(arr_v) == TYPE_ARRAY and (arr_v as Array).size() >= 3:
				custom_node_headings[String(key_v)] = _read_color(arr_v, Color())
	imported_theme_path = String(data.get("imported_theme_path", imported_theme_path))
	imported_theme_label = String(data.get("imported_theme_label", imported_theme_label))
	font_preset_id = String(data.get("font_preset_id", font_preset_id))
	custom_font_path = String(data.get("custom_font_path", custom_font_path))
	custom_font_bold_path = String(data.get("custom_font_bold_path", custom_font_bold_path))
	custom_font_italic_path = String(data.get("custom_font_italic_path", custom_font_italic_path))
	custom_font_bold_italic_path = String(data.get("custom_font_bold_italic_path", custom_font_bold_italic_path))
	custom_font_mono_path = String(data.get("custom_font_mono_path", custom_font_mono_path))
	font_size = int(data.get("font_size", font_size))
	var kb_raw: Variant = data.get("keybindings", {})
	if typeof(kb_raw) == TYPE_DICTIONARY:
		keybindings = (kb_raw as Dictionary).duplicate(true)
	var collapsed_raw: Variant = data.get("outliner_collapsed_by_project", {})
	if typeof(collapsed_raw) == TYPE_DICTIONARY:
		_outliner_collapsed_by_project.clear()
		for project_id_v: Variant in (collapsed_raw as Dictionary).keys():
			var project_id: String = String(project_id_v)
			var inner_raw: Variant = (collapsed_raw as Dictionary)[project_id_v]
			if typeof(inner_raw) != TYPE_DICTIONARY:
				continue
			var inner_clean: Dictionary = {}
			for board_id_v: Variant in (inner_raw as Dictionary).keys():
				if bool((inner_raw as Dictionary)[board_id_v]):
					inner_clean[String(board_id_v)] = true
			if not inner_clean.is_empty():
				_outliner_collapsed_by_project[project_id] = inner_clean
	_panel_layouts.clear()
	var panels_raw: Variant = data.get("panel_layouts", {})
	if typeof(panels_raw) == TYPE_DICTIONARY:
		for panel_key_v: Variant in (panels_raw as Dictionary).keys():
			var entry_raw: Variant = (panels_raw as Dictionary)[panel_key_v]
			if typeof(entry_raw) == TYPE_DICTIONARY:
				_panel_layouts[String(panel_key_v)] = (entry_raw as Dictionary).duplicate(true)
	_loaded = true


func _save() -> void:
	if not _loaded:
		return
	var data: Dictionary = {
		"format_version": FORMAT_VERSION,
		"outliner_visible": outliner_visible,
		"minimap_visible": minimap_visible,
		"minimap_position": ([minimap_position.x, minimap_position.y] if minimap_position_set else null),
		"snap_enabled": snap_enabled,
		"snap_to_grid": snap_to_grid,
		"snap_to_items": snap_to_items,
		"grid_size": grid_size,
		"theme_mode": theme_mode,
		"theme_accent": _color_to_array(theme_accent),
		"custom_bg": _color_to_array(custom_bg),
		"custom_fg": _color_to_array(custom_fg),
		"custom_panel": _color_to_array(custom_panel),
		"custom_subtle": _color_to_array(custom_subtle),
		"custom_node_bg": _color_to_array(custom_node_bg),
		"custom_node_fg": _color_to_array(custom_node_fg),
		"custom_node_heading_bg": _color_to_array(custom_node_heading_bg),
		"custom_node_heading_fg": _color_to_array(custom_node_heading_fg),
		"custom_node_headings": _serialize_node_headings(),
		"imported_theme_path": imported_theme_path,
		"imported_theme_label": imported_theme_label,
		"font_preset_id": font_preset_id,
		"custom_font_path": custom_font_path,
		"custom_font_bold_path": custom_font_bold_path,
		"custom_font_italic_path": custom_font_italic_path,
		"custom_font_bold_italic_path": custom_font_bold_italic_path,
		"custom_font_mono_path": custom_font_mono_path,
		"font_size": font_size,
		"keybindings": keybindings,
		"outliner_collapsed_by_project": _outliner_collapsed_by_project,
		"panel_layouts": _panel_layouts,
	}
	var f: FileAccess = FileAccess.open(PREFS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func _color_to_array(c: Color) -> Array:
	return [c.r, c.g, c.b, c.a]


func _serialize_node_headings() -> Dictionary:
	var out: Dictionary = {}
	for key_v: Variant in custom_node_headings.keys():
		var raw: Variant = custom_node_headings[key_v]
		if typeof(raw) == TYPE_COLOR:
			out[String(key_v)] = _color_to_array(raw)
	return out


func _read_color(raw: Variant, fallback: Color) -> Color:
	if typeof(raw) != TYPE_ARRAY:
		return fallback
	var arr: Array = raw
	if arr.size() < 3:
		return fallback
	var a: float = 1.0 if arr.size() < 4 else float(arr[3])
	return Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
