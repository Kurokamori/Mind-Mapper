class_name ThemeVariants
extends RefCounted

## Centralized library of semantic theme_type_variations applied on top of
## the base dark/light themes. ThemeManager calls apply_to_theme() inside
## build_theme(), so every variant tracks the active palette/accent.
##
## To register a new variant: add a key to VARIANT_PANELS (panel styles) or
## VARIANT_BUTTONS (button styles) or VARIANT_LABELS (label colors), then
## reference it from a scene via `theme_type_variation = "VariantName"`.

const VARIANT_TOOLBAR_PANEL: String = "ToolbarPanel"
const VARIANT_BREADCRUMB_PANEL: String = "BreadcrumbPanel"
const VARIANT_SIDEBAR_PANEL: String = "SidebarPanel"
const VARIANT_MINIMAP_PANEL: String = "MinimapPanel"
const VARIANT_CARD_PANEL: String = "CardPanel"
const VARIANT_OVERLAY_PANEL: String = "OverlayPanel"
const VARIANT_BOTTOM_SHEET_PANEL: String = "BottomSheetPanel"
const VARIANT_MOBILE_TOOLBAR_PANEL: String = "MobileToolbarPanel"
const VARIANT_MOBILE_CHROME_PANEL: String = "MobileChromePanel"
const VARIANT_EXPANSION_ROW_PANEL: String = "ExpansionRowPanel"
const VARIANT_ZOOM_OVERLAY_PANEL: String = "ZoomOverlayPanel"

const VARIANT_SECTION_HEADER: String = "SectionHeader"
const VARIANT_FIELD_LABEL: String = "FieldLabel"
const VARIANT_MUTED_LABEL: String = "MutedLabel"
const VARIANT_HERO_TITLE: String = "HeroTitle"
const VARIANT_HERO_SUBTITLE: String = "HeroSubtitle"
const VARIANT_BREADCRUMB_LABEL: String = "BreadcrumbLabel"
const VARIANT_TOOLBAR_TITLE_LABEL: String = "ToolbarTitleLabel"

const VARIANT_ICON_BUTTON: String = "IconButton"
const VARIANT_FLAT_BUTTON: String = "FlatButton"
const VARIANT_PILL_BUTTON: String = "Pill"
const VARIANT_ACCENT_BUTTON: String = "AccentButton"
const VARIANT_GHOST_BUTTON: String = "GhostButton"
const VARIANT_DANGER_BUTTON: String = "DangerButton"
const VARIANT_TOOLBAR_GROUP_BUTTON: String = "ToolbarGroupButton"
const VARIANT_BREADCRUMB_BUTTON: String = "BreadcrumbButton"
const VARIANT_CLOSE_BUTTON: String = "CloseIconButton"

const VARIANT_MOBILE_BUTTON: String = "MobileButton"
const VARIANT_MOBILE_PRIMARY_BUTTON: String = "MobilePrimaryButton"
const VARIANT_MOBILE_GHOST_BUTTON: String = "MobileGhostButton"
const VARIANT_MOBILE_GROUP_BUTTON: String = "MobileGroupButton"
const VARIANT_BOARD_CARD_BUTTON: String = "BoardCardButton"

const VARIANT_INSPECTOR_SECTION_PANEL: String = "InspectorSectionPanel"
const VARIANT_INSPECTOR_ACCENT_STRIP: String = "InspectorAccentStrip"
const VARIANT_INSPECTOR_DIVIDER: String = "InspectorDivider"
const VARIANT_INSPECTOR_TITLE_LABEL: String = "InspectorTitleLabel"
const VARIANT_INSPECTOR_TYPE_BADGE: String = "InspectorTypeBadge"
const VARIANT_INSPECTOR_SUBSECTION_LABEL: String = "InspectorSubsectionLabel"
const VARIANT_INSPECTOR_FIELD_LABEL: String = "InspectorFieldLabel"
const VARIANT_INSPECTOR_HINT_LABEL: String = "InspectorHintLabel"
const VARIANT_INSPECTOR_VALUE_LABEL: String = "InspectorValueLabel"
const VARIANT_INSPECTOR_ROW_PANEL: String = "InspectorRowPanel"
const VARIANT_INSPECTOR_TEXT_AREA_PANEL: String = "InspectorTextAreaPanel"
const VARIANT_INSPECTOR_SWATCH_BUTTON: String = "InspectorSwatchButton"

const VARIANT_INSET_SCROLL_PANEL: String = "InsetScrollPanel"
const VARIANT_PROMINENT_SCROLLBAR: String = "ProminentScrollbar"

const PANEL_CORNER_RADIUS: int = 4
const BUTTON_CORNER_RADIUS: int = 3
const INPUT_CORNER_RADIUS: int = 3
const PILL_CORNER_RADIUS: int = 999

const PANEL_PADDING_H: int = 10
const PANEL_PADDING_V: int = 8
const BUTTON_PADDING_H: int = 10
const BUTTON_PADDING_V: int = 4
const INPUT_PADDING_H: int = 8
const INPUT_PADDING_V: int = 5

const MOBILE_BUTTON_PADDING_H: int = 14
const MOBILE_BUTTON_PADDING_V: int = 10
const MOBILE_PANEL_PADDING_H: int = 14
const MOBILE_PANEL_PADDING_V: int = 10

const BORDER_WIDTH: int = 1
const BORDER_WIDTH_BOLD: int = 2

const SHADOW_SOFT: float = 0.18
const SHADOW_SOFT_SIZE: int = 6

const PANEL_VARIATION_BASE: String = "PanelContainer"
const BUTTON_VARIATION_BASE: String = "Button"
const LABEL_VARIATION_BASE: String = "Label"
const MENU_BUTTON_VARIATION_BASE: String = "MenuButton"


static func apply_to_theme(theme: Theme, palette: Dictionary, accent: Color) -> void:
	if theme == null:
		return
	var ctx: Dictionary = _resolve_context(palette, accent)
	_apply_base_tightening(theme, ctx)
	_apply_panel_variants(theme, ctx)
	_apply_button_variants(theme, ctx)
	_apply_label_variants(theme, ctx)
	_apply_inspector_variants(theme, ctx)
	_apply_container_separations(theme)


static func _resolve_context(palette: Dictionary, accent: Color) -> Dictionary:
	var bg: Color = palette.get("bg", Color(0.08, 0.08, 0.10))
	var panel: Color = palette.get("panel", Color(0.11, 0.11, 0.14))
	var fg: Color = palette.get("fg", Color(0.92, 0.92, 0.94))
	var subtle: Color = palette.get("subtle", Color(0.28, 0.28, 0.34))
	var is_light: bool = _is_light_palette(bg, fg)
	var panel_raised: Color = panel.lerp(fg, 0.06 if not is_light else 0.04)
	var panel_sunken: Color = panel.lerp(bg, 0.45)
	var border_subtle: Color = subtle.lerp(panel, 0.55)
	var border_accent: Color = accent.lerp(panel, 0.45)
	var hover_bg: Color = panel.lerp(fg, 0.08 if not is_light else 0.06)
	var pressed_bg: Color = panel.lerp(accent, 0.30)
	var fg_muted: Color = fg.lerp(panel, 0.40)
	var fg_dim: Color = fg.lerp(panel, 0.60)
	var accent_fg: Color = Color(1, 1, 1, 1) if _luminance(accent) < 0.55 else Color(0.06, 0.07, 0.10, 1)
	var shadow: Color = Color(0, 0, 0, SHADOW_SOFT if not is_light else SHADOW_SOFT * 0.75)
	return {
		"bg": bg,
		"panel": panel,
		"panel_raised": panel_raised,
		"panel_sunken": panel_sunken,
		"fg": fg,
		"fg_muted": fg_muted,
		"fg_dim": fg_dim,
		"subtle": subtle,
		"border_subtle": border_subtle,
		"border_accent": border_accent,
		"hover_bg": hover_bg,
		"pressed_bg": pressed_bg,
		"accent": accent,
		"accent_fg": accent_fg,
		"shadow": shadow,
		"is_light": is_light,
	}


static func _is_light_palette(bg: Color, fg: Color) -> bool:
	return _luminance(bg) > _luminance(fg)


static func _luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


static func _make_flat(bg: Color, border: Color, corner: int, padding_h: int, padding_v: int, border_w: int = BORDER_WIDTH) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(corner)
	sb.content_margin_left = padding_h
	sb.content_margin_right = padding_h
	sb.content_margin_top = padding_v
	sb.content_margin_bottom = padding_v
	sb.anti_aliasing = true
	return sb


static func _make_empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


static func _apply_base_tightening(theme: Theme, ctx: Dictionary) -> void:
	var panel: Color = ctx.panel
	var border: Color = ctx.border_subtle
	var hover: Color = ctx.hover_bg
	var pressed: Color = ctx.pressed_bg
	var input_bg: Color = ctx.panel_sunken
	var accent: Color = ctx.accent
	var btn_normal: StyleBoxFlat = _make_flat(panel.lerp(ctx.fg, 0.04), border, BUTTON_CORNER_RADIUS, BUTTON_PADDING_H, BUTTON_PADDING_V)
	var btn_hover: StyleBoxFlat = _make_flat(hover, ctx.border_accent.lerp(border, 0.5), BUTTON_CORNER_RADIUS, BUTTON_PADDING_H, BUTTON_PADDING_V)
	var btn_pressed: StyleBoxFlat = _make_flat(pressed, ctx.border_accent, BUTTON_CORNER_RADIUS, BUTTON_PADDING_H, BUTTON_PADDING_V)
	var btn_disabled: StyleBoxFlat = _make_flat(panel.lerp(ctx.bg, 0.35), border.lerp(panel, 0.4), BUTTON_CORNER_RADIUS, BUTTON_PADDING_H, BUTTON_PADDING_V)
	var btn_focus: StyleBoxFlat = _make_flat(Color(0, 0, 0, 0), accent.lerp(ctx.fg, 0.10), BUTTON_CORNER_RADIUS, BUTTON_PADDING_H, BUTTON_PADDING_V, BORDER_WIDTH_BOLD)
	btn_focus.draw_center = false
	for cls: String in ["Button", "MenuButton", "OptionButton", "ColorPickerButton"]:
		theme.set_stylebox("normal", cls, btn_normal)
		theme.set_stylebox("hover", cls, btn_hover)
		theme.set_stylebox("pressed", cls, btn_pressed)
		theme.set_stylebox("disabled", cls, btn_disabled)
		theme.set_stylebox("focus", cls, btn_focus)
		if cls in ["Button", "OptionButton"]:
			theme.set_stylebox("hover_pressed", cls, btn_pressed)
			theme.set_stylebox("normal_mirrored", cls, btn_normal)
			theme.set_stylebox("hover_mirrored", cls, btn_hover)
			theme.set_stylebox("pressed_mirrored", cls, btn_pressed)
			theme.set_stylebox("disabled_mirrored", cls, btn_disabled)
			theme.set_stylebox("hover_pressed_mirrored", cls, btn_pressed)

	var panel_sb: StyleBoxFlat = _make_flat(panel, border, PANEL_CORNER_RADIUS, PANEL_PADDING_H, PANEL_PADDING_V)
	theme.set_stylebox("panel", "PanelContainer", panel_sb)
	theme.set_stylebox("panel", "Panel", panel_sb)

	var input_normal: StyleBoxFlat = _make_flat(input_bg, border, INPUT_CORNER_RADIUS, INPUT_PADDING_H, INPUT_PADDING_V)
	input_normal.bg_color.a = 0.0
	var input_focus: StyleBoxFlat = _make_flat(input_bg, accent, INPUT_CORNER_RADIUS, INPUT_PADDING_H, INPUT_PADDING_V, BORDER_WIDTH_BOLD)
	input_focus.bg_color.a = 0.0
	var input_readonly: StyleBoxFlat = _make_flat(input_bg, border.lerp(panel, 0.35), INPUT_CORNER_RADIUS, INPUT_PADDING_H, INPUT_PADDING_V)
	input_readonly.bg_color.a = 0.0
	for cls: String in ["LineEdit", "TextEdit", "CodeEdit"]:
		theme.set_stylebox("normal", cls, input_normal)
		theme.set_stylebox("focus", cls, input_focus)
		theme.set_stylebox("read_only", cls, input_readonly)

	var popup_sb: StyleBoxFlat = _make_flat(panel.lerp(ctx.bg, 0.18), border, PANEL_CORNER_RADIUS, 6, 6)
	popup_sb.shadow_color = ctx.shadow
	popup_sb.shadow_size = SHADOW_SOFT_SIZE
	theme.set_stylebox("panel", "PopupMenu", popup_sb)
	theme.set_stylebox("panel_disabled", "PopupMenu", popup_sb)
	theme.set_stylebox("panel", "PopupPanel", popup_sb)

	var window_sb: StyleBoxFlat = _make_flat(ctx.bg, border, PANEL_CORNER_RADIUS + 2, 12, 12, BORDER_WIDTH_BOLD)
	window_sb.shadow_color = Color(0, 0, 0, 0.42)
	window_sb.shadow_size = 8
	theme.set_stylebox("panel", "AcceptDialog", window_sb)
	theme.set_stylebox("panel", "ConfirmationDialog", window_sb)

	theme.set_color("font_color", "Label", ctx.fg)
	theme.set_color("font_color", "Button", ctx.fg)
	theme.set_color("font_hover_color", "Button", ctx.fg.lerp(Color.WHITE, 0.10))
	theme.set_color("font_pressed_color", "Button", ctx.accent_fg if _luminance(ctx.pressed_bg) < 0.4 else ctx.fg)


static func _apply_panel_variants(theme: Theme, ctx: Dictionary) -> void:
	var panel: Color = ctx.panel
	var border: Color = ctx.border_subtle
	var accent: Color = ctx.accent

	_register_variation(theme, VARIANT_TOOLBAR_PANEL, PANEL_VARIATION_BASE)
	var toolbar_sb: StyleBoxFlat = _make_flat(panel.lerp(ctx.bg, 0.15), border.lerp(panel, 0.4), PANEL_CORNER_RADIUS, 10, 6)
	toolbar_sb.border_width_top = 0
	toolbar_sb.border_width_left = 0
	toolbar_sb.border_width_right = 0
	toolbar_sb.corner_radius_top_left = 0
	toolbar_sb.corner_radius_top_right = 0
	theme.set_stylebox("panel", VARIANT_TOOLBAR_PANEL, toolbar_sb)

	_register_variation(theme, VARIANT_EXPANSION_ROW_PANEL, PANEL_VARIATION_BASE)
	var exp_sb: StyleBoxFlat = _make_flat(panel.lerp(ctx.bg, 0.10), border.lerp(panel, 0.5), PANEL_CORNER_RADIUS, 10, 6)
	exp_sb.border_width_top = 0
	exp_sb.corner_radius_top_left = 0
	exp_sb.corner_radius_top_right = 0
	theme.set_stylebox("panel", VARIANT_EXPANSION_ROW_PANEL, exp_sb)

	_register_variation(theme, VARIANT_BREADCRUMB_PANEL, PANEL_VARIATION_BASE)
	var bc_sb: StyleBoxFlat = _make_flat(panel.lerp(ctx.bg, 0.30), Color(0, 0, 0, 0), PANEL_CORNER_RADIUS, 12, 2, 0)
	bc_sb.bg_color.a = 0.85
	bc_sb.corner_radius_top_left = 0
	bc_sb.corner_radius_top_right = 0
	theme.set_stylebox("panel", VARIANT_BREADCRUMB_PANEL, bc_sb)

	_register_variation(theme, VARIANT_SIDEBAR_PANEL, PANEL_VARIATION_BASE)
	var sb_sidebar: StyleBoxFlat = _make_flat(panel, border, PANEL_CORNER_RADIUS, 10, 10)
	sb_sidebar.shadow_color = ctx.shadow
	sb_sidebar.shadow_size = SHADOW_SOFT_SIZE
	sb_sidebar.shadow_offset = Vector2(0, 2)
	theme.set_stylebox("panel", VARIANT_SIDEBAR_PANEL, sb_sidebar)

	_register_variation(theme, VARIANT_MINIMAP_PANEL, PANEL_VARIATION_BASE)
	var sb_mm: StyleBoxFlat = _make_flat(panel.lerp(ctx.bg, 0.15), border.lerp(accent, 0.10), PANEL_CORNER_RADIUS, 8, 6)
	sb_mm.bg_color.a = 0.92
	sb_mm.shadow_color = ctx.shadow
	sb_mm.shadow_size = SHADOW_SOFT_SIZE
	sb_mm.shadow_offset = Vector2(0, 2)
	theme.set_stylebox("panel", VARIANT_MINIMAP_PANEL, sb_mm)

	_register_variation(theme, VARIANT_ZOOM_OVERLAY_PANEL, PANEL_VARIATION_BASE)
	var sb_zoom: StyleBoxFlat = _make_flat(panel.lerp(ctx.bg, 0.10), border.lerp(panel, 0.30), PANEL_CORNER_RADIUS, 6, 8)
	sb_zoom.bg_color.a = 0.92
	sb_zoom.shadow_color = ctx.shadow
	sb_zoom.shadow_size = SHADOW_SOFT_SIZE
	sb_zoom.shadow_offset = Vector2(0, 2)
	theme.set_stylebox("panel", VARIANT_ZOOM_OVERLAY_PANEL, sb_zoom)

	_register_variation(theme, VARIANT_CARD_PANEL, PANEL_VARIATION_BASE)
	var sb_card: StyleBoxFlat = _make_flat(panel.lerp(ctx.fg, 0.04), border.lerp(panel, 0.35), PANEL_CORNER_RADIUS, 14, 12)
	theme.set_stylebox("panel", VARIANT_CARD_PANEL, sb_card)

	_register_variation(theme, VARIANT_OVERLAY_PANEL, PANEL_VARIATION_BASE)
	var sb_overlay: StyleBoxFlat = _make_flat(panel, border, PANEL_CORNER_RADIUS + 2, 14, 14, BORDER_WIDTH_BOLD)
	sb_overlay.shadow_color = Color(0, 0, 0, 0.45)
	sb_overlay.shadow_size = 12
	sb_overlay.shadow_offset = Vector2(0, 4)
	theme.set_stylebox("panel", VARIANT_OVERLAY_PANEL, sb_overlay)

	_register_variation(theme, VARIANT_BOTTOM_SHEET_PANEL, PANEL_VARIATION_BASE)
	var sb_sheet: StyleBoxFlat = _make_flat(panel.lerp(ctx.fg, 0.02), border.lerp(panel, 0.3), PANEL_CORNER_RADIUS + 8, 16, 12)
	sb_sheet.corner_radius_bottom_left = 0
	sb_sheet.corner_radius_bottom_right = 0
	sb_sheet.shadow_color = Color(0, 0, 0, 0.40)
	sb_sheet.shadow_size = 12
	sb_sheet.shadow_offset = Vector2(0, -3)
	theme.set_stylebox("panel", VARIANT_BOTTOM_SHEET_PANEL, sb_sheet)

	_register_variation(theme, VARIANT_MOBILE_TOOLBAR_PANEL, PANEL_VARIATION_BASE)
	var sb_mtb: StyleBoxFlat = _make_flat(panel.lerp(ctx.bg, 0.10), border.lerp(panel, 0.3), PANEL_CORNER_RADIUS, MOBILE_PANEL_PADDING_H, MOBILE_PANEL_PADDING_V)
	sb_mtb.shadow_color = ctx.shadow
	sb_mtb.shadow_size = SHADOW_SOFT_SIZE
	sb_mtb.shadow_offset = Vector2(0, 2)
	theme.set_stylebox("panel", VARIANT_MOBILE_TOOLBAR_PANEL, sb_mtb)

	_register_variation(theme, VARIANT_MOBILE_CHROME_PANEL, PANEL_VARIATION_BASE)
	var sb_mch: StyleBoxFlat = _make_flat(panel.lerp(ctx.bg, 0.20), border.lerp(panel, 0.4), PANEL_CORNER_RADIUS, MOBILE_PANEL_PADDING_H, 8)
	theme.set_stylebox("panel", VARIANT_MOBILE_CHROME_PANEL, sb_mch)


static func _apply_button_variants(theme: Theme, ctx: Dictionary) -> void:
	var fg: Color = ctx.fg
	var accent: Color = ctx.accent
	var border: Color = ctx.border_subtle

	# IconButton — square, transparent, hover shows a subtle bg
	_register_variation(theme, VARIANT_ICON_BUTTON, BUTTON_VARIATION_BASE)
	_apply_button_states(theme, VARIANT_ICON_BUTTON,
		_make_empty(),
		_make_flat(ctx.hover_bg, Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS, 4, 4, 0),
		_make_flat(ctx.pressed_bg, Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS, 4, 4, 0),
		_make_empty(),
		_make_flat(Color(0, 0, 0, 0), accent.lerp(fg, 0.10), BUTTON_CORNER_RADIUS, 4, 4, BORDER_WIDTH_BOLD)
	)
	theme.set_color("font_color", VARIANT_ICON_BUTTON, ctx.fg_muted)
	theme.set_color("font_hover_color", VARIANT_ICON_BUTTON, fg)
	theme.set_color("font_pressed_color", VARIANT_ICON_BUTTON, fg)

	# FlatButton — transparent normal, subtle bg on hover/pressed
	_register_variation(theme, VARIANT_FLAT_BUTTON, BUTTON_VARIATION_BASE)
	_apply_button_states(theme, VARIANT_FLAT_BUTTON,
		_make_flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS, BUTTON_PADDING_H, BUTTON_PADDING_V, 0),
		_make_flat(ctx.hover_bg, Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS, BUTTON_PADDING_H, BUTTON_PADDING_V, 0),
		_make_flat(ctx.pressed_bg, Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS, BUTTON_PADDING_H, BUTTON_PADDING_V, 0),
		_make_flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS, BUTTON_PADDING_H, BUTTON_PADDING_V, 0),
		_make_flat(Color(0, 0, 0, 0), accent.lerp(fg, 0.10), BUTTON_CORNER_RADIUS, BUTTON_PADDING_H, BUTTON_PADDING_V, BORDER_WIDTH_BOLD)
	)
	theme.set_color("font_color", VARIANT_FLAT_BUTTON, ctx.fg)
	theme.set_color("font_hover_color", VARIANT_FLAT_BUTTON, fg.lerp(Color.WHITE, 0.10))
	theme.set_color("font_pressed_color", VARIANT_FLAT_BUTTON, fg)

	# CloseIconButton — flat with red-ish hover
	_register_variation(theme, VARIANT_CLOSE_BUTTON, BUTTON_VARIATION_BASE)
	var close_hover: Color = Color(0.95, 0.36, 0.36, 1)
	_apply_button_states(theme, VARIANT_CLOSE_BUTTON,
		_make_empty(),
		_make_flat(close_hover, Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS, 4, 2, 0),
		_make_flat(close_hover.darkened(0.15), Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS, 4, 2, 0),
		_make_empty(),
		_make_flat(Color(0, 0, 0, 0), close_hover, BUTTON_CORNER_RADIUS, 4, 2, BORDER_WIDTH_BOLD)
	)
	theme.set_color("font_color", VARIANT_CLOSE_BUTTON, ctx.fg_muted)
	theme.set_color("font_hover_color", VARIANT_CLOSE_BUTTON, Color.WHITE)
	theme.set_color("font_pressed_color", VARIANT_CLOSE_BUTTON, Color.WHITE)

	# ToolbarGroupButton — header buttons in the toolbar that expand groups
	_register_variation(theme, VARIANT_TOOLBAR_GROUP_BUTTON, BUTTON_VARIATION_BASE)
	_apply_button_states(theme, VARIANT_TOOLBAR_GROUP_BUTTON,
		_make_flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS, 12, 6, 0),
		_make_flat(ctx.hover_bg, Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS, 12, 6, 0),
		_make_flat(accent.lerp(ctx.panel, 0.65), accent.lerp(ctx.fg, 0.10), BUTTON_CORNER_RADIUS, 12, 6, BORDER_WIDTH),
		_make_flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS, 12, 6, 0),
		_make_flat(Color(0, 0, 0, 0), accent.lerp(fg, 0.10), BUTTON_CORNER_RADIUS, 12, 6, BORDER_WIDTH_BOLD)
	)
	theme.set_color("font_color", VARIANT_TOOLBAR_GROUP_BUTTON, ctx.fg)
	theme.set_color("font_hover_color", VARIANT_TOOLBAR_GROUP_BUTTON, fg.lerp(Color.WHITE, 0.10))
	theme.set_color("font_pressed_color", VARIANT_TOOLBAR_GROUP_BUTTON, fg)

	# BreadcrumbButton — entirely flat, accent on hover
	_register_variation(theme, VARIANT_BREADCRUMB_BUTTON, BUTTON_VARIATION_BASE)
	_apply_button_states(theme, VARIANT_BREADCRUMB_BUTTON,
		_make_flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS, 8, 2, 0),
		_make_flat(ctx.hover_bg, Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS, 8, 2, 0),
		_make_flat(ctx.pressed_bg, Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS, 8, 2, 0),
		_make_flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS, 8, 2, 0),
		_make_flat(Color(0, 0, 0, 0), accent.lerp(fg, 0.10), BUTTON_CORNER_RADIUS, 8, 2, BORDER_WIDTH)
	)
	theme.set_color("font_color", VARIANT_BREADCRUMB_BUTTON, ctx.fg_muted)
	theme.set_color("font_hover_color", VARIANT_BREADCRUMB_BUTTON, fg)
	theme.set_color("font_pressed_color", VARIANT_BREADCRUMB_BUTTON, fg)

	# Pill button — fully rounded, toggle-shaped
	_register_variation(theme, VARIANT_PILL_BUTTON, BUTTON_VARIATION_BASE)
	_apply_button_states(theme, VARIANT_PILL_BUTTON,
		_make_flat(ctx.panel.lerp(ctx.fg, 0.04), border, PILL_CORNER_RADIUS, 12, 4),
		_make_flat(ctx.hover_bg, ctx.border_accent.lerp(border, 0.5), PILL_CORNER_RADIUS, 12, 4),
		_make_flat(accent.lerp(ctx.panel, 0.45), accent, PILL_CORNER_RADIUS, 12, 4),
		_make_flat(ctx.panel.lerp(ctx.bg, 0.4), border.lerp(ctx.panel, 0.4), PILL_CORNER_RADIUS, 12, 4),
		_make_flat(Color(0, 0, 0, 0), accent.lerp(fg, 0.10), PILL_CORNER_RADIUS, 12, 4, BORDER_WIDTH_BOLD)
	)

	# AccentButton — primary CTA
	_register_variation(theme, VARIANT_ACCENT_BUTTON, BUTTON_VARIATION_BASE)
	var accent_normal: StyleBoxFlat = _make_flat(accent, accent.lerp(ctx.fg, 0.10), BUTTON_CORNER_RADIUS, 14, 6, 0)
	var accent_hover: StyleBoxFlat = _make_flat(accent.lerp(Color.WHITE, 0.10), accent.lerp(ctx.fg, 0.15), BUTTON_CORNER_RADIUS, 14, 6, 0)
	var accent_pressed: StyleBoxFlat = _make_flat(accent.lerp(Color.BLACK, 0.15), accent.lerp(ctx.fg, 0.20), BUTTON_CORNER_RADIUS, 14, 6, 0)
	var accent_disabled: StyleBoxFlat = _make_flat(accent.lerp(ctx.panel, 0.65), accent.lerp(ctx.panel, 0.55), BUTTON_CORNER_RADIUS, 14, 6, 0)
	_apply_button_states(theme, VARIANT_ACCENT_BUTTON, accent_normal, accent_hover, accent_pressed, accent_disabled,
		_make_flat(Color(0, 0, 0, 0), Color.WHITE, BUTTON_CORNER_RADIUS, 14, 6, BORDER_WIDTH_BOLD))
	theme.set_color("font_color", VARIANT_ACCENT_BUTTON, ctx.accent_fg)
	theme.set_color("font_hover_color", VARIANT_ACCENT_BUTTON, ctx.accent_fg)
	theme.set_color("font_pressed_color", VARIANT_ACCENT_BUTTON, ctx.accent_fg)
	theme.set_color("font_disabled_color", VARIANT_ACCENT_BUTTON, ctx.accent_fg.lerp(ctx.panel, 0.4))

	# GhostButton — outline only
	_register_variation(theme, VARIANT_GHOST_BUTTON, BUTTON_VARIATION_BASE)
	_apply_button_states(theme, VARIANT_GHOST_BUTTON,
		_make_flat(Color(0, 0, 0, 0), border, BUTTON_CORNER_RADIUS, 12, 5),
		_make_flat(ctx.hover_bg, ctx.border_accent.lerp(border, 0.5), BUTTON_CORNER_RADIUS, 12, 5),
		_make_flat(ctx.pressed_bg, ctx.border_accent, BUTTON_CORNER_RADIUS, 12, 5),
		_make_flat(Color(0, 0, 0, 0), border.lerp(ctx.panel, 0.4), BUTTON_CORNER_RADIUS, 12, 5),
		_make_flat(Color(0, 0, 0, 0), accent.lerp(fg, 0.10), BUTTON_CORNER_RADIUS, 12, 5, BORDER_WIDTH_BOLD)
	)

	# DangerButton — red accent
	_register_variation(theme, VARIANT_DANGER_BUTTON, BUTTON_VARIATION_BASE)
	var danger: Color = Color(0.86, 0.32, 0.32)
	_apply_button_states(theme, VARIANT_DANGER_BUTTON,
		_make_flat(danger, danger.lerp(ctx.fg, 0.10), BUTTON_CORNER_RADIUS, 14, 6, 0),
		_make_flat(danger.lerp(Color.WHITE, 0.10), danger.lerp(ctx.fg, 0.20), BUTTON_CORNER_RADIUS, 14, 6, 0),
		_make_flat(danger.lerp(Color.BLACK, 0.15), danger.lerp(ctx.fg, 0.30), BUTTON_CORNER_RADIUS, 14, 6, 0),
		_make_flat(danger.lerp(ctx.panel, 0.65), danger.lerp(ctx.panel, 0.55), BUTTON_CORNER_RADIUS, 14, 6, 0),
		_make_flat(Color(0, 0, 0, 0), Color.WHITE, BUTTON_CORNER_RADIUS, 14, 6, BORDER_WIDTH_BOLD)
	)
	theme.set_color("font_color", VARIANT_DANGER_BUTTON, Color.WHITE)
	theme.set_color("font_hover_color", VARIANT_DANGER_BUTTON, Color.WHITE)
	theme.set_color("font_pressed_color", VARIANT_DANGER_BUTTON, Color.WHITE)

	# MobileButton — large touch target, neutral surface
	_register_variation(theme, VARIANT_MOBILE_BUTTON, BUTTON_VARIATION_BASE)
	_apply_button_states(theme, VARIANT_MOBILE_BUTTON,
		_make_flat(ctx.panel.lerp(ctx.fg, 0.05), border, BUTTON_CORNER_RADIUS + 2, MOBILE_BUTTON_PADDING_H, MOBILE_BUTTON_PADDING_V),
		_make_flat(ctx.hover_bg, ctx.border_accent.lerp(border, 0.4), BUTTON_CORNER_RADIUS + 2, MOBILE_BUTTON_PADDING_H, MOBILE_BUTTON_PADDING_V),
		_make_flat(ctx.pressed_bg, ctx.border_accent, BUTTON_CORNER_RADIUS + 2, MOBILE_BUTTON_PADDING_H, MOBILE_BUTTON_PADDING_V),
		_make_flat(ctx.panel.lerp(ctx.bg, 0.35), border.lerp(ctx.panel, 0.4), BUTTON_CORNER_RADIUS + 2, MOBILE_BUTTON_PADDING_H, MOBILE_BUTTON_PADDING_V),
		_make_flat(Color(0, 0, 0, 0), accent.lerp(fg, 0.15), BUTTON_CORNER_RADIUS + 2, MOBILE_BUTTON_PADDING_H, MOBILE_BUTTON_PADDING_V, BORDER_WIDTH_BOLD)
	)
	theme.set_color("font_color", VARIANT_MOBILE_BUTTON, ctx.fg)
	theme.set_color("font_hover_color", VARIANT_MOBILE_BUTTON, fg.lerp(Color.WHITE, 0.10))
	theme.set_color("font_pressed_color", VARIANT_MOBILE_BUTTON, fg)

	# MobilePrimaryButton — accent-filled CTA for primary mobile actions
	_register_variation(theme, VARIANT_MOBILE_PRIMARY_BUTTON, BUTTON_VARIATION_BASE)
	_apply_button_states(theme, VARIANT_MOBILE_PRIMARY_BUTTON,
		_make_flat(accent, accent.lerp(ctx.fg, 0.10), BUTTON_CORNER_RADIUS + 2, MOBILE_BUTTON_PADDING_H, MOBILE_BUTTON_PADDING_V, 0),
		_make_flat(accent.lerp(Color.WHITE, 0.12), accent.lerp(ctx.fg, 0.15), BUTTON_CORNER_RADIUS + 2, MOBILE_BUTTON_PADDING_H, MOBILE_BUTTON_PADDING_V, 0),
		_make_flat(accent.lerp(Color.BLACK, 0.15), accent.lerp(ctx.fg, 0.20), BUTTON_CORNER_RADIUS + 2, MOBILE_BUTTON_PADDING_H, MOBILE_BUTTON_PADDING_V, 0),
		_make_flat(accent.lerp(ctx.panel, 0.65), accent.lerp(ctx.panel, 0.55), BUTTON_CORNER_RADIUS + 2, MOBILE_BUTTON_PADDING_H, MOBILE_BUTTON_PADDING_V, 0),
		_make_flat(Color(0, 0, 0, 0), Color.WHITE, BUTTON_CORNER_RADIUS + 2, MOBILE_BUTTON_PADDING_H, MOBILE_BUTTON_PADDING_V, BORDER_WIDTH_BOLD)
	)
	theme.set_color("font_color", VARIANT_MOBILE_PRIMARY_BUTTON, ctx.accent_fg)
	theme.set_color("font_hover_color", VARIANT_MOBILE_PRIMARY_BUTTON, ctx.accent_fg)
	theme.set_color("font_pressed_color", VARIANT_MOBILE_PRIMARY_BUTTON, ctx.accent_fg)

	# MobileGhostButton — outline only, mobile-sized
	_register_variation(theme, VARIANT_MOBILE_GHOST_BUTTON, BUTTON_VARIATION_BASE)
	_apply_button_states(theme, VARIANT_MOBILE_GHOST_BUTTON,
		_make_flat(Color(0, 0, 0, 0), border, BUTTON_CORNER_RADIUS + 2, MOBILE_BUTTON_PADDING_H, MOBILE_BUTTON_PADDING_V),
		_make_flat(ctx.hover_bg, ctx.border_accent.lerp(border, 0.4), BUTTON_CORNER_RADIUS + 2, MOBILE_BUTTON_PADDING_H, MOBILE_BUTTON_PADDING_V),
		_make_flat(ctx.pressed_bg, ctx.border_accent, BUTTON_CORNER_RADIUS + 2, MOBILE_BUTTON_PADDING_H, MOBILE_BUTTON_PADDING_V),
		_make_flat(Color(0, 0, 0, 0), border.lerp(ctx.panel, 0.4), BUTTON_CORNER_RADIUS + 2, MOBILE_BUTTON_PADDING_H, MOBILE_BUTTON_PADDING_V),
		_make_flat(Color(0, 0, 0, 0), accent.lerp(fg, 0.15), BUTTON_CORNER_RADIUS + 2, MOBILE_BUTTON_PADDING_H, MOBILE_BUTTON_PADDING_V, BORDER_WIDTH_BOLD)
	)

	# MobileGroupButton — header-of-group expander for the mobile toolbar
	_register_variation(theme, VARIANT_MOBILE_GROUP_BUTTON, BUTTON_VARIATION_BASE)
	_apply_button_states(theme, VARIANT_MOBILE_GROUP_BUTTON,
		_make_flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS + 2, 14, 10, 0),
		_make_flat(ctx.hover_bg, Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS + 2, 14, 10, 0),
		_make_flat(accent.lerp(ctx.panel, 0.55), accent.lerp(ctx.fg, 0.10), BUTTON_CORNER_RADIUS + 2, 14, 10, BORDER_WIDTH),
		_make_flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS + 2, 14, 10, 0),
		_make_flat(Color(0, 0, 0, 0), accent.lerp(fg, 0.15), BUTTON_CORNER_RADIUS + 2, 14, 10, BORDER_WIDTH_BOLD)
	)
	theme.set_color("font_color", VARIANT_MOBILE_GROUP_BUTTON, ctx.fg)
	theme.set_color("font_hover_color", VARIANT_MOBILE_GROUP_BUTTON, fg)
	theme.set_color("font_pressed_color", VARIANT_MOBILE_GROUP_BUTTON, fg)

	# BoardCardButton — large left-aligned tile for project picker recents
	_register_variation(theme, VARIANT_BOARD_CARD_BUTTON, BUTTON_VARIATION_BASE)
	_apply_button_states(theme, VARIANT_BOARD_CARD_BUTTON,
		_make_flat(ctx.panel.lerp(ctx.fg, 0.04), border.lerp(ctx.panel, 0.3), PANEL_CORNER_RADIUS, 16, 14),
		_make_flat(ctx.panel.lerp(ctx.fg, 0.08), ctx.border_accent.lerp(border, 0.4), PANEL_CORNER_RADIUS, 16, 14),
		_make_flat(accent.lerp(ctx.panel, 0.65), accent, PANEL_CORNER_RADIUS, 16, 14),
		_make_flat(ctx.panel.lerp(ctx.bg, 0.35), border.lerp(ctx.panel, 0.5), PANEL_CORNER_RADIUS, 16, 14),
		_make_flat(Color(0, 0, 0, 0), accent.lerp(fg, 0.15), PANEL_CORNER_RADIUS, 16, 14, BORDER_WIDTH_BOLD)
	)
	theme.set_color("font_color", VARIANT_BOARD_CARD_BUTTON, ctx.fg)
	theme.set_color("font_hover_color", VARIANT_BOARD_CARD_BUTTON, fg.lerp(Color.WHITE, 0.10))
	theme.set_color("font_pressed_color", VARIANT_BOARD_CARD_BUTTON, fg)


static func _apply_label_variants(theme: Theme, ctx: Dictionary) -> void:
	_register_variation(theme, VARIANT_SECTION_HEADER, LABEL_VARIATION_BASE)
	theme.set_color("font_color", VARIANT_SECTION_HEADER, ctx.fg_muted)
	theme.set_font_size("font_size", VARIANT_SECTION_HEADER, max(10, _base_font_size() - 1))

	_register_variation(theme, VARIANT_FIELD_LABEL, LABEL_VARIATION_BASE)
	theme.set_color("font_color", VARIANT_FIELD_LABEL, ctx.fg_muted)

	_register_variation(theme, VARIANT_MUTED_LABEL, LABEL_VARIATION_BASE)
	theme.set_color("font_color", VARIANT_MUTED_LABEL, ctx.fg_dim)

	_register_variation(theme, VARIANT_HERO_TITLE, LABEL_VARIATION_BASE)
	theme.set_color("font_color", VARIANT_HERO_TITLE, ctx.fg)
	theme.set_font_size("font_size", VARIANT_HERO_TITLE, _base_font_size() * 6)

	_register_variation(theme, VARIANT_HERO_SUBTITLE, LABEL_VARIATION_BASE)
	theme.set_color("font_color", VARIANT_HERO_SUBTITLE, ctx.fg_muted)
	theme.set_font_size("font_size", VARIANT_HERO_SUBTITLE, _base_font_size() + 2)

	_register_variation(theme, VARIANT_BREADCRUMB_LABEL, LABEL_VARIATION_BASE)
	theme.set_color("font_color", VARIANT_BREADCRUMB_LABEL, ctx.fg)
	theme.set_font_size("font_size", VARIANT_BREADCRUMB_LABEL, max(10, _base_font_size() - 1))

	_register_variation(theme, VARIANT_TOOLBAR_TITLE_LABEL, LABEL_VARIATION_BASE)
	theme.set_color("font_color", VARIANT_TOOLBAR_TITLE_LABEL, ctx.fg)
	theme.set_font_size("font_size", VARIANT_TOOLBAR_TITLE_LABEL, _base_font_size() + 1)


static func _apply_inspector_variants(theme: Theme, ctx: Dictionary) -> void:
	var panel: Color = ctx.panel
	var bg: Color = ctx.bg
	var fg: Color = ctx.fg
	var subtle: Color = ctx.subtle
	var border: Color = ctx.border_subtle
	var accent: Color = ctx.accent

	_register_variation(theme, VARIANT_INSPECTOR_SECTION_PANEL, PANEL_VARIATION_BASE)
	var section_sb: StyleBoxFlat = _make_flat(panel.lerp(bg, 0.20), border.lerp(panel, 0.45), PANEL_CORNER_RADIUS, 12, 10)
	theme.set_stylebox("panel", VARIANT_INSPECTOR_SECTION_PANEL, section_sb)

	_register_variation(theme, VARIANT_INSPECTOR_ROW_PANEL, PANEL_VARIATION_BASE)
	var row_sb: StyleBoxFlat = _make_flat(panel.lerp(fg, 0.02), Color(0, 0, 0, 0), BUTTON_CORNER_RADIUS, 8, 4, 0)
	row_sb.bg_color.a = 0.0
	theme.set_stylebox("panel", VARIANT_INSPECTOR_ROW_PANEL, row_sb)

	_register_variation(theme, VARIANT_INSPECTOR_TEXT_AREA_PANEL, PANEL_VARIATION_BASE)
	var text_area_sb: StyleBoxFlat = _make_flat(ctx.panel_sunken, border.lerp(panel, 0.35), INPUT_CORNER_RADIUS, 8, 6)
	theme.set_stylebox("panel", VARIANT_INSPECTOR_TEXT_AREA_PANEL, text_area_sb)

	_register_variation(theme, VARIANT_INSPECTOR_ACCENT_STRIP, PANEL_VARIATION_BASE)
	var strip_sb: StyleBoxFlat = StyleBoxFlat.new()
	strip_sb.bg_color = accent
	strip_sb.corner_radius_top_left = PANEL_CORNER_RADIUS
	strip_sb.corner_radius_bottom_left = PANEL_CORNER_RADIUS
	strip_sb.corner_radius_top_right = 0
	strip_sb.corner_radius_bottom_right = 0
	strip_sb.set_content_margin_all(0)
	theme.set_stylebox("panel", VARIANT_INSPECTOR_ACCENT_STRIP, strip_sb)

	_register_variation(theme, VARIANT_INSPECTOR_DIVIDER, PANEL_VARIATION_BASE)
	var divider_sb: StyleBoxFlat = StyleBoxFlat.new()
	divider_sb.bg_color = border.lerp(panel, 0.30)
	divider_sb.set_content_margin_all(0)
	theme.set_stylebox("panel", VARIANT_INSPECTOR_DIVIDER, divider_sb)

	_register_variation(theme, VARIANT_INSPECTOR_TITLE_LABEL, LABEL_VARIATION_BASE)
	theme.set_color("font_color", VARIANT_INSPECTOR_TITLE_LABEL, fg)
	theme.set_font_size("font_size", VARIANT_INSPECTOR_TITLE_LABEL, _base_font_size() + 1)

	_register_variation(theme, VARIANT_INSPECTOR_TYPE_BADGE, LABEL_VARIATION_BASE)
	theme.set_color("font_color", VARIANT_INSPECTOR_TYPE_BADGE, accent.lerp(fg, 0.10) if _luminance(accent) < 0.55 else accent.lerp(Color.BLACK, 0.10))
	theme.set_font_size("font_size", VARIANT_INSPECTOR_TYPE_BADGE, max(10, _base_font_size() - 2))

	_register_variation(theme, VARIANT_INSPECTOR_SUBSECTION_LABEL, LABEL_VARIATION_BASE)
	theme.set_color("font_color", VARIANT_INSPECTOR_SUBSECTION_LABEL, fg.lerp(panel, 0.20))
	theme.set_font_size("font_size", VARIANT_INSPECTOR_SUBSECTION_LABEL, max(10, _base_font_size() - 1))

	_register_variation(theme, VARIANT_INSPECTOR_FIELD_LABEL, LABEL_VARIATION_BASE)
	theme.set_color("font_color", VARIANT_INSPECTOR_FIELD_LABEL, ctx.fg_muted)
	theme.set_font_size("font_size", VARIANT_INSPECTOR_FIELD_LABEL, max(10, _base_font_size() - 1))

	_register_variation(theme, VARIANT_INSPECTOR_HINT_LABEL, LABEL_VARIATION_BASE)
	theme.set_color("font_color", VARIANT_INSPECTOR_HINT_LABEL, ctx.fg_dim)
	theme.set_font_size("font_size", VARIANT_INSPECTOR_HINT_LABEL, max(10, _base_font_size() - 2))

	_register_variation(theme, VARIANT_INSPECTOR_VALUE_LABEL, LABEL_VARIATION_BASE)
	theme.set_color("font_color", VARIANT_INSPECTOR_VALUE_LABEL, fg)
	theme.set_font_size("font_size", VARIANT_INSPECTOR_VALUE_LABEL, _base_font_size())

	_register_variation(theme, VARIANT_INSPECTOR_SWATCH_BUTTON, "ColorPickerButton")
	# Swatches inherit the rounded-color-picker shader treatment elsewhere; the
	# theme entries are kept minimal so adjustments from ThemeAdjustments can
	# layer cleanly when callers want subtle border or padding overrides.
	theme.set_color("font_color", VARIANT_INSPECTOR_SWATCH_BUTTON, Color(0, 0, 0, 0))
	theme.set_constant("h_separation", VARIANT_INSPECTOR_SWATCH_BUTTON, 0)

	# InsetScrollPanel — a darker, slightly saturated bg for ScrollContainers
	# so the scroll surface is visually distinct from its parent card.
	_register_variation(theme, VARIANT_INSET_SCROLL_PANEL, "ScrollContainer")
	var scroll_bg: Color = bg.lerp(panel, 0.30)
	scroll_bg = scroll_bg.lerp(accent, 0.05)
	var scroll_sb: StyleBoxFlat = _make_flat(scroll_bg, border.lerp(panel, 0.35), INPUT_CORNER_RADIUS, 4, 4)
	theme.set_stylebox("panel", VARIANT_INSET_SCROLL_PANEL, scroll_sb)

	# ProminentScrollbar — a chunky, high-contrast grabber so it reads as a
	# scrollbar at a glance. Apply via `theme_type_variation` on the inner
	# VScrollBar/HScrollBar (callers can fetch the bar via
	# `scroll.get_v_scroll_bar()` and assign the variation in `_ready`).
	var grabber_corner: int = 8
	var prominent_normal: StyleBoxFlat = _make_flat(accent.lerp(panel, 0.50), Color(0, 0, 0, 0), grabber_corner, 0, 0, 0)
	prominent_normal.content_margin_left = 3.0
	prominent_normal.content_margin_right = 3.0
	prominent_normal.content_margin_top = 3.0
	prominent_normal.content_margin_bottom = 3.0
	var prominent_hover: StyleBoxFlat = _make_flat(accent.lerp(fg, 0.10), Color(0, 0, 0, 0), grabber_corner, 0, 0, 0)
	prominent_hover.content_margin_left = 3.0
	prominent_hover.content_margin_right = 3.0
	prominent_hover.content_margin_top = 3.0
	prominent_hover.content_margin_bottom = 3.0
	var prominent_pressed: StyleBoxFlat = _make_flat(accent, Color(0, 0, 0, 0), grabber_corner, 0, 0, 0)
	prominent_pressed.content_margin_left = 3.0
	prominent_pressed.content_margin_right = 3.0
	prominent_pressed.content_margin_top = 3.0
	prominent_pressed.content_margin_bottom = 3.0
	var prominent_track: StyleBoxFlat = _make_flat(bg.lerp(panel, 0.35), Color(0, 0, 0, 0), grabber_corner, 0, 0, 0)
	prominent_track.bg_color.a = 0.45
	for variant_name: String in [VARIANT_PROMINENT_SCROLLBAR, VARIANT_PROMINENT_SCROLLBAR + "H"]:
		var base_class: String = "VScrollBar" if variant_name == VARIANT_PROMINENT_SCROLLBAR else "HScrollBar"
		_register_variation(theme, variant_name, base_class)
		theme.set_stylebox("grabber", variant_name, prominent_normal)
		theme.set_stylebox("grabber_highlight", variant_name, prominent_hover)
		theme.set_stylebox("grabber_pressed", variant_name, prominent_pressed)
		theme.set_stylebox("scroll", variant_name, prominent_track)
		theme.set_stylebox("scroll_focus", variant_name, prominent_track)


static func _apply_container_separations(theme: Theme) -> void:
	theme.set_constant("separation", "HBoxContainer", 6)
	theme.set_constant("separation", "VBoxContainer", 6)
	theme.set_constant("h_separation", "GridContainer", 8)
	theme.set_constant("v_separation", "GridContainer", 4)
	theme.set_constant("h_separation", "FlowContainer", 4)
	theme.set_constant("v_separation", "FlowContainer", 4)
	theme.set_constant("separation", "HSeparator", 6)
	theme.set_constant("separation", "VSeparator", 6)
	theme.set_constant("separation", "HSplitContainer", 4)
	theme.set_constant("separation", "VSplitContainer", 4)


static func _apply_button_states(theme: Theme, variant: String,
		normal: StyleBox, hover: StyleBox, pressed: StyleBox, disabled: StyleBox, focus: StyleBox) -> void:
	theme.set_stylebox("normal", variant, normal)
	theme.set_stylebox("hover", variant, hover)
	theme.set_stylebox("pressed", variant, pressed)
	theme.set_stylebox("disabled", variant, disabled)
	theme.set_stylebox("focus", variant, focus)
	theme.set_stylebox("hover_pressed", variant, pressed)
	theme.set_stylebox("normal_mirrored", variant, normal)
	theme.set_stylebox("hover_mirrored", variant, hover)
	theme.set_stylebox("pressed_mirrored", variant, pressed)
	theme.set_stylebox("disabled_mirrored", variant, disabled)
	theme.set_stylebox("hover_pressed_mirrored", variant, pressed)


static func _register_variation(theme: Theme, variant: String, base: String) -> void:
	if theme.get_type_variation_base(variant) != StringName(base):
		theme.set_type_variation(variant, base)


static func _base_font_size() -> int:
	return UserPrefs.font_size
