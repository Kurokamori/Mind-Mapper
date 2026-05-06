class_name NewTilesetFromImageDialog
extends ConfirmationDialog

signal tileset_creation_requested(name_str: String, image_source_path: String, tile_size: Vector2i, margins: Vector2i, separation: Vector2i)

@onready var _name_edit: LineEdit = %NameEdit
@onready var _path_edit: LineEdit = %PathEdit
@onready var _browse_button: Button = %BrowseButton
@onready var _tile_w_spin: SpinBox = %TileWSpin
@onready var _tile_h_spin: SpinBox = %TileHSpin
@onready var _margin_x_spin: SpinBox = %MarginXSpin
@onready var _margin_y_spin: SpinBox = %MarginYSpin
@onready var _sep_x_spin: SpinBox = %SepXSpin
@onready var _sep_y_spin: SpinBox = %SepYSpin
@onready var _file_dialog: FileDialog = %FileDialog


func _ready() -> void:
	add_cancel_button("Cancel")
	confirmed.connect(_on_confirmed)
	_browse_button.pressed.connect(_on_browse_pressed)
	_file_dialog.file_selected.connect(_on_file_chosen)


func open() -> void:
	popup_centered()
	_name_edit.grab_focus()


func _on_browse_pressed() -> void:
	_file_dialog.popup_centered_ratio(0.7)


func _on_file_chosen(path: String) -> void:
	_path_edit.text = path
	if _name_edit.text.strip_edges() == "":
		_name_edit.text = path.get_file().get_basename()


func _on_confirmed() -> void:
	var n: String = _name_edit.text.strip_edges()
	if n == "":
		n = "Tileset"
	var p: String = _path_edit.text.strip_edges()
	if p == "" or not FileAccess.file_exists(p):
		return
	var tile_size: Vector2i = Vector2i(int(_tile_w_spin.value), int(_tile_h_spin.value))
	if tile_size.x <= 0 or tile_size.y <= 0:
		tile_size = Vector2i(16, 16)
	var margins: Vector2i = Vector2i(int(_margin_x_spin.value), int(_margin_y_spin.value))
	var separation: Vector2i = Vector2i(int(_sep_x_spin.value), int(_sep_y_spin.value))
	emit_signal("tileset_creation_requested", n, p, tile_size, margins, separation)
