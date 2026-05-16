class_name MobileTodoEditor
extends Control

signal payload_changed(new_payload: Dictionary)

const ROW_SCENE: PackedScene = preload("res://src/mobile/sheets/mobile_todo_row.tscn")

@onready var _title_label: Label = %TodoTitleLabel
@onready var _title_edit: LineEdit = %TodoTitleEdit
@onready var _rename_button: Button = %TodoRenameButton
@onready var _cards_scroll: ScrollContainer = %TodoCardsScroll
@onready var _cards_root: VBoxContainer = %TodoCardsRoot
@onready var _add_card_button: Button = %AddCardButton
@onready var _add_card_input: LineEdit = %AddCardInput
@onready var _summary_label: Label = %SummaryLabel

var _item_dict: Dictionary = {}
var _title_editing: bool = false


func _ready() -> void:
	_rename_button.pressed.connect(_toggle_title_edit)
	_title_edit.text_submitted.connect(_on_title_submitted)
	_title_edit.focus_exited.connect(_on_title_focus_exited)
	_add_card_button.pressed.connect(_on_add_card_pressed)
	_add_card_input.text_submitted.connect(_on_add_card_text_submitted)


func bind(item_dict: Dictionary) -> void:
	_item_dict = item_dict.duplicate(true)
	_apply_title()
	_rebuild_rows()
	_refresh_summary()


func _apply_title() -> void:
	_title_label.text = String(_item_dict.get("title", "Todo List"))
	_title_label.visible = not _title_editing
	_title_edit.visible = _title_editing
	if _title_editing:
		_title_edit.text = _title_label.text
		_title_edit.grab_focus()
		_title_edit.select_all()


func _rebuild_rows() -> void:
	for child: Node in _cards_root.get_children():
		child.queue_free()
	var cards_raw: Variant = _item_dict.get("cards", [])
	var cards: Array = cards_raw if typeof(cards_raw) == TYPE_ARRAY else []
	_render_card_array(cards, _cards_root, 0)


func _render_card_array(cards: Array, parent: VBoxContainer, indent_level: int) -> void:
	for card_v: Variant in cards:
		if typeof(card_v) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = card_v
		var row: MobileTodoRow = ROW_SCENE.instantiate()
		parent.add_child(row)
		row.bind(card, indent_level)
		row.completed_toggled.connect(_on_card_completed_toggled)
		row.text_committed.connect(_on_card_text_committed)
		row.delete_requested.connect(_on_card_delete_requested)
		row.add_child_requested.connect(_on_card_add_child_requested)
		var sub_v: Variant = card.get("subcards", null)
		if typeof(sub_v) == TYPE_ARRAY and (sub_v as Array).size() > 0:
			var sub_container: VBoxContainer = VBoxContainer.new()
			sub_container.add_theme_constant_override("separation", 4)
			parent.add_child(sub_container)
			_render_card_array(sub_v as Array, sub_container, indent_level + 1)


func _refresh_summary() -> void:
	var cards_raw: Variant = _item_dict.get("cards", [])
	var cards: Array = cards_raw if typeof(cards_raw) == TYPE_ARRAY else []
	var counts: Vector2i = TodoCardData.count_completed(cards)
	_summary_label.text = "%d / %d done" % [counts.x, counts.y]


func _toggle_title_edit() -> void:
	_title_editing = not _title_editing
	_apply_title()


func _on_title_submitted(text: String) -> void:
	_commit_title(text)


func _on_title_focus_exited() -> void:
	if _title_editing:
		_commit_title(_title_edit.text)


func _commit_title(text: String) -> void:
	_title_editing = false
	var trimmed: String = text.strip_edges()
	if trimmed == "":
		trimmed = "Todo List"
	if String(_item_dict.get("title", "")) != trimmed:
		_item_dict["title"] = trimmed
		_emit_changed()
	_apply_title()


func _on_add_card_pressed() -> void:
	var text: String = _add_card_input.text.strip_edges()
	_append_top_level_card(text)


func _on_add_card_text_submitted(text: String) -> void:
	_append_top_level_card(text.strip_edges())


func _append_top_level_card(text: String) -> void:
	if text == "":
		return
	var cards_raw: Variant = _item_dict.get("cards", [])
	var cards: Array = (cards_raw if typeof(cards_raw) == TYPE_ARRAY else []).duplicate(true)
	var card: Dictionary = TodoCardData.make_default()
	card["text"] = text
	cards.append(card)
	_item_dict["cards"] = cards
	_add_card_input.text = ""
	_rebuild_rows()
	_refresh_summary()
	_emit_changed()


func _on_card_completed_toggled(card_id: String, completed: bool) -> void:
	var cards_raw: Variant = _item_dict.get("cards", [])
	var cards: Array = cards_raw if typeof(cards_raw) == TYPE_ARRAY else []
	var updated: Array = TodoCardData.mutate_card(cards, card_id, func(c: Dictionary) -> void:
		c["completed"] = completed
	)
	if updated == cards:
		return
	_item_dict["cards"] = updated
	_refresh_summary()
	_emit_changed()


func _on_card_text_committed(card_id: String, new_text: String) -> void:
	var cards_raw: Variant = _item_dict.get("cards", [])
	var cards: Array = cards_raw if typeof(cards_raw) == TYPE_ARRAY else []
	var updated: Array = TodoCardData.mutate_card(cards, card_id, func(c: Dictionary) -> void:
		c["text"] = new_text
	)
	if updated == cards:
		return
	_item_dict["cards"] = updated
	_emit_changed()


func _on_card_delete_requested(card_id: String) -> void:
	var cards_raw: Variant = _item_dict.get("cards", [])
	var cards: Array = cards_raw if typeof(cards_raw) == TYPE_ARRAY else []
	var pkg: Dictionary = TodoCardData.remove_card(cards, card_id)
	if (pkg.get("removed", {}) as Dictionary).is_empty():
		return
	_item_dict["cards"] = pkg.get("cards", cards)
	_rebuild_rows()
	_refresh_summary()
	_emit_changed()


func _on_card_add_child_requested(card_id: String) -> void:
	var cards_raw: Variant = _item_dict.get("cards", [])
	var cards: Array = cards_raw if typeof(cards_raw) == TYPE_ARRAY else []
	var path: Array = TodoCardData.find_path(cards, card_id)
	if path.is_empty():
		return
	var new_card: Dictionary = TodoCardData.make_default()
	new_card["text"] = "New subtask"
	var node: Dictionary = TodoCardData.get_at_path(cards, path)
	if node.is_empty():
		return
	var sub: Array = node.get("subcards", []) as Array
	var updated: Array = TodoCardData.insert_at_path(cards, path, sub.size(), new_card)
	_item_dict["cards"] = updated
	_item_dict["cards"] = TodoCardData.mutate_card(_item_dict["cards"], card_id, func(c: Dictionary) -> void:
		c["expanded"] = true
	)
	_rebuild_rows()
	_refresh_summary()
	_emit_changed()


func _emit_changed() -> void:
	payload_changed.emit(_item_dict.duplicate(true))
