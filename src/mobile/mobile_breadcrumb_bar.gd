class_name MobileBreadcrumbBar
extends PanelContainer

signal crumb_selected(kind: String, target_id: String)

const SEPARATOR_TEXT: String = "›"
const ROOT_LABEL: String = "All Projects"


func _ready() -> void:
	refresh()


func clear() -> void:
	for child: Node in get_children():
		child.queue_free()


func refresh() -> void:
	clear()
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	add_child(hbox)
	var project: Project = AppState.current_project
	if project == null:
		var lbl: Label = Label.new()
		lbl.text = ROOT_LABEL
		lbl.theme_type_variation = &"BreadcrumbLabel"
		hbox.add_child(lbl)
		return
	_append_project_crumb(hbox, project)
	if AppState.current_page_kind == AppState.PAGE_KIND_BOARD and AppState.current_board != null:
		_append_board_chain(hbox, project, AppState.current_board)
	elif AppState.current_page_kind == AppState.PAGE_KIND_MAP and AppState.current_map_page != null:
		_append_separator(hbox)
		_append_map_crumb(hbox, AppState.current_map_page)


func _append_project_crumb(hbox: HBoxContainer, project: Project) -> void:
	var btn: Button = Button.new()
	btn.text = project.name
	btn.focus_mode = Control.FOCUS_NONE
	btn.theme_type_variation = &"BreadcrumbButton"
	btn.pressed.connect(func() -> void:
		if project.root_board_id != "":
			crumb_selected.emit(AppState.PAGE_KIND_BOARD, project.root_board_id)
	)
	hbox.add_child(btn)


func _append_board_chain(hbox: HBoxContainer, project: Project, current: Board) -> void:
	var path: Array = AppState.breadcrumb_path()
	for i: int in range(path.size()):
		_append_separator(hbox)
		var entry: Dictionary = path[i]
		var is_current: bool = i == path.size() - 1
		if is_current:
			var lbl: Label = Label.new()
			lbl.text = String(entry.get("name", "Board"))
			lbl.theme_type_variation = &"BreadcrumbLabel"
			hbox.add_child(lbl)
		else:
			var btn: Button = Button.new()
			btn.text = String(entry.get("name", "Board"))
			btn.focus_mode = Control.FOCUS_NONE
			btn.theme_type_variation = &"BreadcrumbButton"
			var target_id: String = String(entry.get("id", ""))
			btn.pressed.connect(func() -> void: crumb_selected.emit(AppState.PAGE_KIND_BOARD, target_id))
			hbox.add_child(btn)


func _append_map_crumb(hbox: HBoxContainer, page: MapPage) -> void:
	var lbl: Label = Label.new()
	lbl.text = page.name
	lbl.theme_type_variation = &"BreadcrumbLabel"
	hbox.add_child(lbl)


func _append_separator(hbox: HBoxContainer) -> void:
	var sep: Label = Label.new()
	sep.text = SEPARATOR_TEXT
	sep.theme_type_variation = &"MutedLabel"
	hbox.add_child(sep)
