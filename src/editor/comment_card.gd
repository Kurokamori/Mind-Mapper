class_name CommentCard
extends PanelContainer

signal jump_requested(item_id: String, card_id: String)

@onready var _color_button: ColorPickerButton = %ColorButton
@onready var _title_edit: LineEdit = %TitleEdit
@onready var _resolve_button: CheckButton = %ResolveButton
@onready var _edit_button: Button = %EditButton
@onready var _delete_button: Button = %DeleteButton
@onready var _target_button: Button = %TargetButton
@onready var _body_view: RichTextLabel = %BodyView
@onready var _body_edit: TextEdit = %BodyEdit
@onready var _author_label: Label = %AuthorLabel

var _editor: Node = null
var _comment_id: String = ""
var _data: Dictionary = {}
var _suppress_signals: bool = false
var _read_only: bool = false
var _local_stable_id: String = ""
var _is_full_editor: bool = true
var _last_committed_title: String = ""
var _last_committed_body: String = ""
var _last_committed_resolved: bool = false
var _last_committed_color: Color = Color.WHITE


func _ready() -> void:
	ThemeManager.apply_relative_font_size(_author_label, 0.80)
	_color_button.color_changed.connect(_on_color_changed)
	_color_button.popup_closed.connect(_on_color_popup_closed)
	_title_edit.text_submitted.connect(_on_title_submitted)
	_title_edit.focus_exited.connect(_on_title_focus_exited)
	_resolve_button.toggled.connect(_on_resolve_toggled)
	_edit_button.toggled.connect(_on_edit_toggled)
	_delete_button.pressed.connect(_on_delete_pressed)
	_target_button.pressed.connect(_on_target_pressed)
	_body_edit.focus_exited.connect(_on_body_focus_exited)
	if _has_theme_manager():
		ThemeManager.theme_applied.connect(_on_theme_applied)
		ThemeManager.node_palette_changed.connect(_on_node_palette_changed)
	_apply_data_to_widgets()


func _has_theme_manager() -> bool:
	var root: Node = get_tree().root if get_tree() != null else null
	return root != null and root.has_node("ThemeManager")


func _on_theme_applied() -> void:
	_apply_color_visuals(CommentData.color_of(_data))


func _on_node_palette_changed(_old: Dictionary, _new: Dictionary) -> void:
	_apply_color_visuals(CommentData.color_of(_data))


func bind(editor: Node, comment_data: Dictionary) -> void:
	_editor = editor
	_data = CommentData.normalize(comment_data.duplicate(true))
	_comment_id = String(_data.get(CommentData.FIELD_ID, ""))
	if is_inside_tree():
		_apply_data_to_widgets()


func update_data(comment_data: Dictionary) -> void:
	_data = CommentData.normalize(comment_data.duplicate(true))
	if is_inside_tree():
		_apply_data_to_widgets()


func comment_id() -> String:
	return _comment_id


func set_target_label(text: String) -> void:
	if _target_button == null:
		return
	_target_button.text = text


func set_read_only(value: bool) -> void:
	_read_only = value
	if is_inside_tree():
		_apply_permission_visuals()


func set_local_identity(stable_id: String, is_full_editor: bool) -> void:
	_local_stable_id = stable_id
	_is_full_editor = is_full_editor
	if is_inside_tree():
		_apply_permission_visuals()


func _is_local_author() -> bool:
	var author: String = String(_data.get(CommentData.FIELD_AUTHOR_STABLE_ID, ""))
	return author != "" and author == _local_stable_id


func _can_edit_text_fields() -> bool:
	if _read_only:
		return false
	return _is_full_editor or _is_local_author()


func _can_delete_self() -> bool:
	if _read_only:
		return false
	return _is_full_editor or _is_local_author()


func _can_change_color() -> bool:
	return not _read_only


func _can_toggle_resolved() -> bool:
	return not _read_only


func _apply_permission_visuals() -> void:
	if _color_button == null:
		return
	var edit_text: bool = _can_edit_text_fields()
	var change_color: bool = _can_change_color()
	var toggle_resolve: bool = _can_toggle_resolved()
	var can_delete: bool = _can_delete_self()
	_color_button.disabled = not change_color
	_title_edit.editable = edit_text
	_resolve_button.disabled = not toggle_resolve
	_edit_button.disabled = not edit_text
	_delete_button.disabled = not can_delete
	_body_edit.editable = edit_text
	if not edit_text and _edit_button.button_pressed:
		_edit_button.set_pressed_no_signal(false)
		_body_view.visible = true
		_body_edit.visible = false


func _apply_data_to_widgets() -> void:
	_suppress_signals = true
	var color: Color = CommentData.color_of(_data)
	_color_button.color = color
	_title_edit.text = String(_data.get(CommentData.FIELD_TITLE, ""))
	_resolve_button.button_pressed = CommentData.is_resolved(_data)
	var body: String = String(_data.get(CommentData.FIELD_BODY_BBCODE, ""))
	_body_view.text = body
	_body_edit.text = body
	var author: String = String(_data.get(CommentData.FIELD_AUTHOR_DISPLAY_NAME, ""))
	if author == "":
		author = "(unknown)"
	_author_label.text = author
	_last_committed_title = _title_edit.text
	_last_committed_body = body
	_last_committed_resolved = _resolve_button.button_pressed
	_last_committed_color = color
	_apply_resolve_visuals()
	_apply_color_visuals(color)
	_apply_permission_visuals()
	_suppress_signals = false


func _apply_resolve_visuals() -> void:
	var resolved: bool = _resolve_button.button_pressed
	modulate = Color(1, 1, 1, 1) if not resolved else Color(1, 1, 1, CommentData.RESOLVED_DIM_FACTOR)


func _apply_color_visuals(color: Color) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = _resolve_panel_bg_color()
	box.set_corner_radius_all(6)
	box.set_border_width_all(0)
	box.border_width_left = 4
	box.border_color = color
	box.content_margin_left = 6
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	add_theme_stylebox_override("panel", box)
	if _author_label != null:
		_author_label.add_theme_color_override("font_color", _resolve_author_fg_color())


func _resolve_panel_bg_color() -> Color:
	if _has_theme_manager():
		return ThemeManager.node_card_bg_color()
	return Color(0.13, 0.15, 0.21, 1.0)


func _resolve_author_fg_color() -> Color:
	if _has_theme_manager():
		return ThemeManager.node_card_fg_color().lerp(ThemeManager.node_card_bg_color(), 0.35)
	return Color(0.78, 0.84, 0.95, 0.85)


func _on_color_changed(color: Color) -> void:
	if _suppress_signals:
		return
	_apply_color_visuals(color)


func _on_color_popup_closed() -> void:
	if _suppress_signals or not _can_change_color():
		return
	var new_color: Color = _color_button.color
	if new_color.is_equal_approx(_last_committed_color):
		return
	if _editor != null and _editor.has_method("modify_comment_property"):
		_editor.call("modify_comment_property", _comment_id, CommentData.FIELD_COLOR, _last_committed_color, new_color)
	_last_committed_color = new_color


func _on_title_submitted(_text: String) -> void:
	_commit_title_if_changed()
	_title_edit.release_focus()


func _on_title_focus_exited() -> void:
	_commit_title_if_changed()


func _commit_title_if_changed() -> void:
	if _suppress_signals or not _can_edit_text_fields():
		return
	var new_title: String = _title_edit.text
	if new_title == _last_committed_title:
		return
	if _editor != null and _editor.has_method("modify_comment_property"):
		_editor.call("modify_comment_property", _comment_id, CommentData.FIELD_TITLE, _last_committed_title, new_title)
	_last_committed_title = new_title


func _on_resolve_toggled(pressed: bool) -> void:
	if _suppress_signals:
		return
	if not _can_toggle_resolved():
		_suppress_signals = true
		_resolve_button.button_pressed = _last_committed_resolved
		_suppress_signals = false
		return
	_apply_resolve_visuals()
	if _editor != null and _editor.has_method("modify_comment_property"):
		_editor.call("modify_comment_property", _comment_id, CommentData.FIELD_RESOLVED, _last_committed_resolved, pressed)
	_last_committed_resolved = pressed


func _on_edit_toggled(pressed: bool) -> void:
	_body_view.visible = not pressed
	_body_edit.visible = pressed
	if pressed:
		_body_edit.grab_focus()


func _on_body_focus_exited() -> void:
	if _suppress_signals or not _can_edit_text_fields():
		return
	var new_body: String = _body_edit.text
	if new_body == _last_committed_body:
		return
	if _editor != null and _editor.has_method("modify_comment_property"):
		_editor.call("modify_comment_property", _comment_id, CommentData.FIELD_BODY_BBCODE, _last_committed_body, new_body)
	_last_committed_body = new_body
	_body_view.text = new_body


func _on_delete_pressed() -> void:
	if not _can_delete_self():
		return
	if _editor != null and _editor.has_method("delete_comment"):
		_editor.call("delete_comment", _comment_id)


func _on_target_pressed() -> void:
	emit_signal("jump_requested", CommentData.target_item_id(_data), CommentData.target_card_id(_data))
