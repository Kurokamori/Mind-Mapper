class_name LinkPicker
extends ConfirmationDialog

signal link_chosen(target: Dictionary)
signal link_cleared()

@onready var _kind_option: OptionButton = %KindOption
@onready var _target_option: OptionButton = %TargetOption
@onready var _clear_button: Button = %ClearButton

var _target_id_by_index: Dictionary = {}
var _items_on_board: Array = []


func _ready() -> void:
	title = "Link target"
	ok_button_text = "Link"
	add_cancel_button("Cancel")
	confirmed.connect(_on_confirmed)
	_kind_option.clear()
	_kind_option.add_item("Board", 0)
	_kind_option.set_item_metadata(0, BoardItem.LINK_KIND_BOARD)
	_kind_option.add_item("Item on this board", 1)
	_kind_option.set_item_metadata(1, BoardItem.LINK_KIND_ITEM)
	_kind_option.item_selected.connect(_on_kind_selected)
	_clear_button.pressed.connect(_on_clear_pressed)
	_kind_option.select(0)
	_repopulate_targets()


func open_for(current_target: Dictionary, items_on_board: Array) -> void:
	_items_on_board = items_on_board
	var current_kind: String = String(current_target.get("kind", BoardItem.LINK_KIND_BOARD))
	var idx: int = 0
	if current_kind == BoardItem.LINK_KIND_ITEM:
		idx = 1
	_kind_option.select(idx)
	_repopulate_targets()
	_select_existing(String(current_target.get("id", "")))
	PopupSizer.popup_fit(self)


func _on_kind_selected(_index: int) -> void:
	_repopulate_targets()


func _repopulate_targets() -> void:
	_target_option.clear()
	_target_id_by_index.clear()
	var kind: String = _selected_kind()
	if kind == BoardItem.LINK_KIND_BOARD:
		_populate_boards()
	else:
		_populate_items()


func _populate_boards() -> void:
	if AppState.current_project == null:
		return
	var boards: Array = AppState.current_project.list_boards()
	var idx: int = 0
	for entry in boards:
		_target_option.add_item(String(entry.name), idx)
		_target_id_by_index[idx] = String(entry.id)
		idx += 1


func _populate_items() -> void:
	var idx: int = 0
	for it in _items_on_board:
		if not (it is BoardItem):
			continue
		var item: BoardItem = it
		_target_option.add_item("%s — %s" % [item.display_name(), _short_id(item.item_id)], idx)
		_target_id_by_index[idx] = item.item_id
		idx += 1


func _short_id(id: String) -> String:
	if id.length() < 8:
		return id
	return id.substr(0, 8)


func _select_existing(target_id: String) -> void:
	for i in _target_id_by_index.keys():
		if String(_target_id_by_index[i]) == target_id:
			_target_option.select(int(i))
			return


func _selected_kind() -> String:
	var idx: int = _kind_option.selected
	if idx < 0:
		return BoardItem.LINK_KIND_BOARD
	return String(_kind_option.get_item_metadata(idx))


func _on_confirmed() -> void:
	var idx: int = _target_option.selected
	if idx < 0:
		return
	var id: String = String(_target_id_by_index.get(idx, ""))
	if id == "":
		return
	emit_signal("link_chosen", {"kind": _selected_kind(), "id": id})


func _on_clear_pressed() -> void:
	emit_signal("link_cleared")
	hide()
