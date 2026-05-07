class_name BacklinksSection
extends VBoxContainer

@onready var _empty_label: Label = %EmptyLabel
@onready var _entries_container: VBoxContainer = %EntriesContainer

var _item: BoardItem = null
var _editor: Node = null


func bind(item: BoardItem, editor: Node) -> void:
	_item = item
	_editor = editor


func _ready() -> void:
	ThemeManager.apply_relative_font_size(_empty_label, 0.80)
	_refresh()
	if not ProjectIndex.index_changed.is_connected(_refresh):
		ProjectIndex.index_changed.connect(_refresh)


func _exit_tree() -> void:
	if ProjectIndex.index_changed.is_connected(_refresh):
		ProjectIndex.index_changed.disconnect(_refresh)


func _refresh() -> void:
	if _entries_container == null:
		return
	for child: Node in _entries_container.get_children():
		child.queue_free()
	if _item == null:
		_empty_label.visible = true
		return
	var refs: Array = ProjectIndex.backlinks_to_item(_item.item_id)
	if _item is PinboardNode:
		var pin: PinboardNode = _item
		if pin.target_board_id != "":
			refs.append_array(ProjectIndex.backlinks_to_board(pin.target_board_id))
	elif _item is SubpageNode:
		var sub: SubpageNode = _item
		if sub.target_board_id != "":
			refs.append_array(ProjectIndex.backlinks_to_board(sub.target_board_id))
	refs = _deduplicate(refs)
	if refs.is_empty():
		_empty_label.visible = true
		return
	_empty_label.visible = false
	for ref_v: Variant in refs:
		var ref: ProjectIndex.BacklinkRef = ref_v
		_entries_container.add_child(_build_row(ref))


func _deduplicate(refs: Array) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for ref_v: Variant in refs:
		var ref: ProjectIndex.BacklinkRef = ref_v
		var key: String = "%s|%s|%s" % [ref.kind, ref.board_id, ref.item_id]
		if seen.has(key):
			continue
		seen[key] = true
		out.append(ref)
	return out


func _build_row(ref: ProjectIndex.BacklinkRef) -> Control:
	var btn: Button = Button.new()
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = "%s  %s" % [_glyph_for_kind(ref.kind), _line_for_ref(ref)]
	btn.tooltip_text = "%s  ·  on board: %s" % [ref.item_title, ref.board_name]
	btn.pressed.connect(_on_row_pressed.bind(ref))
	return btn


func _line_for_ref(ref: ProjectIndex.BacklinkRef) -> String:
	var label: String = ref.item_title if ref.item_title != "" else "(untitled)"
	return "%s  —  %s" % [label, ref.board_name]


func _glyph_for_kind(kind: String) -> String:
	match kind:
		ProjectIndex.BACKLINK_KIND_PINBOARD: return "[P]"
		ProjectIndex.BACKLINK_KIND_SUBPAGE: return "[S]"
		ProjectIndex.BACKLINK_KIND_LINK_TO_BOARD: return "[→B]"
		ProjectIndex.BACKLINK_KIND_LINK_TO_ITEM: return "[→·]"
	return "[·]"


func _on_row_pressed(ref: ProjectIndex.BacklinkRef) -> void:
	if _editor == null:
		return
	if _editor.has_method("navigate_to_backlink"):
		_editor.navigate_to_backlink(ref.board_id, ref.item_id)
