@tool
class_name AutomaticButtonStateEffect
extends Resource
## Per-state visual effect applied to AutomaticButton (and optionally to
## NinePatchButton when its effects_enabled is on). Each field defaults to its
## identity value so an unset effect resource is a no-op. Setters re-emit the
## changed signal so consumers can rebind shader uniforms / transforms in real
## time without polling.

@export_group("Transform")
## Pixel offset added to the button's visual nodes. Positive x moves right,
## positive y moves down. Useful for "press down" feedback (translate.y > 0
## while pressed) without changing the button's hit rect.
@export var translate: Vector2 = Vector2.ZERO:
	set(value):
		translate = value
		emit_changed()
## Z-rotation in degrees applied around each transformed node's center pivot.
@export_range(-360.0, 360.0, 0.1) var rotation_degrees: float = 0.0:
	set(value):
		rotation_degrees = value
		emit_changed()
## Multiplicative scale applied around each transformed node's center pivot.
@export var scale: Vector2 = Vector2.ONE:
	set(value):
		scale = value
		emit_changed()

@export_group("Color")
## Fraction of the full color wheel the hue is rotated by. 0 leaves hue
## untouched; 0.5 inverts the hue.
@export_range(-1.0, 1.0, 0.001) var hue_shift: float = 0.0:
	set(value):
		hue_shift = value
		emit_changed()
## Multiplier applied to the source texel's HSV saturation. 0 = grayscale,
## 1 = unchanged, >1 boosts saturation up to fully clamped.
@export_range(0.0, 8.0, 0.01) var saturation_mul: float = 1.0:
	set(value):
		saturation_mul = max(0.0, value)
		emit_changed()
## Multiplier applied to the source texel's HSV value (luminosity). 0 = black,
## 1 = unchanged, >1 brightens up to fully clamped.
@export_range(0.0, 8.0, 0.01) var luminosity_mul: float = 1.0:
	set(value):
		luminosity_mul = max(0.0, value)
		emit_changed()
## Multiplier on the final pixel alpha. Lets the button fade independently of
## any per-pixel alpha already in the texture.
@export_range(0.0, 1.0, 0.001) var alpha_mul: float = 1.0:
	set(value):
		alpha_mul = clampf(value, 0.0, 1.0)
		emit_changed()

@export_group("Outline")
## Size in pixels of the outline halo around the button. The outline overlay
## NinePatchRect is enlarged by this amount on every side; 0 disables the
## overlay entirely so no extra draw cost is paid.
@export_range(0.0, 64.0, 0.5) var outline_size: float = 0.0:
	set(value):
		outline_size = max(0.0, value)
		emit_changed()
## Tint of the outline halo. Alpha is honored — set to fully transparent to
## suppress the outline without resetting outline_size.
@export var outline_color: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		outline_color = value
		emit_changed()
## Additional multiplier on the outline's alpha so designers can fade it in
## or out without editing outline_color directly.
@export_range(0.0, 1.0, 0.001) var outline_alpha_mul: float = 1.0:
	set(value):
		outline_alpha_mul = clampf(value, 0.0, 1.0)
		emit_changed()


## True when the effect would cause any visible change versus a fresh, default
## resource. Used by the button helper to skip outline overlay work entirely
## for "off" states without callers having to inspect every field by hand.
func has_visual_effect() -> bool:
	return translate != Vector2.ZERO \
			or not is_equal_approx(rotation_degrees, 0.0) \
			or scale != Vector2.ONE \
			or not is_equal_approx(hue_shift, 0.0) \
			or not is_equal_approx(saturation_mul, 1.0) \
			or not is_equal_approx(luminosity_mul, 1.0) \
			or not is_equal_approx(alpha_mul, 1.0) \
			or has_outline()


func has_outline() -> bool:
	return outline_size > 0.0 \
			and outline_color.a > 0.0 \
			and outline_alpha_mul > 0.0


# --- Default factories --------------------------------------------------------

## Identity effect — equivalent to a fresh `new()`, but explicit at the call
## site. Used by NinePatchButton as the off-by-default value for every state.
static func make_identity() -> AutomaticButtonStateEffect:
	return AutomaticButtonStateEffect.new()


## AutomaticButton's default for the NORMAL state — leaves the texture as
## authored so designers see their source art unchanged at rest.
static func make_default_normal() -> AutomaticButtonStateEffect:
	return AutomaticButtonStateEffect.new()


## AutomaticButton's default for DISABLED — heavy desaturation so the button
## reads as "ghosted" without changing color or fading the sprite away.
static func make_default_disabled() -> AutomaticButtonStateEffect:
	var e: AutomaticButtonStateEffect = AutomaticButtonStateEffect.new()
	e.saturation_mul = 0.2
	return e


## AutomaticButton's default for PRESSED — saturation up, luminosity down,
## a 5px orange halo, and a tiny vertical nudge so the button feels
## physically pushed.
static func make_default_pressed() -> AutomaticButtonStateEffect:
	var e: AutomaticButtonStateEffect = AutomaticButtonStateEffect.new()
	e.saturation_mul = 1.3
	e.luminosity_mul = 0.85
	e.translate = Vector2(0.0, 2.0)
	e.outline_size = 5.0
	e.outline_color = Color(1.0, 0.55, 0.1, 1.0)
	return e


## AutomaticButton's default for HOVER — saturation and luminosity boosted,
## a 5px yellow halo, and a small upward lift so the button feels alive.
static func make_default_hover() -> AutomaticButtonStateEffect:
	var e: AutomaticButtonStateEffect = AutomaticButtonStateEffect.new()
	e.saturation_mul = 1.2
	e.luminosity_mul = 1.15
	e.translate = Vector2(0.0, -1.0)
	e.scale = Vector2(1.02, 1.02)
	e.outline_size = 5.0
	e.outline_color = Color(1.0, 0.95, 0.2, 1.0)
	return e


## AutomaticButton's default for FOCUSED — same look as hover so keyboard /
## gamepad navigation feels identical to mouse-over without doubling up.
static func make_default_focused() -> AutomaticButtonStateEffect:
	return make_default_hover()
