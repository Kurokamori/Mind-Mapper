class_name MobileBacklinksSection
extends Control

signal navigate_to_backlink(board_id: String, item_id: String)

@onready var _list_root: VBoxContainer = %BacklinksList
@onready var _empty_label: Label = %EmptyLabel

var _item_id: String = ""
var _item_type: String = ""
var _target_board_id: String = ""


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not ProjectIndex.index_changed.is_connected(_refresh):
		ProjectIndex.index_changed.connect(_refresh)


func _exit_tree() -> void:
	if ProjectIndex.index_changed.is_connected(_refresh):
		ProjectIndex.index_changed.disconnect(_refresh)


func bind(item_dict: Dictionary) -> void:
	_item_id = String(item_dict.get("id", ""))
	_item_type = String(item_dict.get("type", ""))
	_target_board_id = String(item_dict.get("target_board_id", item_dict.get("child_board_id", "")))
	_refresh()


func _refresh() -> void:
	for child: Node in _list_root.get_children():
		child.queue_free()
	if _item_id == "":
		_empty_label.text = "No item bound."
		_empty_label.visible = true
		return
	var refs: Array = ProjectIndex.backlinks_to_item(_item_id)
	if (_item_type == ItemRegistry.TYPE_PINBOARD or _item_type == ItemRegistry.TYPE_SUBPAGE) and _target_board_id != "":
		var board_refs: Array = ProjectIndex.backlinks_to_board(_target_board_id)
		for r: Variant in board_refs:
			refs.append(r)
	if refs.is_empty():
		_empty_label.text = "Nothing links here yet."
		_empty_label.visible = true
		return
	_empty_label.visible = false
	for ref_v: Variant in refs:
		var ref: ProjectIndex.BacklinkRef = ref_v
		_list_root.add_child(_build_row(ref))


func _build_row(ref: ProjectIndex.BacklinkRef) -> Control:
	var btn: Button = Button.new()
	btn.text = "%s · %s\n%s" % [_kind_label(ref.kind), ref.board_name, ref.item_title]
	btn.custom_minimum_size = Vector2(0, 60)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.pressed.connect(func() -> void: navigate_to_backlink.emit(ref.board_id, ref.item_id))
	return btn


func _kind_label(kind: String) -> String:
	match kind:
		ProjectIndex.BACKLINK_KIND_LINK_TO_ITEM:
			return "Link to item"
		ProjectIndex.BACKLINK_KIND_LINK_TO_BOARD:
			return "Link to board"
		ProjectIndex.BACKLINK_KIND_PINBOARD:
			return "Pinboard"
		ProjectIndex.BACKLINK_KIND_SUBPAGE:
			return "Subpage"
	return "Reference"
