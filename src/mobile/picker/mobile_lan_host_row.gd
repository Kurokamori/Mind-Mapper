class_name MobileLanHostRow
extends PanelContainer

signal pull_requested(host_entry: Dictionary)
signal push_requested(host_entry: Dictionary, local_folder: String)
signal sync_requested(host_entry: Dictionary, local_folder: String)

@onready var _name_label: Label = %LanHostNameLabel
@onready var _detail_label: Label = %LanHostDetailLabel
@onready var _local_label: Label = %LanHostLocalLabel
@onready var _pull_button: Button = %LanHostPullButton
@onready var _push_button: Button = %LanHostPushButton
@onready var _sync_button: Button = %LanHostSyncButton

var _entry: Dictionary = {}
var _local_folder: String = ""


func _ready() -> void:
	_pull_button.pressed.connect(func() -> void: pull_requested.emit(_entry))
	_push_button.pressed.connect(_on_push_pressed)
	_sync_button.pressed.connect(_on_sync_pressed)


func bind(entry: Dictionary, matched_local_folder: String, matched_local_name: String) -> void:
	_entry = entry.duplicate(true)
	_local_folder = matched_local_folder
	var project_name: String = String(_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_NAME, ""))
	var host_name: String = String(_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_HOST_NAME, ""))
	var address: String = String(_entry.get("address", ""))
	if project_name == "":
		project_name = "Unnamed project"
	if host_name == "":
		host_name = "Desktop"
	_name_label.text = project_name
	_detail_label.text = "%s · %s" % [host_name, address]
	var has_local: bool = matched_local_folder != ""
	_push_button.disabled = not has_local
	_sync_button.disabled = not has_local
	_local_label.visible = has_local
	if has_local:
		var label_name: String = matched_local_name if matched_local_name.strip_edges() != "" else project_name
		_local_label.text = "Local copy: %s" % label_name


func _on_push_pressed() -> void:
	if _local_folder == "":
		return
	push_requested.emit(_entry, _local_folder)


func _on_sync_pressed() -> void:
	if _local_folder == "":
		return
	sync_requested.emit(_entry, _local_folder)
