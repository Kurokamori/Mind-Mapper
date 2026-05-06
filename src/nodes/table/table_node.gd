class_name TableNode
extends BoardItem

const HEADER_HEIGHT: float = 28.0
const PADDING: Vector2 = Vector2(6, 6)

@export var rows: int = 3
@export var cols: int = 3
@export var cells: Array = []

@onready var _grid: GridContainer = %Grid
@onready var _add_row_btn: Button = %AddRowBtn
@onready var _add_col_btn: Button = %AddColBtn
@onready var _del_row_btn: Button = %DelRowBtn
@onready var _del_col_btn: Button = %DelColBtn

var _editing_lock: bool = false


func _ready() -> void:
	super._ready()
	_ensure_cells()
	_layout()
	_add_row_btn.pressed.connect(func() -> void: _commit_dimensions(rows + 1, cols))
	_del_row_btn.pressed.connect(func() -> void: _commit_dimensions(max(1, rows - 1), cols))
	_add_col_btn.pressed.connect(func() -> void: _commit_dimensions(rows, cols + 1))
	_del_col_btn.pressed.connect(func() -> void: _commit_dimensions(rows, max(1, cols - 1)))
	_rebuild_grid()


func default_size() -> Vector2:
	return Vector2(360, 220)


func display_name() -> String:
	return "Table"


func _draw_body() -> void:
	_draw_rounded_panel(
		Color(0.13, 0.14, 0.17, 1.0),
		Color(0.30, 0.34, 0.40, 1.0),
		HEADER_HEIGHT,
		Color(0.20, 0.30, 0.45, 1.0),
	)


func _ensure_cells() -> void:
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
		cells[r] = row


func _layout() -> void:
	if _add_row_btn != null:
		_add_row_btn.position = Vector2(4, 2)
		_add_row_btn.size = Vector2(54, 22)
	if _del_row_btn != null:
		_del_row_btn.position = Vector2(60, 2)
		_del_row_btn.size = Vector2(54, 22)
	if _add_col_btn != null:
		_add_col_btn.position = Vector2(118, 2)
		_add_col_btn.size = Vector2(54, 22)
	if _del_col_btn != null:
		_del_col_btn.position = Vector2(174, 2)
		_del_col_btn.size = Vector2(54, 22)
	if _grid != null:
		_grid.position = Vector2(PADDING.x, HEADER_HEIGHT + PADDING.y)
		_grid.size = size - Vector2(PADDING.x * 2, HEADER_HEIGHT + PADDING.y * 2)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _rebuild_grid() -> void:
	if _grid == null:
		return
	_editing_lock = true
	for child in _grid.get_children():
		child.queue_free()
	_grid.columns = max(1, cols)
	for r in range(rows):
		for c in range(cols):
			var le: LineEdit = LineEdit.new()
			le.text = String((cells[r] as Array)[c]) if r < cells.size() and c < (cells[r] as Array).size() else ""
			le.custom_minimum_size = Vector2(60, 24)
			le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var rr: int = r
			var cc: int = c
			le.text_submitted.connect(func(t: String) -> void: _on_cell_text_set(rr, cc, t))
			le.focus_exited.connect(func() -> void: _on_cell_text_set(rr, cc, le.text))
			_grid.add_child(le)
	_editing_lock = false


func _on_cell_text_set(r: int, c: int, value: String) -> void:
	if _editing_lock:
		return
	_ensure_cells()
	var row: Array = cells[r]
	if String(row[c]) == value:
		return
	var before: Array = cells.duplicate(true)
	row[c] = value
	cells[r] = row
	_push_cells_history(before)


func commit_dimensions(new_rows: int, new_cols: int) -> void:
	_commit_dimensions(new_rows, new_cols)


func _commit_dimensions(new_rows: int, new_cols: int) -> void:
	if new_rows == rows and new_cols == cols:
		return
	var before_cells: Array = cells.duplicate(true)
	var before_rows: int = rows
	var before_cols: int = cols
	rows = max(1, new_rows)
	cols = max(1, new_cols)
	_ensure_cells()
	_rebuild_grid()
	var editor: Node = _find_editor()
	if editor == null:
		return
	History.push_already_done(ModifyPropertyCommand.new(editor, item_id, "table_dims", {"rows": before_rows, "cols": before_cols, "cells": before_cells}, {"rows": rows, "cols": cols, "cells": cells.duplicate(true)}))
	if editor.has_method("request_save"):
		editor.request_save()


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


func serialize_payload() -> Dictionary:
	return {"rows": rows, "cols": cols, "cells": cells.duplicate(true)}


func deserialize_payload(d: Dictionary) -> void:
	rows = int(d.get("rows", rows))
	cols = int(d.get("cols", cols))
	var c_raw: Variant = d.get("cells", [])
	if typeof(c_raw) == TYPE_ARRAY:
		cells = (c_raw as Array).duplicate(true)
	_ensure_cells()
	if _grid != null:
		_rebuild_grid()


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"cells":
			if typeof(value) == TYPE_ARRAY:
				cells = (value as Array).duplicate(true)
				_ensure_cells()
				_rebuild_grid()
		"table_dims":
			if typeof(value) == TYPE_DICTIONARY:
				var dd: Dictionary = value
				rows = int(dd.get("rows", rows))
				cols = int(dd.get("cols", cols))
				var c_raw: Variant = dd.get("cells", null)
				if typeof(c_raw) == TYPE_ARRAY:
					cells = (c_raw as Array).duplicate(true)
				_ensure_cells()
				_rebuild_grid()


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/table/table_inspector.tscn")
	var inst: TableInspector = scene.instantiate()
	inst.bind(self)
	return inst
