class_name MobileItemComments
extends Control

signal comments_changed()

const COMMENT_CARD_SCENE: PackedScene = preload("res://src/mobile/sheets/mobile_comment_card.tscn")

@onready var _scroll: ScrollContainer = %CommentsScroll
@onready var _list_root: VBoxContainer = %CommentsList
@onready var _empty_label: Label = %EmptyLabel
@onready var _new_input: TextEdit = %NewCommentInput
@onready var _submit_button: Button = %SubmitCommentButton

var _project: Project = null
var _board: Board = null
var _item_id: String = ""


func _ready() -> void:
	_submit_button.pressed.connect(_on_submit_pressed)


func bind(project: Project, board: Board, item_id: String) -> void:
	_project = project
	_board = board
	_item_id = item_id
	_rebuild_list()


func full_board_comments() -> Array:
	if _board == null:
		return []
	return _board.comments.duplicate(true)


func _rebuild_list() -> void:
	for child: Node in _list_root.get_children():
		child.queue_free()
	if _board == null or _item_id == "":
		_empty_label.visible = true
		return
	var entries: Array = CommentData.filter_for_item(_board.comments, _item_id)
	_empty_label.visible = entries.is_empty()
	for entry: Dictionary in entries:
		var card: MobileCommentCard = COMMENT_CARD_SCENE.instantiate()
		_list_root.add_child(card)
		card.bind(entry)
		card.body_committed.connect(_on_card_body_committed)
		card.toggle_resolved_requested.connect(_on_card_toggle_resolved)
		card.delete_requested.connect(_on_card_delete_requested)


func _on_submit_pressed() -> void:
	if _board == null:
		return
	var raw: String = _new_input.text.strip_edges()
	if raw == "":
		return
	var comment: Dictionary = CommentData.make_default(_item_id, "", _peer_identity_id(), _peer_identity_name())
	comment[CommentData.FIELD_BODY_BBCODE] = raw
	_board.comments.append(comment)
	_new_input.text = ""
	_rebuild_list()
	comments_changed.emit()


func _on_card_body_committed(comment_id: String, new_body: String) -> void:
	var idx: int = CommentData.find_index(_board.comments, comment_id)
	if idx < 0:
		return
	var entry: Dictionary = _board.comments[idx]
	if String(entry.get(CommentData.FIELD_BODY_BBCODE, "")) == new_body:
		return
	entry[CommentData.FIELD_BODY_BBCODE] = new_body
	entry[CommentData.FIELD_LAST_EDITED_UNIX] = int(Time.get_unix_time_from_system())
	_board.comments[idx] = entry
	comments_changed.emit()


func _on_card_toggle_resolved(comment_id: String) -> void:
	var idx: int = CommentData.find_index(_board.comments, comment_id)
	if idx < 0:
		return
	var entry: Dictionary = _board.comments[idx]
	entry[CommentData.FIELD_RESOLVED] = not bool(entry.get(CommentData.FIELD_RESOLVED, false))
	entry[CommentData.FIELD_LAST_EDITED_UNIX] = int(Time.get_unix_time_from_system())
	_board.comments[idx] = entry
	_rebuild_list()
	comments_changed.emit()


func _on_card_delete_requested(comment_id: String) -> void:
	var idx: int = CommentData.find_index(_board.comments, comment_id)
	if idx < 0:
		return
	_board.comments.remove_at(idx)
	_rebuild_list()
	comments_changed.emit()


func _peer_identity_id() -> String:
	var root: Node = get_tree().root
	if root != null and root.has_node("KeypairService"):
		var svc: Node = root.get_node("KeypairService")
		if svc.has_method("stable_id"):
			return String(svc.call("stable_id"))
	return "mobile"


func _peer_identity_name() -> String:
	var root: Node = get_tree().root
	if root != null and root.has_node("KeypairService"):
		var svc: Node = root.get_node("KeypairService")
		if svc.has_method("display_name"):
			return String(svc.call("display_name"))
	return "Mobile"
