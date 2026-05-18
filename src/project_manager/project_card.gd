class_name ProjectCard
extends PanelContainer

signal open_requested(folder_path: String)
signal forget_requested(folder_path: String)
signal join_live_requested(folder_path: String, lobby_entry: Dictionary, adapter_kind: String)
signal host_requested(folder_path: String)
signal broadcast_toggle_requested(folder_path: String, want_active: bool)

const SCENE: PackedScene = preload("res://src/project_manager/project_card.tscn")

@onready var _name_label: Label = %NameLabel
@onready var _path_label: Label = %PathLabel
@onready var _modified_label: Label = %ModifiedLabel
@onready var _live_status_label: Label = %LiveStatusLabel
@onready var _join_live_button: Button = %JoinLiveButton
@onready var _broadcast_button: Button = %BroadcastButton
@onready var _host_button: Button = %HostButton
@onready var _open_button: Button = %OpenButton
@onready var _forget_button: Button = %ForgetButton

var _folder_path: String = ""
var _project_id: String = ""
var _pending_entry: Dictionary = {}
var _live_lobby: Dictionary = {}
var _live_adapter_kind: String = ""
var _broadcast_active: bool = false
var _pending_broadcast_active: bool = false


static func create() -> ProjectCard:
	return SCENE.instantiate() as ProjectCard


func _ready() -> void:
	ThemeManager.apply_relative_font_size(_name_label, 1.30)
	ThemeManager.apply_relative_font_size(_path_label, 0.80)
	ThemeManager.apply_relative_font_size(_modified_label, 0.80)
	ThemeManager.apply_relative_font_size(_live_status_label, 0.80)
	_open_button.pressed.connect(func() -> void: emit_signal("open_requested", _folder_path))
	_forget_button.pressed.connect(func() -> void: emit_signal("forget_requested", _folder_path))
	_join_live_button.pressed.connect(_on_join_live_pressed)
	_host_button.pressed.connect(func() -> void: emit_signal("host_requested", _folder_path))
	_broadcast_button.toggled.connect(_on_broadcast_toggled)
	if not _pending_entry.is_empty():
		_apply(_pending_entry)
		_pending_entry = {}
	if _pending_broadcast_active:
		set_broadcast_active(true)
		_pending_broadcast_active = false


func bind(entry: Dictionary) -> void:
	if is_node_ready():
		_apply(entry)
	else:
		_pending_entry = entry.duplicate()


func project_id() -> String:
	return _project_id


func folder_path() -> String:
	return _folder_path


func mark_live(lobby_entry: Dictionary, adapter_kind: String) -> void:
	_live_lobby = lobby_entry.duplicate()
	_live_adapter_kind = adapter_kind
	if _join_live_button == null or _live_status_label == null:
		return
	if lobby_entry.is_empty():
		_join_live_button.visible = false
		_live_status_label.text = ""
		return
	_join_live_button.visible = true
	_live_status_label.text = "● Hosted by %s (%s)" % [String(lobby_entry.get("host_display_name", "Host")), adapter_kind.to_upper()]
	_live_status_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.55, 1.0))


func _on_join_live_pressed() -> void:
	if _live_lobby.is_empty():
		return
	emit_signal("join_live_requested", _folder_path, _live_lobby, _live_adapter_kind)


func set_broadcast_active(active: bool) -> void:
	if not is_node_ready():
		_pending_broadcast_active = active
		return
	_broadcast_active = active
	_broadcast_button.set_pressed_no_signal(active)
	if active:
		_broadcast_button.text = "● Broadcasting"
		_broadcast_button.tooltip_text = "Stop broadcasting this project to phones on the LAN."
	else:
		_broadcast_button.text = "Broadcast"
		_broadcast_button.tooltip_text = "Broadcast this project to phones on the LAN (no full multiplayer session)."


func _on_broadcast_toggled(pressed: bool) -> void:
	if _folder_path == "":
		_broadcast_button.set_pressed_no_signal(_broadcast_active)
		return
	emit_signal("broadcast_toggle_requested", _folder_path, pressed)


func _apply(entry: Dictionary) -> void:
	_folder_path = String(entry.get("folder_path", ""))
	_project_id = String(entry.get("id", ""))
	_name_label.text = String(entry.get("name", "Untitled"))
	_path_label.text = _folder_path
	var unix: int = int(entry.get("modified_unix", 0))
	if unix > 0:
		_modified_label.text = "Modified: %s" % Time.get_datetime_string_from_unix_time(unix)
	else:
		_modified_label.text = ""
	if _live_status_label != null:
		_live_status_label.text = ""
