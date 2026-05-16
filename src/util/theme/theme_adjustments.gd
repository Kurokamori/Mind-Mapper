class_name ThemeAdjustments
extends RefCounted

## Per-control theme adjustments that compose on top of the active theme
## without permanently overwriting it. Adjustments declared via this helper
## re-resolve against the freshly applied theme whenever ThemeManager emits
## theme_applied, so custom/imported themes can override the base while the
## control keeps its declared local tweaks (smaller padding, tighter corners,
## tinted surface, etc.).
##
## Typical use from a control script:
##     ThemeAdjustments.adjust_panel(self, {"padding_scale": 0.5})
##     ThemeAdjustments.adjust_button(close_btn, {"corner_scale": 0.5, "padding_scale": 0.7})
##
## The helper hooks ThemeManager.theme_applied once per process and re-runs
## every registered adjustment automatically — callers do not need to manage
## reconnect/disconnect lifecycles.

const META_ADJUSTMENTS: String = "_theme_adjustments"
const META_REGISTERED: String = "_theme_adjustments_registered"

static var ADJUSTABLE_BUTTON_STATES: PackedStringArray = PackedStringArray([
	"normal", "hover", "pressed", "disabled", "focus", "hover_pressed",
])
static var ADJUSTABLE_INPUT_STATES: PackedStringArray = PackedStringArray([
	"normal", "focus", "read_only",
])

static var PANEL_TYPES: PackedStringArray = PackedStringArray([
	"PanelContainer", "Panel",
])

static var _bus_connected: bool = false


static func adjust_panel(ctrl: Control, spec: Dictionary) -> void:
	if ctrl == null:
		return
	_record(ctrl, "panel", spec)
	_ensure_bus()
	_apply_now(ctrl)


static func adjust_button(ctrl: Control, spec: Dictionary) -> void:
	if ctrl == null:
		return
	_record(ctrl, "button", spec)
	_ensure_bus()
	_apply_now(ctrl)


static func adjust_input(ctrl: Control, spec: Dictionary) -> void:
	if ctrl == null:
		return
	_record(ctrl, "input", spec)
	_ensure_bus()
	_apply_now(ctrl)


static func clear(ctrl: Control) -> void:
	if ctrl == null:
		return
	if ctrl.has_meta(META_ADJUSTMENTS):
		var entries: Dictionary = ctrl.get_meta(META_ADJUSTMENTS)
		for key_v: Variant in entries.keys():
			match String(key_v):
				"panel":
					ctrl.remove_theme_stylebox_override("panel")
				"button":
					for state: String in ADJUSTABLE_BUTTON_STATES:
						ctrl.remove_theme_stylebox_override(state)
				"input":
					for state: String in ADJUSTABLE_INPUT_STATES:
						ctrl.remove_theme_stylebox_override(state)
		ctrl.remove_meta(META_ADJUSTMENTS)


static func _record(ctrl: Control, key: String, spec: Dictionary) -> void:
	var entries: Dictionary
	if ctrl.has_meta(META_ADJUSTMENTS):
		entries = ctrl.get_meta(META_ADJUSTMENTS)
	else:
		entries = {}
	entries[key] = spec.duplicate(true)
	ctrl.set_meta(META_ADJUSTMENTS, entries)


static func _ensure_bus() -> void:
	if _bus_connected:
		return
	if not ThemeManager.theme_applied.is_connected(Callable(ThemeAdjustments, "_on_theme_applied")):
		ThemeManager.theme_applied.connect(Callable(ThemeAdjustments, "_on_theme_applied"))
	_bus_connected = true


static func _on_theme_applied() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	_walk(tree.root)


static func _walk(node: Node) -> void:
	if node is Control:
		var ctrl: Control = node as Control
		if ctrl.has_meta(META_ADJUSTMENTS):
			_apply_now(ctrl)
	for child: Node in node.get_children():
		_walk(child)


static func _apply_now(ctrl: Control) -> void:
	if not ctrl.has_meta(META_ADJUSTMENTS):
		return
	var entries: Dictionary = ctrl.get_meta(META_ADJUSTMENTS)
	for key_v: Variant in entries.keys():
		var key: String = key_v
		var spec: Dictionary = entries[key_v]
		match key:
			"panel":
				_apply_panel(ctrl, spec)
			"button":
				_apply_button(ctrl, spec)
			"input":
				_apply_input(ctrl, spec)


static func _apply_panel(ctrl: Control, spec: Dictionary) -> void:
	var source: StyleBox = _resolve_themed_stylebox(ctrl, "panel")
	if source == null:
		return
	var sb: StyleBox = _adjust_stylebox(source, spec)
	if sb != null:
		ctrl.add_theme_stylebox_override("panel", sb)


static func _apply_button(ctrl: Control, spec: Dictionary) -> void:
	for state: String in ADJUSTABLE_BUTTON_STATES:
		var source: StyleBox = _resolve_themed_stylebox(ctrl, state)
		if source == null:
			continue
		var sb: StyleBox = _adjust_stylebox(source, spec)
		if sb != null:
			ctrl.add_theme_stylebox_override(state, sb)


static func _apply_input(ctrl: Control, spec: Dictionary) -> void:
	for state: String in ADJUSTABLE_INPUT_STATES:
		var source: StyleBox = _resolve_themed_stylebox(ctrl, state)
		if source == null:
			continue
		var sb: StyleBox = _adjust_stylebox(source, spec)
		if sb != null:
			ctrl.add_theme_stylebox_override(state, sb)


static func _resolve_themed_stylebox(ctrl: Control, slot: String) -> StyleBox:
	if ctrl == null:
		return null
	var theme: Theme = ThemeManager.current_theme()
	if theme == null:
		return null
	var current_override: StyleBox = ctrl.get_theme_stylebox(slot) if ctrl.has_theme_stylebox_override(slot) else null
	if current_override != null:
		ctrl.remove_theme_stylebox_override(slot)
	var variant: String = String(ctrl.theme_type_variation)
	var base_class: String = ctrl.get_class()
	var candidates: PackedStringArray = PackedStringArray()
	if variant != "":
		candidates.append(variant)
	candidates.append(base_class)
	for candidate: String in candidates:
		var found: StyleBox = _theme_lookup(theme, slot, candidate)
		if found != null:
			return found
	if current_override != null:
		return current_override
	return null


static func _theme_lookup(theme: Theme, slot: String, type_name: String) -> StyleBox:
	if theme.has_stylebox(slot, type_name):
		return theme.get_stylebox(slot, type_name)
	var variation_base: StringName = theme.get_type_variation_base(type_name)
	if variation_base != StringName(""):
		return _theme_lookup(theme, slot, String(variation_base))
	return null


static func _adjust_stylebox(source: StyleBox, spec: Dictionary) -> StyleBox:
	if source == null:
		return null
	if not (source is StyleBoxFlat):
		# StyleBoxEmpty / textured boxes have no adjustable padding or color;
		# return a duplicate to keep override behavior consistent.
		return source.duplicate() as StyleBox
	var sb: StyleBoxFlat = (source as StyleBoxFlat).duplicate() as StyleBoxFlat
	var padding_scale: float = float(spec.get("padding_scale", 1.0))
	if not is_equal_approx(padding_scale, 1.0):
		sb.content_margin_left = max(0.0, sb.content_margin_left * padding_scale)
		sb.content_margin_right = max(0.0, sb.content_margin_right * padding_scale)
		sb.content_margin_top = max(0.0, sb.content_margin_top * padding_scale)
		sb.content_margin_bottom = max(0.0, sb.content_margin_bottom * padding_scale)
	var corner_scale: float = float(spec.get("corner_scale", 1.0))
	if not is_equal_approx(corner_scale, 1.0):
		sb.corner_radius_top_left = int(max(0.0, sb.corner_radius_top_left * corner_scale))
		sb.corner_radius_top_right = int(max(0.0, sb.corner_radius_top_right * corner_scale))
		sb.corner_radius_bottom_left = int(max(0.0, sb.corner_radius_bottom_left * corner_scale))
		sb.corner_radius_bottom_right = int(max(0.0, sb.corner_radius_bottom_right * corner_scale))
	var border_scale: float = float(spec.get("border_scale", 1.0))
	if not is_equal_approx(border_scale, 1.0):
		sb.border_width_left = int(max(0.0, sb.border_width_left * border_scale))
		sb.border_width_right = int(max(0.0, sb.border_width_right * border_scale))
		sb.border_width_top = int(max(0.0, sb.border_width_top * border_scale))
		sb.border_width_bottom = int(max(0.0, sb.border_width_bottom * border_scale))
	var bg_tint_raw: Variant = spec.get("bg_tint", null)
	var bg_tint_strength: float = float(spec.get("bg_tint_strength", 0.0))
	if typeof(bg_tint_raw) == TYPE_COLOR and bg_tint_strength > 0.0:
		sb.bg_color = sb.bg_color.lerp(bg_tint_raw, clampf(bg_tint_strength, 0.0, 1.0))
	var bg_alpha_raw: Variant = spec.get("bg_alpha", null)
	if typeof(bg_alpha_raw) == TYPE_FLOAT or typeof(bg_alpha_raw) == TYPE_INT:
		sb.bg_color.a = clampf(float(bg_alpha_raw), 0.0, 1.0)
	var border_tint_raw: Variant = spec.get("border_tint", null)
	var border_tint_strength: float = float(spec.get("border_tint_strength", 0.0))
	if typeof(border_tint_raw) == TYPE_COLOR and border_tint_strength > 0.0:
		sb.border_color = sb.border_color.lerp(border_tint_raw, clampf(border_tint_strength, 0.0, 1.0))
	var shadow_raw: Variant = spec.get("shadow_size", null)
	if typeof(shadow_raw) == TYPE_INT or typeof(shadow_raw) == TYPE_FLOAT:
		sb.shadow_size = int(max(0, int(shadow_raw)))
	return sb
