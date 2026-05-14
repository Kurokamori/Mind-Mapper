@tool
class_name AutomaticButton
extends BaseButton
## Button-shaped Control that takes a single source texture and extrapolates
## per-state visual variation through a HSV recolor shader, an outline overlay
## NinePatchRect, and Control-level transforms. Mirrors NinePatchButton's
## ergonomics (patch margins, content margins, label styling, optional shared
## style resource, editor preview) but replaces the per-state textures and
## per-state modulate with a single AutomaticButtonStateEffect per state.

enum VisualState {
	NORMAL,
	HOVER,
	PRESSED,
	DISABLED,
	FOCUSED,
}

@export_group("Style Resource")
## Optional shared style. When assigned, every visual property below is sourced
## from the resource and the per-instance exports are ignored. Leave null to
## use the per-instance values authored on this scene. Edits to the resource
## (or any of its sub-resources) propagate via the changed signal so all
## buttons that share the style update together.
@export var style: AutomaticButtonStyle = null:
	set(value):
		if style == value:
			return
		if style != null and style.changed.is_connected(_on_style_changed):
			style.changed.disconnect(_on_style_changed)
		style = value
		if style != null and not style.changed.is_connected(_on_style_changed):
			style.changed.connect(_on_style_changed)
		_on_style_changed()

@export_group("Texture")
## Single source texture. The same texture is used for every state — visual
## variation is produced by the per-state effect resources below.
@export var texture: Texture2D = null:
	set(value):
		texture = value
		_apply_textures()
		_refresh()

@export_group("Patch Margins")
@export var patch_margin_left: int = 0:
	set(value):
		patch_margin_left = value
		_apply_patch_margins()
@export var patch_margin_top: int = 0:
	set(value):
		patch_margin_top = value
		_apply_patch_margins()
@export var patch_margin_right: int = 0:
	set(value):
		patch_margin_right = value
		_apply_patch_margins()
@export var patch_margin_bottom: int = 0:
	set(value):
		patch_margin_bottom = value
		_apply_patch_margins()
@export var axis_stretch_horizontal: NinePatchRect.AxisStretchMode = NinePatchRect.AXIS_STRETCH_MODE_STRETCH:
	set(value):
		axis_stretch_horizontal = value
		_apply_patch_stretch()
@export var axis_stretch_vertical: NinePatchRect.AxisStretchMode = NinePatchRect.AXIS_STRETCH_MODE_STRETCH:
	set(value):
		axis_stretch_vertical = value
		_apply_patch_stretch()

@export_group("Content Margins")
## Inset (in pixels) applied to the inner Label so its usable area can shrink
## inside the patch independently of patch_margin_*. Patch margins control how
## the texture stretches; content margins control where the label sits.
@export var content_margin_left: int = 0:
	set(value):
		content_margin_left = value
		_apply_content_margins()
		update_minimum_size()
@export var content_margin_top: int = 0:
	set(value):
		content_margin_top = value
		_apply_content_margins()
		update_minimum_size()
@export var content_margin_right: int = 0:
	set(value):
		content_margin_right = value
		_apply_content_margins()
		update_minimum_size()
@export var content_margin_bottom: int = 0:
	set(value):
		content_margin_bottom = value
		_apply_content_margins()
		update_minimum_size()

@export_group("Label")
@export_multiline var text: String = "":
	set(value):
		text = value
		_apply_label_text()
@export var font: Font = null:
	set(value):
		font = value
		_apply_label_font()
@export var font_size: int = 16:
	set(value):
		font_size = max(1, value)
		_apply_label_font()
@export var label_color_normal: Color = Color.WHITE:
	set(value):
		label_color_normal = value
		_refresh()
@export var label_color_hover: Color = Color.WHITE:
	set(value):
		label_color_hover = value
		_refresh()
@export var label_color_pressed: Color = Color.WHITE:
	set(value):
		label_color_pressed = value
		_refresh()
@export var label_color_disabled: Color = Color(1.0, 1.0, 1.0, 0.5):
	set(value):
		label_color_disabled = value
		_refresh()
@export var label_color_focused: Color = Color.WHITE:
	set(value):
		label_color_focused = value
		_refresh()
@export var label_outline_size: int = 0:
	set(value):
		label_outline_size = max(0, value)
		_apply_label_font()
@export var label_outline_color: Color = Color.BLACK:
	set(value):
		label_outline_color = value
		_apply_label_font()
@export var label_horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER:
	set(value):
		label_horizontal_alignment = value
		_apply_label_alignment()
@export var label_vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER:
	set(value):
		label_vertical_alignment = value
		_apply_label_alignment()
@export var label_autowrap: TextServer.AutowrapMode = TextServer.AUTOWRAP_OFF:
	set(value):
		label_autowrap = value
		_apply_label_alignment()
@export var label_clip_text: bool = false:
	set(value):
		label_clip_text = value
		_apply_label_alignment()

@export_group("Modulate")
## Base modulate applied to the main NinePatchRect on top of the HSV shader.
## Per-state recoloring should go through the effect resources; this is a
## single global tint for situations like fading the whole button out.
@export var modulate_base: Color = Color.WHITE:
	set(value):
		modulate_base = value
		_refresh()
## When true, modulate_base is overridden at draw time by ThemeManager.icon_color()
## so a white source texture tints to the per-theme icon color (dark/light/custom).
## Per-state HSV effects from the effect resources still compose on top. Leave
## off for buttons that author an explicit modulate_base.
@export var use_theme_icon_color: bool = false:
	set(value):
		use_theme_icon_color = value
		_connect_theme_signal()
		_refresh()

@export_group("State Effects")
## When any of these are null, the button falls back to its sensible built-in
## default effect for that state (e.g. a 5px orange halo on PRESSED). Assign a
## fresh AutomaticButtonStateEffect to strip a state to identity, or author a
## resource on disk and reuse it across many buttons.
## Effect setters disconnect the previous resource's `changed` signal, store
## the new value (direct self-assignment so GDScript does not recurse the
## setter), and re-subscribe so live inspector tweaks bounce back to _refresh.
@export var effect_normal: AutomaticButtonStateEffect = null:
	set(value):
		if effect_normal == value:
			return
		if effect_normal != null and effect_normal.changed.is_connected(_on_effect_changed):
			effect_normal.changed.disconnect(_on_effect_changed)
		effect_normal = value
		if value != null and not value.changed.is_connected(_on_effect_changed):
			value.changed.connect(_on_effect_changed)
		_refresh()
@export var effect_hover: AutomaticButtonStateEffect = null:
	set(value):
		if effect_hover == value:
			return
		if effect_hover != null and effect_hover.changed.is_connected(_on_effect_changed):
			effect_hover.changed.disconnect(_on_effect_changed)
		effect_hover = value
		if value != null and not value.changed.is_connected(_on_effect_changed):
			value.changed.connect(_on_effect_changed)
		_refresh()
@export var effect_pressed: AutomaticButtonStateEffect = null:
	set(value):
		if effect_pressed == value:
			return
		if effect_pressed != null and effect_pressed.changed.is_connected(_on_effect_changed):
			effect_pressed.changed.disconnect(_on_effect_changed)
		effect_pressed = value
		if value != null and not value.changed.is_connected(_on_effect_changed):
			value.changed.connect(_on_effect_changed)
		_refresh()
@export var effect_disabled: AutomaticButtonStateEffect = null:
	set(value):
		if effect_disabled == value:
			return
		if effect_disabled != null and effect_disabled.changed.is_connected(_on_effect_changed):
			effect_disabled.changed.disconnect(_on_effect_changed)
		effect_disabled = value
		if value != null and not value.changed.is_connected(_on_effect_changed):
			value.changed.connect(_on_effect_changed)
		_refresh()
@export var effect_focused: AutomaticButtonStateEffect = null:
	set(value):
		if effect_focused == value:
			return
		if effect_focused != null and effect_focused.changed.is_connected(_on_effect_changed):
			effect_focused.changed.disconnect(_on_effect_changed)
		effect_focused = value
		if value != null and not value.changed.is_connected(_on_effect_changed):
			value.changed.connect(_on_effect_changed)
		_refresh()

@export_group("Editor Preview")
## In the editor, force the visuals into a specific state so designers can
## tune each look without running the game. Ignored at runtime — actual
## button state takes over once _ready connects the input signals.
@export var preview_state: VisualState = VisualState.NORMAL:
	set(value):
		preview_state = value
		_refresh()
## When true, the editor preview also reflects how the visuals would change
## when disabled is toggled on the BaseButton.
@export var preview_respects_disabled: bool = true:
	set(value):
		preview_respects_disabled = value
		_refresh()

@onready var _outline_patch: NinePatchRect = %OutlinePatch
@onready var _ninepatch: NinePatchRect = %NinePatch
@onready var _label: Label = %Label

var _hovered: bool = false
var _ready_done: bool = false
## Cached fallback effects — one per state — populated lazily when neither the
## per-instance export nor the style resource provides one. Cached so repeated
## refreshes don't allocate; never serialized.
var _fallback_effects: Dictionary = {}


func _init() -> void:
	## Pre-populate built-in defaults on a brand new instance so the inspector
	## immediately shows the colorful "automatic" look. Designers can null any
	## slot to opt back into a fresh, identity effect.
	if effect_normal == null:
		effect_normal = AutomaticButtonStateEffect.make_default_normal()
	if effect_hover == null:
		effect_hover = AutomaticButtonStateEffect.make_default_hover()
	if effect_pressed == null:
		effect_pressed = AutomaticButtonStateEffect.make_default_pressed()
	if effect_disabled == null:
		effect_disabled = AutomaticButtonStateEffect.make_default_disabled()
	if effect_focused == null:
		effect_focused = AutomaticButtonStateEffect.make_default_focused()


func _ready() -> void:
	_outline_patch = get_node_or_null("%OutlinePatch")
	_ninepatch = get_node_or_null("%NinePatch")
	_label = get_node_or_null("%Label")
	_ready_done = true
	_apply_textures()
	_apply_patch_margins()
	_apply_patch_stretch()
	_apply_content_margins()
	_apply_label_text()
	_apply_label_font()
	_apply_label_alignment()
	if not Engine.is_editor_hint():
		if not mouse_entered.is_connected(_on_mouse_entered):
			mouse_entered.connect(_on_mouse_entered)
		if not mouse_exited.is_connected(_on_mouse_exited):
			mouse_exited.connect(_on_mouse_exited)
		if not focus_entered.is_connected(_on_focus_changed):
			focus_entered.connect(_on_focus_changed)
		if not focus_exited.is_connected(_on_focus_changed):
			focus_exited.connect(_on_focus_changed)
		if not button_down.is_connected(_refresh):
			button_down.connect(_refresh)
		if not button_up.is_connected(_refresh):
			button_up.connect(_refresh)
		if not toggled.is_connected(_on_toggled):
			toggled.connect(_on_toggled)
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	_connect_theme_signal()
	_refresh()


func _exit_tree() -> void:
	var tm: Node = _theme_manager()
	if tm != null and tm.has_signal(&"theme_applied") and tm.is_connected(&"theme_applied", _on_theme_applied):
		tm.disconnect(&"theme_applied", _on_theme_applied)


## Combines the Label's intrinsic size with the four content margins so the
## button (and any container holding it) reserves room for the text plus its
## inset. custom_minimum_size still takes effect because BaseButton picks the
## per-axis maximum of custom_minimum_size and _get_minimum_size().
func _get_minimum_size() -> Vector2:
	var label_min: Vector2 = Vector2.ZERO
	if _label != null:
		label_min = _label.get_minimum_size()
	var horizontal: float = label_min.x + float(_eff_int(&"content_margin_left") + _eff_int(&"content_margin_right"))
	var vertical: float = label_min.y + float(_eff_int(&"content_margin_top") + _eff_int(&"content_margin_bottom"))
	return Vector2(maxf(0.0, horizontal), maxf(0.0, vertical))


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_refresh()


func _set(property: StringName, value: Variant) -> bool:
	if property == &"disabled":
		call_deferred("_refresh")
	return false


# --- State resolution ---------------------------------------------------------

func _refresh() -> void:
	if not _ready_done:
		return
	var state: VisualState = _resolve_state()
	_apply_state(state)


func _resolve_state() -> VisualState:
	if Engine.is_editor_hint():
		if preview_respects_disabled and disabled:
			return VisualState.DISABLED
		return preview_state
	if disabled:
		return VisualState.DISABLED
	if button_pressed or is_pressed():
		return VisualState.PRESSED
	if _hovered:
		return VisualState.HOVER
	if has_focus():
		return VisualState.FOCUSED
	return VisualState.NORMAL


func _apply_state(state: VisualState) -> void:
	if _ninepatch == null or _label == null or _outline_patch == null:
		return
	_ninepatch.modulate = _resolved_modulate_base()
	_label.add_theme_color_override(&"font_color", _label_color_for(state))
	var effect: AutomaticButtonStateEffect = _effect_for(state)
	var pivot_targets: Array[Control] = [_outline_patch, _ninepatch, _label]
	AutomaticButtonEffects.apply_visuals(effect, _ninepatch, _outline_patch, pivot_targets)
	_apply_state_offsets(effect)


## Compose each child Control's baseline anchor offset with the per-state
## translate (and the outline overlay's outward inset). The Label's baseline
## comes from content_margin_*; the two NinePatchRects baseline at zero.
## Called from _apply_state and from _apply_content_margins so a margin tweak
## immediately reflects in the visible Label without needing a refresh.
func _apply_state_offsets(effect: AutomaticButtonStateEffect) -> void:
	var t: Vector2 = AutomaticButtonEffects.resolve_translate(effect)
	var pad: float = AutomaticButtonEffects.resolve_outline_pad(effect)
	if _outline_patch != null:
		_outline_patch.offset_left = t.x - pad
		_outline_patch.offset_top = t.y - pad
		_outline_patch.offset_right = t.x + pad
		_outline_patch.offset_bottom = t.y + pad
	if _ninepatch != null:
		_ninepatch.offset_left = t.x
		_ninepatch.offset_top = t.y
		_ninepatch.offset_right = t.x
		_ninepatch.offset_bottom = t.y
	if _label != null:
		_label.offset_left = float(_eff_int(&"content_margin_left")) + t.x
		_label.offset_top = float(_eff_int(&"content_margin_top")) + t.y
		_label.offset_right = -float(_eff_int(&"content_margin_right")) + t.x
		_label.offset_bottom = -float(_eff_int(&"content_margin_bottom")) + t.y


# --- Effect resolution --------------------------------------------------------

## Resolve which AutomaticButtonStateEffect to apply for the given state. The
## per-instance / style export wins when set; otherwise the cached built-in
## default for the state is used. Returning a non-null effect keeps the apply
## helper from having to special-case the disabled-styling-but-no-effect case.
func _effect_for(state: VisualState) -> AutomaticButtonStateEffect:
	var prop: StringName = _effect_prop_for(state)
	var from_export: AutomaticButtonStateEffect = null
	if style != null:
		from_export = style.get(prop)
	if from_export == null:
		from_export = get(prop)
	if from_export != null:
		return from_export
	return _resolve_fallback_effect(state)


func _effect_prop_for(state: VisualState) -> StringName:
	match state:
		VisualState.HOVER:
			return &"effect_hover"
		VisualState.PRESSED:
			return &"effect_pressed"
		VisualState.DISABLED:
			return &"effect_disabled"
		VisualState.FOCUSED:
			return &"effect_focused"
		_:
			return &"effect_normal"


func _resolve_fallback_effect(state: VisualState) -> AutomaticButtonStateEffect:
	if _fallback_effects.has(state):
		return _fallback_effects[state]
	var made: AutomaticButtonStateEffect
	match state:
		VisualState.HOVER:
			made = AutomaticButtonStateEffect.make_default_hover()
		VisualState.PRESSED:
			made = AutomaticButtonStateEffect.make_default_pressed()
		VisualState.DISABLED:
			made = AutomaticButtonStateEffect.make_default_disabled()
		VisualState.FOCUSED:
			made = AutomaticButtonStateEffect.make_default_focused()
		_:
			made = AutomaticButtonStateEffect.make_default_normal()
	_fallback_effects[state] = made
	return made


func _label_color_for(state: VisualState) -> Color:
	match state:
		VisualState.HOVER:
			return _eff_color(&"label_color_hover")
		VisualState.PRESSED:
			return _eff_color(&"label_color_pressed")
		VisualState.DISABLED:
			return _eff_color(&"label_color_disabled")
		VisualState.FOCUSED:
			return _eff_color(&"label_color_focused")
		_:
			return _eff_color(&"label_color_normal")


# --- Visual application -------------------------------------------------------

func _apply_textures() -> void:
	if _ninepatch == null or _outline_patch == null:
		return
	var tex: Texture2D = _eff_texture(&"texture")
	_ninepatch.texture = tex
	_outline_patch.texture = tex


func _apply_patch_margins() -> void:
	if _ninepatch == null or _outline_patch == null:
		return
	var l: int = _eff_int(&"patch_margin_left")
	var t: int = _eff_int(&"patch_margin_top")
	var r: int = _eff_int(&"patch_margin_right")
	var b: int = _eff_int(&"patch_margin_bottom")
	_ninepatch.patch_margin_left = l
	_ninepatch.patch_margin_top = t
	_ninepatch.patch_margin_right = r
	_ninepatch.patch_margin_bottom = b
	_outline_patch.patch_margin_left = l
	_outline_patch.patch_margin_top = t
	_outline_patch.patch_margin_right = r
	_outline_patch.patch_margin_bottom = b


func _apply_patch_stretch() -> void:
	if _ninepatch == null or _outline_patch == null:
		return
	var h: NinePatchRect.AxisStretchMode = _eff_int(&"axis_stretch_horizontal")
	var v: NinePatchRect.AxisStretchMode = _eff_int(&"axis_stretch_vertical")
	_ninepatch.axis_stretch_horizontal = h
	_ninepatch.axis_stretch_vertical = v
	_outline_patch.axis_stretch_horizontal = h
	_outline_patch.axis_stretch_vertical = v


func _apply_content_margins() -> void:
	if _label == null:
		return
	## Pin the Label to fill the button so the content margin offsets are
	## interpreted relative to the button rect. Designers who want manual
	## label placement can leave all four content margins at 0 and drag the
	## Label child directly — non-zero margins overwrite that placement.
	## Offsets themselves are stamped by _apply_state_offsets so the per-state
	## translate composes with the margins without two paths fighting each
	## other.
	_label.anchor_left = 0.0
	_label.anchor_top = 0.0
	_label.anchor_right = 1.0
	_label.anchor_bottom = 1.0
	if _ready_done:
		_refresh()


func _apply_label_text() -> void:
	if _label == null:
		return
	_label.text = text
	update_minimum_size()


func _apply_label_font() -> void:
	if _label == null:
		return
	var eff_font: Font = _eff_font()
	if eff_font != null:
		_label.add_theme_font_override(&"font", eff_font)
	else:
		_label.remove_theme_font_override(&"font")
	_label.add_theme_font_size_override(&"font_size", _eff_int(&"font_size"))
	_label.add_theme_constant_override(&"outline_size", _eff_int(&"label_outline_size"))
	_label.add_theme_color_override(&"font_outline_color", _eff_color(&"label_outline_color"))
	update_minimum_size()


func _apply_label_alignment() -> void:
	if _label == null:
		return
	_label.horizontal_alignment = _eff_int(&"label_horizontal_alignment")
	_label.vertical_alignment = _eff_int(&"label_vertical_alignment")
	_label.autowrap_mode = _eff_int(&"label_autowrap")
	_label.clip_text = _eff_bool(&"label_clip_text")


# --- Style resolution ---------------------------------------------------------

## Each resolver picks the field from the assigned style resource when one is
## set, otherwise falls back to the per-instance export of the same name. The
## style and the button intentionally share field names so a single StringName
## can address either side via Object.get(), keeping the resolver one-liners.
func _eff_int(prop: StringName) -> int:
	if style != null:
		return int(style.get(prop))
	return int(get(prop))


func _eff_bool(prop: StringName) -> bool:
	if style != null:
		return bool(style.get(prop))
	return bool(get(prop))


func _eff_color(prop: StringName) -> Color:
	if style != null:
		return style.get(prop)
	return get(prop)


func _eff_texture(prop: StringName) -> Texture2D:
	if style != null:
		return style.get(prop)
	return get(prop)


func _eff_font() -> Font:
	if style != null:
		return style.font
	return font


func _on_style_changed() -> void:
	if not _ready_done:
		return
	_apply_textures()
	_apply_patch_margins()
	_apply_patch_stretch()
	_apply_content_margins()
	_apply_label_font()
	_apply_label_alignment()
	_refresh()
	update_minimum_size()


func _on_effect_changed() -> void:
	_refresh()


## Resolve the modulate applied to the main NinePatchRect. When
## use_theme_icon_color is on, the per-theme icon color replaces the authored
## modulate_base; the authored color's alpha is still honored so designers can
## fade an icon button independently of the theme tint.
func _resolved_modulate_base() -> Color:
	var base: Color = _eff_color(&"modulate_base")
	if not use_theme_icon_color:
		return base
	var tm: Node = _theme_manager()
	if tm == null or not tm.has_method(&"icon_color"):
		return base
	var raw: Variant = tm.call(&"icon_color")
	if typeof(raw) != TYPE_COLOR:
		return base
	var tinted: Color = raw
	return Color(tinted.r, tinted.g, tinted.b, tinted.a * base.a)


func _theme_manager() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null(^"ThemeManager")


func _connect_theme_signal() -> void:
	var tm: Node = _theme_manager()
	if tm == null or not tm.has_signal(&"theme_applied"):
		return
	var connected: bool = tm.is_connected(&"theme_applied", _on_theme_applied)
	if use_theme_icon_color and not connected:
		tm.connect(&"theme_applied", _on_theme_applied)
	elif not use_theme_icon_color and connected:
		tm.disconnect(&"theme_applied", _on_theme_applied)


func _on_theme_applied() -> void:
	if use_theme_icon_color:
		_refresh()


# --- Input wiring -------------------------------------------------------------

func _on_mouse_entered() -> void:
	_hovered = true
	_refresh()


func _on_mouse_exited() -> void:
	_hovered = false
	_refresh()


func _on_focus_changed() -> void:
	_refresh()


func _on_toggled(_pressed: bool) -> void:
	_refresh()


func _on_resized() -> void:
	## Pivot offsets depend on each Control's current size, so re-stamp them
	## (and the rest of the per-state offsets) whenever the button resizes —
	## otherwise rotation / scale around the center drifts off the new center.
	_refresh()


# --- Helpers for callers ------------------------------------------------------

func get_ninepatch() -> NinePatchRect:
	return _ninepatch


func get_outline_patch() -> NinePatchRect:
	return _outline_patch


func get_label() -> Label:
	return _label
