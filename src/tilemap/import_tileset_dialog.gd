class_name ImportTilesetDialog
extends ConfirmationDialog

signal tileset_import_requested(name_str: String, tres_path: String, godot_project_root: String)

@onready var _name_edit: LineEdit = %NameEdit
@onready var _tres_path_edit: LineEdit = %TresPathEdit
@onready var _tres_browse: Button = %TresBrowse
@onready var _project_root_edit: LineEdit = %ProjectRootEdit
@onready var _project_root_browse: Button = %ProjectRootBrowse
@onready var _tres_dialog: FileDialog = %TresDialog
@onready var _root_dialog: FileDialog = %RootDialog
@onready var _info_label: Label = %InfoLabel


func _ready() -> void:
	add_cancel_button("Cancel")
	confirmed.connect(_on_confirmed)
	ThemeManager.apply_relative_font_size(_info_label, 0.85)
	_tres_browse.pressed.connect(_on_tres_browse)
	_project_root_browse.pressed.connect(_on_root_browse)
	_tres_dialog.file_selected.connect(_on_tres_chosen)
	_root_dialog.dir_selected.connect(_on_root_chosen)


func open() -> void:
	PopupSizer.popup_fit(self, {"preferred": Vector2i(560, 320)})
	_name_edit.grab_focus()


func _on_tres_browse() -> void:
	PopupSizer.popup_fit(_tres_dialog, {"ratio": Vector2(0.7, 0.7)})


func _on_root_browse() -> void:
	PopupSizer.popup_fit(_root_dialog, {"ratio": Vector2(0.7, 0.7)})


func _on_tres_chosen(path: String) -> void:
	_tres_path_edit.text = path
	if _name_edit.text.strip_edges() == "":
		_name_edit.text = path.get_file().get_basename()
	_auto_fill_root(path)


func _on_root_chosen(dir: String) -> void:
	_project_root_edit.text = dir
	_validate_paths()


func _auto_fill_root(tres_path: String) -> void:
	if _project_root_edit.text.strip_edges() != "":
		_validate_paths()
		return
	var current: String = tres_path.get_base_dir()
	while current != "":
		var candidate: String = current.path_join("project.godot")
		if FileAccess.file_exists(candidate):
			_project_root_edit.text = current
			_validate_paths()
			return
		var parent: String = current.get_base_dir()
		if parent == "" or parent == current:
			break
		current = parent
	_validate_paths()


func _validate_paths() -> void:
	var tres: String = _tres_path_edit.text.strip_edges()
	var root: String = _project_root_edit.text.strip_edges()
	if tres == "":
		_info_label.text = "Pick a Godot TileSet (.tres)."
		return
	if not FileAccess.file_exists(tres):
		_info_label.text = "Tileset file not found."
		return
	if root != "" and not tres.begins_with(root):
		_info_label.text = "Warning: tileset is outside the chosen Godot project. Reference-mode export will not be safe."
		return
	if root == "":
		_info_label.text = "Pick the Godot project root so reference-mode exports compute correct res:// paths."
		return
	_info_label.text = "Looks good. The .tres will be referenced via res:// at export time."


func _on_confirmed() -> void:
	var n: String = _name_edit.text.strip_edges()
	if n == "":
		n = "Tileset"
	var tres: String = _tres_path_edit.text.strip_edges()
	if not FileAccess.file_exists(tres):
		return
	var root: String = _project_root_edit.text.strip_edges()
	emit_signal("tileset_import_requested", n, tres, root)
