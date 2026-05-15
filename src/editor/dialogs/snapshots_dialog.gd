extends Window

@onready var _list: ItemList = %SnapshotList
@onready var _label_input: LineEdit = %LabelInput
@onready var _create_btn: Button = %CreateButton
@onready var _restore_btn: Button = %RestoreButton
@onready var _delete_btn: Button = %DeleteButton
@onready var _close_btn: Button = %CloseButton
@onready var _status: Label = %StatusLabel

var _project: Project = null


func bind(project: Project) -> void:
	_project = project


func _ready() -> void:
	close_requested.connect(queue_free)
	_close_btn.pressed.connect(queue_free)
	_create_btn.pressed.connect(_on_create)
	_restore_btn.pressed.connect(_on_restore)
	_delete_btn.pressed.connect(_on_delete)
	_refresh()


func _refresh() -> void:
	if _list == null:
		return
	_list.clear()
	if _project == null:
		_status.text = "(no project)"
		return
	var snapshots: Array = _project.list_snapshots()
	for s in snapshots:
		var when: String = Time.get_datetime_string_from_unix_time(int(s.created_unix), true)
		_list.add_item("%s — %s" % [when, String(s.label)])
		_list.set_item_metadata(_list.item_count - 1, String(s.id))
	_status.text = "%d snapshots" % snapshots.size()


func _on_create() -> void:
	if _project == null:
		return
	var label: String = _label_input.text.strip_edges()
	if label == "":
		label = "manual"
	var id: String = _project.create_snapshot(label)
	if id != "":
		_status.text = "Snapshot saved."
		_label_input.text = ""
		_refresh()
	else:
		_status.text = "Snapshot failed."


func _on_restore() -> void:
	var sel: PackedInt32Array = _list.get_selected_items()
	if sel.size() == 0 or _project == null:
		return
	var id: String = String(_list.get_item_metadata(sel[0]))
	var conf: ConfirmationDialog = ConfirmationDialog.new()
	conf.dialog_text = "Restore this snapshot? Current state will be overwritten."
	conf.confirmed.connect(func() -> void:
		if _project.restore_snapshot(id):
			_status.text = "Restored."
			History.clear_all()
			if AppState.current_board != null:
				var fresh: Board = _project.read_board(AppState.current_board.id)
				if fresh != null:
					AppState.current_board = fresh
					AppState.emit_signal("current_board_changed", fresh)
		else:
			_status.text = "Restore failed."
		conf.queue_free()
	)
	conf.canceled.connect(func() -> void: conf.queue_free())
	add_child(conf)
	PopupSizer.popup_fit(conf)


func _on_delete() -> void:
	var sel: PackedInt32Array = _list.get_selected_items()
	if sel.size() == 0 or _project == null:
		return
	var id: String = String(_list.get_item_metadata(sel[0]))
	if _project.delete_snapshot(id):
		_status.text = "Deleted."
		_refresh()
