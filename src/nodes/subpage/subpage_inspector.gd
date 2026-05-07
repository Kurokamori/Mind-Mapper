class_name SubpageInspector
extends VBoxContainer

@onready var _title_edit: LineEdit = %TitleEdit
@onready var _open_button: Button = %OpenButton
@onready var _refresh_button: Button = %RefreshButton
@onready var _retarget_option: OptionButton = %RetargetOption
@onready var _zoom_spin: SpinBox = %ZoomSpin
@onready var _autofit_check: CheckBox = %AutoFitCheck

var _item: SubpageNode
var _editor: Node
var _binders: Dictionary = {}
var _suppress_signals: bool = false
var _board_id_by_index: Dictionary = {}


func bind(item: SubpageNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	if _item == null:
		return
	_suppress_signals = true
	_title_edit.text = _item.title
	_zoom_spin.value = _item.view_zoom * 100.0
	_autofit_check.button_pressed = _item.auto_fit
	_populate_retarget()
	_suppress_signals = false
	_binders["title"] = PropertyBinder.new(_editor, _item, "title", _item.title)
	_binders["view_zoom"] = PropertyBinder.new(_editor, _item, "view_zoom", _item.view_zoom)
	_binders["auto_fit"] = PropertyBinder.new(_editor, _item, "auto_fit", _item.auto_fit)
	_title_edit.text_changed.connect(func(t: String) -> void: _binders["title"].live(t))
	_title_edit.focus_exited.connect(func() -> void: _commit_title(_title_edit.text))
	_title_edit.text_submitted.connect(func(t: String) -> void: _commit_title(t))
	_zoom_spin.value_changed.connect(_on_zoom_changed)
	_autofit_check.toggled.connect(_on_autofit_toggled)
	_open_button.pressed.connect(_on_open_pressed)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_retarget_option.item_selected.connect(_on_retarget_selected)


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null


func _populate_retarget() -> void:
	_retarget_option.clear()
	_board_id_by_index.clear()
	if AppState.current_project == null:
		return
	var boards: Array = AppState.current_project.list_boards()
	var idx: int = 0
	_retarget_option.add_item("(create new)", idx)
	_board_id_by_index[idx] = ""
	idx += 1
	var current_idx: int = 0
	for entry in boards:
		var bid: String = String(entry.id)
		var bname: String = String(entry.name)
		_retarget_option.add_item(bname, idx)
		_board_id_by_index[idx] = bid
		if bid == _item.target_board_id:
			current_idx = idx
		idx += 1
	if current_idx >= 0:
		_retarget_option.select(current_idx)


func _commit_title(text: String) -> void:
	_binders["title"].commit(text)
	if _item != null and _item.target_board_id != "" and OpBus.has_project() and not OpBus.is_applying_remote():
		OpBus.record_local_change(OpKinds.RENAME_BOARD, {
			"board_id": _item.target_board_id,
			"name": text,
		}, "")


func _on_zoom_changed(value: float) -> void:
	if _suppress_signals:
		return
	var z: float = clamp(value / 100.0, 0.05, 4.0)
	_binders["view_zoom"].live(z)
	_binders["view_zoom"].commit(z)


func _on_autofit_toggled(pressed: bool) -> void:
	if _suppress_signals:
		return
	_binders["auto_fit"].live(pressed)
	_binders["auto_fit"].commit(pressed)


func _on_open_pressed() -> void:
	if _item == null:
		return
	var id: String = _item.ensure_target_board()
	if id == "":
		return
	AppState.navigate_to_board(id)


func _on_refresh_pressed() -> void:
	_populate_retarget()


func _on_retarget_selected(index: int) -> void:
	if _suppress_signals or _item == null:
		return
	var id: String = String(_board_id_by_index.get(index, ""))
	if id == _item.target_board_id:
		return
	if id == "":
		_item.target_board_id = ""
		_item.ensure_target_board()
	else:
		var prev: String = _item.target_board_id
		var binder: PropertyBinder = PropertyBinder.new(_editor, _item, "target_board_id", prev)
		binder.live(id)
		binder.commit(id)
