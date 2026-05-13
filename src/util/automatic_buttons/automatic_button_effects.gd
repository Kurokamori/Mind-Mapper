@tool
class_name AutomaticButtonEffects
extends RefCounted
## Shared application logic for AutomaticButtonStateEffect. Stamps shader
## uniforms onto the main and outline NinePatchRects, toggles outline
## visibility, and writes pivot / rotation / scale onto each pivot target so
## the visuals rotate around the button's center.
##
## Layout offsets (anchor-relative left / top / right / bottom) are NOT touched
## here because each owning button knows the baseline offsets of its child
## controls (e.g. a Label's content margins) and how the per-state translate
## composes with them. Owning buttons call resolve_outline_pad / translate
## helpers below to fold the effect into their own offset-stamping pass.

const COLOR_SHADER: Shader = preload("res://src/util/automatic_buttons/automatic_button_color.gdshader")
const OUTLINE_SHADER: Shader = preload("res://src/util/automatic_buttons/automatic_button_outline.gdshader")
## Resource meta key marking a ShaderMaterial as already cloned for the
## current button instance. Without this, ShaderMaterials embedded as
## sub-resources in a .tscn would be shared across every scene instance, so
## one button's state change would tint every other button at the same time.
const _OWNED_META: StringName = &"_auto_button_owned"


## Ensure `rect` carries an instance-owned ShaderMaterial bound to the HSV
## color shader and return it. The first call replaces or clones the material
## so subsequent uniform writes never bleed into other buttons that share the
## same packed scene; later calls reuse the owned material directly.
static func ensure_color_material(rect: NinePatchRect) -> ShaderMaterial:
	if rect == null:
		return null
	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if mat == null or mat.shader != COLOR_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = COLOR_SHADER
		mat.set_meta(_OWNED_META, true)
		rect.material = mat
	elif not mat.has_meta(_OWNED_META):
		mat = mat.duplicate() as ShaderMaterial
		mat.set_meta(_OWNED_META, true)
		rect.material = mat
	return mat


## Ensure `rect` carries an instance-owned ShaderMaterial bound to the outline
## shader and return it. Same instance-isolation strategy as
## ensure_color_material.
static func ensure_outline_material(rect: NinePatchRect) -> ShaderMaterial:
	if rect == null:
		return null
	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if mat == null or mat.shader != OUTLINE_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = OUTLINE_SHADER
		mat.set_meta(_OWNED_META, true)
		rect.material = mat
	elif not mat.has_meta(_OWNED_META):
		mat = mat.duplicate() as ShaderMaterial
		mat.set_meta(_OWNED_META, true)
		rect.material = mat
	return mat


## Push shader / visibility / pivot / rotation / scale for the given effect.
## A null effect is treated as identity. The owning button is responsible for
## composing the effect's translate and the outline pad into each control's
## anchor offsets — see resolve_outline_pad and resolve_translate.
static func apply_visuals(
		effect: AutomaticButtonStateEffect,
		main_rect: NinePatchRect,
		outline_rect: NinePatchRect,
		pivot_targets: Array[Control],
) -> void:
	var eff: AutomaticButtonStateEffect = effect
	if eff == null:
		eff = AutomaticButtonStateEffect.new()
	if main_rect != null:
		var color_mat: ShaderMaterial = ensure_color_material(main_rect)
		color_mat.set_shader_parameter(&"hue_shift", eff.hue_shift)
		color_mat.set_shader_parameter(&"saturation_mul", eff.saturation_mul)
		color_mat.set_shader_parameter(&"luminosity_mul", eff.luminosity_mul)
		color_mat.set_shader_parameter(&"alpha_mul", eff.alpha_mul)
	if outline_rect != null:
		if eff.has_outline():
			outline_rect.visible = true
			var outline_mat: ShaderMaterial = ensure_outline_material(outline_rect)
			outline_mat.set_shader_parameter(&"outline_color", eff.outline_color)
			outline_mat.set_shader_parameter(&"outline_alpha_mul", eff.outline_alpha_mul)
		else:
			outline_rect.visible = false
	for ctrl: Control in pivot_targets:
		if ctrl == null:
			continue
		ctrl.pivot_offset = ctrl.size * 0.5
		ctrl.rotation_degrees = eff.rotation_degrees
		ctrl.scale = eff.scale


## Reset everything apply_visuals would set back to identity. Layout offsets
## are still owned by the button and untouched here.
static func clear_visuals(
		main_rect: NinePatchRect,
		outline_rect: NinePatchRect,
		pivot_targets: Array[Control],
) -> void:
	if main_rect != null:
		main_rect.material = null
	if outline_rect != null:
		outline_rect.visible = false
		outline_rect.material = null
	for ctrl: Control in pivot_targets:
		if ctrl == null:
			continue
		ctrl.rotation_degrees = 0.0
		ctrl.scale = Vector2.ONE


## How far the outline overlay needs to extend past the main rect on every
## side, in pixels. 0 when the effect has no outline so the overlay collapses
## back to the main rect's bounds.
static func resolve_outline_pad(effect: AutomaticButtonStateEffect) -> float:
	if effect == null or not effect.has_outline():
		return 0.0
	return effect.outline_size


## Per-state pixel translate, or zero when the effect is null. Owning buttons
## add this to each control's baseline anchor offsets.
static func resolve_translate(effect: AutomaticButtonStateEffect) -> Vector2:
	if effect == null:
		return Vector2.ZERO
	return effect.translate
