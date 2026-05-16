class_name CommentsPanel
extends DockablePanel

signal close_requested
signal jump_to_target_requested(item_id: String, card_id: String)

const COMMENT_CARD_SCENE: PackedScene = preload("res://src/editor/comment_card.tscn")

const SCOPE_ALL: int = 0
const SCOPE_SELECTED_ITEM: int = 1

@onready var _show_resolved_button: CheckButton = %ShowResolvedButton
@onready var _close_button: Button = %CloseButton
@onready var _scope_button: OptionButton = %ScopeButton
@onready var _empty_label: Label = %EmptyLabel
@onready var _scroll: ScrollContainer = %Scroll
@onready var _list: VBoxContainer = %List

var _editor: Node = null
var _show_resolved: bool = true
var _scope_mode: int = SCOPE_ALL
var _selected_item_id: String = ""
var _comments: Array = []
var _cards_by_comment_id: Dictionary = {}
var _read_only: bool = false
var _local_stable_id: String = ""
var _is_full_editor: bool = true


func _ready() -> void:
	super._ready()
	_close_button.pressed.connect(_on_close_pressed)
	_show_resolved_button.button_pressed = _show_resolved
	_show_resolved_button.toggled.connect(_on_show_resolved_toggled)
	_scope_button.add_item("All comments on board", SCOPE_ALL)
	_scope_button.add_item("On selected item only", SCOPE_SELECTED_ITEM)
	_scope_button.item_selected.connect(_on_scope_changed)
	if Engine.has_singleton("SelectionBus") or _has_selection_bus():
		SelectionBus.selection_changed.connect(_on_selection_changed)


func _has_theme_manager() -> bool:
	var root: Node = get_tree().root if get_tree() != null else null
	return root != null and root.has_node("ThemeManager")


func _has_selection_bus() -> bool:
	var root: Node = get_tree().root if get_tree() != null else null
	return root != null and root.has_node("SelectionBus")


func bind_editor(editor: Node) -> void:
	_editor = editor


func set_read_only(value: bool) -> void:
	_read_only = value
	for c_v: Variant in _cards_by_comment_id.values():
		var card: CommentCard = c_v as CommentCard
		if card != null:
			card.set_read_only(value)


func set_local_identity(stable_id: String, is_full_editor: bool) -> void:
	_local_stable_id = stable_id
	_is_full_editor = is_full_editor
	for c_v: Variant in _cards_by_comment_id.values():
		var card: CommentCard = c_v as CommentCard
		if card != null:
			card.set_local_identity(stable_id, is_full_editor)


func set_comments(comments: Array) -> void:
	_comments = comments.duplicate(true)
	_render()


func notify_selection_changed(selected_ids: Array) -> void:
	if selected_ids.size() == 1:
		_selected_item_id = String(selected_ids[0])
	else:
		_selected_item_id = ""
	if _scope_mode == SCOPE_SELECTED_ITEM:
		_render()


func _on_selection_changed(selected: Array) -> void:
	var ids: Array = []
	for it_v: Variant in selected:
		if it_v is BoardItem:
			ids.append((it_v as BoardItem).item_id)
	notify_selection_changed(ids)


func _on_show_resolved_toggled(pressed: bool) -> void:
	_show_resolved = pressed
	_render()


func _on_scope_changed(idx: int) -> void:
	_scope_mode = idx
	_render()


func _on_close_pressed() -> void:
	emit_signal("close_requested")


func _render() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	_cards_by_comment_id.clear()
	var visible_comments: Array = _filtered_comments()
	if visible_comments.is_empty():
		_empty_label.visible = true
		_scroll.visible = false
		return
	_empty_label.visible = false
	_scroll.visible = true
	visible_comments.sort_custom(_sort_comments)
	for comment_v: Variant in visible_comments:
		if typeof(comment_v) != TYPE_DICTIONARY:
			continue
		var card: CommentCard = COMMENT_CARD_SCENE.instantiate()
		_list.add_child(card)
		card.bind(_editor, comment_v as Dictionary)
		card.set_target_label(_target_label_for(comment_v as Dictionary))
		card.set_local_identity(_local_stable_id, _is_full_editor)
		card.set_read_only(_read_only)
		card.jump_requested.connect(_on_card_jump_requested)
		_cards_by_comment_id[String((comment_v as Dictionary).get(CommentData.FIELD_ID, ""))] = card


func _filtered_comments() -> Array:
	var out: Array = []
	for entry_v: Variant in _comments:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		if not _show_resolved and CommentData.is_resolved(entry):
			continue
		if _scope_mode == SCOPE_SELECTED_ITEM:
			if _selected_item_id == "" or CommentData.target_item_id(entry) != _selected_item_id:
				continue
		out.append(entry)
	return out


static func _sort_comments(a: Dictionary, b: Dictionary) -> bool:
	var ar: bool = CommentData.is_resolved(a)
	var br: bool = CommentData.is_resolved(b)
	if ar != br:
		return not ar
	return int(a.get(CommentData.FIELD_CREATED_UNIX, 0)) > int(b.get(CommentData.FIELD_CREATED_UNIX, 0))


func _target_label_for(comment: Dictionary) -> String:
	var item_id: String = CommentData.target_item_id(comment)
	var card_id: String = CommentData.target_card_id(comment)
	var item_label: String = "(deleted item)"
	if _editor != null and _editor.has_method("comment_target_item_label"):
		var resolved: String = String(_editor.call("comment_target_item_label", item_id))
		if resolved != "":
			item_label = resolved
	if card_id == "":
		return "On: %s →" % item_label
	var card_label: String = card_id
	if _editor != null and _editor.has_method("comment_target_card_label"):
		var resolved_card: String = String(_editor.call("comment_target_card_label", item_id, card_id))
		if resolved_card != "":
			card_label = resolved_card
	return "On: %s · %s →" % [item_label, card_label]


func _on_card_jump_requested(item_id: String, card_id: String) -> void:
	emit_signal("jump_to_target_requested", item_id, card_id)


func update_comment(comment: Dictionary) -> void:
	var comment_id: String = String(comment.get(CommentData.FIELD_ID, ""))
	if comment_id == "":
		return
	var idx: int = CommentData.find_index(_comments, comment_id)
	if idx < 0:
		_comments.append(comment.duplicate(true))
	else:
		_comments[idx] = comment.duplicate(true)
	if _cards_by_comment_id.has(comment_id) and _passes_filter(comment):
		(_cards_by_comment_id[comment_id] as CommentCard).update_data(comment)
	else:
		_render()


func remove_comment(comment_id: String) -> void:
	var idx: int = CommentData.find_index(_comments, comment_id)
	if idx >= 0:
		_comments.remove_at(idx)
	_render()


func _passes_filter(comment: Dictionary) -> bool:
	if not _show_resolved and CommentData.is_resolved(comment):
		return false
	if _scope_mode == SCOPE_SELECTED_ITEM:
		if _selected_item_id == "" or CommentData.target_item_id(comment) != _selected_item_id:
			return false
	return true
