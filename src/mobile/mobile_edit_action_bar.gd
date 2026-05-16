class_name MobileEditActionBar
extends PanelContainer

signal action_requested(action: String)
signal annotation_color_picked(color: Color)
signal annotation_width_picked(width: float)

const ACTION_ADD: String = "add"
const ACTION_UNDO: String = "undo"
const ACTION_REDO: String = "redo"
const ACTION_TOGGLE_CONNECT: String = "toggle_connect"
const ACTION_TOGGLE_PEN: String = "toggle_pen"
const ACTION_TOGGLE_ERASER: String = "toggle_eraser"
const ACTION_DELETE: String = "delete"
const ACTION_DUPLICATE: String = "duplicate"
const ACTION_TOGGLE_LOCK: String = "toggle_lock"
const ACTION_EXIT_EDIT: String = "exit_edit"
const ACTION_BOARD_SETTINGS: String = "board_settings"
const ACTION_ARRANGE: String = "arrange"
const ACTION_SNAP: String = "snap"

@onready var _add_button: Button = %AddButton
@onready var _undo_button: Button = %UndoButton
@onready var _redo_button: Button = %RedoButton
@onready var _connect_button: Button = %ConnectButton
@onready var _pen_button: Button = %PenButton
@onready var _eraser_button: Button = %EraserButton
@onready var _delete_button: Button = %DeleteButton
@onready var _duplicate_button: Button = %DuplicateButton
@onready var _lock_button: Button = %LockButton
@onready var _color_button: ColorPickerButton = %ColorButton
@onready var _width_slider: HSlider = %WidthSlider
@onready var _exit_button: Button = %ExitButton
@onready var _board_settings_button: Button = %BoardSettingsButton
@onready var _arrange_button: Button = %ArrangeButton
@onready var _snap_button: Button = %SnapButton
@onready var _mode_label: Label = %ModeLabel
@onready var _annotation_panel: HBoxContainer = %AnnotationPanel


func _ready() -> void:
	_add_button.pressed.connect(func() -> void: action_requested.emit(ACTION_ADD))
	_undo_button.pressed.connect(func() -> void: action_requested.emit(ACTION_UNDO))
	_redo_button.pressed.connect(func() -> void: action_requested.emit(ACTION_REDO))
	_connect_button.pressed.connect(func() -> void: action_requested.emit(ACTION_TOGGLE_CONNECT))
	_pen_button.pressed.connect(func() -> void: action_requested.emit(ACTION_TOGGLE_PEN))
	_eraser_button.pressed.connect(func() -> void: action_requested.emit(ACTION_TOGGLE_ERASER))
	_delete_button.pressed.connect(func() -> void: action_requested.emit(ACTION_DELETE))
	_duplicate_button.pressed.connect(func() -> void: action_requested.emit(ACTION_DUPLICATE))
	_lock_button.pressed.connect(func() -> void: action_requested.emit(ACTION_TOGGLE_LOCK))
	_exit_button.pressed.connect(func() -> void: action_requested.emit(ACTION_EXIT_EDIT))
	_board_settings_button.pressed.connect(func() -> void: action_requested.emit(ACTION_BOARD_SETTINGS))
	_arrange_button.pressed.connect(func() -> void: action_requested.emit(ACTION_ARRANGE))
	_snap_button.pressed.connect(func() -> void: action_requested.emit(ACTION_SNAP))
	_color_button.color_changed.connect(func(c: Color) -> void: annotation_color_picked.emit(c))
	_width_slider.value_changed.connect(func(v: float) -> void: annotation_width_picked.emit(v))
	_width_slider.min_value = AnnotationStroke.MIN_WIDTH
	_width_slider.max_value = 24.0
	_width_slider.step = 0.5
	_width_slider.value = AnnotationStroke.DEFAULT_WIDTH
	_color_button.color = AnnotationStroke.DEFAULT_COLOR
	_annotation_panel.visible = false
	set_history_state(false, false)
	set_selection_state(0, "")


func set_mode(mode: String) -> void:
	_connect_button.button_pressed = mode == MobileBoardView.MODE_CONNECT
	_pen_button.button_pressed = mode == MobileBoardView.MODE_PEN
	_eraser_button.button_pressed = mode == MobileBoardView.MODE_ERASER
	_annotation_panel.visible = mode == MobileBoardView.MODE_PEN or mode == MobileBoardView.MODE_ERASER
	match mode:
		MobileBoardView.MODE_EDIT:
			_mode_label.text = "Edit"
		MobileBoardView.MODE_CONNECT:
			_mode_label.text = "Connect: tap source, then target"
		MobileBoardView.MODE_PEN:
			_mode_label.text = "Pen: draw with finger"
		MobileBoardView.MODE_ERASER:
			_mode_label.text = "Eraser: drag to remove strokes"
		_:
			_mode_label.text = "Edit"


func set_history_state(can_undo: bool, can_redo: bool) -> void:
	_undo_button.disabled = not can_undo
	_redo_button.disabled = not can_redo


func set_selection_state(selected_item_count: int, selected_connection_id: String) -> void:
	var has_items: bool = selected_item_count > 0
	var has_connection: bool = selected_connection_id != ""
	_delete_button.disabled = not (has_items or has_connection)
	_duplicate_button.disabled = not has_items
	_lock_button.disabled = not has_items


func set_annotation_color(color: Color) -> void:
	_color_button.color = color


func set_annotation_width(width: float) -> void:
	_width_slider.value = width
