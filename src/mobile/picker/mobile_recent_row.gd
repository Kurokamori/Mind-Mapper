class_name MobileRecentRow
extends PanelContainer

signal open_requested(folder_path: String, source: String, remote_label: String)
signal remove_requested(folder_path: String)

@onready var _name_label: Label = %RecentNameLabel
@onready var _detail_label: Label = %RecentDetailLabel
@onready var _open_button: Button = %RecentOpenButton
@onready var _remove_button: Button = %RecentRemoveButton

var _entry: Dictionary = {}


func _ready() -> void:
	_open_button.pressed.connect(_on_open)
	_remove_button.pressed.connect(_on_remove)


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
