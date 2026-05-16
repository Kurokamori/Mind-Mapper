extends DockablePanel

@onready var _list: VBoxContainer = %List
@onready var _empty_label: Label = %EmptyLabel
@onready var _close_btn: Button = %CloseButton

var _refresh_timer: Timer


func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_close_btn.pressed.connect(func() -> void: visible = false)
	TimerRegistry.timers_changed.connect(_rebuild)
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 0.5
	_refresh_timer.one_shot = false
	_refresh_timer.timeout.connect(_rebuild)
	add_child(_refresh_timer)
	_refresh_timer.start()
	_rebuild()


func _rebuild() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	var entries: Array = TimerRegistry.entries()
	if entries.is_empty():
		_empty_label.visible = true
		return
	_empty_label.visible = false
	for e in entries:
		_list.add_child(_make_row(e))


func _make_row(entry: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var dot: ColorRect = ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.color = Color(0.4, 0.85, 0.4) if bool(entry.get("running", false)) else Color(0.5, 0.5, 0.5)
	row.add_child(dot)
	var label: Label = Label.new()
	label.text = String(entry.get("label", "Timer"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var time_label: Label = Label.new()
	time_label.text = TimerRegistry.format_duration(float(entry.get("seconds_remaining", 0.0)), false)
	row.add_child(time_label)
	var jump: Button = Button.new()
	jump.text = "Jump"
	var board_id: String = String(entry.get("board_id", ""))
	var item_id: String = String(entry.get("item_id", ""))
	jump.pressed.connect(func() -> void:
		if AppState.current_board != null and AppState.current_board.id != board_id:
			AppState.navigate_to_board(board_id)
		var ed: Node = _find_editor()
		if ed != null and ed.has_method("navigate_to_backlink"):
			ed.navigate_to_backlink(board_id, item_id)
	)
	row.add_child(jump)
	return row


func _find_editor() -> Node:
	return EditorLocator.find_for(self)
