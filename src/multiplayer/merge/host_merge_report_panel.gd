class_name HostMergeReportPanel
extends Window

signal rollback_individual_requested(report_id: String, op_id: String)
signal rollback_all_requested(report_id: String)
signal report_dismissed(report_id: String)

@onready var _report_tabs: TabContainer = %ReportTabs
@onready var _empty_label: Label = %EmptyLabel
@onready var _close_button: Button = %CloseButton
@onready var _row_template: PanelContainer = %ReportRowTemplate
@onready var _tab_template: VBoxContainer = %ReportTabTemplate

var _reports: Array = []
var _tabs_by_report_id: Dictionary = {}


func _ready() -> void:
	close_requested.connect(_on_close_requested)
	if _row_template != null:
		_row_template.visible = false
	if _tab_template != null:
		_tab_template.visible = false
		_tab_template.get_parent().remove_child(_tab_template)
	_close_button.pressed.connect(_on_close_button_pressed)
	_refresh_empty_state()


func add_report(report: Dictionary) -> void:
	_reports.append(report)
	_build_tab_for_report(report)
	_refresh_empty_state()
	popup_centered_clamped(Vector2i(720, 480))


func mark_op_rolled_back(report_id: String, op_id: String) -> void:
	for report in _reports:
		if String((report as Dictionary).get("report_id", "")) != report_id:
			continue
		var entries: Array = (report as Dictionary).get("entries", []) as Array
		for entry in entries:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			if String((entry as Dictionary).get("op_id", "")) == op_id:
				(entry as Dictionary)["rolled_back"] = true
				_refresh_tab_for_report(report)
				return


func mark_report_rolled_back(report_id: String) -> void:
	for report in _reports:
		if String((report as Dictionary).get("report_id", "")) != report_id:
			continue
		var entries: Array = (report as Dictionary).get("entries", []) as Array
		for entry in entries:
			if typeof(entry) == TYPE_DICTIONARY:
				(entry as Dictionary)["rolled_back"] = true
		_refresh_tab_for_report(report)
		return


func remove_report(report_id: String) -> void:
	for i in range(_reports.size()):
		if String((_reports[i] as Dictionary).get("report_id", "")) != report_id:
			continue
		_reports.remove_at(i)
		break
	if _tabs_by_report_id.has(report_id):
		var tab_node: Control = _tabs_by_report_id[report_id] as Control
		if tab_node != null and is_instance_valid(tab_node):
			tab_node.queue_free()
		_tabs_by_report_id.erase(report_id)
	_refresh_empty_state()


func _build_tab_for_report(report: Dictionary) -> void:
	var report_id: String = String(report.get("report_id", ""))
	if report_id == "":
		return
	if _tabs_by_report_id.has(report_id):
		_refresh_tab_for_report(report)
		return
	var tab_root: VBoxContainer = _tab_template.duplicate() as VBoxContainer
	tab_root.visible = true
	tab_root.name = _tab_title(report)
	_report_tabs.add_child(tab_root)
	_tabs_by_report_id[report_id] = tab_root
	_populate_tab(tab_root, report)


func _refresh_tab_for_report(report: Dictionary) -> void:
	var report_id: String = String(report.get("report_id", ""))
	if not _tabs_by_report_id.has(report_id):
		return
	var tab_root: VBoxContainer = _tabs_by_report_id[report_id] as VBoxContainer
	if tab_root == null:
		return
	for child in tab_root.get_children():
		child.queue_free()
	_populate_tab(tab_root, report)


func _populate_tab(tab_root: VBoxContainer, report: Dictionary) -> void:
	var summary_label: Label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.text = _summary_text(report)
	tab_root.add_child(summary_label)
	var bulk_row: HBoxContainer = HBoxContainer.new()
	bulk_row.add_theme_constant_override("separation", 8)
	tab_root.add_child(bulk_row)
	var rollback_all_button: Button = Button.new()
	rollback_all_button.text = "Roll back the whole merge"
	rollback_all_button.pressed.connect(_on_rollback_all_pressed.bind(String(report.get("report_id", ""))))
	bulk_row.add_child(rollback_all_button)
	var dismiss_button: Button = Button.new()
	dismiss_button.text = "Dismiss"
	dismiss_button.pressed.connect(_on_dismiss_report_pressed.bind(String(report.get("report_id", ""))))
	bulk_row.add_child(dismiss_button)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_root.add_child(scroll)
	var rows_vbox: VBoxContainer = VBoxContainer.new()
	rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(rows_vbox)
	var entries: Array = report.get("entries", []) as Array
	for entry_v: Variant in entries:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		_add_entry_row(rows_vbox, String(report.get("report_id", "")), entry_v as Dictionary)


func _add_entry_row(rows_vbox: VBoxContainer, report_id: String, entry: Dictionary) -> void:
	var row: PanelContainer = _row_template.duplicate() as PanelContainer
	row.visible = true
	rows_vbox.add_child(row)
	var description_label: Label = row.get_node("RowMargin/RowHBox/RowDescriptionLabel") as Label
	var status_label: Label = row.get_node("RowMargin/RowHBox/RowStatusLabel") as Label
	var rollback_button: Button = row.get_node("RowMargin/RowHBox/RowRollbackButton") as Button
	description_label.text = _entry_description(entry)
	status_label.text = _entry_status_text(entry)
	rollback_button.disabled = bool(entry.get("rolled_back", false)) or not bool(entry.get("can_rollback", true))
	rollback_button.pressed.connect(_on_rollback_individual_pressed.bind(report_id, String(entry.get("op_id", ""))))


func _summary_text(report: Dictionary) -> String:
	var name: String = String(report.get("author_display_name", "A co-author"))
	var kept_local: int = int(report.get("kept_local_count", 0))
	var kept_host: int = int(report.get("kept_host_count", 0))
	var auto_merged: int = int(report.get("auto_merged_count", 0))
	var unix: int = int(report.get("origin_unix", 0))
	var time_str: String = _format_timestamp(unix)
	return "%s rejoined and resolved offline edits at %s.\nApplied: %d of their changes (overrode host)\nKept host: %d (their offline change discarded)\nAuto-merged non-conflicting: %d" % [name, time_str, kept_local, kept_host, auto_merged]


func _entry_description(entry: Dictionary) -> String:
	var target: String = String(entry.get("target_label", ""))
	var prop: String = String(entry.get("property_label", ""))
	var resolution: String = String(entry.get("resolution_label", ""))
	var value: String = String(entry.get("value_text", ""))
	var meta: String = String(entry.get("meta_text", ""))
	var lines: Array = []
	lines.append("%s — %s" % [target, prop])
	if value != "":
		lines.append(value)
	if meta != "":
		lines.append(meta)
	if resolution != "":
		lines.append(resolution)
	return "\n".join(lines)


func _entry_status_text(entry: Dictionary) -> String:
	if bool(entry.get("rolled_back", false)):
		return "Rolled back"
	if not bool(entry.get("can_rollback", true)):
		return "Cannot roll back"
	return ""


func _tab_title(report: Dictionary) -> String:
	var name: String = String(report.get("author_display_name", "merge"))
	var unix: int = int(report.get("origin_unix", 0))
	if unix > 0:
		var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix)
		return "%s @ %02d:%02d" % [name, int(dt.get("hour", 0)), int(dt.get("minute", 0))]
	return name


func _format_timestamp(unix_seconds: int) -> String:
	if unix_seconds <= 0:
		return "(unknown time)"
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix_seconds)
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(dt.get("year", 0)),
		int(dt.get("month", 0)),
		int(dt.get("day", 0)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
		int(dt.get("second", 0)),
	]


func _refresh_empty_state() -> void:
	_empty_label.visible = _reports.is_empty()
	_report_tabs.visible = not _reports.is_empty()


func _on_rollback_individual_pressed(report_id: String, op_id: String) -> void:
	emit_signal("rollback_individual_requested", report_id, op_id)


func _on_rollback_all_pressed(report_id: String) -> void:
	emit_signal("rollback_all_requested", report_id)


func _on_dismiss_report_pressed(report_id: String) -> void:
	emit_signal("report_dismissed", report_id)
	remove_report(report_id)


func _on_close_button_pressed() -> void:
	hide()


func _on_close_requested() -> void:
	hide()
