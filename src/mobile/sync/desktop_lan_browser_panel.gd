class_name DesktopLanBrowserPanel
extends Control

signal host_pulled(folder_path: String, project_id: String, host_entry: Dictionary)
signal host_pushed(host_entry: Dictionary)
signal host_synced(folder_path: String, project_id: String, host_entry: Dictionary)
signal toast_requested(severity: String, message: String)

const HOST_ROW_SCENE: PackedScene = preload("res://src/mobile/sync/desktop_lan_host_row.tscn")

@onready var _hosts_root: VBoxContainer = %HostsRoot
@onready var _empty_label: Label = %EmptyLabel
@onready var _status_label: Label = %StatusLabel
@onready var _hosts_scroll: ScrollContainer = %HostsScroll

var _rows: Array = []


func _ready() -> void:
	if DesktopLanSyncService != null:
		DesktopLanSyncService.hosts_changed.connect(_on_hosts_changed)
		DesktopLanSyncService.status_changed.connect(_on_status_changed)
		DesktopLanSyncService.flow_completed.connect(_on_flow_completed)
		DesktopLanSyncService.flow_failed.connect(_on_flow_failed)
		_render(DesktopLanSyncService.discovered_hosts())
		_status_label.text = DesktopLanSyncService.last_status()
	else:
		_status_label.text = "LAN sync service unavailable"


func refresh_now() -> void:
	if DesktopLanSyncService == null:
		return
	_render(DesktopLanSyncService.discovered_hosts())


func _on_hosts_changed(host_list: Array) -> void:
	_render(host_list)


func _on_status_changed(message: String) -> void:
	_status_label.text = message


func _render(host_list: Array) -> void:
	for child: Node in _hosts_root.get_children():
		if child == _empty_label:
			continue
		child.queue_free()
	_rows.clear()
	_empty_label.visible = host_list.is_empty()
	for entry_v: Variant in host_list:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var row: DesktopLanHostRow = HOST_ROW_SCENE.instantiate()
		_hosts_root.add_child(row)
		var local_folder: String = DesktopLanSyncService.find_local_folder_for_host(entry)
		var local_name: String = _local_name_for(entry)
		row.bind(entry, local_folder, local_name)
		row.pull_requested.connect(_on_row_pull_requested)
		row.push_requested.connect(_on_row_push_requested)
		row.sync_requested.connect(_on_row_sync_requested)
		_rows.append(row)


func _local_name_for(host_entry: Dictionary) -> String:
	if ProjectStore == null:
		return ""
	var project_id: String = String(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_ID, ""))
	if project_id == "":
		return ""
	for entry_v: Variant in ProjectStore.recent():
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		if String(entry.get("id", "")) == project_id:
			return String(entry.get("name", ""))
	return ""


func _on_row_pull_requested(host_entry: Dictionary) -> void:
	var err: Error = DesktopLanSyncService.begin_pull(host_entry)
	if err != OK:
		toast_requested.emit("error", "Pull could not start (%d)" % err)


func _on_row_push_requested(host_entry: Dictionary, local_folder: String) -> void:
	var err: Error = DesktopLanSyncService.begin_push(host_entry, local_folder)
	if err != OK:
		toast_requested.emit("error", "Push could not start (%d)" % err)


func _on_row_sync_requested(host_entry: Dictionary, local_folder: String) -> void:
	var err: Error = DesktopLanSyncService.begin_two_way_sync(host_entry, local_folder)
	if err != OK:
		toast_requested.emit("error", "Sync could not start (%d)" % err)


func _on_flow_completed(folder_path: String, project_id: String, flow: String, host_entry: Dictionary) -> void:
	match flow:
		LanSyncClient.FLOW_PULL:
			host_pulled.emit(folder_path, project_id, host_entry)
			toast_requested.emit("info", "Pulled '%s'" % String(host_entry.get(LanSyncProtocol.ANNOUNCE_FIELD_PROJECT_NAME, "project")))
		LanSyncClient.FLOW_PUSH:
			host_pushed.emit(host_entry)
			toast_requested.emit("info", "Push completed")
		LanSyncClient.FLOW_SYNC:
			host_synced.emit(folder_path, project_id, host_entry)
			toast_requested.emit("info", "Sync completed")


func _on_flow_failed(reason: String, _flow: String, _host_entry: Dictionary) -> void:
	toast_requested.emit("error", "LAN flow failed: %s" % reason)
