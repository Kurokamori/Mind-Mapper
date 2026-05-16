class_name TableNode
extends BoardItem

signal active_cell_changed(row: int, col: int)
signal axis_selection_changed(axis: String, index: int)

const HEADER_HEIGHT: float = 36.0
const PADDING: Vector2 = Vector2(8, 8)
const GRID_BOTTOM_PADDING: float = 28.0
const GRID_FRAME_WIDTH: int = 2
const HEADER_BUTTON_WIDTH: float = 100.0
const HEADER_BUTTON_HEIGHT: float = 22.0
const HEADER_BUTTON_GAP: float = 3.0
const HEADER_BUTTON_GROUP_GAP: float = 8.0
const HEADER_BUTTON_RIGHT_MARGIN: float = 6.0
const CELL_MIN_WIDTH: float = 60.0
const CELL_MIN_HEIGHT: float = 32.0
const GRID_HSEPARATION: int = 0
const GRID_VSEPARATION: int = 0
const CELL_PADDING_LEFT: int = 8
const CELL_PADDING_RIGHT: int = 8
const CELL_PADDING_TOP: int = 4
const CELL_PADDING_BOTTOM: int = 4
const CELL_CORNER_RADIUS: int = 0
const GRID_LINE_WIDTH: int = 2
const ACTIVE_OUTLINE_WIDTH: int = 2
const EDIT_OUTLINE_WIDTH: int = 3
const ACTIVE_OUTLINE_COLOR: Color = Color(0.35, 0.70, 1.00, 1.0)
const EDIT_OUTLINE_COLOR: Color = Color(0.95, 0.78, 0.30, 1.0)
const AXIS_SELECT_OUTLINE_WIDTH: int = 2
const EDGE_STRIP_WIDTH: float = 8.0
const STRIP_INDICATOR_HOVER_ALPHA: float = 0.55
const STRIP_INDICATOR_ACTIVE_ALPHA: float = 1.0
const AXIS_ACTIONS_GAP: float = 6.0

const SIDE_LEFT: String = "left"
const SIDE_RIGHT: String = "right"
const SIDE_TOP: String = "top"
const SIDE_BOTTOM: String = "bottom"
const COLUMN_RESIZE_HANDLE_SCENE: PackedScene = preload("res://src/nodes/table/column_resize_handle.tscn")

const ALIGN_LEFT: int = 0
const ALIGN_CENTER: int = 1
const ALIGN_RIGHT: int = 2

const VALIGN_TOP: int = 0
const VALIGN_MIDDLE: int = 1
const VALIGN_BOTTOM: int = 2

const ALIGN_INHERIT: int = -1

const AXIS_ROW: String = "row"
const AXIS_COL: String = "col"

const LEGACY_BG: Color = Color(0.13, 0.14, 0.17, 1.0)
const LEGACY_ACCENT: Color = Color(0.20, 0.30, 0.45, 1.0)
const LEGACY_HEADER_FG: Color = Color(0.95, 0.97, 1.0, 1.0)
const LEGACY_GRID_LINE: Color = Color(0.30, 0.34, 0.40, 1.0)

@export var title: String = "Table"
@export var rows: int = 3
@export var cols: int = 3
@export var cells: Array = []
@export var col_aligns: Array = []
@export var col_valigns: Array = []
@export var row_aligns: Array = []
@export var row_valigns: Array = []
@export var has_header_row: bool = false
@export var rules: Array = []
@export var cell_formats: Dictionary = {}
@export var col_widths: Array = []

@export var bg_color: Color = LEGACY_BG
@export var bg_color_custom: bool = false
@export var accent_color: Color = LEGACY_ACCENT
@export var accent_color_custom: bool = false
@export var header_fg_color: Color = LEGACY_HEADER_FG
@export var header_fg_color_custom: bool = false
@export var grid_line_color: Color = LEGACY_GRID_LINE
@export var grid_line_color_custom: bool = false

@onready var _title_label: Label = %TitleLabel
@onready var _title_edit: LineEdit = %TitleEdit
@onready var _grid: GridContainer = %Grid
@onready var _add_row_btn: Button = %AddRowBtn
@onready var _add_col_btn: Button = %AddColBtn
@onready var _del_row_btn: Button = %DelRowBtn
@onready var _del_col_btn: Button = %DelColBtn
@onready var _resize_handles: Control = %ResizeHandles
@onready var _row_strip_left: Control = %RowSelectStripLeft
@onready var _row_strip_right: Control = %RowSelectStripRight
@onready var _col_strip_top: Control = %ColSelectStripTop
@onready var _col_strip_bottom: Control = %ColSelectStripBottom
@onready var _axis_actions: TableAxisActions = %AxisActions

var _commit_lock: bool = false
var _pre_edit_title: String = ""
var _pending_edit_cell: Vector2i = Vector2i(-1, -1)
var _edit_target: String = ""
var _active_line_edits: Array = []
var _active_cell: Vector2i = Vector2i(0, 0)
var _grow_pending: bool = false
var _col_widths_before_drag: Array = []
var _drag_active_column: int = -1
var _handles_position_pending: bool = false

var _selected_axis: String = ""
var _selected_axis_index: int = -1
var _selected_axis_side: String = ""
var _strip_hover_axis: String = ""
var _strip_hover_index: int = -1
var _strip_hover_side: String = ""


func _ready() -> void:
	super._ready()
	_ensure_arrays()
	_layout()
	_refresh_visuals()
	_rebuild_grid()
	_request_grow_to_fit()
	ThemeManager.theme_applied.connect(_refresh_visuals)
	ThemeManager.node_palette_changed.connect(func(_a: Dictionary, _b: Dictionary) -> void: _refresh_visuals())
	SelectionBus.selection_changed.connect(_on_selection_changed)
	_connect_axis_strip_signals()
	if _axis_actions != null:
		_axis_actions.action_requested.connect(_on_axis_action_requested)
		_axis_actions.visible = false
	if read_only:
		return
	_add_row_btn.pressed.connect(func() -> void: _commit_dimensions(rows + 1, cols))
	_del_row_btn.pressed.connect(func() -> void: _commit_dimensions(max(1, rows - 1), cols))
	_add_col_btn.pressed.connect(func() -> void: _commit_dimensions(rows, cols + 1))
	_del_col_btn.pressed.connect(func() -> void: _commit_dimensions(rows, max(1, cols - 1)))
	_title_edit.focus_exited.connect(_on_title_focus_exited)
	_title_edit.text_submitted.connect(_on_title_submitted)


func default_size() -> Vector2:
	return Vector2(380, 240)


func minimum_item_size() -> Vector2:
	var header_min_w: float = HEADER_BUTTON_WIDTH * 4.0 + HEADER_BUTTON_GAP * 2.0 + HEADER_BUTTON_GROUP_GAP + HEADER_BUTTON_RIGHT_MARGIN + 80.0
	var content_min_w: float = 0.0
	for c in range(cols):
		var w: float = _column_fixed_width(c)
		if w <= 0.0:
			w = CELL_MIN_WIDTH
		content_min_w += w
	var min_w: float = max(MIN_ITEM_WIDTH, max(header_min_w, content_min_w + PADDING.x * 2.0))
	var min_h: float = HEADER_HEIGHT + PADDING.y + GRID_BOTTOM_PADDING + CELL_MIN_HEIGHT * float(max(1, rows))
	return Vector2(min_w, min_h)


func display_name() -> String:
	return "Table"


func _draw_body() -> void:
	_draw_rounded_panel(
		_resolved_bg(),
		_resolved_accent().darkened(0.3),
		HEADER_HEIGHT,
		_resolved_accent(),
	)
	_draw_grid_frame()
	_draw_axis_hover_highlight()
	_draw_axis_selection_highlight()


func _draw_grid_frame() -> void:
	if _grid == null:
		return
	var frame_rect: Rect2 = Rect2(_grid.position, _grid.size)
	var frame_sb: StyleBoxFlat = StyleBoxFlat.new()
	frame_sb.draw_center = false
	frame_sb.border_color = _resolved_grid_line()
	frame_sb.set_border_width_all(GRID_FRAME_WIDTH)
	frame_sb.set_corner_radius_all(0)
	draw_style_box(frame_sb, frame_rect)


func _draw_axis_hover_highlight() -> void:
	if _grid == null:
		return
	if _strip_hover_axis == "" or _strip_hover_index < 0 or _strip_hover_side == "":
		return
	if _selected_axis == _strip_hover_axis and _selected_axis_index == _strip_hover_index and _selected_axis_side == _strip_hover_side:
		return
	var rect: Rect2 = _side_indicator_rect(_strip_hover_axis, _strip_hover_index, _strip_hover_side)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var color: Color = _resolved_accent()
	color.a = STRIP_INDICATOR_HOVER_ALPHA
	draw_rect(rect, color, true)


func _draw_axis_selection_highlight() -> void:
	if _grid == null or _selected_axis == "" or _selected_axis_index < 0:
		return
	var bar_rect: Rect2 = _side_indicator_rect(_selected_axis, _selected_axis_index, _selected_axis_side)
	if bar_rect.size.x > 0.0 and bar_rect.size.y > 0.0:
		var fill: Color = ACTIVE_OUTLINE_COLOR
		fill.a = STRIP_INDICATOR_ACTIVE_ALPHA
		draw_rect(bar_rect, fill, true)
	var rect: Rect2
	if _selected_axis == AXIS_ROW:
		rect = _row_world_rect(_selected_axis_index)
	else:
		rect = _col_world_rect(_selected_axis_index)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var outline_sb: StyleBoxFlat = StyleBoxFlat.new()
	outline_sb.draw_center = false
	outline_sb.border_color = ACTIVE_OUTLINE_COLOR
	outline_sb.set_border_width_all(AXIS_SELECT_OUTLINE_WIDTH)
	outline_sb.set_corner_radius_all(0)
	draw_style_box(outline_sb, rect)


func _side_indicator_rect(axis: String, index: int, side: String) -> Rect2:
	if axis == AXIS_ROW:
		var row_rect: Rect2 = _row_world_rect(index)
		if row_rect.size.x <= 0.0 or row_rect.size.y <= 0.0:
			return Rect2()
		var strip: Control = _row_strip_right if side == SIDE_RIGHT else _row_strip_left
		if strip == null:
			return Rect2()
		return Rect2(Vector2(strip.position.x, row_rect.position.y), Vector2(strip.size.x, row_rect.size.y))
	if axis == AXIS_COL:
		var col_rect: Rect2 = _col_world_rect(index)
		if col_rect.size.x <= 0.0 or col_rect.size.y <= 0.0:
			return Rect2()
		var strip_c: Control = _col_strip_bottom if side == SIDE_BOTTOM else _col_strip_top
		if strip_c == null:
			return Rect2()
		return Rect2(Vector2(col_rect.position.x, strip_c.position.y), Vector2(col_rect.size.x, strip_c.size.y))
	return Rect2()


func _resolved_bg() -> Color:
	return bg_color if bg_color_custom else ThemeManager.node_bg_color()


func _resolved_accent() -> Color:
	if accent_color_custom:
		return accent_color
	if ThemeManager.has_method("heading_bg"):
		return ThemeManager.heading_bg("table")
	return LEGACY_ACCENT


func _resolved_header_fg() -> Color:
	if header_fg_color_custom:
		return header_fg_color
	if ThemeManager.has_method("heading_fg"):
		return ThemeManager.heading_fg("table")
	return LEGACY_HEADER_FG


func _resolved_grid_line() -> Color:
	if grid_line_color_custom:
		return grid_line_color
	return _resolved_bg().lerp(_resolved_text_color(), 0.35)


func _resolved_text_color() -> Color:
	return ThemeManager.node_fg_color() if ThemeManager.has_method("node_fg_color") else Color(0.92, 0.94, 0.97, 1.0)


func _ensure_arrays() -> void:
	rows = max(1, rows)
	cols = max(1, cols)
	while cells.size() < rows:
		cells.append([])
	if cells.size() > rows:
		cells.resize(rows)
	for r in range(rows):
		var row_v: Variant = cells[r]
		var row: Array = row_v if typeof(row_v) == TYPE_ARRAY else []
		while row.size() < cols:
			row.append("")
		if row.size() > cols:
			row.resize(cols)
		for c in range(cols):
			row[c] = String(row[c])
		cells[r] = row
	while col_aligns.size() < cols:
		col_aligns.append(ALIGN_LEFT)
	if col_aligns.size() > cols:
		col_aligns.resize(cols)
	for c in range(cols):
		col_aligns[c] = clamp(int(col_aligns[c]), ALIGN_LEFT, ALIGN_RIGHT)
	while col_valigns.size() < cols:
		col_valigns.append(VALIGN_MIDDLE)
	if col_valigns.size() > cols:
		col_valigns.resize(cols)
	for c in range(cols):
		col_valigns[c] = clamp(int(col_valigns[c]), VALIGN_TOP, VALIGN_BOTTOM)
	while row_aligns.size() < rows:
		row_aligns.append(ALIGN_INHERIT)
	if row_aligns.size() > rows:
		row_aligns.resize(rows)
	for r in range(rows):
		row_aligns[r] = _normalize_h_align_with_inherit(row_aligns[r])
	while row_valigns.size() < rows:
		row_valigns.append(ALIGN_INHERIT)
	if row_valigns.size() > rows:
		row_valigns.resize(rows)
	for r in range(rows):
		row_valigns[r] = _normalize_v_align_with_inherit(row_valigns[r])
	while col_widths.size() < cols:
		col_widths.append(0.0)
	if col_widths.size() > cols:
		col_widths.resize(cols)
	for c in range(cols):
		col_widths[c] = max(0.0, float(col_widths[c]))
	rules = TableRule.normalize_array(rules)
	cell_formats = _normalize_cell_formats(cell_formats)


func _normalize_h_align_with_inherit(value: Variant) -> int:
	var v: int = int(value)
	if v == ALIGN_INHERIT:
		return ALIGN_INHERIT
	return clamp(v, ALIGN_LEFT, ALIGN_RIGHT)


func _normalize_v_align_with_inherit(value: Variant) -> int:
	var v: int = int(value)
	if v == ALIGN_INHERIT:
		return ALIGN_INHERIT
	return clamp(v, VALIGN_TOP, VALIGN_BOTTOM)


func _layout() -> void:
	var btn_y: float = (HEADER_HEIGHT - HEADER_BUTTON_HEIGHT) * 0.5
	var x_right: float = size.x - HEADER_BUTTON_RIGHT_MARGIN
	if _del_col_btn != null:
		_del_col_btn.size = Vector2(HEADER_BUTTON_WIDTH, HEADER_BUTTON_HEIGHT)
		_del_col_btn.position = Vector2(x_right - HEADER_BUTTON_WIDTH, btn_y)
	if _add_col_btn != null:
		_add_col_btn.size = Vector2(HEADER_BUTTON_WIDTH, HEADER_BUTTON_HEIGHT)
		_add_col_btn.position = Vector2(x_right - HEADER_BUTTON_WIDTH * 2 - HEADER_BUTTON_GAP, btn_y)
	var second_group_right: float = x_right - HEADER_BUTTON_WIDTH * 2 - HEADER_BUTTON_GAP - HEADER_BUTTON_GROUP_GAP
	if _del_row_btn != null:
		_del_row_btn.size = Vector2(HEADER_BUTTON_WIDTH, HEADER_BUTTON_HEIGHT)
		_del_row_btn.position = Vector2(second_group_right - HEADER_BUTTON_WIDTH, btn_y)
	if _add_row_btn != null:
		_add_row_btn.size = Vector2(HEADER_BUTTON_WIDTH, HEADER_BUTTON_HEIGHT)
		_add_row_btn.position = Vector2(second_group_right - HEADER_BUTTON_WIDTH * 2 - HEADER_BUTTON_GAP, btn_y)
	var title_right: float = (second_group_right - HEADER_BUTTON_WIDTH * 2 - HEADER_BUTTON_GAP) - 8.0
	var title_left: float = PADDING.x
	var title_width: float = max(40.0, title_right - title_left)
	var title_y: float = (HEADER_HEIGHT - 22.0) * 0.5
	if _title_label != null:
		_title_label.position = Vector2(title_left, title_y)
		_title_label.size = Vector2(title_width, 22.0)
	if _title_edit != null:
		_title_edit.position = Vector2(title_left, title_y)
		_title_edit.size = Vector2(title_width, 22.0)
	var grid_top: float = HEADER_HEIGHT + PADDING.y
	var grid_bottom: float = size.y - GRID_BOTTOM_PADDING
	var grid_left: float = PADDING.x
	var grid_right: float = size.x - PADDING.x
	var grid_width: float = max(0.0, grid_right - grid_left)
	var grid_height: float = max(0.0, grid_bottom - grid_top)
	if _grid != null:
		_grid.position = Vector2(grid_left, grid_top)
		_grid.size = Vector2(grid_width, grid_height)
	if _resize_handles != null:
		_resize_handles.position = Vector2(grid_left, grid_top)
		_resize_handles.size = Vector2(grid_width, grid_height)
		_request_handle_reposition()
	if _row_strip_left != null:
		_row_strip_left.position = Vector2(0.0, grid_top)
		_row_strip_left.size = Vector2(EDGE_STRIP_WIDTH, grid_height)
	if _row_strip_right != null:
		_row_strip_right.position = Vector2(grid_right, grid_top)
		_row_strip_right.size = Vector2(EDGE_STRIP_WIDTH, grid_height)
	if _col_strip_top != null:
		_col_strip_top.position = Vector2(grid_left, grid_top - EDGE_STRIP_WIDTH)
		_col_strip_top.size = Vector2(grid_width, EDGE_STRIP_WIDTH)
	if _col_strip_bottom != null:
		_col_strip_bottom.position = Vector2(grid_left, grid_bottom)
		_col_strip_bottom.size = Vector2(grid_width, EDGE_STRIP_WIDTH)
	_reposition_axis_actions()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _refresh_visuals() -> void:
	if _title_label != null:
		_title_label.text = title
		_title_label.add_theme_color_override("font_color", _resolved_header_fg())
	if _title_edit != null:
		_title_edit.add_theme_color_override("font_color", _resolved_header_fg())
	_refresh_button_colors()
	if _grid != null:
		_apply_cell_styling()
	queue_redraw()


func _refresh_button_colors() -> void:
	for btn: Button in [_add_row_btn, _add_col_btn, _del_row_btn, _del_col_btn]:
		if btn == null:
			continue
		btn.add_theme_color_override("font_color", _resolved_header_fg())
		btn.add_theme_color_override("font_hover_color", _resolved_header_fg())
		btn.add_theme_color_override("font_pressed_color", _resolved_header_fg())
		var sb_normal: StyleBoxFlat = _make_header_button_stylebox(0.18)
		var sb_hover: StyleBoxFlat = _make_header_button_stylebox(0.30)
		var sb_pressed: StyleBoxFlat = _make_header_button_stylebox(0.45)
		btn.add_theme_stylebox_override("normal", sb_normal)
		btn.add_theme_stylebox_override("hover", sb_hover)
		btn.add_theme_stylebox_override("pressed", sb_pressed)
		btn.add_theme_stylebox_override("focus", sb_hover)


func _make_header_button_stylebox(strength: float) -> StyleBoxFlat:
	var fg: Color = _resolved_header_fg()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	var tint: Color = fg
	tint.a = strength * 0.45
	sb.bg_color = tint
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	return sb


func _rebuild_grid() -> void:
	if _grid == null:
		return
	_commit_lock = true
	_active_line_edits.clear()
	for child in _grid.get_children():
		child.queue_free()
	_grid.columns = max(1, cols)
	_grid.add_theme_constant_override("h_separation", GRID_HSEPARATION)
	_grid.add_theme_constant_override("v_separation", GRID_VSEPARATION)
	var editing: bool = is_editing() and not read_only and not locked
	for r in range(rows):
		for c in range(cols):
			var cell_text: String = String((cells[r] as Array)[c])
			var cell_ctrl: PanelContainer = _build_cell(r, c, cell_text, editing)
			_grid.add_child(cell_ctrl)
	_apply_cell_styling()
	_rebuild_resize_handles()
	_commit_lock = false
	if editing and _pending_edit_cell.x >= 0 and _pending_edit_cell.y >= 0:
		_focus_cell_after_build(_pending_edit_cell.x, _pending_edit_cell.y)
		_pending_edit_cell = Vector2i(-1, -1)
	_reposition_axis_actions()


func _rebuild_resize_handles() -> void:
	if _resize_handles == null:
		return
	for child in _resize_handles.get_children():
		child.queue_free()
	if read_only or locked:
		return
	for c in range(cols):
		var handle: TableColumnResizeHandle = COLUMN_RESIZE_HANDLE_SCENE.instantiate()
		handle.column = c
		handle.drag_started.connect(_on_resize_drag_started)
		handle.drag_motion.connect(_on_resize_drag_motion)
		handle.drag_ended.connect(_on_resize_drag_ended)
		_resize_handles.add_child(handle)
	_request_handle_reposition()


func _request_handle_reposition() -> void:
	if _handles_position_pending:
		return
	_handles_position_pending = true
	_reposition_handles_async()


func _reposition_handles_async() -> void:
	await get_tree().process_frame
	_handles_position_pending = false
	if not is_inside_tree() or _resize_handles == null or _grid == null:
		return
	var grid_children: Array = _grid.get_children()
	if grid_children.is_empty():
		return
	var column_right_edges: Array = []
	for c in range(cols):
		var idx: int = c
		if idx >= grid_children.size():
			break
		var panel: PanelContainer = grid_children[idx] as PanelContainer
		if panel == null:
			continue
		column_right_edges.append(panel.position.x + panel.size.x)
	var handle_height: float = _resize_handles.size.y
	var handles: Array = _resize_handles.get_children()
	for handle_v: Variant in handles:
		var handle: TableColumnResizeHandle = handle_v as TableColumnResizeHandle
		if handle == null:
			continue
		var col_idx: int = handle.column
		if col_idx < 0 or col_idx >= column_right_edges.size():
			handle.visible = false
			continue
		var edge_x: float = float(column_right_edges[col_idx])
		handle.position = Vector2(edge_x - TableColumnResizeHandle.HANDLE_WIDTH * 0.5, 0.0)
		handle.size = Vector2(TableColumnResizeHandle.HANDLE_WIDTH, handle_height)
		handle.visible = true
	_reposition_axis_actions()


func _on_resize_drag_started(column: int) -> void:
	if column < 0 or column >= cols:
		return
	_drag_active_column = column
	_col_widths_before_drag = col_widths.duplicate(true)


func _on_resize_drag_motion(column: int, delta_x: float) -> void:
	if column != _drag_active_column or column < 0 or column >= cols:
		return
	var current: float = float(col_widths[column])
	if current <= 0.0:
		current = _measure_column_width(column)
	var new_width: float = max(CELL_MIN_WIDTH, current + delta_x)
	if is_equal_approx(new_width, current) and float(col_widths[column]) > 0.0:
		return
	col_widths[column] = new_width
	_apply_column_widths_to_cells(column)


func _on_resize_drag_ended(column: int) -> void:
	if column != _drag_active_column:
		_drag_active_column = -1
		return
	_drag_active_column = -1
	var after: Array = col_widths.duplicate(true)
	if after == _col_widths_before_drag:
		return
	var editor: Node = _find_editor()
	if editor != null:
		History.push_already_done(ModifyPropertyCommand.new(editor, item_id, "col_widths", _col_widths_before_drag, after))
		if editor.has_method("request_save"):
			editor.request_save()
	_request_grow_to_fit()


func _measure_column_width(c: int) -> float:
	if _grid == null:
		return CELL_MIN_WIDTH
	var grid_children: Array = _grid.get_children()
	if c < 0 or c >= grid_children.size():
		return CELL_MIN_WIDTH
	var panel: PanelContainer = grid_children[c] as PanelContainer
	if panel == null:
		return CELL_MIN_WIDTH
	return panel.size.x


func _apply_column_widths_to_cells(only_column: int = -1) -> void:
	if _grid == null:
		return
	var grid_children: Array = _grid.get_children()
	for child_v: Variant in grid_children:
		var panel: PanelContainer = child_v as PanelContainer
		if panel == null:
			continue
		var c: int = int(panel.get_meta("cell_col", -1))
		if only_column >= 0 and c != only_column:
			continue
		var fixed_width: float = _column_fixed_width(c)
		if fixed_width > 0.0:
			panel.custom_minimum_size = Vector2(fixed_width, CELL_MIN_HEIGHT)
			panel.size_flags_horizontal = Control.SIZE_FILL
		else:
			panel.custom_minimum_size = Vector2(CELL_MIN_WIDTH, CELL_MIN_HEIGHT)
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.queue_sort()
	_request_handle_reposition()


func set_column_width(c: int, value: float) -> void:
	if c < 0 or c >= cols:
		return
	var before: Array = col_widths.duplicate(true)
	col_widths[c] = max(0.0, value)
	if col_widths == before:
		return
	var editor: Node = _find_editor()
	if editor == null:
		_apply_column_widths_to_cells(c)
		return
	History.push(ModifyPropertyCommand.new(editor, item_id, "col_widths", before, col_widths.duplicate(true)))


func reset_column_width(c: int) -> void:
	set_column_width(c, 0.0)


func column_width_at(c: int) -> float:
	return _column_fixed_width(c)


func _build_cell(r: int, c: int, value: String, editing: bool) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var fixed_width: float = _column_fixed_width(c)
	if fixed_width > 0.0:
		panel.custom_minimum_size = Vector2(fixed_width, CELL_MIN_HEIGHT)
		panel.size_flags_horizontal = Control.SIZE_FILL
	else:
		panel.custom_minimum_size = Vector2(CELL_MIN_WIDTH, CELL_MIN_HEIGHT)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("cell_row", r)
	panel.set_meta("cell_col", c)
	panel.clip_contents = true
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CELL_PADDING_LEFT)
	margin.add_theme_constant_override("margin_right", CELL_PADDING_RIGHT)
	margin.add_theme_constant_override("margin_top", CELL_PADDING_TOP)
	margin.add_theme_constant_override("margin_bottom", CELL_PADDING_BOTTOM)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(margin)
	var valign_box: VBoxContainer = VBoxContainer.new()
	valign_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	valign_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	valign_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	valign_box.add_theme_constant_override("separation", 0)
	margin.add_child(valign_box)
	var h_align: int = _effective_h_align(r, c)
	var v_align: int = _effective_v_align(r, c)
	if editing:
		var le: LineEdit = LineEdit.new()
		le.text = value
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.size_flags_vertical = _vbox_size_flag_for_valign(v_align)
		le.context_menu_enabled = false
		le.expand_to_text_length = false
		le.flat = true
		le.custom_minimum_size = Vector2(0, 0)
		le.clip_contents = true
		le.add_theme_constant_override("minimum_character_width", 0)
		le.set_meta("cell_row", r)
		le.set_meta("cell_col", c)
		_apply_transparent_line_edit_style(le)
		var rr: int = r
		var cc: int = c
		le.text_submitted.connect(func(t: String) -> void: _on_cell_text_submit(rr, cc, t))
		le.focus_exited.connect(func() -> void: _on_cell_focus_exited(rr, cc, le))
		le.focus_entered.connect(func() -> void: set_active_cell(rr, cc))
		le.gui_input.connect(func(ev: InputEvent) -> void: _on_cell_line_edit_input(ev))
		_align_line_edit(le, h_align)
		valign_box.add_child(le)
		_active_line_edits.append(le)
	else:
		var rtl: RichTextLabel = RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.selection_enabled = false
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rtl.size_flags_vertical = _vbox_size_flag_for_valign(v_align)
		rtl.custom_minimum_size = Vector2(0, 0)
		rtl.clip_contents = true
		valign_box.add_child(rtl)
	return panel


func _vbox_size_flag_for_valign(v_align: int) -> int:
	match v_align:
		VALIGN_TOP:
			return Control.SIZE_EXPAND | Control.SIZE_SHRINK_BEGIN
		VALIGN_BOTTOM:
			return Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
		_:
			return Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER


func _effective_h_align(r: int, c: int) -> int:
	var fmt: Dictionary = get_cell_format(r, c)
	var cell_h: int = int(fmt.get("align_h", ALIGN_INHERIT))
	if cell_h != ALIGN_INHERIT:
		return clamp(cell_h, ALIGN_LEFT, ALIGN_RIGHT)
	if r >= 0 and r < row_aligns.size():
		var row_h: int = int(row_aligns[r])
		if row_h != ALIGN_INHERIT:
			return clamp(row_h, ALIGN_LEFT, ALIGN_RIGHT)
	if c >= 0 and c < col_aligns.size():
		return clamp(int(col_aligns[c]), ALIGN_LEFT, ALIGN_RIGHT)
	return ALIGN_LEFT


func _effective_v_align(r: int, c: int) -> int:
	var fmt: Dictionary = get_cell_format(r, c)
	var cell_v: int = int(fmt.get("align_v", ALIGN_INHERIT))
	if cell_v != ALIGN_INHERIT:
		return clamp(cell_v, VALIGN_TOP, VALIGN_BOTTOM)
	if r >= 0 and r < row_valigns.size():
		var row_v: int = int(row_valigns[r])
		if row_v != ALIGN_INHERIT:
			return clamp(row_v, VALIGN_TOP, VALIGN_BOTTOM)
	if c >= 0 and c < col_valigns.size():
		return clamp(int(col_valigns[c]), VALIGN_TOP, VALIGN_BOTTOM)
	return VALIGN_MIDDLE


func _align_line_edit(le: LineEdit, align_id: int) -> void:
	match align_id:
		ALIGN_CENTER:
			le.alignment = HORIZONTAL_ALIGNMENT_CENTER
		ALIGN_RIGHT:
			le.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_:
			le.alignment = HORIZONTAL_ALIGNMENT_LEFT


func _apply_cell_styling() -> void:
	if _grid == null:
		return
	var grid_children: Array = _grid.get_children()
	for idx in range(grid_children.size()):
		var panel: PanelContainer = grid_children[idx] as PanelContainer
		if panel == null:
			continue
		var r: int = int(panel.get_meta("cell_row", 0))
		var c: int = int(panel.get_meta("cell_col", 0))
		var is_header_cell: bool = has_header_row and r == 0
		var cell_text: String = String((cells[r] as Array)[c]) if r < cells.size() and c < (cells[r] as Array).size() else ""
		var formatting: Dictionary = TableRule.evaluate_cell(rules, r, c, cell_text, is_header_cell)
		var fg: Color = _resolved_text_color()
		var fg_set: bool = false
		var bg: Color = Color(0, 0, 0, 0)
		var bg_set: bool = false
		var bold: bool = false
		var italic: bool = false
		if is_header_cell:
			bg = _resolved_accent()
			bg_set = true
			fg = _resolved_header_fg()
			fg_set = true
			bold = true
		if formatting.get("bg", null) != null:
			bg = formatting["bg"]
			bg_set = true
		if formatting.get("fg", null) != null:
			fg = formatting["fg"]
			fg_set = true
		if bool(formatting.get("bold", false)):
			bold = true
		if bool(formatting.get("italic", false)):
			italic = true
		var cell_override: Dictionary = get_cell_format(r, c)
		if bool(cell_override.get("use_bg", false)):
			bg = ColorUtil.from_array(cell_override.get("bg", null), bg)
			bg_set = true
		if bool(cell_override.get("use_fg", false)):
			fg = ColorUtil.from_array(cell_override.get("fg", null), fg)
			fg_set = true
		if bool(cell_override.get("bold", false)):
			bold = true
		if bool(cell_override.get("italic", false)):
			italic = true
		_style_cell_panel(panel, bg, bg_set, r, c)
		var h_align: int = _effective_h_align(r, c)
		var v_align: int = _effective_v_align(r, c)
		var inner: Control = _find_cell_inner(panel)
		if inner is RichTextLabel:
			_apply_rtl_text(inner as RichTextLabel, cell_text, fg, fg_set, bold, italic, h_align)
			inner.size_flags_vertical = _vbox_size_flag_for_valign(v_align)
		elif inner is LineEdit:
			_align_line_edit(inner as LineEdit, h_align)
			inner.size_flags_vertical = _vbox_size_flag_for_valign(v_align)
			if fg_set:
				inner.add_theme_color_override("font_color", fg)
				inner.add_theme_color_override("font_selected_color", fg)
			else:
				inner.remove_theme_color_override("font_color")
				inner.remove_theme_color_override("font_selected_color")


func _find_cell_inner(panel: PanelContainer) -> Control:
	if panel.get_child_count() == 0:
		return null
	var margin: Node = panel.get_child(0)
	if margin == null or margin.get_child_count() == 0:
		return null
	var box: Node = margin.get_child(0)
	if box == null or box.get_child_count() == 0:
		return null
	var inner: Node = box.get_child(0)
	return inner as Control


func _style_cell_panel(panel: PanelContainer, bg: Color, bg_set: bool, r: int, c: int) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	if bg_set:
		sb.bg_color = bg
	else:
		sb.bg_color = _cell_default_bg()
	sb.set_corner_radius_all(CELL_CORNER_RADIUS)
	var editing_cell: bool = is_editing() and _edit_target == "cell" and r == _active_cell.x and c == _active_cell.y
	var active_in_read: bool = _selected and not editing_cell and r == _active_cell.x and c == _active_cell.y
	if editing_cell:
		sb.border_color = EDIT_OUTLINE_COLOR
		sb.set_border_width_all(EDIT_OUTLINE_WIDTH)
	elif active_in_read:
		sb.border_color = ACTIVE_OUTLINE_COLOR
		sb.set_border_width_all(ACTIVE_OUTLINE_WIDTH)
	else:
		sb.border_color = _resolved_grid_line()
		sb.border_width_left = 0
		sb.border_width_top = 0
		sb.border_width_right = GRID_LINE_WIDTH if c < cols - 1 else 0
		sb.border_width_bottom = GRID_LINE_WIDTH if r < rows - 1 else 0
	panel.add_theme_stylebox_override("panel", sb)


func _column_fixed_width(c: int) -> float:
	if c < 0 or c >= col_widths.size():
		return 0.0
	return max(0.0, float(col_widths[c]))


func _apply_transparent_line_edit_style(le: LineEdit) -> void:
	var transparent: StyleBoxEmpty = StyleBoxEmpty.new()
	le.add_theme_stylebox_override("normal", transparent)
	le.add_theme_stylebox_override("focus", transparent)
	le.add_theme_stylebox_override("read_only", transparent)
	var caret_color: Color = _resolved_text_color()
	le.add_theme_color_override("caret_color", caret_color)
	var selection: Color = _resolved_accent()
	selection.a = 0.40
	le.add_theme_color_override("selection_color", selection)


func _cell_format_key(r: int, c: int) -> String:
	return "%d,%d" % [r, c]


func get_cell_format(r: int, c: int) -> Dictionary:
	var key: String = _cell_format_key(r, c)
	var v: Variant = cell_formats.get(key, {})
	return v if typeof(v) == TYPE_DICTIONARY else {}


func set_cell_format(r: int, c: int, fmt: Dictionary) -> void:
	if r < 0 or r >= rows or c < 0 or c >= cols:
		return
	var before: Dictionary = _normalize_cell_formats(cell_formats)
	var new_formats: Dictionary = before.duplicate(true)
	var key: String = _cell_format_key(r, c)
	var normalized_entry: Dictionary = _normalize_single_cell_format(fmt)
	if _cell_format_is_empty(normalized_entry):
		new_formats.erase(key)
	else:
		new_formats[key] = normalized_entry
	if new_formats.hash() == before.hash():
		return
	var editor: Node = _find_editor()
	if editor == null:
		cell_formats = new_formats
		_apply_cell_styling()
		return
	History.push(ModifyPropertyCommand.new(editor, item_id, "cell_formats", before, new_formats))


func clear_cell_format(r: int, c: int) -> void:
	set_cell_format(r, c, {})


func _cell_format_is_empty(fmt: Dictionary) -> bool:
	if fmt.is_empty():
		return true
	if bool(fmt.get("use_bg", false)):
		return false
	if bool(fmt.get("use_fg", false)):
		return false
	if bool(fmt.get("bold", false)):
		return false
	if bool(fmt.get("italic", false)):
		return false
	if int(fmt.get("align_h", ALIGN_INHERIT)) != ALIGN_INHERIT:
		return false
	if int(fmt.get("align_v", ALIGN_INHERIT)) != ALIGN_INHERIT:
		return false
	return true


func _normalize_single_cell_format(d: Dictionary) -> Dictionary:
	var raw_h: int = int(d.get("align_h", ALIGN_INHERIT))
	var align_h: int = raw_h if raw_h == ALIGN_INHERIT else clamp(raw_h, ALIGN_LEFT, ALIGN_RIGHT)
	var raw_v: int = int(d.get("align_v", ALIGN_INHERIT))
	var align_v: int = raw_v if raw_v == ALIGN_INHERIT else clamp(raw_v, VALIGN_TOP, VALIGN_BOTTOM)
	return {
		"use_bg": bool(d.get("use_bg", false)),
		"bg": d.get("bg", [1.0, 1.0, 1.0, 1.0]),
		"use_fg": bool(d.get("use_fg", false)),
		"fg": d.get("fg", [0.0, 0.0, 0.0, 1.0]),
		"bold": bool(d.get("bold", false)),
		"italic": bool(d.get("italic", false)),
		"align_h": align_h,
		"align_v": align_v,
	}


func _normalize_cell_formats(raw: Variant) -> Dictionary:
	var src: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var out: Dictionary = {}
	for key_v: Variant in src.keys():
		var k: String = String(key_v)
		var v: Variant = src[key_v]
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var normalized: Dictionary = _normalize_single_cell_format(v)
		if _cell_format_is_empty(normalized):
			continue
		out[k] = normalized
	return out


func set_active_cell(r: int, c: int) -> void:
	if rows <= 0 or cols <= 0:
		return
	var clamped_r: int = clamp(r, 0, rows - 1)
	var clamped_c: int = clamp(c, 0, cols - 1)
	clear_axis_selection()
	if _active_cell.x == clamped_r and _active_cell.y == clamped_c:
		return
	_active_cell = Vector2i(clamped_r, clamped_c)
	emit_signal("active_cell_changed", clamped_r, clamped_c)
	_apply_cell_styling()


func active_cell() -> Vector2i:
	return _active_cell


func _cell_default_bg() -> Color:
	var base: Color = _resolved_bg()
	var fg: Color = _resolved_text_color()
	return base.lerp(fg, 0.06)


func _apply_rtl_text(rtl: RichTextLabel, text: String, fg: Color, _fg_set: bool, bold: bool, italic: bool, align_id: int) -> void:
	var escaped: String = _escape_bbcode(text)
	var open: String = ""
	var close: String = ""
	if bold:
		open += "[b]"
		close = "[/b]" + close
	if italic:
		open += "[i]"
		close = "[/i]" + close
	var alignment_tag_open: String = ""
	var alignment_tag_close: String = ""
	match align_id:
		ALIGN_CENTER:
			alignment_tag_open = "[center]"
			alignment_tag_close = "[/center]"
		ALIGN_RIGHT:
			alignment_tag_open = "[right]"
			alignment_tag_close = "[/right]"
	rtl.add_theme_color_override("default_color", fg)
	rtl.text = alignment_tag_open + open + escaped + close + alignment_tag_close


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")


func _focus_cell_after_build(r: int, c: int) -> void:
	for le_v: Variant in _active_line_edits:
		var le: LineEdit = le_v as LineEdit
		if le == null:
			continue
		if int(le.get_meta("cell_row", -1)) == r and int(le.get_meta("cell_col", -1)) == c:
			le.call_deferred("grab_focus")
			le.call_deferred("select_all")
			return


func _on_cell_text_submit(r: int, c: int, value: String) -> void:
	_commit_cell_text(r, c, value)
	_move_focus_to_next(r, c)


func _on_cell_focus_exited(r: int, c: int, le: LineEdit) -> void:
	if le == null:
		return
	_commit_cell_text(r, c, le.text)
	_check_end_edit_on_focus_loss.call_deferred()


func _check_end_edit_on_focus_loss() -> void:
	if not is_editing():
		return
	for le_v: Variant in _active_line_edits:
		var le: LineEdit = le_v as LineEdit
		if le == null:
			continue
		if le.has_focus():
			return
	if _title_edit != null and _title_edit.has_focus():
		return
	end_edit()


func _on_cell_line_edit_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			if is_editing():
				end_edit()
			get_viewport().set_input_as_handled()


func _move_focus_to_next(r: int, c: int) -> void:
	var next_r: int = r
	var next_c: int = c + 1
	if next_c >= cols:
		next_c = 0
		next_r = r + 1
	if next_r >= rows:
		end_edit()
		return
	_focus_cell_after_build(next_r, next_c)


func _commit_cell_text(r: int, c: int, value: String) -> void:
	if _commit_lock:
		return
	_ensure_arrays()
	if r < 0 or r >= cells.size():
		return
	var row: Array = cells[r]
	if c < 0 or c >= row.size():
		return
	if String(row[c]) == value:
		return
	var before: Array = cells.duplicate(true)
	row[c] = value
	cells[r] = row
	_apply_cell_styling()
	_push_cells_history(before)


func commit_dimensions(new_rows: int, new_cols: int) -> void:
	_commit_dimensions(new_rows, new_cols)


func _commit_dimensions(new_rows: int, new_cols: int) -> void:
	new_rows = max(1, new_rows)
	new_cols = max(1, new_cols)
	if new_rows == rows and new_cols == cols:
		return
	var before_payload: Dictionary = _table_dims_payload()
	rows = new_rows
	cols = new_cols
	_ensure_arrays()
	_clamp_active_cell()
	_clamp_axis_selection()
	_rebuild_grid()
	_request_grow_to_fit()
	var after_payload: Dictionary = _table_dims_payload()
	var editor: Node = _find_editor()
	if editor == null:
		return
	History.push_already_done(ModifyPropertyCommand.new(editor, item_id, "table_dims", before_payload, after_payload))
	if editor.has_method("request_save"):
		editor.request_save()


func _table_dims_payload() -> Dictionary:
	return {
		"rows": rows,
		"cols": cols,
		"cells": cells.duplicate(true),
		"col_aligns": col_aligns.duplicate(true),
		"col_valigns": col_valigns.duplicate(true),
		"row_aligns": row_aligns.duplicate(true),
		"row_valigns": row_valigns.duplicate(true),
		"col_widths": col_widths.duplicate(true),
		"cell_formats": cell_formats.duplicate(true),
	}


func insert_row_at(index: int) -> void:
	_ensure_arrays()
	var clamped: int = clamp(index, 0, rows)
	var before_payload: Dictionary = _table_dims_payload()
	var new_row: Array = []
	for c in range(cols):
		new_row.append("")
	cells.insert(clamped, new_row)
	row_aligns.insert(clamped, ALIGN_INHERIT)
	row_valigns.insert(clamped, ALIGN_INHERIT)
	cell_formats = _shift_cell_formats_for_row_insert(cell_formats, clamped)
	rows += 1
	_clamp_active_cell()
	_set_axis_selection(AXIS_ROW, clamped)
	_rebuild_grid()
	_request_grow_to_fit()
	_push_table_dims_history(before_payload)


func delete_row_at(index: int) -> void:
	_ensure_arrays()
	if rows <= 1:
		return
	if index < 0 or index >= rows:
		return
	var before_payload: Dictionary = _table_dims_payload()
	cells.remove_at(index)
	row_aligns.remove_at(index)
	row_valigns.remove_at(index)
	cell_formats = _shift_cell_formats_for_row_delete(cell_formats, index)
	rows -= 1
	_clamp_active_cell()
	if _selected_axis == AXIS_ROW:
		var new_index: int = clamp(index, 0, rows - 1)
		_set_axis_selection(AXIS_ROW, new_index)
	else:
		_clamp_axis_selection()
	_rebuild_grid()
	_request_grow_to_fit()
	_push_table_dims_history(before_payload)


func insert_col_at(index: int) -> void:
	_ensure_arrays()
	var clamped: int = clamp(index, 0, cols)
	var before_payload: Dictionary = _table_dims_payload()
	for r in range(rows):
		var row: Array = cells[r]
		row.insert(clamped, "")
		cells[r] = row
	col_aligns.insert(clamped, ALIGN_LEFT)
	col_valigns.insert(clamped, VALIGN_MIDDLE)
	col_widths.insert(clamped, 0.0)
	cell_formats = _shift_cell_formats_for_col_insert(cell_formats, clamped)
	cols += 1
	_clamp_active_cell()
	_set_axis_selection(AXIS_COL, clamped)
	_rebuild_grid()
	_request_grow_to_fit()
	_push_table_dims_history(before_payload)


func delete_col_at(index: int) -> void:
	_ensure_arrays()
	if cols <= 1:
		return
	if index < 0 or index >= cols:
		return
	var before_payload: Dictionary = _table_dims_payload()
	for r in range(rows):
		var row: Array = cells[r]
		row.remove_at(index)
		cells[r] = row
	col_aligns.remove_at(index)
	col_valigns.remove_at(index)
	col_widths.remove_at(index)
	cell_formats = _shift_cell_formats_for_col_delete(cell_formats, index)
	cols -= 1
	_clamp_active_cell()
	if _selected_axis == AXIS_COL:
		var new_index: int = clamp(index, 0, cols - 1)
		_set_axis_selection(AXIS_COL, new_index)
	else:
		_clamp_axis_selection()
	_rebuild_grid()
	_request_grow_to_fit()
	_push_table_dims_history(before_payload)


func _push_table_dims_history(before_payload: Dictionary) -> void:
	var after_payload: Dictionary = _table_dims_payload()
	var editor: Node = _find_editor()
	if editor == null:
		return
	History.push_already_done(ModifyPropertyCommand.new(editor, item_id, "table_dims", before_payload, after_payload))
	if editor.has_method("request_save"):
		editor.request_save()


func _shift_cell_formats_for_row_insert(src: Dictionary, inserted_row: int) -> Dictionary:
	var out: Dictionary = {}
	for key_v: Variant in src.keys():
		var k: String = String(key_v)
		var coords: PackedInt32Array = _split_cell_format_key(k)
		if coords.size() != 2:
			continue
		var r: int = coords[0]
		var c: int = coords[1]
		if r >= inserted_row:
			r += 1
		out[_cell_format_key(r, c)] = (src[key_v] as Dictionary).duplicate(true)
	return out


func _shift_cell_formats_for_row_delete(src: Dictionary, deleted_row: int) -> Dictionary:
	var out: Dictionary = {}
	for key_v: Variant in src.keys():
		var k: String = String(key_v)
		var coords: PackedInt32Array = _split_cell_format_key(k)
		if coords.size() != 2:
			continue
		var r: int = coords[0]
		var c: int = coords[1]
		if r == deleted_row:
			continue
		if r > deleted_row:
			r -= 1
		out[_cell_format_key(r, c)] = (src[key_v] as Dictionary).duplicate(true)
	return out


func _shift_cell_formats_for_col_insert(src: Dictionary, inserted_col: int) -> Dictionary:
	var out: Dictionary = {}
	for key_v: Variant in src.keys():
		var k: String = String(key_v)
		var coords: PackedInt32Array = _split_cell_format_key(k)
		if coords.size() != 2:
			continue
		var r: int = coords[0]
		var c: int = coords[1]
		if c >= inserted_col:
			c += 1
		out[_cell_format_key(r, c)] = (src[key_v] as Dictionary).duplicate(true)
	return out


func _shift_cell_formats_for_col_delete(src: Dictionary, deleted_col: int) -> Dictionary:
	var out: Dictionary = {}
	for key_v: Variant in src.keys():
		var k: String = String(key_v)
		var coords: PackedInt32Array = _split_cell_format_key(k)
		if coords.size() != 2:
			continue
		var r: int = coords[0]
		var c: int = coords[1]
		if c == deleted_col:
			continue
		if c > deleted_col:
			c -= 1
		out[_cell_format_key(r, c)] = (src[key_v] as Dictionary).duplicate(true)
	return out


func _split_cell_format_key(k: String) -> PackedInt32Array:
	var parts: PackedStringArray = k.split(",")
	if parts.size() != 2:
		return PackedInt32Array()
	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return PackedInt32Array()
	var arr: PackedInt32Array = PackedInt32Array()
	arr.append(parts[0].to_int())
	arr.append(parts[1].to_int())
	return arr


func _clamp_active_cell() -> void:
	if rows <= 0 or cols <= 0:
		return
	var clamped_r: int = clamp(_active_cell.x, 0, rows - 1)
	var clamped_c: int = clamp(_active_cell.y, 0, cols - 1)
	if clamped_r == _active_cell.x and clamped_c == _active_cell.y:
		return
	_active_cell = Vector2i(clamped_r, clamped_c)
	emit_signal("active_cell_changed", clamped_r, clamped_c)


func _request_grow_to_fit() -> void:
	if _grow_pending:
		return
	_grow_pending = true
	_grow_to_fit_async()


func _grow_to_fit_async() -> void:
	await get_tree().process_frame
	_grow_pending = false
	if _grid == null or not is_inside_tree():
		return
	var grid_min: Vector2 = _grid.get_combined_minimum_size()
	var required_w: float = grid_min.x + PADDING.x * 2.0
	var required_h: float = grid_min.y + HEADER_HEIGHT + PADDING.y * 2.0
	var min_b: Vector2 = minimum_item_size()
	required_w = max(required_w, min_b.x)
	required_h = max(required_h, min_b.y)
	var new_size: Vector2 = size
	var changed: bool = false
	if new_size.x < required_w:
		new_size.x = required_w
		changed = true
	if new_size.y < required_h:
		new_size.y = required_h
		changed = true
	if changed:
		size = new_size
		_layout()


func _push_cells_history(before: Array) -> void:
	var editor: Node = _find_editor()
	if editor == null:
		return
	History.push_already_done(ModifyPropertyCommand.new(editor, item_id, "cells", before, cells.duplicate(true)))
	if editor.has_method("request_save"):
		editor.request_save()


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null


func _connect_axis_strip_signals() -> void:
	if _row_strip_left != null:
		_row_strip_left.gui_input.connect(_on_row_strip_input.bind(_row_strip_left))
		_row_strip_left.mouse_exited.connect(_on_axis_strip_mouse_exited)
	if _row_strip_right != null:
		_row_strip_right.gui_input.connect(_on_row_strip_input.bind(_row_strip_right))
		_row_strip_right.mouse_exited.connect(_on_axis_strip_mouse_exited)
	if _col_strip_top != null:
		_col_strip_top.gui_input.connect(_on_col_strip_input.bind(_col_strip_top))
		_col_strip_top.mouse_exited.connect(_on_axis_strip_mouse_exited)
	if _col_strip_bottom != null:
		_col_strip_bottom.gui_input.connect(_on_col_strip_input.bind(_col_strip_bottom))
		_col_strip_bottom.mouse_exited.connect(_on_axis_strip_mouse_exited)


func _on_row_strip_input(event: InputEvent, strip: Control) -> void:
	var side: String = SIDE_LEFT if strip == _row_strip_left else SIDE_RIGHT
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		var idx: int = _row_index_for_strip_local(strip, motion.position)
		_update_strip_hover(AXIS_ROW, idx, side)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var idx: int = _row_index_for_strip_local(strip, mb.position)
			if idx >= 0:
				_handle_axis_click(AXIS_ROW, idx, side)
				strip.accept_event()


func _on_col_strip_input(event: InputEvent, strip: Control) -> void:
	var side: String = SIDE_TOP if strip == _col_strip_top else SIDE_BOTTOM
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		var idx: int = _col_index_for_strip_local(strip, motion.position)
		_update_strip_hover(AXIS_COL, idx, side)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var idx: int = _col_index_for_strip_local(strip, mb.position)
			if idx >= 0:
				_handle_axis_click(AXIS_COL, idx, side)
				strip.accept_event()


func _on_axis_strip_mouse_exited() -> void:
	_update_strip_hover("", -1, "")


func _update_strip_hover(axis: String, index: int, side: String) -> void:
	if _strip_hover_axis == axis and _strip_hover_index == index and _strip_hover_side == side:
		return
	_strip_hover_axis = axis
	_strip_hover_index = index
	_strip_hover_side = side
	queue_redraw()


func _row_index_for_strip_local(strip: Control, local_pos: Vector2) -> int:
	if _grid == null or strip == null:
		return -1
	var y_in_grid: float = strip.position.y + local_pos.y - _grid.position.y
	return _row_index_at_grid_y(y_in_grid)


func _col_index_for_strip_local(strip: Control, local_pos: Vector2) -> int:
	if _grid == null or strip == null:
		return -1
	var x_in_grid: float = strip.position.x + local_pos.x - _grid.position.x
	return _col_index_at_grid_x(x_in_grid)


func _row_index_at_grid_y(y_in_grid: float) -> int:
	if y_in_grid < 0.0:
		return -1
	var grid_children: Array = _grid.get_children()
	for r in range(rows):
		var rect: Rect2 = _grid_row_rect(r, grid_children)
		if rect.size.y <= 0.0:
			continue
		if y_in_grid >= rect.position.y and y_in_grid < rect.position.y + rect.size.y:
			return r
	return -1


func _col_index_at_grid_x(x_in_grid: float) -> int:
	if x_in_grid < 0.0:
		return -1
	var grid_children: Array = _grid.get_children()
	for c in range(cols):
		var rect: Rect2 = _grid_col_rect(c, grid_children)
		if rect.size.x <= 0.0:
			continue
		if x_in_grid >= rect.position.x and x_in_grid < rect.position.x + rect.size.x:
			return c
	return -1


func _grid_row_rect(r: int, grid_children: Array) -> Rect2:
	if r < 0 or r >= rows:
		return Rect2()
	var first_idx: int = r * cols
	if first_idx >= grid_children.size():
		return Rect2()
	var last_idx: int = first_idx + cols - 1
	if last_idx >= grid_children.size():
		last_idx = grid_children.size() - 1
	var first_panel: PanelContainer = grid_children[first_idx] as PanelContainer
	var last_panel: PanelContainer = grid_children[last_idx] as PanelContainer
	if first_panel == null or last_panel == null:
		return Rect2()
	var y: float = first_panel.position.y
	var h: float = (last_panel.position.y + last_panel.size.y) - y
	var x: float = first_panel.position.x
	var w: float = (last_panel.position.x + last_panel.size.x) - x
	return Rect2(Vector2(x, y), Vector2(w, h))


func _grid_col_rect(c: int, grid_children: Array) -> Rect2:
	if c < 0 or c >= cols:
		return Rect2()
	if grid_children.size() == 0:
		return Rect2()
	var first_panel: PanelContainer = grid_children[c] as PanelContainer
	var last_row_first: int = (rows - 1) * cols
	var last_panel_idx: int = last_row_first + c
	if last_panel_idx >= grid_children.size():
		last_panel_idx = grid_children.size() - 1
	var last_panel: PanelContainer = grid_children[last_panel_idx] as PanelContainer
	if first_panel == null or last_panel == null:
		return Rect2()
	var x: float = first_panel.position.x
	var w: float = first_panel.size.x
	var y: float = first_panel.position.y
	var h: float = (last_panel.position.y + last_panel.size.y) - y
	return Rect2(Vector2(x, y), Vector2(w, h))


func _row_world_rect(r: int) -> Rect2:
	if _grid == null:
		return Rect2()
	var grid_children: Array = _grid.get_children()
	var rect: Rect2 = _grid_row_rect(r, grid_children)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Rect2()
	rect.position += _grid.position
	return rect


func _col_world_rect(c: int) -> Rect2:
	if _grid == null:
		return Rect2()
	var grid_children: Array = _grid.get_children()
	var rect: Rect2 = _grid_col_rect(c, grid_children)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Rect2()
	rect.position += _grid.position
	return rect


func _handle_axis_click(axis: String, index: int, side: String) -> void:
	if read_only:
		return
	emit_signal("selection_requested", self, false)
	_set_axis_selection(axis, index, side)


func _set_axis_selection(axis: String, index: int, side: String = "") -> void:
	if axis == AXIS_ROW:
		if index < 0 or index >= rows:
			return
	elif axis == AXIS_COL:
		if index < 0 or index >= cols:
			return
	else:
		return
	var resolved_side: String = _resolve_axis_side(axis, side)
	if _selected_axis == axis and _selected_axis_index == index and _selected_axis_side == resolved_side:
		_show_axis_actions_for_selection()
		return
	_selected_axis = axis
	_selected_axis_index = index
	_selected_axis_side = resolved_side
	_show_axis_actions_for_selection()
	emit_signal("axis_selection_changed", axis, index)
	queue_redraw()


func _resolve_axis_side(axis: String, side: String) -> String:
	if axis == AXIS_ROW:
		if side == SIDE_LEFT or side == SIDE_RIGHT:
			return side
		if _selected_axis == AXIS_ROW and (_selected_axis_side == SIDE_LEFT or _selected_axis_side == SIDE_RIGHT):
			return _selected_axis_side
		return SIDE_RIGHT
	if axis == AXIS_COL:
		if side == SIDE_TOP or side == SIDE_BOTTOM:
			return side
		if _selected_axis == AXIS_COL and (_selected_axis_side == SIDE_TOP or _selected_axis_side == SIDE_BOTTOM):
			return _selected_axis_side
		return SIDE_BOTTOM
	return ""


func clear_axis_selection() -> void:
	if _selected_axis == "" and _selected_axis_index == -1:
		return
	_selected_axis = ""
	_selected_axis_index = -1
	_selected_axis_side = ""
	if _axis_actions != null:
		_axis_actions.visible = false
	emit_signal("axis_selection_changed", "", -1)
	queue_redraw()


func _clamp_axis_selection() -> void:
	if _selected_axis == AXIS_ROW:
		if rows <= 0 or _selected_axis_index >= rows:
			clear_axis_selection()
	elif _selected_axis == AXIS_COL:
		if cols <= 0 or _selected_axis_index >= cols:
			clear_axis_selection()


func selected_axis() -> String:
	return _selected_axis


func selected_axis_index() -> int:
	return _selected_axis_index


func select_row(index: int, side: String = "") -> void:
	_set_axis_selection(AXIS_ROW, index, side)


func select_column(index: int, side: String = "") -> void:
	_set_axis_selection(AXIS_COL, index, side)


func _show_axis_actions_for_selection() -> void:
	if _axis_actions == null:
		return
	if _selected_axis == "" or _selected_axis_index < 0 or read_only or locked:
		_axis_actions.visible = false
		return
	_axis_actions.configure(_selected_axis, _selected_axis_index)
	_axis_actions.visible = true
	_reposition_axis_actions()


func _reposition_axis_actions() -> void:
	if _axis_actions == null or not _axis_actions.visible:
		return
	if _grid == null:
		return
	_axis_actions.reset_size()
	var size_v: Vector2 = _axis_actions.get_combined_minimum_size()
	var grid_top: float = _grid.position.y
	var grid_bottom: float = grid_top + _grid.size.y
	var grid_left: float = _grid.position.x
	var grid_right: float = grid_left + _grid.size.x
	if _selected_axis == AXIS_ROW:
		var rect: Rect2 = _row_world_rect(_selected_axis_index)
		var y: float = rect.position.y + (rect.size.y - size_v.y) * 0.5
		var prefers_left: bool = _selected_axis_side == SIDE_LEFT
		var x_left: float = grid_left - size_v.x - AXIS_ACTIONS_GAP
		var x_right: float = grid_right + AXIS_ACTIONS_GAP
		var x: float
		if prefers_left:
			x = x_left
			if x < 2.0:
				x = x_right
		else:
			x = x_right
			if x + size_v.x > size.x - 2.0:
				x = x_left
		if x < 2.0:
			x = 2.0
		if x + size_v.x > size.x - 2.0:
			x = max(2.0, size.x - size_v.x - 2.0)
		y = clamp(y, 2.0, max(2.0, size.y - size_v.y - 2.0))
		_axis_actions.position = Vector2(x, y)
		_axis_actions.size = size_v
	else:
		var rect_c: Rect2 = _col_world_rect(_selected_axis_index)
		var x_c: float = rect_c.position.x + (rect_c.size.x - size_v.x) * 0.5
		var prefers_top: bool = _selected_axis_side == SIDE_TOP
		var y_top: float = grid_top - size_v.y - AXIS_ACTIONS_GAP
		var y_bottom: float = grid_bottom + AXIS_ACTIONS_GAP
		var y_c: float
		if prefers_top:
			y_c = y_top
			if y_c < HEADER_HEIGHT + 2.0:
				y_c = y_bottom
		else:
			y_c = y_bottom
			if y_c + size_v.y > size.y - 2.0:
				y_c = y_top
		if y_c < HEADER_HEIGHT + 2.0:
			y_c = HEADER_HEIGHT + 2.0
		if y_c + size_v.y > size.y - 2.0:
			y_c = max(HEADER_HEIGHT + 2.0, size.y - size_v.y - 2.0)
		x_c = clamp(x_c, 2.0, max(2.0, size.x - size_v.x - 2.0))
		_axis_actions.position = Vector2(x_c, y_c)
		_axis_actions.size = size_v


func _on_axis_action_requested(action: String) -> void:
	if _selected_axis == "" or _selected_axis_index < 0:
		return
	if _selected_axis == AXIS_ROW:
		match action:
			TableAxisActions.ACTION_INSERT_BEFORE:
				insert_row_at(_selected_axis_index)
			TableAxisActions.ACTION_INSERT_AFTER:
				insert_row_at(_selected_axis_index + 1)
			TableAxisActions.ACTION_DELETE:
				delete_row_at(_selected_axis_index)
	else:
		match action:
			TableAxisActions.ACTION_INSERT_BEFORE:
				insert_col_at(_selected_axis_index)
			TableAxisActions.ACTION_INSERT_AFTER:
				insert_col_at(_selected_axis_index + 1)
			TableAxisActions.ACTION_DELETE:
				delete_col_at(_selected_axis_index)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var local: Vector2 = get_local_mouse_position()
			if local.y > HEADER_HEIGHT and not mb.double_click:
				var single_cell: Vector2i = _cell_at_local(local)
				if single_cell.x >= 0 and single_cell.y >= 0:
					set_active_cell(single_cell.x, single_cell.y)
			if mb.double_click and not locked and not read_only:
				if local.y <= HEADER_HEIGHT:
					if not _is_over_header_button(local):
						_edit_target = "title"
						_pending_edit_cell = Vector2i(-1, -1)
						begin_edit()
						accept_event()
						return
				else:
					var cell_coord: Vector2i = _cell_at_local(local)
					if cell_coord.x >= 0 and cell_coord.y >= 0:
						_edit_target = "cell"
						_pending_edit_cell = cell_coord
						set_active_cell(cell_coord.x, cell_coord.y)
						if is_editing():
							_focus_cell_after_build(cell_coord.x, cell_coord.y)
							accept_event()
							return
						begin_edit()
						accept_event()
						return
	super._gui_input(event)


func _is_over_header_button(local: Vector2) -> bool:
	for btn: Button in [_add_row_btn, _add_col_btn, _del_row_btn, _del_col_btn]:
		if btn == null:
			continue
		var rect: Rect2 = Rect2(btn.position, btn.size)
		if rect.has_point(local):
			return true
	return false


func _cell_at_local(local: Vector2) -> Vector2i:
	if _grid == null:
		return Vector2i(-1, -1)
	var grid_local: Vector2 = local - _grid.position
	if grid_local.x < 0 or grid_local.y < 0:
		return Vector2i(-1, -1)
	if grid_local.x > _grid.size.x or grid_local.y > _grid.size.y:
		return Vector2i(-1, -1)
	var children: Array = _grid.get_children()
	for idx in range(children.size()):
		var panel: PanelContainer = children[idx] as PanelContainer
		if panel == null:
			continue
		var rect: Rect2 = Rect2(panel.position, panel.size)
		if rect.has_point(grid_local):
			return Vector2i(int(panel.get_meta("cell_row", -1)), int(panel.get_meta("cell_col", -1)))
	return Vector2i(-1, -1)


func _on_edit_begin() -> void:
	if _edit_target == "title":
		_pre_edit_title = title
		_title_edit.text = title
		_title_label.visible = false
		_title_edit.visible = true
		_title_edit.call_deferred("grab_focus")
		_title_edit.call_deferred("select_all")
	else:
		_rebuild_grid()


func _on_edit_end() -> void:
	if _edit_target == "title":
		var new_title: String = _title_edit.text
		_title_edit.release_focus()
		_title_edit.visible = false
		_title_label.visible = true
		if new_title != _pre_edit_title:
			var editor: Node = _find_editor()
			if editor != null:
				History.push(ModifyPropertyCommand.new(editor, item_id, "title", _pre_edit_title, new_title))
			else:
				title = new_title
		_refresh_visuals()
	else:
		_rebuild_grid()
	_edit_target = ""
	_pending_edit_cell = Vector2i(-1, -1)


func _on_title_focus_exited() -> void:
	if is_editing() and _edit_target == "title":
		end_edit()


func _on_title_submitted(_t: String) -> void:
	if is_editing() and _edit_target == "title":
		end_edit()


func _on_selection_changed(selected: Array) -> void:
	if is_editing() and not selected.has(self):
		end_edit()
	if not selected.has(self):
		clear_axis_selection()
	_apply_cell_styling()


func serialize_payload() -> Dictionary:
	var out: Dictionary = {
		"title": title,
		"rows": rows,
		"cols": cols,
		"cells": cells.duplicate(true),
		"col_aligns": col_aligns.duplicate(true),
		"col_valigns": col_valigns.duplicate(true),
		"row_aligns": row_aligns.duplicate(true),
		"row_valigns": row_valigns.duplicate(true),
		"col_widths": col_widths.duplicate(true),
		"has_header_row": has_header_row,
		"rules": rules.duplicate(true),
		"cell_formats": cell_formats.duplicate(true),
		"bg_color_custom": bg_color_custom,
		"accent_color_custom": accent_color_custom,
		"header_fg_color_custom": header_fg_color_custom,
		"grid_line_color_custom": grid_line_color_custom,
	}
	if bg_color_custom:
		out["bg_color"] = ColorUtil.to_array(bg_color)
	if accent_color_custom:
		out["accent_color"] = ColorUtil.to_array(accent_color)
	if header_fg_color_custom:
		out["header_fg_color"] = ColorUtil.to_array(header_fg_color)
	if grid_line_color_custom:
		out["grid_line_color"] = ColorUtil.to_array(grid_line_color)
	return out


func deserialize_payload(d: Dictionary) -> void:
	title = String(d.get("title", title))
	rows = int(d.get("rows", rows))
	cols = int(d.get("cols", cols))
	var c_raw: Variant = d.get("cells", [])
	if typeof(c_raw) == TYPE_ARRAY:
		cells = (c_raw as Array).duplicate(true)
	var a_raw: Variant = d.get("col_aligns", [])
	if typeof(a_raw) == TYPE_ARRAY:
		col_aligns = (a_raw as Array).duplicate(true)
	var av_raw: Variant = d.get("col_valigns", [])
	if typeof(av_raw) == TYPE_ARRAY:
		col_valigns = (av_raw as Array).duplicate(true)
	else:
		col_valigns = []
	var ra_raw: Variant = d.get("row_aligns", [])
	if typeof(ra_raw) == TYPE_ARRAY:
		row_aligns = (ra_raw as Array).duplicate(true)
	else:
		row_aligns = []
	var rav_raw: Variant = d.get("row_valigns", [])
	if typeof(rav_raw) == TYPE_ARRAY:
		row_valigns = (rav_raw as Array).duplicate(true)
	else:
		row_valigns = []
	var w_raw: Variant = d.get("col_widths", [])
	if typeof(w_raw) == TYPE_ARRAY:
		col_widths = (w_raw as Array).duplicate(true)
	has_header_row = bool(d.get("has_header_row", has_header_row))
	var r_raw: Variant = d.get("rules", [])
	rules = TableRule.normalize_array(r_raw)
	cell_formats = _normalize_cell_formats(d.get("cell_formats", {}))
	_load_color_field(d, "bg_color", "bg_color_custom", LEGACY_BG, _set_bg)
	_load_color_field(d, "accent_color", "accent_color_custom", LEGACY_ACCENT, _set_accent)
	_load_color_field(d, "header_fg_color", "header_fg_color_custom", LEGACY_HEADER_FG, _set_header_fg)
	_load_color_field(d, "grid_line_color", "grid_line_color_custom", LEGACY_GRID_LINE, _set_grid_line)
	_ensure_arrays()
	if _grid != null:
		_refresh_visuals()
		_rebuild_grid()
		_request_grow_to_fit()


func _set_bg(c: Color) -> void:
	bg_color = c


func _set_accent(c: Color) -> void:
	accent_color = c


func _set_header_fg(c: Color) -> void:
	header_fg_color = c


func _set_grid_line(c: Color) -> void:
	grid_line_color = c


func _load_color_field(d: Dictionary, color_key: String, custom_key: String, legacy: Color, setter: Callable) -> void:
	if d.has(custom_key):
		var is_custom: bool = bool(d[custom_key])
		set(custom_key, is_custom)
		if is_custom and d.has(color_key):
			setter.call(ColorUtil.from_array(d[color_key], legacy))
		return
	if not d.has(color_key):
		return
	var stored: Color = ColorUtil.from_array(d[color_key], legacy)
	var is_legacy: bool = stored == legacy
	set(custom_key, not is_legacy)
	if not is_legacy:
		setter.call(stored)


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"title":
			title = String(value)
			_refresh_visuals()
		"cells":
			if typeof(value) == TYPE_ARRAY:
				cells = (value as Array).duplicate(true)
				_ensure_arrays()
				_rebuild_grid()
		"col_aligns":
			if typeof(value) == TYPE_ARRAY:
				col_aligns = (value as Array).duplicate(true)
				_ensure_arrays()
				_rebuild_grid()
		"col_valigns":
			if typeof(value) == TYPE_ARRAY:
				col_valigns = (value as Array).duplicate(true)
				_ensure_arrays()
				_rebuild_grid()
		"row_aligns":
			if typeof(value) == TYPE_ARRAY:
				row_aligns = (value as Array).duplicate(true)
				_ensure_arrays()
				_rebuild_grid()
		"row_valigns":
			if typeof(value) == TYPE_ARRAY:
				row_valigns = (value as Array).duplicate(true)
				_ensure_arrays()
				_rebuild_grid()
		"col_widths":
			if typeof(value) == TYPE_ARRAY:
				col_widths = (value as Array).duplicate(true)
				_ensure_arrays()
				_apply_column_widths_to_cells()
		"has_header_row":
			has_header_row = bool(value)
			_apply_cell_styling()
		"rules":
			rules = TableRule.normalize_array(value)
			_apply_cell_styling()
		"cell_formats":
			cell_formats = _normalize_cell_formats(value)
			_rebuild_grid()
			emit_signal("active_cell_changed", _active_cell.x, _active_cell.y)
		"table_dims":
			if typeof(value) == TYPE_DICTIONARY:
				var dd: Dictionary = value
				rows = int(dd.get("rows", rows))
				cols = int(dd.get("cols", cols))
				var c_raw: Variant = dd.get("cells", null)
				if typeof(c_raw) == TYPE_ARRAY:
					cells = (c_raw as Array).duplicate(true)
				var a_raw: Variant = dd.get("col_aligns", null)
				if typeof(a_raw) == TYPE_ARRAY:
					col_aligns = (a_raw as Array).duplicate(true)
				var av_raw: Variant = dd.get("col_valigns", null)
				if typeof(av_raw) == TYPE_ARRAY:
					col_valigns = (av_raw as Array).duplicate(true)
				var ra_raw: Variant = dd.get("row_aligns", null)
				if typeof(ra_raw) == TYPE_ARRAY:
					row_aligns = (ra_raw as Array).duplicate(true)
				var rav_raw: Variant = dd.get("row_valigns", null)
				if typeof(rav_raw) == TYPE_ARRAY:
					row_valigns = (rav_raw as Array).duplicate(true)
				var w_raw: Variant = dd.get("col_widths", null)
				if typeof(w_raw) == TYPE_ARRAY:
					col_widths = (w_raw as Array).duplicate(true)
				var cf_raw: Variant = dd.get("cell_formats", null)
				if typeof(cf_raw) == TYPE_DICTIONARY:
					cell_formats = _normalize_cell_formats(cf_raw)
				_ensure_arrays()
				_clamp_active_cell()
				_clamp_axis_selection()
				_rebuild_grid()
				_request_grow_to_fit()
		"bg_color":
			if value == null:
				bg_color_custom = false
			else:
				bg_color = ColorUtil.from_array(value, bg_color)
				bg_color_custom = true
			_refresh_visuals()
		"accent_color":
			if value == null:
				accent_color_custom = false
			else:
				accent_color = ColorUtil.from_array(value, accent_color)
				accent_color_custom = true
			_refresh_visuals()
		"header_fg_color":
			if value == null:
				header_fg_color_custom = false
			else:
				header_fg_color = ColorUtil.from_array(value, header_fg_color)
				header_fg_color_custom = true
			_refresh_visuals()
		"grid_line_color":
			if value == null:
				grid_line_color_custom = false
			else:
				grid_line_color = ColorUtil.from_array(value, grid_line_color)
				grid_line_color_custom = true
			_refresh_visuals()


func set_col_align(col: int, value: int) -> void:
	_ensure_arrays()
	if col < 0 or col >= cols:
		return
	var clamped: int = clamp(value, ALIGN_LEFT, ALIGN_RIGHT)
	if int(col_aligns[col]) == clamped:
		return
	var before: Array = col_aligns.duplicate(true)
	col_aligns[col] = clamped
	_rebuild_grid()
	var editor: Node = _find_editor()
	if editor != null:
		History.push_already_done(ModifyPropertyCommand.new(editor, item_id, "col_aligns", before, col_aligns.duplicate(true)))
		if editor.has_method("request_save"):
			editor.request_save()


func set_col_valign(col: int, value: int) -> void:
	_ensure_arrays()
	if col < 0 or col >= cols:
		return
	var clamped: int = clamp(value, VALIGN_TOP, VALIGN_BOTTOM)
	if int(col_valigns[col]) == clamped:
		return
	var before: Array = col_valigns.duplicate(true)
	col_valigns[col] = clamped
	_rebuild_grid()
	var editor: Node = _find_editor()
	if editor != null:
		History.push_already_done(ModifyPropertyCommand.new(editor, item_id, "col_valigns", before, col_valigns.duplicate(true)))
		if editor.has_method("request_save"):
			editor.request_save()


func set_row_align(row: int, value: int) -> void:
	_ensure_arrays()
	if row < 0 or row >= rows:
		return
	var clamped: int = _normalize_h_align_with_inherit(value)
	if int(row_aligns[row]) == clamped:
		return
	var before: Array = row_aligns.duplicate(true)
	row_aligns[row] = clamped
	_rebuild_grid()
	var editor: Node = _find_editor()
	if editor != null:
		History.push_already_done(ModifyPropertyCommand.new(editor, item_id, "row_aligns", before, row_aligns.duplicate(true)))
		if editor.has_method("request_save"):
			editor.request_save()


func set_row_valign(row: int, value: int) -> void:
	_ensure_arrays()
	if row < 0 or row >= rows:
		return
	var clamped: int = _normalize_v_align_with_inherit(value)
	if int(row_valigns[row]) == clamped:
		return
	var before: Array = row_valigns.duplicate(true)
	row_valigns[row] = clamped
	_rebuild_grid()
	var editor: Node = _find_editor()
	if editor != null:
		History.push_already_done(ModifyPropertyCommand.new(editor, item_id, "row_valigns", before, row_valigns.duplicate(true)))
		if editor.has_method("request_save"):
			editor.request_save()


func row_align_at(row: int) -> int:
	if row < 0 or row >= row_aligns.size():
		return ALIGN_INHERIT
	return int(row_aligns[row])


func row_valign_at(row: int) -> int:
	if row < 0 or row >= row_valigns.size():
		return ALIGN_INHERIT
	return int(row_valigns[row])


func col_align_at(col: int) -> int:
	if col < 0 or col >= col_aligns.size():
		return ALIGN_LEFT
	return int(col_aligns[col])


func col_valign_at(col: int) -> int:
	if col < 0 or col >= col_valigns.size():
		return VALIGN_MIDDLE
	return int(col_valigns[col])


func effective_h_align_at(r: int, c: int) -> int:
	return _effective_h_align(r, c)


func effective_v_align_at(r: int, c: int) -> int:
	return _effective_v_align(r, c)


func set_has_header_row(value: bool) -> void:
	if has_header_row == value:
		return
	var editor: Node = _find_editor()
	if editor == null:
		has_header_row = value
		_apply_cell_styling()
		return
	History.push(ModifyPropertyCommand.new(editor, item_id, "has_header_row", has_header_row, value))


func replace_rules(new_rules: Array) -> void:
	var normalized: Array = TableRule.normalize_array(new_rules)
	var before: Array = rules.duplicate(true)
	if before == normalized:
		return
	var editor: Node = _find_editor()
	if editor == null:
		rules = normalized
		_apply_cell_styling()
		return
	History.push(ModifyPropertyCommand.new(editor, item_id, "rules", before, normalized))


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/table/table_inspector.tscn")
	var inst: TableInspector = scene.instantiate()
	inst.bind(self)
	return inst


func bulk_shareable_properties() -> Array:
	return [
		{"key": "bg_color", "label": "Background", "kind": "color_with_reset"},
		{"key": "accent_color", "label": "Header color", "kind": "color_with_reset"},
		{"key": "header_fg_color", "label": "Header text", "kind": "color_with_reset"},
		{"key": "grid_line_color", "label": "Grid line", "kind": "color_with_reset"},
	]
