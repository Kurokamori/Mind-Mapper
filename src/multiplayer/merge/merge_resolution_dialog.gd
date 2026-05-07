class_name MergeResolutionDialog
extends Window

signal merge_confirmed(resolutions: Array)
signal merge_cancelled()

@onready var _summary_label: Label = %SummaryLabel
@onready var _conflict_list: VBoxContainer = %ConflictList
@onready var _row_template: Control = %RowTemplate
@onready var _keep_all_mine_button: Button = %KeepAllMineButton
@onready var _keep_all_host_button: Button = %KeepAllHostButton
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton
@onready var _status_label: Label = %StatusLabel

var _conflicts: Array = []
var _row_controls: Array = []


func _ready() -> void:
	close_requested.connect(_on_close_requested)
	if _row_template != null:
		_row_template.visible = false
	_keep_all_mine_button.pressed.connect(_on_keep_all_mine_pressed)
	_keep_all_host_button.pressed.connect(_on_keep_all_host_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)


func setup(conflicts: Array, non_conflicting_local_count: int, non_conflicting_remote_count: int, host_display_name: String) -> void:
	_conflicts = conflicts.duplicate()
	for c in _conflicts:
		(c as Dictionary)["resolution"] = MergeAnalyzer.RESOLUTION_PENDING
	_summary_label.text = _build_summary_text(non_conflicting_local_count, non_conflicting_remote_count, host_display_name)
	_clear_rows()
	for i in range(_conflicts.size()):
		var conflict: Dictionary = _conflicts[i] as Dictionary
		var row: Control = _row_template.duplicate() as Control
		row.visible = true
		_conflict_list.add_child(row)
		_populate_row(row, conflict, i)
		_row_controls.append(row)
	_update_status()


func _build_summary_text(local_count: int, remote_count: int, host_display_name: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("%d conflicting edit(s) need your attention." % _conflicts.size())
	parts.append("%d of your offline change(s) will be sent to the host." % local_count)
	var host_label: String = host_display_name if host_display_name != "" else "the host"
	parts.append("%d change(s) from %s will be merged in automatically." % [remote_count, host_label])
	return "\n".join(parts)


func _clear_rows() -> void:
	for row in _row_controls:
		if row != null and is_instance_valid(row):
			row.queue_free()
	_row_controls.clear()


func _populate_row(row: Control, conflict: Dictionary, index: int) -> void:
	var target_label: Label = row.get_node("RowVBox/TargetLabel") as Label
	var property_label: Label = row.get_node("RowVBox/PropertyLabel") as Label
	var local_label_value: Label = row.get_node("RowVBox/SidesRow/LocalPanel/LocalVBox/LocalValueLabel") as Label
	var local_meta_label: Label = row.get_node("RowVBox/SidesRow/LocalPanel/LocalVBox/LocalMetaLabel") as Label
	var remote_value_label: Label = row.get_node("RowVBox/SidesRow/RemotePanel/RemoteVBox/RemoteValueLabel") as Label
	var remote_meta_label: Label = row.get_node("RowVBox/SidesRow/RemotePanel/RemoteVBox/RemoteMetaLabel") as Label
	var keep_local_button: Button = row.get_node("RowVBox/SidesRow/LocalPanel/LocalVBox/KeepLocalButton") as Button
	var keep_remote_button: Button = row.get_node("RowVBox/SidesRow/RemotePanel/RemoteVBox/KeepRemoteButton") as Button
	var resolution_label: Label = row.get_node("RowVBox/ResolutionLabel") as Label
	target_label.text = _format_target(conflict)
	property_label.text = "Property: %s" % String(conflict.get("property_label", ""))
	var local_summary: Dictionary = conflict.get("local_summary", {}) as Dictionary
	var remote_summary: Dictionary = conflict.get("remote_summary", {}) as Dictionary
	local_label_value.text = _format_value_block(local_summary)
	local_meta_label.text = _format_meta(local_summary, "you")
	remote_value_label.text = _format_value_block(remote_summary)
	remote_meta_label.text = _format_meta(remote_summary, "host")
	keep_local_button.pressed.connect(_on_keep_local_pressed.bind(index))
	keep_remote_button.pressed.connect(_on_keep_remote_pressed.bind(index))
	row.set_meta("resolution_label", resolution_label)
	_refresh_resolution_label(index)


func _format_target(conflict: Dictionary) -> String:
	var kind: String = String(conflict.get("target_kind", ""))
	var id_str: String = String(conflict.get("target_id", ""))
	match kind:
		MergeAnalyzer.TARGET_KIND_ITEM:
			return "Node %s" % id_str
		MergeAnalyzer.TARGET_KIND_CONNECTION:
			return "Connection %s" % id_str
		MergeAnalyzer.TARGET_KIND_COMMENT:
			return "Comment %s" % id_str
		MergeAnalyzer.TARGET_KIND_BOARD:
			return "Board property %s" % id_str
		_:
			return id_str


func _format_value_block(summary: Dictionary) -> String:
	var label: String = String(summary.get("label", ""))
	var value: String = String(summary.get("value_text", ""))
	if label == "":
		return value
	if value == "":
		return label
	return "%s\n%s" % [label, value]


func _format_meta(summary: Dictionary, fallback_label: String) -> String:
	var author: String = String(summary.get("author_display_name", ""))
	if author == "":
		author = fallback_label
	var origin_unix: int = int(summary.get("origin_unix", 0))
	var ts: String = _format_timestamp(origin_unix)
	return "%s · %s" % [author, ts]


func _format_timestamp(unix_seconds: int) -> String:
	if unix_seconds <= 0:
		return "unknown time"
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix_seconds)
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(dt.get("year", 0)),
		int(dt.get("month", 0)),
		int(dt.get("day", 0)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
		int(dt.get("second", 0)),
	]


func _on_keep_local_pressed(index: int) -> void:
	(_conflicts[index] as Dictionary)["resolution"] = MergeAnalyzer.RESOLUTION_KEEP_LOCAL
	_refresh_resolution_label(index)
	_update_status()


func _on_keep_remote_pressed(index: int) -> void:
	(_conflicts[index] as Dictionary)["resolution"] = MergeAnalyzer.RESOLUTION_KEEP_REMOTE
	_refresh_resolution_label(index)
	_update_status()


func _on_keep_all_mine_pressed() -> void:
	for i in range(_conflicts.size()):
		(_conflicts[i] as Dictionary)["resolution"] = MergeAnalyzer.RESOLUTION_KEEP_LOCAL
		_refresh_resolution_label(i)
	_update_status()


func _on_keep_all_host_pressed() -> void:
	for i in range(_conflicts.size()):
		(_conflicts[i] as Dictionary)["resolution"] = MergeAnalyzer.RESOLUTION_KEEP_REMOTE
		_refresh_resolution_label(i)
	_update_status()


func _refresh_resolution_label(index: int) -> void:
	if index < 0 or index >= _row_controls.size():
		return
	var row: Control = _row_controls[index] as Control
	if row == null:
		return
	var label: Label = row.get_meta("resolution_label", null) as Label
	if label == null:
		return
	var resolution: String = String((_conflicts[index] as Dictionary).get("resolution", MergeAnalyzer.RESOLUTION_PENDING))
	match resolution:
		MergeAnalyzer.RESOLUTION_KEEP_LOCAL:
			label.text = "→ Keeping your edit"
		MergeAnalyzer.RESOLUTION_KEEP_REMOTE:
			label.text = "→ Keeping host's edit"
		_:
			label.text = "→ Pending"


func _update_status() -> void:
	var pending: int = 0
	for c in _conflicts:
		if String((c as Dictionary).get("resolution", MergeAnalyzer.RESOLUTION_PENDING)) == MergeAnalyzer.RESOLUTION_PENDING:
			pending += 1
	if pending == 0:
		_status_label.text = "All conflicts resolved. Ready to apply."
		_confirm_button.disabled = false
	else:
		_status_label.text = "%d conflict(s) still pending." % pending
		_confirm_button.disabled = true


func _on_confirm_pressed() -> void:
	emit_signal("merge_confirmed", _conflicts)
	hide()


func _on_cancel_pressed() -> void:
	emit_signal("merge_cancelled")
	hide()


func _on_close_requested() -> void:
	emit_signal("merge_cancelled")
	hide()
