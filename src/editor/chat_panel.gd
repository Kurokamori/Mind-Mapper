class_name ChatPanel
extends DockablePanel

signal close_requested()

const TIMESTAMP_FORMAT_24H: String = "%02d:%02d"

@onready var _close_button: Button = %ChatCloseButton
@onready var _history_label: RichTextLabel = %ChatHistoryLabel
@onready var _empty_label: Label = %ChatEmptyLabel
@onready var _input: LineEdit = %ChatInputLine
@onready var _send_button: Button = %ChatSendButton
@onready var _status_label: Label = %ChatStatusLabel

var _input_disabled_reason: String = "no_session"
var _autoscroll_pinned: bool = true
var _suppress_scroll_event: bool = false
var _ready_done: bool = false


func _ready() -> void:
	super._ready()
	_close_button.pressed.connect(_on_close_pressed)
	_send_button.pressed.connect(_on_send_pressed)
	_input.text_submitted.connect(_on_input_submitted)
	_input.text_changed.connect(_on_input_changed)
	var bar: VScrollBar = _history_label.get_v_scroll_bar()
	if bar != null:
		bar.value_changed.connect(_on_history_scroll_changed)
	if _has_theme_manager():
		ThemeManager.theme_applied.connect(_apply_theme_dependent_state)
		_apply_theme_dependent_state()
	if _has_multiplayer_service():
		MultiplayerService.chat_message_received.connect(_on_chat_message_received)
		MultiplayerService.chat_history_cleared.connect(_on_chat_history_cleared)
		MultiplayerService.session_state_changed.connect(_on_session_state_changed)
	_render_full_history()
	_refresh_input_enabled()
	_ready_done = true


func _has_theme_manager() -> bool:
	var root: Node = get_tree().root if get_tree() != null else null
	return root != null and root.has_node("ThemeManager")


func _has_multiplayer_service() -> bool:
	var root: Node = get_tree().root if get_tree() != null else null
	return root != null and root.has_node("MultiplayerService")


func _apply_theme_dependent_state() -> void:
	if _has_theme_manager():
		ThemeManager.apply_translucent_panel(self)
	if _empty_label != null and _has_theme_manager():
		_empty_label.add_theme_color_override("font_color", ThemeManager.dim_foreground_color())
	if _status_label != null and _has_theme_manager():
		_status_label.add_theme_color_override("font_color", ThemeManager.dim_foreground_color())


func grab_input_focus() -> void:
	if _input == null:
		return
	if _input_disabled_reason != "":
		return
	_input.grab_focus()


func _on_close_pressed() -> void:
	emit_signal("close_requested")


func _on_send_pressed() -> void:
	_submit_current_input()


func _on_input_submitted(_text: String) -> void:
	_submit_current_input()


func _on_input_changed(_text: String) -> void:
	_refresh_send_button_enabled()


func _on_history_scroll_changed(_value: float) -> void:
	if _suppress_scroll_event:
		return
	var bar: VScrollBar = _history_label.get_v_scroll_bar()
	if bar == null:
		return
	var at_bottom: bool = bar.value >= bar.max_value - bar.page - 1.0
	_autoscroll_pinned = at_bottom


func _submit_current_input() -> void:
	var text: String = _input.text
	if text.strip_edges() == "":
		return
	if not _has_multiplayer_service():
		return
	if not MultiplayerService.is_in_session():
		return
	var err: Error = MultiplayerService.send_chat_message(text)
	if err == OK:
		_input.text = ""
		_refresh_send_button_enabled()
		_autoscroll_pinned = true
		_input.grab_focus()


func _on_chat_message_received(entry: Dictionary) -> void:
	_append_entry_line(entry)
	_apply_autoscroll_if_pinned()


func _on_chat_history_cleared() -> void:
	_render_full_history()


func _on_session_state_changed(_state: int) -> void:
	_refresh_input_enabled()


func _render_full_history() -> void:
	_history_label.clear()
	if not _has_multiplayer_service():
		_update_empty_state()
		return
	var entries: Array = MultiplayerService.recent_chat_messages()
	for entry_v: Variant in entries:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		_append_entry_line(entry_v as Dictionary)
	_apply_autoscroll_if_pinned()
	_update_empty_state()


func _append_entry_line(entry: Dictionary) -> void:
	var is_system: bool = bool(entry.get("is_system", false))
	var timestamp_unix: int = int(entry.get("timestamp_unix", 0))
	var stamp: String = _format_timestamp(timestamp_unix)
	var stamp_color: Color = _muted_color()
	var stamp_hex: String = _color_hex(stamp_color)
	if is_system:
		var sys_color: Color = _muted_color()
		var sys_hex: String = _color_hex(sys_color)
		_history_label.append_text("[color=%s]%s · %s[/color]\n" % [sys_hex, stamp, _bbcode_escape(String(entry.get("text", "")))])
	else:
		var name_color: Color = _ensure_visible_color(entry.get("color", _muted_color()) as Color)
		var name_hex: String = _color_hex(name_color)
		var display_name: String = String(entry.get("display_name", "Player"))
		var body: String = String(entry.get("text", ""))
		_history_label.append_text("[color=%s]%s[/color] [b][color=%s]%s[/color][/b]\n" % [stamp_hex, stamp, name_hex, _bbcode_escape(display_name)])
		_history_label.append_text("%s\n" % _bbcode_escape(body))
	_update_empty_state()


func _apply_autoscroll_if_pinned() -> void:
	if not _autoscroll_pinned:
		return
	_suppress_scroll_event = true
	call_deferred("_scroll_history_to_bottom")


func _scroll_history_to_bottom() -> void:
	var bar: VScrollBar = _history_label.get_v_scroll_bar()
	if bar != null:
		bar.value = bar.max_value
	_suppress_scroll_event = false


func _update_empty_state() -> void:
	if _empty_label == null:
		return
	var has_entries: bool = false
	if _has_multiplayer_service():
		has_entries = not MultiplayerService.recent_chat_messages().is_empty()
	_empty_label.visible = not has_entries


func _refresh_input_enabled() -> void:
	var in_session: bool = false
	if _has_multiplayer_service():
		in_session = MultiplayerService.is_in_session()
	if in_session:
		_input.editable = true
		_input.placeholder_text = "Send a message…"
		_input_disabled_reason = ""
		if _status_label != null:
			_status_label.text = ""
			_status_label.visible = false
	else:
		_input.editable = false
		_input.placeholder_text = "Not in a session"
		_input_disabled_reason = "no_session"
		if _status_label != null:
			_status_label.text = "Join or host a session to chat."
			_status_label.visible = true
	_refresh_send_button_enabled()


func _refresh_send_button_enabled() -> void:
	var can_send: bool = _input.editable and _input.text.strip_edges() != ""
	_send_button.disabled = not can_send


func _format_timestamp(timestamp_unix: int) -> String:
	if timestamp_unix <= 0:
		return ""
	var tz: Dictionary = Time.get_time_zone_from_system()
	var bias_seconds: int = int(tz.get("bias", 0)) * 60
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(timestamp_unix + bias_seconds)
	return TIMESTAMP_FORMAT_24H % [int(dt.get("hour", 0)), int(dt.get("minute", 0))]


func _muted_color() -> Color:
	if _has_theme_manager():
		return ThemeManager.dim_foreground_color()
	return Color(0.6, 0.6, 0.7, 1.0)


func _ensure_visible_color(color: Color) -> Color:
	var bg: Color = _panel_background_color()
	var luma_color: float = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
	var luma_bg: float = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
	if abs(luma_color - luma_bg) < 0.18:
		if luma_bg < 0.5:
			return color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.45)
		return color.lerp(Color(0.0, 0.0, 0.0, 1.0), 0.45)
	return color


func _panel_background_color() -> Color:
	if _has_theme_manager():
		return ThemeManager.panel_color()
	return Color(0.11, 0.11, 0.14, 1.0)


func _color_hex(c: Color) -> String:
	var r: int = int(round(clampf(c.r, 0.0, 1.0) * 255.0))
	var g: int = int(round(clampf(c.g, 0.0, 1.0) * 255.0))
	var b: int = int(round(clampf(c.b, 0.0, 1.0) * 255.0))
	return "#%02x%02x%02x" % [r, g, b]


func _bbcode_escape(text: String) -> String:
	return text.replace("[", "[lb]")
