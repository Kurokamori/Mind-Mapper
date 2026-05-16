class_name MobileBoardCommentsSheet
extends Control

signal comments_changed()

const COMMENT_CARD_SCENE: PackedScene = preload("res://src/mobile/sheets/mobile_comment_card.tscn")

@onready var _scroll: ScrollContainer = %BoardCommentsScroll
@onready var _list_root: VBoxContainer = %BoardCommentsList
@onready var _empty_label: Label = %BoardCommentsEmptyLabel
@onready var _new_input: TextEdit = %BoardCommentInput
@onready var _submit_button: Button = %BoardCommentSubmitButton
@onready var _hide_resolved_toggle: CheckButton = %HideResolvedToggle

var _project: Project = null
var _board: Board = null
var _board_view: MobileBoardView = null
var _hide_resolved: bool = false


func _ready() -> void:
	_submit_button.pressed.connect(_on_submit_pressed)
	_hide_resolved_toggle.toggled.connect(_on_hide_resolved_toggled)


func bind(project: Project, board: Board, board_view: MobileBoardView) -> void:
	_project = project
	_board = board
	_board_view = board_view
	_rebuild_list()


func _rebuild_list() -> void:
	for child: Node in _list_root.get_children():
		child.queue_free()
	if _board == null:
		_empty_label.visible = true
		return
	var entries: Array = _filter_entries(_board.comments)
	_empty_label.visible = entries.is_empty()
	for entry: Dictionary in entries:
		var card: MobileCommentCard = COMMENT_CARD_SCENE.instantiate()
		_list_root.add_child(card)
		card.bind(entry)
		card.body_committed.connect(_on_card_body_committed)
		card.toggle_resolved_requested.connect(_on_card_toggle_resolved)
		card.delete_requested.connect(_on_card_delete_requested)


func _filter_entries(comments: Array) -> Array:
	var out: Array = []
	for entry_v: Variant in comments:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = CommentData.normalize(entry_v as Dictionary)
		if _hide_resolved and bool(entry.get(CommentData.FIELD_RESOLVED, false)):
			continue
		out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(b.get(CommentData.FIELD_LAST_EDITED_UNIX, 0)) < int(a.get(CommentData.FIELD_LAST_EDITED_UNIX, 0))
	)
	return out


func _on_hide_resolved_toggled(value: bool) -> void:
	_hide_resolved = value
	_rebuild_list()


func _on_submit_pressed() -> void:
	if _board == null:
		return
	var raw: String = _new_input.text.strip_edges()
	if raw == "":
		return
	var comment: Dictionary = CommentData.make_default("", "", _peer_id(), _peer_name())
	comment[CommentData.FIELD_BODY_BBCODE] = raw
	_board.comments.append(comment)
	_new_input.text = ""
	_persist()
	_rebuild_list()


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
	_persist()


func _on_card_toggle_resolved(comment_id: String) -> void:
	var idx: int = CommentData.find_index(_board.comments, comment_id)
	if idx < 0:
		return
	var entry: Dictionary = _board.comments[idx]
	entry[CommentData.FIELD_RESOLVED] = not bool(entry.get(CommentData.FIELD_RESOLVED, false))
	entry[CommentData.FIELD_LAST_EDITED_UNIX] = int(Time.get_unix_time_from_system())
	_board.comments[idx] = entry
	_persist()
	_rebuild_list()


func _on_card_delete_requested(comment_id: String) -> void:
	var idx: int = CommentData.find_index(_board.comments, comment_id)
	if idx < 0:
		return
	_board.comments.remove_at(idx)
	_persist()
	_rebuild_list()


func _persist() -> void:
	if _board_view == null:
		if _project != null and _board != null:
			_project.write_board(_board)
		return
	_board_view.update_board_comments(_board.comments)
	comments_changed.emit()


func _peer_id() -> String:
	var root: Node = get_tree().root
	if root != null and root.has_node("KeypairService"):
		var svc: Node = root.get_node("KeypairService")
		if svc.has_method("stable_id"):
			return String(svc.call("stable_id"))
	return "mobile"


func _peer_name() -> String:
	var root: Node = get_tree().root
	if root != null and root.has_node("KeypairService"):
		var svc: Node = root.get_node("KeypairService")
		if svc.has_method("display_name"):
			return String(svc.call("display_name"))
	return "Mobile"
