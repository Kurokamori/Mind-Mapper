class_name StickyNode
extends BoardItem

const PADDING: Vector2 = Vector2(12, 10)
const DEFAULT_FONT_SIZE: int = 16
const COLOR_PALETTE: Array[Color] = [
	Color(1.00, 0.93, 0.55),
	Color(1.00, 0.78, 0.55),
	Color(0.78, 0.93, 0.62),
	Color(0.62, 0.85, 1.00),
	Color(0.95, 0.70, 0.85),
	Color(0.85, 0.78, 1.00),
]

@export var text: String = "Sticky note"
@export var font_size: int = DEFAULT_FONT_SIZE
@export var color_index: int = 0
@export var h_align: int = 0
@export var v_align: int = 0

@onready var _label: Label = %Label
@onready var _edit: TextEdit = %TextEdit

var _pre_edit_text: String = ""


func _ready() -> void:
	super._ready()
	_edit.focus_exited.connect(_commit_text)
	SelectionBus.selection_changed.connect(_on_selection_changed)
	_layout()
	_refresh_visuals()


func default_size() -> Vector2:
	return Vector2(180, 160)


func display_name() -> String:
	return "Sticky"


func _on_selection_changed(selected: Array) -> void:
	if not is_editing():
		return
	if not selected.has(self):
		_commit_text()


func _draw_body() -> void:
	var fill: Color = COLOR_PALETTE[clampi(color_index, 0, COLOR_PALETTE.size() - 1)]
	_draw_rounded_panel(fill, fill.darkened(0.35))
	var fold: PackedVector2Array = PackedVector2Array([
		Vector2(size.x - 16.0, size.y - NODE_CORNER_RADIUS),
		Vector2(size.x - NODE_CORNER_RADIUS, size.y),
		Vector2(size.x - 16.0, size.y),
	])
	draw_colored_polygon(fold, fill.darkened(0.18))


func _refresh_visuals() -> void:
	if _label != null:
		_label.text = text
		_label.add_theme_font_size_override("font_size", font_size)
		_label.add_theme_color_override("font_color", Color(0.10, 0.09, 0.05))
		_label.horizontal_alignment = clampi(h_align, 0, 2) as HorizontalAlignment
		_label.vertical_alignment = clampi(v_align, 0, 2) as VerticalAlignment
	if _edit != null:
		_edit.add_theme_font_size_override("font_size", font_size)
		_edit.add_theme_color_override("font_color", Color(0.10, 0.09, 0.05))
	queue_redraw()


func _layout() -> void:
	if _label != null:
		_label.position = PADDING
		_label.size = size - PADDING * 2
	if _edit != null:
		_edit.position = PADDING
		_edit.size = size - PADDING * 2


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _on_edit_begin() -> void:
	_pre_edit_text = text
	_edit.text = text
	_label.visible = false
	_edit.visible = true
	_edit.grab_focus()
	_edit.select_all()


func _on_edit_end() -> void:
	var new_text: String = _edit.text
	_edit.release_focus()
	_edit.visible = false
	_label.visible = true
	if new_text != _pre_edit_text:
		var editor: Node = _find_editor()
		if editor != null:
			History.push(ModifyPropertyCommand.new(editor, item_id, "text", _pre_edit_text, new_text))
		else:
			text = new_text
			_refresh_visuals()
	else:
		_refresh_visuals()


func _commit_text() -> void:
	if is_editing():
		end_edit()


func _find_editor() -> Node:
	return EditorLocator.find_for(self)


func _gui_input(event: InputEvent) -> void:
	if is_editing():
		return
	super._gui_input(event)


func serialize_payload() -> Dictionary:
	return {
		"text": text,
		"font_size": font_size,
		"color_index": color_index,
		"h_align": h_align,
		"v_align": v_align,
	}


func deserialize_payload(d: Dictionary) -> void:
	text = String(d.get("text", text))
	font_size = int(d.get("font_size", font_size))
	color_index = int(d.get("color_index", color_index))
	h_align = clampi(int(d.get("h_align", h_align)), 0, 2)
	v_align = clampi(int(d.get("v_align", v_align)), 0, 2)
	if _label != null:
		_refresh_visuals()


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"text":
			text = String(value)
			_refresh_visuals()
		"font_size":
			font_size = int(value)
			_refresh_visuals()
		"color_index":
			color_index = int(value)
			_refresh_visuals()
		"h_align":
			h_align = clampi(int(value), 0, 2)
			_refresh_visuals()
		"v_align":
			v_align = clampi(int(value), 0, 2)
			_refresh_visuals()


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/sticky/sticky_inspector.tscn")
	var inst: StickyInspector = scene.instantiate()
	inst.bind(self)
	return inst


func bulk_shareable_properties() -> Array:
	return [
		{"key": "font_size", "label": "Font size", "kind": "int_range", "min": 6, "max": 96},
		{"key": "h_align", "label": "Horizontal align (0=L 1=C 2=R)", "kind": "int_range", "min": 0, "max": 2},
		{"key": "v_align", "label": "Vertical align (0=T 1=C 2=B)", "kind": "int_range", "min": 0, "max": 2},
	]
