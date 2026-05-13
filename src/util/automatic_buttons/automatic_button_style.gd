@tool
class_name AutomaticButtonStyle
extends Resource
## Shared visual configuration for AutomaticButton. Mirrors the field names on
## the button itself so the button can resolve a property from either side via
## Object.get(), letting one StringName address both the per-instance export
## and the shared style. A single source texture drives all states; per-state
## variation comes from AutomaticButtonStateEffect resources.

@export_group("Texture")
## Single source texture used for every visual state. The same texture is also
## fed to the outline overlay NinePatchRect so the halo follows whatever
## silhouette the texture defines.
@export var texture: Texture2D = null:
	set(value):
		texture = value
		emit_changed()

@export_group("Patch Margins")
@export var patch_margin_left: int = 0:
	set(value):
		patch_margin_left = value
		emit_changed()
@export var patch_margin_top: int = 0:
	set(value):
		patch_margin_top = value
		emit_changed()
@export var patch_margin_right: int = 0:
	set(value):
		patch_margin_right = value
		emit_changed()
@export var patch_margin_bottom: int = 0:
	set(value):
		patch_margin_bottom = value
		emit_changed()
@export var axis_stretch_horizontal: NinePatchRect.AxisStretchMode = NinePatchRect.AXIS_STRETCH_MODE_STRETCH:
	set(value):
		axis_stretch_horizontal = value
		emit_changed()
@export var axis_stretch_vertical: NinePatchRect.AxisStretchMode = NinePatchRect.AXIS_STRETCH_MODE_STRETCH:
	set(value):
		axis_stretch_vertical = value
		emit_changed()

@export_group("Content Margins")
@export var content_margin_left: int = 0:
	set(value):
		content_margin_left = value
		emit_changed()
@export var content_margin_top: int = 0:
	set(value):
		content_margin_top = value
		emit_changed()
@export var content_margin_right: int = 0:
	set(value):
		content_margin_right = value
		emit_changed()
@export var content_margin_bottom: int = 0:
	set(value):
		content_margin_bottom = value
		emit_changed()

@export_group("Label")
@export var font: Font = null:
	set(value):
		font = value
		emit_changed()
@export var font_size: int = 16:
	set(value):
		font_size = max(1, value)
		emit_changed()
@export var label_color_normal: Color = Color.WHITE:
	set(value):
		label_color_normal = value
		emit_changed()
@export var label_color_hover: Color = Color.WHITE:
	set(value):
		label_color_hover = value
		emit_changed()
@export var label_color_pressed: Color = Color.WHITE:
	set(value):
		label_color_pressed = value
		emit_changed()
@export var label_color_disabled: Color = Color(1.0, 1.0, 1.0, 0.5):
	set(value):
		label_color_disabled = value
		emit_changed()
@export var label_color_focused: Color = Color.WHITE:
	set(value):
		label_color_focused = value
		emit_changed()
@export var label_outline_size: int = 0:
	set(value):
		label_outline_size = max(0, value)
		emit_changed()
@export var label_outline_color: Color = Color.BLACK:
	set(value):
		label_outline_color = value
		emit_changed()
@export var label_horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER:
	set(value):
		label_horizontal_alignment = value
		emit_changed()
@export var label_vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER:
	set(value):
		label_vertical_alignment = value
		emit_changed()
@export var label_autowrap: TextServer.AutowrapMode = TextServer.AUTOWRAP_OFF:
	set(value):
		label_autowrap = value
		emit_changed()
@export var label_clip_text: bool = false:
	set(value):
		label_clip_text = value
		emit_changed()

@export_group("Modulate")
## Base modulate applied to the main NinePatchRect after the HSV shader. Acts
## as a global tint; per-state recoloring should be done through the effect
## resources instead.
@export var modulate_base: Color = Color.WHITE:
	set(value):
		modulate_base = value
		emit_changed()

@export_group("State Effects")
## When null, the button falls back to its built-in default effect for that
## state. To strip a state to identity (no transform, no shader change),
## assign a fresh AutomaticButtonStateEffect with default values. Assignments
## rewire the sub-resource's `changed` signal into this style's `emit_changed`
## so live edits to the effect propagate to every button sharing this style.
@export var effect_normal: AutomaticButtonStateEffect = null:
	set(value):
		if effect_normal == value:
			return
		if effect_normal != null and effect_normal.changed.is_connected(emit_changed):
			effect_normal.changed.disconnect(emit_changed)
		effect_normal = value
		if value != null and not value.changed.is_connected(emit_changed):
			value.changed.connect(emit_changed)
		emit_changed()
@export var effect_hover: AutomaticButtonStateEffect = null:
	set(value):
		if effect_hover == value:
			return
		if effect_hover != null and effect_hover.changed.is_connected(emit_changed):
			effect_hover.changed.disconnect(emit_changed)
		effect_hover = value
		if value != null and not value.changed.is_connected(emit_changed):
			value.changed.connect(emit_changed)
		emit_changed()
@export var effect_pressed: AutomaticButtonStateEffect = null:
	set(value):
		if effect_pressed == value:
			return
		if effect_pressed != null and effect_pressed.changed.is_connected(emit_changed):
			effect_pressed.changed.disconnect(emit_changed)
		effect_pressed = value
		if value != null and not value.changed.is_connected(emit_changed):
			value.changed.connect(emit_changed)
		emit_changed()
@export var effect_disabled: AutomaticButtonStateEffect = null:
	set(value):
		if effect_disabled == value:
			return
		if effect_disabled != null and effect_disabled.changed.is_connected(emit_changed):
			effect_disabled.changed.disconnect(emit_changed)
		effect_disabled = value
		if value != null and not value.changed.is_connected(emit_changed):
			value.changed.connect(emit_changed)
		emit_changed()
@export var effect_focused: AutomaticButtonStateEffect = null:
	set(value):
		if effect_focused == value:
			return
		if effect_focused != null and effect_focused.changed.is_connected(emit_changed):
			effect_focused.changed.disconnect(emit_changed)
		effect_focused = value
		if value != null and not value.changed.is_connected(emit_changed):
			value.changed.connect(emit_changed)
		emit_changed()
