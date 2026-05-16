class_name MobileBreadcrumbBar
extends PanelContainer

signal crumb_selected(kind: String, target_id: String)

const SEPARATOR_TEXT: String = " > "
const ROOT_LABEL: String = "All Projects"


func _ready() -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.10, 0.85)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8.0)
	add_theme_stylebox_override("panel", sb)
	refresh()


func clear() -> void:
	for child: Node in get_children():
		child.queue_free()


func refresh() -> void:
	clear()
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	add_child(hbox)
	var project: Project = AppState.current_project
	if project == null:
		var lbl: Label = Label.new()
		lbl.text = ROOT_LABEL
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
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.70, 0.80, 0.95))
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
		var btn: Button = Button.new()
		btn.text = String(entry.get("name", "Board"))
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 16)
		var is_current: bool = i == path.size() - 1
		btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0) if is_current else Color(0.70, 0.80, 0.95))
		var target_id: String = String(entry.get("id", ""))
		btn.pressed.connect(func() -> void: crumb_selected.emit(AppState.PAGE_KIND_BOARD, target_id))
		hbox.add_child(btn)


func _append_map_crumb(hbox: HBoxContainer, page: MapPage) -> void:
	var lbl: Label = Label.new()
	lbl.text = page.name
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	lbl.add_theme_font_size_override("font_size", 16)
	hbox.add_child(lbl)


func _append_separator(hbox: HBoxContainer) -> void:
	var sep: Label = Label.new()
	sep.text = SEPARATOR_TEXT
	sep.add_theme_color_override("font_color", Color(0.50, 0.55, 0.65))
	hbox.add_child(sep)
