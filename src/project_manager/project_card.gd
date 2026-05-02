class_name ProjectCard
extends PanelContainer

signal open_requested(folder_path: String)
signal forget_requested(folder_path: String)

const SCENE: PackedScene = preload("res://src/project_manager/project_card.tscn")

@onready var _name_label: Label = %NameLabel
@onready var _path_label: Label = %PathLabel
@onready var _modified_label: Label = %ModifiedLabel
@onready var _open_button: Button = %OpenButton
@onready var _forget_button: Button = %ForgetButton

var _folder_path: String = ""
var _pending_entry: Dictionary = {}


static func create() -> ProjectCard:
	return SCENE.instantiate() as ProjectCard


func _ready() -> void:
	_open_button.pressed.connect(func() -> void: emit_signal("open_requested", _folder_path))
	_forget_button.pressed.connect(func() -> void: emit_signal("forget_requested", _folder_path))
	if not _pending_entry.is_empty():
		_apply(_pending_entry)
		_pending_entry = {}


func bind(entry: Dictionary) -> void:
	if is_node_ready():
		_apply(entry)
	else:
		_pending_entry = entry.duplicate()


func _apply(entry: Dictionary) -> void:
	_folder_path = String(entry.get("folder_path", ""))
	_name_label.text = String(entry.get("name", "Untitled"))
	_path_label.text = _folder_path
	var unix: int = int(entry.get("modified_unix", 0))
	if unix > 0:
		_modified_label.text = "Modified: %s" % Time.get_datetime_string_from_unix_time(unix)
	else:
		_modified_label.text = ""
