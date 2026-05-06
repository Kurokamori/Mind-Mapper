class_name PresenceAvatar
extends PanelContainer

const AVATAR_DIAMETER: float = 28.0

signal follow_camera_requested(stable_id: String)

@onready var _initial_label: Label = %InitialLabel
@onready var _role_badge: Label = %RoleBadge
@onready var _hosting_dot: ColorRect = %HostingDot
@onready var _name_tooltip_label: Label = %NameTooltipLabel
@onready var _self_marker: Label = %SelfMarker

var _stable_id: String = ""
var _avatar_color: Color = Color(0.55, 0.78, 1.0, 1.0)
var _is_self: bool = false


func bind(stable_id: String, display_name: String, role: String, hosting: bool, color: Color, is_self: bool) -> void:
	_stable_id = stable_id
	_avatar_color = color
	_is_self = is_self
	if _initial_label != null:
		_initial_label.text = _make_initials(display_name)
		_initial_label.add_theme_color_override("font_color", _contrast_color(color))
	if _role_badge != null:
		match role:
			ParticipantsManifest.ROLE_OWNER:
				_role_badge.text = "★"
				_role_badge.modulate = Color(1.0, 0.85, 0.3, 1.0)
			ParticipantsManifest.ROLE_CO_AUTHOR:
				_role_badge.text = "✎"
				_role_badge.modulate = Color(0.7, 0.92, 1.0, 1.0)
			_:
				_role_badge.text = "◔"
				_role_badge.modulate = Color(0.85, 0.85, 0.92, 1.0)
	if _hosting_dot != null:
		_hosting_dot.visible = hosting
	if _name_tooltip_label != null:
		_name_tooltip_label.text = display_name
		_name_tooltip_label.tooltip_text = "%s — %s" % [display_name, role]
	if _self_marker != null:
		_self_marker.visible = is_self
	tooltip_text = "%s — %s%s" % [display_name, role, "  (you)" if is_self else ""]
	_apply_avatar_style()


func _apply_avatar_style() -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = _avatar_color
	sb.set_corner_radius_all(int(AVATAR_DIAMETER * 0.5))
	sb.set_border_width_all(2)
	sb.border_color = Color(_avatar_color.r * 0.6, _avatar_color.g * 0.6, _avatar_color.b * 0.6, 1.0)
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(AVATAR_DIAMETER, AVATAR_DIAMETER)


func stable_id() -> String:
	return _stable_id


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("follow_camera_requested", _stable_id)


func _make_initials(display_name: String) -> String:
	var trimmed: String = display_name.strip_edges()
	if trimmed == "":
		return "?"
	var parts: PackedStringArray = trimmed.split(" ", false)
	if parts.size() == 0:
		return trimmed.substr(0, 1).to_upper()
	if parts.size() == 1:
		return parts[0].substr(0, 1).to_upper()
	return (parts[0].substr(0, 1) + parts[parts.size() - 1].substr(0, 1)).to_upper()


func _contrast_color(c: Color) -> Color:
	var luma: float = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	return Color(0.05, 0.05, 0.08, 1.0) if luma > 0.5 else Color(0.97, 0.98, 1.0, 1.0)
