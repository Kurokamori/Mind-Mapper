class_name LinkSection
extends VBoxContainer

@onready var _status_label: Label = %StatusLabel
@onready var _set_button: Button = %SetButton
@onready var _follow_button: Button = %FollowButton
@onready var _clear_button: Button = %ClearButton

var _item: BoardItem
var _editor: Node


func bind(item: BoardItem, editor: Node) -> void:
	_item = item
	_editor = editor


func _ready() -> void:
	ThemeManager.apply_relative_font_size(_status_label, 0.80)
	ThemeManager.apply_relative_font_sizes(self, {"Hint": 0.72})
	_set_button.pressed.connect(_on_set_pressed)
	_follow_button.pressed.connect(_on_follow_pressed)
	_clear_button.pressed.connect(_on_clear_pressed)
	_refresh()


func _refresh() -> void:
	if _item == null or not _item.has_link():
		_status_label.text = "No link"
		_follow_button.disabled = true
		_clear_button.disabled = true
		return
	var kind: String = String(_item.link_target.get("kind", ""))
	var id: String = String(_item.link_target.get("id", ""))
	var label: String = ""
	if kind == BoardItem.LINK_KIND_BOARD and AppState.current_project != null:
		var bn: String = String(AppState.current_project.board_index.get(id, "(missing)"))
		label = "Board: %s" % bn
	elif kind == BoardItem.LINK_KIND_ITEM:
		label = "Item: %s" % id.substr(0, 8)
	else:
		label = "Linked"
	_status_label.text = label
	_follow_button.disabled = false
	_clear_button.disabled = false


func _on_set_pressed() -> void:
	if _editor == null:
		return
	if _editor.has_method("open_link_picker_for"):
		_editor.open_link_picker_for(_item, Callable(self, "_on_picker_result"))


func _on_picker_result(result: Dictionary) -> void:
	if _item == null or _editor == null:
		return
	var prev: Dictionary = _item.link_target.duplicate(true) if _item.link_target != null else {}
	var binder: PropertyBinder = PropertyBinder.new(_editor, _item, "link_target", prev)
	if result.is_empty():
		binder.live({})
		binder.commit({})
	else:
		var nv: Dictionary = result.duplicate(true)
		binder.live(nv)
		binder.commit(nv)
	_refresh()


func _on_follow_pressed() -> void:
	if _item == null or not _item.has_link() or _editor == null:
		return
	if _editor.has_method("follow_item_link"):
		_editor.follow_item_link(_item)


func _on_clear_pressed() -> void:
	if _item == null:
		return
	_on_picker_result({})
