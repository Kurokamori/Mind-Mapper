class_name CommandPalette
extends CanvasLayer

signal result_chosen(result: ProjectIndex.SearchResult)

const MAX_RESULTS: int = 80

@onready var _backdrop: ColorRect = %Backdrop
@onready var _panel: PanelContainer = %Panel
@onready var _query_edit: LineEdit = %QueryEdit
@onready var _results: ItemList = %Results
@onready var _hint_label: Label = %HintLabel

var _current_results: Array = []
var _ignore_next_text_changed: bool = false


func _ready() -> void:
	visible = false
	_query_edit.text_changed.connect(_on_query_changed)
	_query_edit.text_submitted.connect(_on_query_submitted)
	_query_edit.gui_input.connect(_on_query_gui_input)
	_results.item_activated.connect(_on_result_activated)
	_results.item_clicked.connect(_on_result_clicked)
	_backdrop.gui_input.connect(_on_backdrop_input)


func open() -> void:
	visible = true
	_ignore_next_text_changed = true
	_query_edit.text = ""
	_ignore_next_text_changed = false
	_refresh_results("")
	_query_edit.grab_focus()


func close() -> void:
	visible = false
	_results.clear()
	_current_results.clear()


func is_open() -> bool:
	return visible


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			close()


func _on_query_changed(text: String) -> void:
	if _ignore_next_text_changed:
		_ignore_next_text_changed = false
		return
	_refresh_results(text)


func _on_query_submitted(_text: String) -> void:
	_activate_selected()


func _on_query_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event as InputEventKey
		match k.keycode:
			KEY_ESCAPE:
				close()
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_move_selection(1)
				get_viewport().set_input_as_handled()
			KEY_UP:
				_move_selection(-1)
				get_viewport().set_input_as_handled()
			KEY_PAGEDOWN:
				_move_selection(8)
				get_viewport().set_input_as_handled()
			KEY_PAGEUP:
				_move_selection(-8)
				get_viewport().set_input_as_handled()


func _move_selection(delta: int) -> void:
	var total: int = _results.item_count
	if total == 0:
		return
	var current: int = -1
	var selected: PackedInt32Array = _results.get_selected_items()
	if selected.size() > 0:
		current = selected[0]
	var next: int = clamp(current + delta, 0, total - 1)
	if current < 0:
		next = 0 if delta >= 0 else total - 1
	_results.select(next)
	_results.ensure_current_is_visible()


func _on_result_activated(index: int) -> void:
	_activate_index(index)


func _on_result_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_LEFT:
		_activate_index(index)


func _activate_selected() -> void:
	var selected: PackedInt32Array = _results.get_selected_items()
	if selected.size() > 0:
		_activate_index(selected[0])
	elif _current_results.size() > 0:
		_activate_index(0)


func _activate_index(index: int) -> void:
	if index < 0 or index >= _current_results.size():
		return
	var result: ProjectIndex.SearchResult = _current_results[index]
	close()
	emit_signal("result_chosen", result)


func _refresh_results(query: String) -> void:
	_results.clear()
	_current_results.clear()
	var trimmed: String = query.strip_edges()
	if trimmed == "":
		_hint_label.text = "Type to search · ↑/↓ to move · Enter to jump · Esc to close"
		return
	var raw: Array = ProjectIndex.search(trimmed, MAX_RESULTS)
	_current_results = raw
	if raw.is_empty():
		_hint_label.text = "No results for \"%s\"" % trimmed
		return
	_hint_label.text = "%d result%s" % [raw.size(), "" if raw.size() == 1 else "s"]
	for entry_v: Variant in raw:
		var entry: ProjectIndex.SearchResult = entry_v
		var prefix: String = _glyph_for_kind(entry.kind)
		var line: String = "%s  %s   —   %s" % [prefix, entry.title, entry.subtitle]
		_results.add_item(line)
	_results.select(0)


func _glyph_for_kind(kind: String) -> String:
	match kind:
		ProjectIndex.SEARCH_RESULT_KIND_BOARD: return "[B]"
		ProjectIndex.SEARCH_RESULT_KIND_ITEM: return "[·]"
		ProjectIndex.SEARCH_RESULT_KIND_TODO_CARD: return "[✓]"
		ProjectIndex.SEARCH_RESULT_KIND_BLOCK_ROW: return "[▤]"
		ProjectIndex.SEARCH_RESULT_KIND_CONNECTION: return "[→]"
	return "[ ]"
