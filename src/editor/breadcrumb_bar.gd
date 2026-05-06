class_name BreadcrumbBar
extends PanelContainer

@onready var _back_button: Button = %BackButton
@onready var _root_button: Button = %RootButton
@onready var _segments: HBoxContainer = %Segments
@onready var _current_label: Label = %CurrentLabel


func _ready() -> void:
	ThemeManager.theme_applied.connect(_apply_translucent_panel)
	_apply_translucent_panel()
	_back_button.pressed.connect(_on_back_pressed)
	_root_button.pressed.connect(_on_root_pressed)
	AppState.navigation_changed.connect(_refresh)
	_refresh()


func _apply_translucent_panel() -> void:
	ThemeManager.apply_translucent_panel(self)
	var sb: StyleBox = get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		var flat: StyleBoxFlat = sb as StyleBoxFlat
		flat.content_margin_top = 0.0
		flat.content_margin_bottom = 0.0


func _refresh() -> void:
	if _segments == null:
		return
	for child in _segments.get_children():
		child.queue_free()
	_back_button.disabled = not AppState.can_go_back()
	if AppState.current_project == null:
		_current_label.text = ""
		_root_button.disabled = true
		return
	if AppState.current_page_kind == AppState.PAGE_KIND_MAP:
		if AppState.current_map_page == null:
			_current_label.text = ""
			_root_button.disabled = true
			return
		_current_label.text = "🗺  " + AppState.current_map_page.name
		_root_button.disabled = false
		return
	if AppState.current_board == null:
		_current_label.text = ""
		_root_button.disabled = true
		return
	var path: Array = AppState.breadcrumb_path()
	if path.is_empty():
		_current_label.text = AppState.current_board.name
		_root_button.disabled = (AppState.current_board.id == AppState.current_project.root_board_id)
		return
	_root_button.disabled = (path[0].get("id", "") == AppState.current_board.id)
	for i in range(path.size()):
		var entry: Dictionary = path[i]
		if i == path.size() - 1:
			_current_label.text = String(entry.get("name", ""))
		else:
			var btn := Button.new()
			btn.text = String(entry.get("name", ""))
			btn.flat = true
			btn.focus_mode = Control.FOCUS_NONE
			btn.pressed.connect(_on_segment_pressed.bind(String(entry.get("id", ""))))
			_segments.add_child(btn)
			var sep := Label.new()
			sep.text = "›"
			_segments.add_child(sep)


func _on_back_pressed() -> void:
	AppState.navigate_back()


func _on_root_pressed() -> void:
	if AppState.current_project == null:
		return
	AppState.navigate_to_board(AppState.current_project.root_board_id)


func _on_segment_pressed(board_id: String) -> void:
	AppState.navigate_to_board(board_id)
