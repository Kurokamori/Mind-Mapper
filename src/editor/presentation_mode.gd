extends Control

@onready var _backdrop: ColorRect = %Backdrop
@onready var _stage_clip: Control = %StageClip
@onready var _stage: Control = %Stage
@onready var _board_label: Label = %BoardLabel
@onready var _hint_label: Label = %HintLabel
@onready var _close_button: Button = %CloseButton

const SLIDE_PADDING: Vector2 = Vector2(80, 120)

var _project: Project = null
var _board: Board = null
var _items: Array = []
var _connections: Array = []
var _slides: Array = []
var _slide_index: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = true
	_close_button.pressed.connect(_on_close_pressed)


func _on_close_pressed() -> void:
	queue_free()


func start(project: Project, board: Board, items: Array, connections: Array) -> void:
	_project = project
	_board = board
	_items = items.duplicate()
	_connections = connections.duplicate()
	_compute_slides()
	_slide_index = 0
	call_deferred("_render")
	grab_focus()


func _compute_slides() -> void:
	_slides.clear()
	var consumed: Dictionary = {}
	var groups: Array = []
	var loose: Array = []
	for it_v in _items:
		var it: BoardItem = it_v
		if it is GroupNode:
			groups.append(it)
		else:
			loose.append(it)
	for g_v in groups:
		var g: BoardItem = g_v
		var rect: Rect2 = Rect2(g.position, g.size)
		var children: Array = []
		for it_v in loose:
			var it: BoardItem = it_v
			if consumed.has(it.item_id):
				continue
			var center: Vector2 = it.position + it.size * 0.5
			if rect.has_point(center):
				consumed[it.item_id] = true
				children.append(it)
		var slide_items: Array = [g]
		for child in children:
			slide_items.append(child)
		_slides.append({
			"bounds": _bounds_for(slide_items),
			"items": slide_items,
			"is_group": true,
			"primary": g,
		})
	for it_v in loose:
		var it: BoardItem = it_v
		if consumed.has(it.item_id):
			continue
		_slides.append({
			"bounds": Rect2(it.position, it.size),
			"items": [it],
			"is_group": false,
			"primary": it,
		})
	_slides.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ay: float = (a.bounds as Rect2).position.y
		var by: float = (b.bounds as Rect2).position.y
		if absf(ay - by) > 12.0:
			return ay < by
		return (a.bounds as Rect2).position.x < (b.bounds as Rect2).position.x
	)


func _bounds_for(items: Array) -> Rect2:
	var min_p: Vector2 = Vector2(INF, INF)
	var max_p: Vector2 = Vector2(-INF, -INF)
	for it_v in items:
		var it: BoardItem = it_v
		min_p.x = min(min_p.x, it.position.x)
		min_p.y = min(min_p.y, it.position.y)
		max_p.x = max(max_p.x, it.position.x + it.size.x)
		max_p.y = max(max_p.y, it.position.y + it.size.y)
	if min_p.x == INF:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return Rect2(min_p, max_p - min_p)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event
		match k.keycode:
			KEY_ESCAPE:
				queue_free()
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_DOWN, KEY_SPACE, KEY_PAGEDOWN:
				_advance(1)
				get_viewport().set_input_as_handled()
			KEY_LEFT, KEY_UP, KEY_BACKSPACE, KEY_PAGEUP:
				_advance(-1)
				get_viewport().set_input_as_handled()
			KEY_HOME:
				_slide_index = 0
				_render()
				get_viewport().set_input_as_handled()
			KEY_END:
				_slide_index = max(0, _slides.size() - 1)
				_render()
				get_viewport().set_input_as_handled()


func _advance(delta: int) -> void:
	if _slides.is_empty():
		return
	_slide_index = clampi(_slide_index + delta, 0, _slides.size() - 1)
	_render()


func _render() -> void:
	for child in _stage.get_children():
		child.queue_free()
	if _slides.is_empty():
		_board_label.text = "%s — (no items)" % (_board.name if _board != null else "")
		_hint_label.text = "Esc to exit"
		return
	var slide: Dictionary = _slides[_slide_index]
	var bounds: Rect2 = slide.bounds
	var bg: Color = ThemeManager.background_color()
	_backdrop.color = bg
	var slide_items: Array = slide.items
	var primary: BoardItem = slide.primary
	var slide_label: String = primary.display_name() if primary != null else ""
	_board_label.text = "%s — slide %d / %d %s" % [
		(_board.name if _board != null else ""),
		_slide_index + 1,
		_slides.size(),
		"(group: %s)" % String(primary.title) if (primary is GroupNode and "title" in primary) else "",
	]
	_hint_label.text = "Esc exit  ←/→ navigate  Home/End jump  (%s)" % slide_label
	var stage_size: Vector2 = _stage_clip.size
	if stage_size.x <= 0 or stage_size.y <= 0:
		stage_size = Vector2(1280, 720)
	var content_size: Vector2 = bounds.size + SLIDE_PADDING * 2.0
	var scale_x: float = stage_size.x / max(1.0, content_size.x)
	var scale_y: float = stage_size.y / max(1.0, content_size.y)
	var s: float = min(scale_x, scale_y)
	if s <= 0.0:
		s = 1.0
	_stage.scale = Vector2(s, s)
	var scaled_size: Vector2 = content_size * s
	var stage_origin: Vector2 = (stage_size - scaled_size) * 0.5
	_stage.position = stage_origin
	for it_v in slide_items:
		var it: BoardItem = it_v
		var dict_copy: Dictionary = it.to_dict()
		var inst: BoardItem = ItemRegistry.instantiate_from_dict(dict_copy)
		if inst == null:
			continue
		inst.read_only = true
		inst.position = (it.position - bounds.position) + SLIDE_PADDING
		_stage.add_child(inst)
	var conn_overlay: PresentationConnections = PresentationConnections.new()
	conn_overlay.bind(_connections, slide_items, bounds.position - SLIDE_PADDING)
	conn_overlay.size = bounds.size + SLIDE_PADDING * 2.0
	conn_overlay.position = Vector2.ZERO
	conn_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(conn_overlay)
	_stage.move_child(conn_overlay, 0)


class PresentationConnections extends Control:
	var _connections: Array = []
	var _items: Array = []
	var _origin: Vector2 = Vector2.ZERO

	func bind(connections: Array, items: Array, origin: Vector2) -> void:
		_connections = connections
		_items = items
		_origin = origin
		queue_redraw()

	func _draw() -> void:
		var by_id: Dictionary = {}
		for it_v in _items:
			var it: BoardItem = it_v
			by_id[it.item_id] = it
		for c_v in _connections:
			var c: Connection = c_v
			if not by_id.has(c.from_item_id) or not by_id.has(c.to_item_id):
				continue
			var a: BoardItem = by_id[c.from_item_id]
			var b: BoardItem = by_id[c.to_item_id]
			var p1: Vector2 = (a.position + a.size * 0.5) - _origin
			var p2: Vector2 = (b.position + b.size * 0.5) - _origin
			draw_line(p1, p2, c.color, max(1.0, c.thickness), true)
			if c.arrow_end:
				_draw_arrow(p1, p2, c.color, c.thickness)
			if c.arrow_start:
				_draw_arrow(p2, p1, c.color, c.thickness)

	func _draw_arrow(prev: Vector2, tip: Vector2, color: Color, width: float) -> void:
		var dir: Vector2 = tip - prev
		if dir.length_squared() < 0.0001:
			return
		dir = dir.normalized()
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var base: Vector2 = tip - dir * 12.0
		var left: Vector2 = base + perp * 4.0
		var right: Vector2 = base - perp * 4.0
		draw_colored_polygon(PackedVector2Array([tip, left, right]), color)
