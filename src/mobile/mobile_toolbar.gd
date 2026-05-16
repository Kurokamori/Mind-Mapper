class_name MobileToolbar
extends PanelContainer

signal action_requested(action: String, payload: Variant)

const ACTION_BACK_TO_PROJECTS: String = "back_to_projects"
const ACTION_FRAME_ALL: String = "frame_all"
const ACTION_TOGGLE_BOARDS: String = "toggle_boards"
const ACTION_TOGGLE_MAPS: String = "toggle_maps"
const ACTION_TOGGLE_COMMENTS: String = "toggle_comments"
const ACTION_NAVIGATE_BACK: String = "navigate_back"
const ACTION_CLOSE_TOOLBAR: String = "close_toolbar"
const ACTION_TOGGLE_EDIT: String = "toggle_edit"
const ACTION_TOGGLE_OUTLINER: String = "toggle_outliner"
const ACTION_DRAW_PEN: String = "draw_pen"
const ACTION_DRAW_ERASER: String = "draw_eraser"
const ACTION_DRAW_PICK: String = "draw_pick"
const ACTION_DRAW_COLOR: String = "draw_color"
const ACTION_DRAW_WIDTH: String = "draw_width"
const ACTION_FILE_TEMPLATES: String = "file_templates"
const ACTION_FILE_TILESETS: String = "file_tilesets"
const ACTION_FILE_IMPORT: String = "file_import"
const ACTION_FILE_EXPORT: String = "file_export"
const ACTION_OPEN_THEME: String = "open_theme"
const ACTION_OPEN_KEYBINDINGS: String = "open_keybindings"

const GROUP_NONE: String = ""
const GROUP_VIEW: String = "view"
const GROUP_DRAW: String = "draw"
const GROUP_FILE: String = "file"

const DRAW_TOOL_NONE: String = "none"
const DRAW_TOOL_PEN: String = "pen"
const DRAW_TOOL_ERASER: String = "eraser"
const DRAW_TOOL_PICK: String = "pick"

@onready var _back_button: Button = %BackButton
@onready var _projects_button: Button = %ProjectsButton
@onready var _frame_button: Button = %FrameButton
@onready var _boards_button: Button = %BoardsButton
@onready var _maps_button: Button = %MapsButton
@onready var _comments_button: Button = %CommentsButton
@onready var _edit_button: Button = %EditButton
@onready var _outliner_button: Button = %OutlinerButton
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel

@onready var _view_group_button: Button = %ViewGroupButton
@onready var _draw_group_button: Button = %DrawGroupButton
@onready var _file_group_button: Button = %FileGroupButton
@onready var _expansion_panel: PanelContainer = %ExpansionPanel
@onready var _view_group: HFlowContainer = %ViewGroup
@onready var _draw_group: HFlowContainer = %DrawGroup
@onready var _file_group: HFlowContainer = %FileGroup
@onready var _view_margin: MarginContainer = %ViewMargin
@onready var _draw_margin: MarginContainer = %DrawMargin
@onready var _file_margin: MarginContainer = %FileMargin

@onready var _draw_pen_button: Button = %DrawPenButton
@onready var _draw_eraser_button: Button = %DrawEraserButton
@onready var _draw_pick_button: Button = %DrawPickButton
@onready var _draw_color_button: ColorPickerButton = %DrawColorButton
@onready var _draw_width_slider: HSlider = %DrawWidthSlider

@onready var _templates_button: Button = %TemplatesButton
@onready var _tilesets_button: Button = %TilesetsButton
@onready var _import_button: Button = %ImportButton
@onready var _export_button: Button = %ExportButton
@onready var _settings_menu_button: MenuButton = %SettingsMenuButton

const SETTINGS_THEME_ID: int = 0
const SETTINGS_KEYBINDINGS_ID: int = 1

var _active_groups: Dictionary = {}
var _active_draw_tool: String = DRAW_TOOL_NONE


func _ready() -> void:
	_back_button.pressed.connect(func() -> void: action_requested.emit(ACTION_NAVIGATE_BACK, null))
	_projects_button.pressed.connect(func() -> void: action_requested.emit(ACTION_BACK_TO_PROJECTS, null))
	_frame_button.pressed.connect(func() -> void: action_requested.emit(ACTION_FRAME_ALL, null))
	_boards_button.pressed.connect(func() -> void: action_requested.emit(ACTION_TOGGLE_BOARDS, null))
	_maps_button.pressed.connect(func() -> void: action_requested.emit(ACTION_TOGGLE_MAPS, null))
	_comments_button.pressed.connect(func() -> void: action_requested.emit(ACTION_TOGGLE_COMMENTS, null))
	_outliner_button.pressed.connect(func() -> void: action_requested.emit(ACTION_TOGGLE_OUTLINER, null))
	_edit_button.pressed.connect(func() -> void: action_requested.emit(ACTION_TOGGLE_EDIT, null))

	_view_group_button.toggled.connect(func(p: bool) -> void: _on_group_toggled(GROUP_VIEW, p))
	_draw_group_button.toggled.connect(func(p: bool) -> void: _on_group_toggled(GROUP_DRAW, p))
	_file_group_button.toggled.connect(func(p: bool) -> void: _on_group_toggled(GROUP_FILE, p))

	_draw_pen_button.toggled.connect(func(p: bool) -> void: _on_draw_tool_toggled(DRAW_TOOL_PEN, p))
	_draw_eraser_button.toggled.connect(func(p: bool) -> void: _on_draw_tool_toggled(DRAW_TOOL_ERASER, p))
	_draw_pick_button.toggled.connect(func(p: bool) -> void: _on_draw_tool_toggled(DRAW_TOOL_PICK, p))
	_draw_color_button.color = AnnotationStroke.DEFAULT_COLOR
	_draw_color_button.color_changed.connect(func(c: Color) -> void: action_requested.emit(ACTION_DRAW_COLOR, c))
	_draw_width_slider.min_value = AnnotationStroke.MIN_WIDTH
	_draw_width_slider.max_value = 24.0
	_draw_width_slider.step = 0.5
	_draw_width_slider.value = AnnotationStroke.DEFAULT_WIDTH
	_draw_width_slider.value_changed.connect(func(v: float) -> void: action_requested.emit(ACTION_DRAW_WIDTH, v))

	_templates_button.pressed.connect(func() -> void: action_requested.emit(ACTION_FILE_TEMPLATES, null))
	_tilesets_button.pressed.connect(func() -> void: action_requested.emit(ACTION_FILE_TILESETS, null))
	_import_button.pressed.connect(func() -> void: action_requested.emit(ACTION_FILE_IMPORT, null))
	_export_button.pressed.connect(func() -> void: action_requested.emit(ACTION_FILE_EXPORT, null))
	_setup_settings_menu()

	_apply_active_group()


func _setup_settings_menu() -> void:
	var popup: PopupMenu = _settings_menu_button.get_popup()
	popup.clear()
	popup.add_item("Theme & Fonts", SETTINGS_THEME_ID)
	popup.add_item("Keybindings", SETTINGS_KEYBINDINGS_ID)
	if not popup.id_pressed.is_connected(_on_settings_menu_id_pressed):
		popup.id_pressed.connect(_on_settings_menu_id_pressed)


func _on_settings_menu_id_pressed(id: int) -> void:
	match id:
		SETTINGS_THEME_ID:
			action_requested.emit(ACTION_OPEN_THEME, null)
		SETTINGS_KEYBINDINGS_ID:
			action_requested.emit(ACTION_OPEN_KEYBINDINGS, null)


func set_edit_state(in_edit_mode: bool) -> void:
	_edit_button.set_pressed_no_signal(in_edit_mode)
	_edit_button.text = "Done" if in_edit_mode else "Edit"


func set_edit_button_visible(value: bool) -> void:
	_edit_button.visible = value


func set_draw_tool(tool_name: String) -> void:
	_active_draw_tool = tool_name
	_sync_draw_buttons()


func set_annotation_color(color: Color) -> void:
	_draw_color_button.color = color


func set_annotation_width(width: float) -> void:
	_draw_width_slider.value = width


func collapse_groups() -> void:
	_active_groups.clear()
	_apply_active_group()


func set_project_label(project_name: String, source: String, remote_label: String) -> void:
	_title_label.text = project_name
	if remote_label != "":
		_subtitle_label.text = "%s · %s" % [_source_label(source), remote_label]
	else:
		_subtitle_label.text = _source_label(source)


func _source_label(source: String) -> String:
	match source:
		MobileProjectRegistry.SOURCE_SYNCED:
			return "LAN sync"
		MobileProjectRegistry.SOURCE_IMPORTED:
			return "Imported"
		MobileProjectRegistry.SOURCE_EXTERNAL:
			return "External folder"
		_:
			return "Local"


func _on_group_toggled(group: String, pressed: bool) -> void:
	if pressed:
		_active_groups[group] = true
	else:
		_active_groups.erase(group)
	_apply_active_group()


func _apply_active_group() -> void:
	var groups: Dictionary = {
		GROUP_VIEW: [_view_margin, _view_group_button],
		GROUP_DRAW: [_draw_margin, _draw_group_button],
		GROUP_FILE: [_file_margin, _file_group_button],
	}
	for key_v: Variant in groups.keys():
		var key: String = key_v
		var entry: Array = groups[key_v]
		var container: MarginContainer = entry[0]
		var btn: Button = entry[1]
		var is_active: bool = _active_groups.has(key)
		if container != null:
			container.visible = is_active
		if btn != null and btn.button_pressed != is_active:
			btn.set_pressed_no_signal(is_active)
	if _expansion_panel != null:
		_expansion_panel.visible = not _active_groups.is_empty()


func _on_draw_tool_toggled(tool_name: String, pressed: bool) -> void:
	if pressed:
		_active_draw_tool = tool_name
	elif _active_draw_tool == tool_name:
		_active_draw_tool = DRAW_TOOL_NONE
	_sync_draw_buttons()
	match _active_draw_tool:
		DRAW_TOOL_PEN:
			action_requested.emit(ACTION_DRAW_PEN, true)
		DRAW_TOOL_ERASER:
			action_requested.emit(ACTION_DRAW_ERASER, true)
		DRAW_TOOL_PICK:
			action_requested.emit(ACTION_DRAW_PICK, true)
		_:
			action_requested.emit(ACTION_DRAW_PEN, false)


func _sync_draw_buttons() -> void:
	if _draw_pen_button != null:
		_draw_pen_button.set_pressed_no_signal(_active_draw_tool == DRAW_TOOL_PEN)
	if _draw_eraser_button != null:
		_draw_eraser_button.set_pressed_no_signal(_active_draw_tool == DRAW_TOOL_ERASER)
	if _draw_pick_button != null:
		_draw_pick_button.set_pressed_no_signal(_active_draw_tool == DRAW_TOOL_PICK)
