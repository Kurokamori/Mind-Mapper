class_name NewMapDialog
extends ConfirmationDialog

signal map_created(map_name: String, tile_size: Vector2i)

@onready var _name_edit: LineEdit = %NameEdit
@onready var _tile_w_spin: SpinBox = %TileWSpin
@onready var _tile_h_spin: SpinBox = %TileHSpin


func _ready() -> void:
	add_cancel_button("Cancel")
	confirmed.connect(_on_confirmed)


func open() -> void:
	_name_edit.text = "New Map"
	_tile_w_spin.value = 16
	_tile_h_spin.value = 16
	PopupSizer.popup_fit(self, {"preferred": Vector2i(360, 200)})
	_name_edit.grab_focus()


func _on_confirmed() -> void:
	var n: String = _name_edit.text.strip_edges()
	if n == "":
		n = "New Map"
	var ts: Vector2i = Vector2i(int(_tile_w_spin.value), int(_tile_h_spin.value))
	if ts.x <= 0 or ts.y <= 0:
		ts = Vector2i(16, 16)
	emit_signal("map_created", n, ts)
