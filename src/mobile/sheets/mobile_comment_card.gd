class_name MobileCommentCard
extends PanelContainer

signal body_committed(comment_id: String, new_body: String)
signal toggle_resolved_requested(comment_id: String)
signal delete_requested(comment_id: String)

@onready var _author_label: Label = %AuthorLabel
@onready var _timestamp_label: Label = %TimestampLabel
@onready var _resolved_badge: Label = %ResolvedBadge
@onready var _body_view: RichTextLabel = %BodyView
@onready var _body_edit: TextEdit = %BodyEdit
@onready var _edit_button: Button = %EditButton
@onready var _save_button: Button = %SaveButton
@onready var _cancel_button: Button = %CancelButton
@onready var _resolve_button: Button = %ResolveButton
@onready var _delete_button: Button = %DeleteButton

var _comment_id: String = ""
var _comment_dict: Dictionary = {}
var _editing: bool = false


func _ready() -> void:
	_edit_button.pressed.connect(_enter_edit_mode)
	_save_button.pressed.connect(_commit_edit)
	_cancel_button.pressed.connect(_cancel_edit)
	_resolve_button.pressed.connect(func() -> void: toggle_resolved_requested.emit(_comment_id))
	_delete_button.pressed.connect(func() -> void: delete_requested.emit(_comment_id))
	_apply_edit_state()


func bind(comment_dict: Dictionary) -> void:
	_comment_dict = CommentData.normalize(comment_dict)
	_comment_id = String(_comment_dict.get(CommentData.FIELD_ID, ""))
	_author_label.text = String(_comment_dict.get(CommentData.FIELD_AUTHOR_DISPLAY_NAME, "Unknown"))
	_author_label.add_theme_color_override("font_color", CommentData.color_of(_comment_dict))
	var created: int = int(_comment_dict.get(CommentData.FIELD_CREATED_UNIX, 0))
	_timestamp_label.text = Time.get_datetime_string_from_unix_time(created)
	var resolved: bool = bool(_comment_dict.get(CommentData.FIELD_RESOLVED, false))
	_resolved_badge.visible = resolved
	_resolve_button.text = "Unresolve" if resolved else "Resolve"
	_body_view.text = String(_comment_dict.get(CommentData.FIELD_BODY_BBCODE, ""))
	_apply_edit_state()


func _apply_edit_state() -> void:
	_body_view.visible = not _editing
	_body_edit.visible = _editing
	_edit_button.visible = not _editing
	_save_button.visible = _editing
	_cancel_button.visible = _editing


func _enter_edit_mode() -> void:
	_editing = true
	_body_edit.text = _body_view.text
	_apply_edit_state()
	_body_edit.grab_focus()


func _cancel_edit() -> void:
	_editing = false
	_apply_edit_state()


func _commit_edit() -> void:
	var new_body: String = _body_edit.text.strip_edges()
	body_committed.emit(_comment_id, new_body)
	_editing = false
	_body_view.text = new_body
	_apply_edit_state()
