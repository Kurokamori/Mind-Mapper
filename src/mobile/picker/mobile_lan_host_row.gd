class_name MobileLanHostRow
extends PanelContainer

signal pull_requested(host_entry: Dictionary)

@onready var _name_label: Label = %LanHostNameLabel
@onready var _detail_label: Label = %LanHostDetailLabel
@onready var _pull_button: Button = %LanHostPullButton

var _entry: Dictionary = {}


func _ready() -> void:
	_pull_button.pressed.connect(func() -> void: pull_requested.emit(_entry))


func bind(entry: Dictionary) -> void:
	_entry = entry.duplicate(true)
	var project_name: String = String(_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_NAME, ""))
	var host_name: String = String(_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_HOST_NAME, ""))
	var address: String = String(_entry.get("address", ""))
	if project_name == "":
		project_name = "Unnamed project"
	if host_name == "":
		host_name = "Desktop"
	_name_label.text = project_name
	_detail_label.text = "%s · %s" % [host_name, address]
