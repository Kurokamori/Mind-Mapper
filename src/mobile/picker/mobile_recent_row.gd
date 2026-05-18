class_name MobileRecentRow
extends PanelContainer

signal open_requested(folder_path: String, source: String, remote_label: String)
signal remove_requested(folder_path: String)
signal broadcast_toggle_requested(folder_path: String, want_active: bool)

@onready var _name_label: Label = %RecentNameLabel
@onready var _detail_label: Label = %RecentDetailLabel
@onready var _open_button: Button = %RecentOpenButton
@onready var _remove_button: Button = %RecentRemoveButton
@onready var _broadcast_button: Button = %RecentBroadcastButton

var _entry: Dictionary = {}
var _broadcast_active: bool = false


func _ready() -> void:
	_open_button.pressed.connect(_on_open)
	_remove_button.pressed.connect(_on_remove)
	_broadcast_button.toggled.connect(_on_broadcast_toggled)
	_apply_broadcast_appearance()


func folder_path() -> String:
	return String(_entry.get(MobileProjectRegistry.FIELD_FOLDER, ""))


func set_broadcast_active(active: bool) -> void:
	_broadcast_active = active
	if _broadcast_button == null:
		return
	_broadcast_button.set_pressed_no_signal(active)
	_apply_broadcast_appearance()


func _apply_broadcast_appearance() -> void:
	if _broadcast_button == null:
		return
	if _broadcast_active:
		_broadcast_button.text = "● Broadcasting"
		_broadcast_button.tooltip_text = "Stop broadcasting this project on the LAN."
	else:
		_broadcast_button.text = "Broadcast"
		_broadcast_button.tooltip_text = "Broadcast this project on the LAN so other devices can sync with it."


func _on_broadcast_toggled(pressed: bool) -> void:
	var folder: String = folder_path()
	if folder == "":
		_broadcast_button.set_pressed_no_signal(_broadcast_active)
		return
	broadcast_toggle_requested.emit(folder, pressed)


func bind(entry: Dictionary) -> void:
	_entry = entry.duplicate(true)
	_name_label.text = String(_entry.get(MobileProjectRegistry.FIELD_NAME, "Project"))
	_detail_label.text = _build_detail()


func _build_detail() -> String:
	var source: String = String(_entry.get(MobileProjectRegistry.FIELD_SOURCE, ""))
	var detail: String = _source_label(source)
	var remote_name: String = String(_entry.get(MobileProjectRegistry.FIELD_REMOTE_NAME, ""))
	if remote_name != "":
		detail = "%s · %s" % [detail, remote_name]
	var last_opened: int = int(_entry.get(MobileProjectRegistry.FIELD_LAST_OPENED_UNIX, 0))
	if last_opened > 0:
		detail = "%s · %s" % [detail, Time.get_datetime_string_from_unix_time(last_opened)]
	return detail


func _source_label(source: String) -> String:
	match source:
		MobileProjectRegistry.SOURCE_SYNCED:
			return "LAN sync"
		MobileProjectRegistry.SOURCE_IMPORTED:
			return "Imported"
		MobileProjectRegistry.SOURCE_EXTERNAL:
			return "External folder"
		_:
			return "Local"


func _on_open() -> void:
	open_requested.emit(
		String(_entry.get(MobileProjectRegistry.FIELD_FOLDER, "")),
		String(_entry.get(MobileProjectRegistry.FIELD_SOURCE, MobileProjectRegistry.SOURCE_LOCAL)),
		String(_entry.get(MobileProjectRegistry.FIELD_REMOTE_NAME, "")),
	)


func _on_remove() -> void:
	remove_requested.emit(String(_entry.get(MobileProjectRegistry.FIELD_FOLDER, "")))
