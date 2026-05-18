class_name BoardExporter
extends RefCounted

const MAX_VIEWPORT_SIDE: int = 16384
const PADDING: float = 32.0
const TILE_GAP: float = 64.0
const TILE_LABEL_HEIGHT: float = 56.0
const TILE_LABEL_FONT_SIZE: int = 28
const TILE_LABEL_PAD_X: float = 16.0
const TILE_LABEL_PAD_Y: float = 12.0
const TILE_LABEL_BG: Color = Color(0.13, 0.16, 0.22, 1.0)
const TILE_LABEL_FG: Color = Color(0.95, 0.96, 0.99, 1.0)
const TILE_BORDER_COLOR: Color = Color(0.28, 0.32, 0.40, 1.0)
const TILE_BORDER_WIDTH: float = 2.0
const TILES_PER_ROW_TARGET_RATIO: float = 1.6

const SVG_FONT_FAMILY: String = "Inter, system-ui, -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif"
const SVG_ARROW_LENGTH: float = 12.0
const SVG_ARROW_WIDTH: float = 8.0


class TileLayout extends RefCounted:
	var board: Board
	var label: String
	var bounds: Rect2
	var content_size: Vector2
	var tile_size: Vector2
	var tile_origin: Vector2

	func _init(b: Board, lbl: String) -> void:
		board = b
		label = lbl


var _host: Node


func _init(host: Node) -> void:
	_host = host


func export_board(board: Board, path: String) -> bool:
	if board == null or _host == null:
		return false
	if board.items.is_empty():
		return false
	var bounds: Rect2 = compute_board_bounds(board)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return false
	var world_top_left: Vector2 = bounds.position - Vector2(PADDING, PADDING)
	var world_size: Vector2 = bounds.size + Vector2(PADDING * 2.0, PADDING * 2.0)
	return await _render_tiles_to_png([_make_single_layout(board, world_top_left, world_size)], path)


func export_unfolded(root_board: Board, project: Project, path: String) -> bool:
	if root_board == null or project == null or _host == null:
		return false
	var ordered: Array = _collect_boards_breadth_first(root_board, project)
	if ordered.is_empty():
		return false
	var layouts: Array = []
	for b_variant in ordered:
		var b: Board = b_variant
		var lbl: String = b.name if b.name != "" else "(unnamed)"
		var tl: TileLayout = TileLayout.new(b, lbl)
		tl.bounds = compute_board_bounds(b)
		var content_w: float = max(tl.bounds.size.x, 320.0) + PADDING * 2.0
		var content_h: float = max(tl.bounds.size.y, 200.0) + PADDING * 2.0
		tl.content_size = Vector2(content_w, content_h)
		tl.tile_size = Vector2(content_w, content_h + TILE_LABEL_HEIGHT)
		layouts.append(tl)
	_pack_tiles(layouts)
	return await _render_tiles_to_png(layouts, path)


func compute_board_bounds(board: Board) -> Rect2:
	var min_p: Vector2 = Vector2(INF, INF)
	var max_p: Vector2 = Vector2(-INF, -INF)
	for d in board.items:
		var pos: Variant = d.get("position", [0, 0])
		var sz: Variant = d.get("size", [0, 0])
		if typeof(pos) != TYPE_ARRAY or typeof(sz) != TYPE_ARRAY:
			continue
		var px: float = float(pos[0])
		var py: float = float(pos[1])
		var sx: float = float(sz[0])
		var sy: float = float(sz[1])
		min_p.x = min(min_p.x, px)
		min_p.y = min(min_p.y, py)
		max_p.x = max(max_p.x, px + sx)
		max_p.y = max(max_p.y, py + sy)
	if min_p.x == INF:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return Rect2(min_p, max_p - min_p)


func _make_single_layout(board: Board, world_top_left: Vector2, world_size: Vector2) -> TileLayout:
	var tl: TileLayout = TileLayout.new(board, board.name if board.name != "" else "")
	tl.bounds = Rect2(world_top_left + Vector2(PADDING, PADDING), world_size - Vector2(PADDING * 2.0, PADDING * 2.0))
	tl.content_size = world_size
	if tl.label != "":
		tl.tile_size = Vector2(world_size.x, world_size.y + TILE_LABEL_HEIGHT)
	else:
		tl.tile_size = world_size
	tl.tile_origin = Vector2.ZERO
	return tl


func _collect_boards_breadth_first(root: Board, project: Project) -> Array:
	var visited: Dictionary = {}
	var ordered: Array = []
	var queue: Array = [root]
	visited[root.id] = true
	while not queue.is_empty():
		var b: Board = queue.pop_front() as Board
		ordered.append(b)
		for d in b.items:
			var t: String = String(d.get("type", ""))
			if t != ItemRegistry.TYPE_PINBOARD and t != ItemRegistry.TYPE_SUBPAGE:
				continue
			var child_id: String = String(d.get("target_board_id", ""))
			if child_id == "" or visited.has(child_id):
				continue
			var child_board: Board = project.read_board(child_id)
			if child_board == null:
				continue
			visited[child_id] = true
			queue.append(child_board)
	return ordered


func _pack_tiles(layouts: Array) -> void:
	var n: int = layouts.size()
	if n == 0:
		return
	var tiles_per_row: int = max(1, int(round(sqrt(float(n)) * TILES_PER_ROW_TARGET_RATIO)))
	tiles_per_row = min(tiles_per_row, n)
	var col_widths: Array[float] = []
	col_widths.resize(tiles_per_row)
	for i in range(tiles_per_row):
		col_widths[i] = 0.0
	var row_heights: Array[float] = []
	for i in range(n):
		var col: int = i % tiles_per_row
		var row: int = i / tiles_per_row
		if row >= row_heights.size():
			row_heights.append(0.0)
		col_widths[col] = max(col_widths[col], layouts[i].tile_size.x)
		row_heights[row] = max(row_heights[row], layouts[i].tile_size.y)
	var col_x: Array[float] = []
	col_x.resize(tiles_per_row)
	var x_acc: float = 0.0
	for c in range(tiles_per_row):
		col_x[c] = x_acc
		x_acc += col_widths[c] + TILE_GAP
	var row_y: Array[float] = []
	row_y.resize(row_heights.size())
	var y_acc: float = 0.0
	for r in range(row_heights.size()):
		row_y[r] = y_acc
		y_acc += row_heights[r] + TILE_GAP
	for i in range(n):
		var col: int = i % tiles_per_row
		var row: int = i / tiles_per_row
		layouts[i].tile_origin = Vector2(col_x[col], row_y[row])


func _render_tiles_to_png(layouts: Array, path: String) -> bool:
	if layouts.is_empty():
		return false
	var total_size: Vector2 = Vector2.ZERO
	for entry in layouts:
		var tl: TileLayout = entry
		total_size.x = max(total_size.x, tl.tile_origin.x + tl.tile_size.x)
		total_size.y = max(total_size.y, tl.tile_origin.y + tl.tile_size.y)
	var outer_pad: float = PADDING
	var canvas_world_size: Vector2 = total_size + Vector2(outer_pad * 2.0, outer_pad * 2.0)
	var canvas_world_origin: Vector2 = Vector2(-outer_pad, -outer_pad)
	var zoom: float = 1.0
	var vp_size: Vector2i = Vector2i(int(ceil(canvas_world_size.x)), int(ceil(canvas_world_size.y)))
	var max_side: int = max(vp_size.x, vp_size.y)
	if max_side > MAX_VIEWPORT_SIDE:
		zoom = float(MAX_VIEWPORT_SIDE) / float(max_side)
		vp_size = Vector2i(int(ceil(canvas_world_size.x * zoom)), int(ceil(canvas_world_size.y * zoom)))
	var sub: SubViewport = SubViewport.new()
	sub.size = vp_size
	sub.transparent_bg = false
	sub.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub.disable_3d = true
	sub.handle_input_locally = false
	_host.add_child(sub)
	var world: Node2D = Node2D.new()
	sub.add_child(world)
	var cam: Camera2D = Camera2D.new()
	cam.zoom = Vector2(zoom, zoom)
	cam.position = canvas_world_origin + canvas_world_size * 0.5
	world.add_child(cam)
	cam.make_current()
	var bg_layer: ExportTilesLayer = ExportTilesLayer.new()
	bg_layer.configure(layouts, canvas_world_origin, canvas_world_size, zoom)
	world.add_child(bg_layer)
	for entry in layouts:
		_populate_tile(world, entry as TileLayout)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = sub.get_texture().get_image()
	var ok: bool = false
	if img != null:
		var err: int = img.save_png(path)
		ok = err == OK
	sub.queue_free()
	return ok


func _populate_tile(world: Node2D, tl: TileLayout) -> void:
	var content_world_origin: Vector2 = tl.tile_origin + Vector2(0.0, _label_height_for(tl))
	var item_offset: Vector2 = content_world_origin + Vector2(PADDING, PADDING) - tl.bounds.position
	var holder: Node2D = Node2D.new()
	holder.position = item_offset
	world.add_child(holder)
	for d in tl.board.items:
		var inst: BoardItem = ItemRegistry.instantiate_from_dict(d)
		if inst == null:
			continue
		inst.read_only = true
		inst.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(inst)


func _label_height_for(tl: TileLayout) -> float:
	return TILE_LABEL_HEIGHT if tl.label != "" else 0.0


class ExportTilesLayer extends Node2D:
	var _layouts: Array = []
	var _canvas_origin: Vector2 = Vector2.ZERO
	var _canvas_size: Vector2 = Vector2.ZERO
	var _zoom: float = 1.0
	var _font: Font = null

	func configure(layouts: Array, canvas_origin: Vector2, canvas_size: Vector2, zoom: float) -> void:
		_layouts = layouts
		_canvas_origin = canvas_origin
		_canvas_size = canvas_size
		_zoom = zoom
		_font = ThemeDB.fallback_font

	func _ready() -> void:
		z_index = -1000
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(_canvas_origin, _canvas_size), ThemeManager.background_color(), true)
		for entry in _layouts:
			var tl: TileLayout = entry
			var content_origin: Vector2 = tl.tile_origin + Vector2(0.0, BoardExporter.TILE_LABEL_HEIGHT if tl.label != "" else 0.0)
			var content_rect: Rect2 = Rect2(content_origin, tl.content_size)
			GridBackground.draw_grid_into(self, content_rect, SnapService.grid_size, true, _zoom)
			draw_rect(content_rect, BoardExporter.TILE_BORDER_COLOR, false, BoardExporter.TILE_BORDER_WIDTH)
			if tl.label != "":
				var label_rect: Rect2 = Rect2(tl.tile_origin, Vector2(tl.tile_size.x, BoardExporter.TILE_LABEL_HEIGHT))
				draw_rect(label_rect, BoardExporter.TILE_LABEL_BG, true)
				draw_rect(label_rect, BoardExporter.TILE_BORDER_COLOR, false, BoardExporter.TILE_BORDER_WIDTH)
				if _font != null:
					var text_pos: Vector2 = label_rect.position + Vector2(BoardExporter.TILE_LABEL_PAD_X, BoardExporter.TILE_LABEL_HEIGHT - BoardExporter.TILE_LABEL_PAD_Y)
					draw_string(_font, text_pos, tl.label, HORIZONTAL_ALIGNMENT_LEFT, label_rect.size.x - BoardExporter.TILE_LABEL_PAD_X * 2.0, BoardExporter.TILE_LABEL_FONT_SIZE, BoardExporter.TILE_LABEL_FG)


# ============================================================================
# SVG export
# ============================================================================


func export_svg(board: Board, items: Array, connections: Array, project: Project, path: String) -> bool:
	if board == null:
		return false
	var item_dicts: Array = []
	for it_v in items:
		var it: BoardItem = it_v
		if it == null:
			continue
		item_dicts.append(it.to_dict())
	var connection_dicts: Array = []
	for c_v in connections:
		if c_v is Connection:
			connection_dicts.append((c_v as Connection).to_dict())
		elif typeof(c_v) == TYPE_DICTIONARY:
			connection_dicts.append(c_v)
	var bounds: Rect2 = _items_bounds_dicts(item_dicts)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		bounds = Rect2(Vector2.ZERO, Vector2(800, 600))
	var pad: float = PADDING
	var origin: Vector2 = bounds.position - Vector2(pad, pad)
	var canvas_size: Vector2 = bounds.size + Vector2(pad * 2.0, pad * 2.0)
	var bg: Color = _board_background(board)
	var sb: PackedStringArray = PackedStringArray()
	sb.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
	sb.append("<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xhtml=\"http://www.w3.org/1999/xhtml\" viewBox=\"%f %f %f %f\" width=\"%f\" height=\"%f\">\n" % [
		origin.x, origin.y, canvas_size.x, canvas_size.y, canvas_size.x, canvas_size.y,
	])
	sb.append("<defs><style><![CDATA[\n")
	sb.append(_item_css())
	sb.append("\n]]></style></defs>\n")
	sb.append("<rect x=\"%f\" y=\"%f\" width=\"%f\" height=\"%f\" fill=\"%s\"/>\n" % [
		origin.x, origin.y, canvas_size.x, canvas_size.y, _color_to_svg(bg),
	])
	sb.append("<g id=\"connections\">\n")
	for cd in connection_dicts:
		sb.append(_svg_connection(cd as Dictionary, item_dicts))
	sb.append("</g>\n")
	sb.append("<g id=\"items\">\n")
	for d in _sort_groups_first(item_dicts):
		sb.append(_svg_item(d as Dictionary, project))
	sb.append("</g>\n")
	sb.append("</svg>\n")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("".join(sb))
	f.close()
	return true


func _items_bounds_dicts(item_dicts: Array) -> Rect2:
	var min_p: Vector2 = Vector2(INF, INF)
	var max_p: Vector2 = Vector2(-INF, -INF)
	for d_v in item_dicts:
		var d: Dictionary = d_v
		var p: Vector2 = _read_v2(d.get("position", [0, 0]))
		var s: Vector2 = _read_v2(d.get("size", [160, 80]))
		min_p.x = min(min_p.x, p.x)
		min_p.y = min(min_p.y, p.y)
		max_p.x = max(max_p.x, p.x + s.x)
		max_p.y = max(max_p.y, p.y + s.y)
	if min_p.x == INF:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return Rect2(min_p, max_p - min_p)


func _read_v2(raw: Variant) -> Vector2:
	if typeof(raw) == TYPE_VECTOR2:
		return raw
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO


func _read_color(raw: Variant, fallback: Color) -> Color:
	return ColorUtil.from_array(raw, fallback)


func _board_background(board: Board) -> Color:
	if board != null and board.has_method("get_background_color"):
		return board.get_background_color()
	return Color(0.077, 0.107, 0.179, 1.0)


func _xml_escape(s: String) -> String:
	return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&apos;")


func _color_to_svg(c: Color) -> String:
	return "rgba(%d,%d,%d,%f)" % [int(c.r * 255.0), int(c.g * 255.0), int(c.b * 255.0), c.a]


func _color_to_css(c: Color) -> String:
	return "rgba(%d,%d,%d,%f)" % [int(c.r * 255.0), int(c.g * 255.0), int(c.b * 255.0), c.a]


# ---------------- connection geometry helpers (dict-based) ----------------


func _item_rect_dict(d: Dictionary) -> Rect2:
	return Rect2(_read_v2(d.get("position", [0, 0])), _read_v2(d.get("size", [160, 80])))


func _item_center_dict(d: Dictionary) -> Vector2:
	var r: Rect2 = _item_rect_dict(d)
	return r.position + r.size * 0.5


func _anchor_world_dict(d: Dictionary, anchor: String) -> Vector2:
	var r: Rect2 = _item_rect_dict(d)
	var p: Vector2 = r.position
	var s: Vector2 = r.size
	match anchor:
		"N":
			return p + Vector2(s.x * 0.5, 0.0)
		"NE":
			return p + Vector2(s.x, 0.0)
		"E":
			return p + Vector2(s.x, s.y * 0.5)
		"SE":
			return p + s
		"S":
			return p + Vector2(s.x * 0.5, s.y)
		"SW":
			return p + Vector2(0.0, s.y)
		"W":
			return p + Vector2(0.0, s.y * 0.5)
		"NW":
			return p
		_:
			return p + s * 0.5


func _intersect_rect_edge(r: Rect2, center: Vector2, target: Vector2) -> Vector2:
	var dir: Vector2 = target - center
	if dir.length_squared() <= 0.0001:
		return center
	var half: Vector2 = r.size * 0.5
	if half.x <= 0.0 or half.y <= 0.0:
		return center
	var sx: float = INF
	if abs(dir.x) > 0.0001:
		sx = half.x / abs(dir.x)
	var sy: float = INF
	if abs(dir.y) > 0.0001:
		sy = half.y / abs(dir.y)
	return center + dir * min(sx, sy)


func _resolve_endpoint_dict(d: Dictionary, anchor: String, target_ref: Vector2) -> Vector2:
	if anchor == "" or anchor == Connection.ANCHOR_AUTO:
		var center: Vector2 = _item_center_dict(d)
		return _intersect_rect_edge(_item_rect_dict(d), center, target_ref)
	return _anchor_world_dict(d, anchor)


func _find_dict_by_id(items: Array, id: String) -> Dictionary:
	for it in items:
		if String((it as Dictionary).get("id", "")) == id:
			return it
	return {}


func _svg_connection(c: Dictionary, items: Array) -> String:
	var from_d: Dictionary = _find_dict_by_id(items, String(c.get("from_item_id", "")))
	var to_d: Dictionary = _find_dict_by_id(items, String(c.get("to_item_id", "")))
	if from_d.is_empty() or to_d.is_empty():
		return ""
	var color: Color = _read_color(c.get("color", null), Connection.DEFAULT_COLOR)
	var thickness: float = float(c.get("thickness", Connection.DEFAULT_THICKNESS))
	var style: String = String(c.get("style", Connection.DEFAULT_STYLE))
	var arrow_end: bool = bool(c.get("arrow_end", Connection.DEFAULT_ARROW_END))
	var arrow_start: bool = bool(c.get("arrow_start", Connection.DEFAULT_ARROW_START))
	var label: String = String(c.get("label", ""))
	var label_size: int = int(c.get("label_font_size", Connection.DEFAULT_LABEL_FONT_SIZE))
	var from_anchor: String = String(c.get("from_anchor", Connection.ANCHOR_AUTO))
	var to_anchor: String = String(c.get("to_anchor", Connection.ANCHOR_AUTO))
	var wps: Array = []
	var wp_raw: Variant = c.get("waypoints", [])
	if typeof(wp_raw) == TYPE_ARRAY:
		for w in (wp_raw as Array):
			if typeof(w) == TYPE_ARRAY and (w as Array).size() >= 2:
				wps.append(Vector2(float(w[0]), float(w[1])))
	var to_ref: Vector2 = _anchor_world_dict(to_d, to_anchor) if to_anchor != Connection.ANCHOR_AUTO else _item_center_dict(to_d)
	var from_ref: Vector2 = _anchor_world_dict(from_d, from_anchor) if from_anchor != Connection.ANCHOR_AUTO else _item_center_dict(from_d)
	var first_target: Vector2 = wps[0] if wps.size() > 0 else to_ref
	var last_target: Vector2 = wps[wps.size() - 1] if wps.size() > 0 else from_ref
	var start_p: Vector2 = _resolve_endpoint_dict(from_d, from_anchor, first_target)
	var end_p: Vector2 = _resolve_endpoint_dict(to_d, to_anchor, last_target)
	var path_d: String = ""
	if wps.size() > 0:
		var pts: PackedVector2Array = PackedVector2Array()
		pts.append(start_p)
		for w in wps:
			pts.append(w)
		pts.append(end_p)
		if style == Connection.STYLE_BEZIER:
			path_d = _svg_smooth_path(pts)
		else:
			path_d = _svg_polyline_path(pts)
	else:
		match style:
			Connection.STYLE_BEZIER:
				path_d = _svg_bezier_pair(start_p, end_p)
			Connection.STYLE_ORTHOGONAL:
				var mx: float = (start_p.x + end_p.x) * 0.5
				path_d = "M %f %f L %f %f L %f %f L %f %f" % [start_p.x, start_p.y, mx, start_p.y, mx, end_p.y, end_p.x, end_p.y]
			_:
				path_d = "M %f %f L %f %f" % [start_p.x, start_p.y, end_p.x, end_p.y]
	var stroke: String = _color_to_svg(color)
	var s: String = "<g class=\"conn\">\n"
	s += "<path d=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"%f\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>\n" % [path_d, stroke, max(1.0, thickness)]
	if arrow_end:
		var prev_pt: Vector2 = _path_tail_prev_point(start_p, end_p, wps, style)
		s += _svg_arrow_polygon(prev_pt, end_p, color, thickness)
	if arrow_start:
		var next_pt: Vector2 = _path_head_next_point(start_p, end_p, wps, style)
		s += _svg_arrow_polygon(next_pt, start_p, color, thickness)
	if label != "":
		var mid: Vector2 = _path_midpoint_simple(start_p, end_p, wps)
		var fs: int = max(8, label_size)
		var safe: String = _xml_escape(label)
		var pad_x: float = 6.0
		var w: float = float(label.length()) * float(fs) * 0.55 + pad_x * 2.0
		var h: float = float(fs) + pad_x * 1.4
		s += "<rect x=\"%f\" y=\"%f\" width=\"%f\" height=\"%f\" fill=\"rgba(16,20,28,0.85)\" stroke=\"%s\" stroke-width=\"1\" rx=\"3\"/>\n" % [
			mid.x - w * 0.5, mid.y - h * 0.5, w, h, stroke,
		]
		s += "<text x=\"%f\" y=\"%f\" fill=\"#f0f4fa\" font-family=\"%s\" font-size=\"%d\" text-anchor=\"middle\" dominant-baseline=\"middle\">%s</text>\n" % [
			mid.x, mid.y, SVG_FONT_FAMILY, fs, safe,
		]
	s += "</g>\n"
	return s


func _svg_polyline_path(pts: PackedVector2Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for i in range(pts.size()):
		parts.append(("M" if i == 0 else "L") + (" %f %f" % [pts[i].x, pts[i].y]))
	return " ".join(parts)


func _svg_smooth_path(pts: PackedVector2Array) -> String:
	if pts.size() < 2:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	parts.append("M %f %f" % [pts[0].x, pts[0].y])
	for i in range(pts.size() - 1):
		var p0: Vector2 = pts[max(0, i - 1)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[min(pts.size() - 1, i + 2)]
		var c1: Vector2 = p1 + (p2 - p0) / 6.0
		var c2: Vector2 = p2 - (p3 - p1) / 6.0
		parts.append("C %f %f, %f %f, %f %f" % [c1.x, c1.y, c2.x, c2.y, p2.x, p2.y])
	return " ".join(parts)


func _svg_bezier_pair(start_p: Vector2, end_p: Vector2) -> String:
	var distance: float = start_p.distance_to(end_p)
	var handle_offset: float = clamp(distance * 0.4, 30.0, 220.0)
	var direction: Vector2 = end_p - start_p
	var horizontal: bool = abs(direction.x) >= abs(direction.y)
	var c1: Vector2
	var c2: Vector2
	if horizontal:
		var sx: float = -1.0 if direction.x < 0.0 else 1.0
		c1 = start_p + Vector2(handle_offset * sx, 0.0)
		c2 = end_p - Vector2(handle_offset * sx, 0.0)
	else:
		var sy: float = -1.0 if direction.y < 0.0 else 1.0
		c1 = start_p + Vector2(0.0, handle_offset * sy)
		c2 = end_p - Vector2(0.0, handle_offset * sy)
	return "M %f %f C %f %f, %f %f, %f %f" % [start_p.x, start_p.y, c1.x, c1.y, c2.x, c2.y, end_p.x, end_p.y]


func _path_tail_prev_point(start_p: Vector2, end_p: Vector2, wps: Array, style: String) -> Vector2:
	if wps.size() > 0:
		return wps[wps.size() - 1]
	if style == Connection.STYLE_ORTHOGONAL:
		var mx: float = (start_p.x + end_p.x) * 0.5
		return Vector2(mx, end_p.y)
	return start_p


func _path_head_next_point(start_p: Vector2, end_p: Vector2, wps: Array, style: String) -> Vector2:
	if wps.size() > 0:
		return wps[0]
	if style == Connection.STYLE_ORTHOGONAL:
		var mx: float = (start_p.x + end_p.x) * 0.5
		return Vector2(mx, start_p.y)
	return end_p


func _path_midpoint_simple(start_p: Vector2, end_p: Vector2, wps: Array) -> Vector2:
	if wps.size() == 0:
		return start_p.lerp(end_p, 0.5)
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(start_p)
	for w in wps:
		pts.append(w)
	pts.append(end_p)
	var total: float = 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	if total <= 0.0:
		return pts[0]
	var target: float = total * 0.5
	var t: float = 0.0
	for i in range(pts.size() - 1):
		var seg: float = pts[i].distance_to(pts[i + 1])
		if t + seg >= target:
			var u: float = 0.0 if seg <= 0.0 else (target - t) / seg
			return pts[i].lerp(pts[i + 1], u)
		t += seg
	return pts[pts.size() - 1]


func _svg_arrow_polygon(prev: Vector2, tip: Vector2, color: Color, thickness: float) -> String:
	var dir: Vector2 = tip - prev
	if dir.length_squared() <= 0.0001:
		return ""
	dir = dir.normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var base: Vector2 = tip - dir * SVG_ARROW_LENGTH
	var left: Vector2 = base + perp * (SVG_ARROW_WIDTH * 0.5)
	var right: Vector2 = base - perp * (SVG_ARROW_WIDTH * 0.5)
	var hex: String = _color_to_svg(color)
	return "<polygon points=\"%f,%f %f,%f %f,%f\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%f\" stroke-linejoin=\"round\"/>\n" % [
		tip.x, tip.y, left.x, left.y, right.x, right.y, hex, hex, max(1.0, thickness * 0.6),
	]


# ---------------- per-item SVG rendering ----------------


func _svg_item(d: Dictionary, project: Project) -> String:
	var pos: Vector2 = _read_v2(d.get("position", [0, 0]))
	var sz: Vector2 = _read_v2(d.get("size", [160, 80]))
	var t: String = String(d.get("type", ""))
	var inner: String = ""
	if t == ItemRegistry.TYPE_PRIMITIVE:
		inner = _svg_primitive_inline(pos, sz, d)
	else:
		var html: String = _item_inner_html(d, project, sz)
		inner = _svg_foreign_object(pos, sz, html)
	var deco: String = ""
	deco += _svg_tags_strip(pos, sz, d.get("tags", []))
	if bool(d.get("locked", false)):
		deco += _svg_lock_badge(pos, sz)
	if _has_link_dict(d):
		deco += _svg_link_badge(pos, sz)
	return "<g class=\"item type-%s\">\n%s%s</g>\n" % [t, inner, deco]


func _has_link_dict(d: Dictionary) -> bool:
	var lt_v: Variant = d.get("link_target", null)
	if typeof(lt_v) != TYPE_DICTIONARY:
		return false
	var lt: Dictionary = lt_v
	return String(lt.get("kind", "")) != "" and String(lt.get("id", "")) != ""


func _svg_foreign_object(pos: Vector2, sz: Vector2, html: String) -> String:
	return "<foreignObject x=\"%f\" y=\"%f\" width=\"%f\" height=\"%f\">\n<div xmlns=\"http://www.w3.org/1999/xhtml\" class=\"bi-host\">%s</div>\n</foreignObject>\n" % [pos.x, pos.y, sz.x, sz.y, html]


func _svg_tags_strip(pos: Vector2, sz: Vector2, tags_raw: Variant) -> String:
	if typeof(tags_raw) != TYPE_ARRAY or (tags_raw as Array).size() == 0:
		return ""
	var s: String = ""
	var tx: float = pos.x + 4.0
	var ty: float = pos.y + sz.y - 6.0
	for tag in (tags_raw as Array):
		var c: Color = Tags.color_for(String(tag))
		s += "<rect x=\"%f\" y=\"%f\" width=\"14\" height=\"4\" fill=\"%s\"/>\n" % [tx, ty, _color_to_svg(c)]
		tx += 16.0
	return s


func _svg_lock_badge(pos: Vector2, sz: Vector2) -> String:
	var cx: float = pos.x + sz.x - 12.0
	var cy: float = pos.y + 12.0
	return "<g class=\"badge-lock\"><circle cx=\"%f\" cy=\"%f\" r=\"8\" fill=\"#7f8087\"/><rect x=\"%f\" y=\"%f\" width=\"8\" height=\"6\" fill=\"#1a1305\"/></g>\n" % [
		cx, cy, cx - 4.0, cy - 1.0,
	]


func _svg_link_badge(pos: Vector2, sz: Vector2) -> String:
	var cx: float = pos.x + sz.x - 12.0
	var cy: float = pos.y + 12.0
	return "<g class=\"badge-link\"><circle cx=\"%f\" cy=\"%f\" r=\"9\" fill=\"#f3c74e\"/><text x=\"%f\" y=\"%f\" font-family=\"%s\" font-size=\"12\" fill=\"#1a1305\" text-anchor=\"middle\" dominant-baseline=\"middle\">↗</text></g>\n" % [
		cx, cy, cx, cy + 1.0, SVG_FONT_FAMILY,
	]


func _svg_primitive_inline(pos: Vector2, sz: Vector2, d: Dictionary) -> String:
	var shape: int = int(d.get("shape", 0))
	var fill_enabled: bool = bool(d.get("fill_enabled", true))
	var fill_color: Color = _read_color(d.get("fill_color", null), Color(0.30, 0.55, 0.85, 1.0))
	var outline_color: Color = _read_color(d.get("outline_color", null), Color(0.05, 0.10, 0.18, 1.0))
	var outline_width: float = float(d.get("outline_width", 2.0))
	var corner_radius: float = float(d.get("corner_radius", 12.0))
	var fx: String = _color_to_svg(fill_color) if fill_enabled else "none"
	var ox: String = _color_to_svg(outline_color)
	var x: float = pos.x
	var y: float = pos.y
	var w: float = sz.x
	var h: float = sz.y
	match shape:
		0:
			return "<rect x=\"%f\" y=\"%f\" width=\"%f\" height=\"%f\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%f\"/>\n" % [x, y, w, h, fx, ox, outline_width]
		1:
			var r: float = clamp(corner_radius, 0.0, min(w, h) * 0.5)
			return "<rect x=\"%f\" y=\"%f\" width=\"%f\" height=\"%f\" rx=\"%f\" ry=\"%f\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%f\"/>\n" % [x, y, w, h, r, r, fx, ox, outline_width]
		2:
			return "<ellipse cx=\"%f\" cy=\"%f\" rx=\"%f\" ry=\"%f\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%f\"/>\n" % [x + w * 0.5, y + h * 0.5, w * 0.5, h * 0.5, fx, ox, outline_width]
		3:
			return "<polygon points=\"%f,%f %f,%f %f,%f\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%f\" stroke-linejoin=\"round\"/>\n" % [
				x + w * 0.5, y, x + w, y + h, x, y + h, fx, ox, outline_width,
			]
		4:
			return "<polygon points=\"%f,%f %f,%f %f,%f %f,%f\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%f\" stroke-linejoin=\"round\"/>\n" % [
				x + w * 0.5, y, x + w, y + h * 0.5, x + w * 0.5, y + h, x, y + h * 0.5, fx, ox, outline_width,
			]
		5:
			return "<line x1=\"%f\" y1=\"%f\" x2=\"%f\" y2=\"%f\" stroke=\"%s\" stroke-width=\"%f\" stroke-linecap=\"round\"/>\n" % [x, y + h, x + w, y, ox, max(1.0, outline_width)]
		6:
			var p1: Vector2 = Vector2(x, y + h)
			var p2: Vector2 = Vector2(x + w, y)
			var arrow: String = _svg_arrow_polygon(p1, p2, outline_color, outline_width)
			return "<line x1=\"%f\" y1=\"%f\" x2=\"%f\" y2=\"%f\" stroke=\"%s\" stroke-width=\"%f\" stroke-linecap=\"round\"/>\n%s" % [p1.x, p1.y, p2.x, p2.y, ox, max(1.0, outline_width), arrow]
	return ""


# ============================================================================
# HTML export
# ============================================================================


func export_html(project: Project, path: String) -> bool:
	if project == null:
		return false
	var boards_data: Array = []
	for entry in project.list_boards():
		var b: Board = project.read_board(String(entry.id))
		if b == null:
			continue
		var bg: Color = b.get_background_color() if b.has_method("get_background_color") else _board_background(b)
		var board_dict: Dictionary = {
			"id": b.id,
			"name": b.name,
			"parent_board_id": b.parent_board_id,
			"bg_color": [bg.r, bg.g, bg.b, bg.a],
			"bounds": _bounds_to_array(_items_bounds_dicts(b.items)),
			"items": _html_items_payload(b.items, project),
			"connections": _html_connections_payload(b.connections),
		}
		boards_data.append(board_dict)
	var data_json: String = JSON.stringify({
		"name": project.name,
		"root_board_id": project.root_board_id,
		"boards": boards_data,
	})
	data_json = data_json.replace("</", "<\\/")
	var sb: PackedStringArray = PackedStringArray()
	sb.append("<!doctype html>\n<html><head><meta charset=\"utf-8\"><title>")
	sb.append(_xml_escape(project.name))
	sb.append("</title><style>\n")
	sb.append(_html_global_css())
	sb.append("\n")
	sb.append(_item_css())
	sb.append("\n</style></head><body>\n")
	sb.append("<aside id=\"sidebar\"><h2 class=\"proj-title\"></h2><div id=\"board-tree\"></div></aside>\n")
	sb.append("<main id=\"main\">\n")
	sb.append("<header id=\"topbar\"><span id=\"crumbs\"></span><span id=\"controls\"><button id=\"zoom-out\">−</button><span id=\"zoom-label\">100%</span><button id=\"zoom-in\">+</button><button id=\"zoom-reset\">Fit</button></span></header>\n")
	sb.append("<div id=\"viewport\"><div id=\"world\"><svg id=\"conn-layer\" xmlns=\"http://www.w3.org/2000/svg\"></svg><div id=\"items-layer\"></div></div></div>\n")
	sb.append("</main>\n")
	sb.append("<script>\nconst PROJECT = ")
	sb.append(data_json)
	sb.append(";\n")
	sb.append(_html_runtime_js())
	sb.append("\n</script></body></html>\n")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("".join(sb))
	f.close()
	return true


func _bounds_to_array(r: Rect2) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]


func _sort_groups_first(item_dicts: Array) -> Array:
	var groups: Array = []
	var others: Array = []
	for d_v in item_dicts:
		var d: Dictionary = d_v
		if String(d.get("type", "")) == ItemRegistry.TYPE_GROUP:
			groups.append(d)
		else:
			others.append(d)
	return groups + others


func _html_items_payload(items: Array, project: Project) -> Array:
	var out: Array = []
	for d_v in _sort_groups_first(items):
		var d: Dictionary = d_v
		var pos: Vector2 = _read_v2(d.get("position", [0, 0]))
		var sz: Vector2 = _read_v2(d.get("size", [160, 80]))
		var entry: Dictionary = {
			"id": String(d.get("id", "")),
			"type": String(d.get("type", "")),
			"x": pos.x,
			"y": pos.y,
			"w": sz.x,
			"h": sz.y,
			"locked": bool(d.get("locked", false)),
			"tags": d.get("tags", []),
			"link_target": d.get("link_target", {}),
			"target_board_id": String(d.get("target_board_id", "")),
		}
		entry["html"] = _item_inner_html(d, project, sz)
		out.append(entry)
	return out


func _html_connections_payload(connections: Array) -> Array:
	var out: Array = []
	for c_v in connections:
		var d: Dictionary = c_v
		var color_arr: Array = ColorUtil.to_array(_read_color(d.get("color", null), Connection.DEFAULT_COLOR))
		out.append({
			"id": String(d.get("id", "")),
			"from_item_id": String(d.get("from_item_id", "")),
			"to_item_id": String(d.get("to_item_id", "")),
			"from_anchor": String(d.get("from_anchor", Connection.ANCHOR_AUTO)),
			"to_anchor": String(d.get("to_anchor", Connection.ANCHOR_AUTO)),
			"color": color_arr,
			"thickness": float(d.get("thickness", Connection.DEFAULT_THICKNESS)),
			"style": String(d.get("style", Connection.DEFAULT_STYLE)),
			"arrow_end": bool(d.get("arrow_end", Connection.DEFAULT_ARROW_END)),
			"arrow_start": bool(d.get("arrow_start", Connection.DEFAULT_ARROW_START)),
			"label": String(d.get("label", "")),
			"label_font_size": int(d.get("label_font_size", Connection.DEFAULT_LABEL_FONT_SIZE)),
			"waypoints": d.get("waypoints", []),
		})
	return out


# ============================================================================
# Shared item inner-HTML rendering (used by SVG foreignObject and HTML export)
# ============================================================================


func _item_inner_html(d: Dictionary, project: Project, sz: Vector2) -> String:
	var t: String = String(d.get("type", ""))
	match t:
		ItemRegistry.TYPE_TEXT:
			return _html_text(d)
		ItemRegistry.TYPE_LABEL:
			return _html_label(d)
		ItemRegistry.TYPE_STICKY:
			return _html_sticky(d)
		ItemRegistry.TYPE_RICH_TEXT:
			return _html_rich(d)
		ItemRegistry.TYPE_GROUP:
			return _html_group(d)
		ItemRegistry.TYPE_URL:
			return _html_url(d)
		ItemRegistry.TYPE_CODE:
			return _html_code(d)
		ItemRegistry.TYPE_TODO_LIST:
			return _html_todo(d)
		ItemRegistry.TYPE_BLOCK_STACK:
			return _html_blocks(d, project)
		ItemRegistry.TYPE_TABLE:
			return _html_table(d)
		ItemRegistry.TYPE_EQUATION:
			return _html_equation(d)
		ItemRegistry.TYPE_TIMER:
			return _html_timer(d)
		ItemRegistry.TYPE_IMAGE:
			return _html_image(d, project, sz)
		ItemRegistry.TYPE_SOUND:
			return _html_sound(d, project)
		ItemRegistry.TYPE_PINBOARD:
			return _html_nav(d, "pinboard")
		ItemRegistry.TYPE_SUBPAGE:
			return _html_nav(d, "subpage")
		ItemRegistry.TYPE_PRIMITIVE:
			return _html_primitive(d)
	return "<div class=\"bi bi-text\">%s</div>" % _xml_escape(t)


func _style_color(prop: String, c: Color) -> String:
	return "%s:%s" % [prop, _color_to_css(c)]


func _html_text(d: Dictionary) -> String:
	var bg: Color = _read_color(d.get("bg_color", null), Color(0.16, 0.17, 0.20, 1.0))
	var fg: Color = _read_color(d.get("fg_color", null), Color(0.95, 0.96, 0.98, 1.0))
	var fs: int = int(d.get("font_size", 18))
	var text: String = String(d.get("text", ""))
	return "<div class=\"bi bi-text\" style=\"background:%s;color:%s;font-size:%dpx\">%s</div>" % [
		_color_to_css(bg), _color_to_css(fg), fs, _xml_escape(text).replace("\n", "<br/>"),
	]


func _html_label(d: Dictionary) -> String:
	var bg: Color = _read_color(d.get("bg_color", null), Color(0, 0, 0, 0))
	var fg: Color = _read_color(d.get("fg_color", null), Color(0.95, 0.96, 0.98, 1.0))
	var fs: int = int(d.get("font_size", 16))
	var bold: bool = bool(d.get("bold", true))
	var italic: bool = bool(d.get("italic", false))
	var weight: String = "700" if bold else "400"
	var style: String = "italic" if italic else "normal"
	var text: String = String(d.get("text", ""))
	return "<div class=\"bi bi-label\" style=\"background:%s;color:%s;font-size:%dpx;font-weight:%s;font-style:%s\">%s</div>" % [
		_color_to_css(bg), _color_to_css(fg), fs, weight, style, _xml_escape(text).replace("\n", "<br/>"),
	]


func _html_sticky(d: Dictionary) -> String:
	var palette: Array = [
		Color(1.00, 0.93, 0.55), Color(1.00, 0.78, 0.55), Color(0.78, 0.93, 0.62),
		Color(0.62, 0.85, 1.00), Color(0.95, 0.70, 0.85), Color(0.85, 0.78, 1.00),
	]
	var idx: int = clampi(int(d.get("color_index", 0)), 0, palette.size() - 1)
	var bg: Color = palette[idx]
	var fs: int = int(d.get("font_size", 16))
	var text: String = String(d.get("text", ""))
	return "<div class=\"bi bi-sticky\" style=\"background:%s;font-size:%dpx\">%s</div>" % [
		_color_to_css(bg), fs, _xml_escape(text).replace("\n", "<br/>"),
	]


func _html_rich(d: Dictionary) -> String:
	var bg: Color = _read_color(d.get("bg_color", null), Color(0.16, 0.17, 0.20, 1.0))
	var fg: Color = _read_color(d.get("fg_color", null), Color(0.95, 0.96, 0.98, 1.0))
	var fs: int = int(d.get("font_size", 16))
	var html_body: String = _bbcode_to_html(String(d.get("bbcode_text", "")))
	return "<div class=\"bi bi-rich\" style=\"background:%s;color:%s;font-size:%dpx\">%s</div>" % [
		_color_to_css(bg), _color_to_css(fg), fs, html_body,
	]


func _html_group(d: Dictionary) -> String:
	var bg: Color = _read_color(d.get("bg_color", null), Color(0.18, 0.20, 0.26, 0.6))
	var tbg: Color = _read_color(d.get("title_bg_color", null), Color(0.30, 0.50, 0.85, 1.0))
	var tfg: Color = _read_color(d.get("title_fg_color", null), Color(1, 1, 1, 1))
	var title: String = String(d.get("title", "Group"))
	return "<div class=\"bi bi-group\" style=\"background:%s\"><div class=\"bi-group-title\" style=\"background:%s;color:%s\">%s</div><div class=\"bi-group-body\"></div></div>" % [
		_color_to_css(bg), _color_to_css(tbg), _color_to_css(tfg), _xml_escape(title),
	]


func _html_url(d: Dictionary) -> String:
	var url: String = String(d.get("url", ""))
	var title: String = String(d.get("title", url))
	var desc: String = String(d.get("description", ""))
	var s: String = "<div class=\"bi bi-url\"><h3>%s</h3><a href=\"%s\" target=\"_blank\" rel=\"noopener\">%s</a>" % [
		_xml_escape(title), _xml_escape(url), _xml_escape(url),
	]
	if desc != "":
		s += "<p>%s</p>" % _xml_escape(desc).replace("\n", "<br/>")
	s += "</div>"
	return s


func _html_code(d: Dictionary) -> String:
	var code: String = String(d.get("code", ""))
	var lang: String = String(d.get("language", "plaintext"))
	var fs: int = int(d.get("font_size", 13))
	return "<div class=\"bi bi-code\"><div class=\"bi-code-head\">%s</div><pre style=\"font-size:%dpx\">%s</pre></div>" % [
		_xml_escape(lang), fs, _xml_escape(code),
	]


func _html_todo(d: Dictionary) -> String:
	var title: String = String(d.get("title", "List"))
	var accent: Color = _read_color(d.get("accent_color", null), Color(0.30, 0.50, 0.85, 1.0))
	var cards_raw: Variant = d.get("cards", [])
	var s: String = "<div class=\"bi bi-todo\"><div class=\"bi-head\" style=\"background:%s\">%s</div><ul class=\"bi-list\">" % [
		_color_to_css(accent), _xml_escape(title),
	]
	if typeof(cards_raw) == TYPE_ARRAY:
		for c_v in (cards_raw as Array):
			var c: Dictionary = c_v
			var done: bool = bool(c.get("completed", false))
			var txt: String = String(c.get("text", ""))
			var mark: String = "☑" if done else "☐"
			var cls: String = "done" if done else ""
			s += "<li class=\"%s\"><span class=\"mk\">%s</span> %s</li>" % [cls, mark, _xml_escape(txt)]
	s += "</ul></div>"
	return s


func _html_blocks(d: Dictionary, project: Project = null) -> String:
	var title: String = String(d.get("title", "Blocks"))
	var accent: Color = _read_color(d.get("accent_color", null), Color(0.30, 0.50, 0.85, 1.0))
	var blocks_raw: Variant = d.get("blocks", [])
	var s: String = "<div class=\"bi bi-blocks\"><div class=\"bi-head\" style=\"background:%s\">%s</div><div class=\"bi-list\">" % [
		_color_to_css(accent), _xml_escape(title),
	]
	if typeof(blocks_raw) == TYPE_ARRAY:
		for b_v in (blocks_raw as Array):
			var b: Dictionary = b_v
			var txt: String = String(b.get("text", ""))
			var indent: int = clampi(int(b.get("indent_level", 0)), 0, 6)
			var pad_left: int = indent * 18
			var img_html: String = ""
			var img_path: String = _resolve_block_image_path(b, project)
			if img_path != "":
				var data_uri: String = _file_to_data_uri(img_path)
				if data_uri != "":
					img_html = "<img class=\"bi-block-img\" src=\"%s\" alt=\"\"/>" % data_uri
			var link_attr: String = ""
			var lt_v: Variant = b.get("link_target", null)
			if typeof(lt_v) == TYPE_DICTIONARY:
				var lt: Dictionary = lt_v
				if String(lt.get("kind", "")) != "" and String(lt.get("id", "")) != "":
					link_attr = " data-link-kind=\"%s\" data-link-id=\"%s\"" % [_xml_escape(String(lt.get("kind",""))), _xml_escape(String(lt.get("id","")))]
			s += "<div class=\"bi-block\" style=\"margin-left:%dpx\"%s>%s%s</div>" % [
				pad_left, link_attr, img_html, _xml_escape(txt).replace("\n", "<br/>"),
			]
	s += "</div></div>"
	return s


func _html_table(d: Dictionary) -> String:
	var rows: int = int(d.get("rows", 0))
	var cols: int = int(d.get("cols", 0))
	var cells_raw: Variant = d.get("cells", [])
	var s: String = "<div class=\"bi bi-table\"><table>"
	if typeof(cells_raw) == TYPE_ARRAY:
		var arr: Array = cells_raw
		for r in range(min(rows, arr.size())):
			var row_v: Variant = arr[r]
			if typeof(row_v) != TYPE_ARRAY:
				continue
			var row: Array = row_v
			s += "<tr>"
			for c in range(cols):
				var cell: String = String(row[c]) if c < row.size() else ""
				if r == 0:
					s += "<th>%s</th>" % _xml_escape(cell)
				else:
					s += "<td>%s</td>" % _xml_escape(cell).replace("\n", "<br/>")
			s += "</tr>"
	s += "</table></div>"
	return s


func _html_equation(d: Dictionary) -> String:
	var latex: String = String(d.get("latex", ""))
	var fs: int = int(d.get("font_size", 22))
	return "<div class=\"bi bi-eq\" style=\"font-size:%dpx\">%s</div>" % [fs, _xml_escape(latex)]


func _html_timer(d: Dictionary) -> String:
	var label: String = String(d.get("label_text", "Timer"))
	var mode: String = String(d.get("mode", "duration"))
	var time: String
	var caption: String = ""
	if mode == "target":
		var target_unix: int = int(d.get("target_unix", 0))
		if target_unix > 0:
			caption = Time.get_datetime_string_from_unix_time(target_unix, true)
			var delta: int = target_unix - int(Time.get_unix_time_from_system())
			time = TimerRegistry.format_duration(float(max(0, delta)), false)
		else:
			time = TimerRegistry.format_duration(0.0, false)
	else:
		time = TimerRegistry.format_duration(float(d.get("initial_duration_sec", 0.0)), false)
	var caption_html: String = ""
	if caption != "":
		caption_html = "<div class=\"sub\">→ %s</div>" % _xml_escape(caption)
	return "<div class=\"bi bi-timer\"><div class=\"lbl\">%s</div><div class=\"val\">%s</div>%s</div>" % [
		_xml_escape(label), time, caption_html,
	]


func _html_image(d: Dictionary, project: Project, _sz: Vector2) -> String:
	var resolved: String = _resolve_image_path(d, project)
	var data_uri: String = ""
	if resolved != "":
		data_uri = _file_to_data_uri(resolved)
	if data_uri == "":
		var alt: String = String(d.get("source_path", ""))
		var label: String = alt.get_file() if alt != "" else "image"
		return "<div class=\"bi bi-image\"><div class=\"ph\">🖼  %s</div></div>" % _xml_escape(label)
	return "<div class=\"bi bi-image\"><img src=\"%s\" alt=\"\"/></div>" % data_uri


func _html_sound(d: Dictionary, project: Project) -> String:
	var label: String = String(d.get("display_label", "Audio"))
	if label == "":
		label = String(d.get("source_path", "Audio")).get_file()
	var resolved: String = _resolve_sound_path(d, project)
	var data_uri: String = _file_to_data_uri(resolved) if resolved != "" else ""
	var s: String = "<div class=\"bi bi-sound\"><span class=\"ic\">🔊</span><div class=\"snd-body\"><div class=\"lbl\">%s</div>" % _xml_escape(label)
	if data_uri != "":
		s += "<audio controls preload=\"none\" src=\"%s\"></audio>" % data_uri
	s += "</div></div>"
	return s


func _html_nav(d: Dictionary, kind: String) -> String:
	var title: String = String(d.get("title", kind.capitalize()))
	var icon: String = "📌" if kind == "pinboard" else "📄"
	var target: String = String(d.get("target_board_id", ""))
	return "<div class=\"bi bi-nav\" data-target-board=\"%s\"><h3><span class=\"ic\">%s</span> %s</h3><div class=\"sub\">Open board →</div></div>" % [
		_xml_escape(target), icon, _xml_escape(title),
	]


func _html_primitive(d: Dictionary) -> String:
	var shape: int = int(d.get("shape", 0))
	var fill_enabled: bool = bool(d.get("fill_enabled", true))
	var fill_color: Color = _read_color(d.get("fill_color", null), Color(0.30, 0.55, 0.85, 1.0))
	var outline_color: Color = _read_color(d.get("outline_color", null), Color(0.05, 0.10, 0.18, 1.0))
	var outline_width: float = float(d.get("outline_width", 2.0))
	var corner_radius: float = float(d.get("corner_radius", 12.0))
	var fx: String = _color_to_css(fill_color) if fill_enabled else "none"
	var ox: String = _color_to_css(outline_color)
	var inner: String = ""
	match shape:
		0:
			inner = "<rect x=\"%f\" y=\"%f\" width=\"calc(100%% - %f)\" height=\"calc(100%% - %f)\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%f\"/>" % [
				outline_width * 0.5, outline_width * 0.5, outline_width, outline_width, fx, ox, outline_width,
			]
		1:
			inner = "<rect x=\"%f\" y=\"%f\" width=\"calc(100%% - %f)\" height=\"calc(100%% - %f)\" rx=\"%f\" ry=\"%f\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%f\"/>" % [
				outline_width * 0.5, outline_width * 0.5, outline_width, outline_width, corner_radius, corner_radius, fx, ox, outline_width,
			]
		2:
			inner = "<ellipse cx=\"50%%\" cy=\"50%%\" rx=\"calc(50%% - %f)\" ry=\"calc(50%% - %f)\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%f\"/>" % [
				outline_width * 0.5, outline_width * 0.5, fx, ox, outline_width,
			]
		3:
			inner = "<polygon points=\"50,0 100,100 0,100\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%f\" stroke-linejoin=\"round\" vector-effect=\"non-scaling-stroke\"/>" % [fx, ox, outline_width]
		4:
			inner = "<polygon points=\"50,0 100,50 50,100 0,50\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%f\" stroke-linejoin=\"round\" vector-effect=\"non-scaling-stroke\"/>" % [fx, ox, outline_width]
		5:
			inner = "<line x1=\"0\" y1=\"100\" x2=\"100\" y2=\"0\" stroke=\"%s\" stroke-width=\"%f\" stroke-linecap=\"round\" vector-effect=\"non-scaling-stroke\"/>" % [ox, outline_width]
		6:
			inner = "<line x1=\"4\" y1=\"96\" x2=\"96\" y2=\"4\" stroke=\"%s\" stroke-width=\"%f\" stroke-linecap=\"round\" vector-effect=\"non-scaling-stroke\"/><polygon points=\"96,4 86,4 96,14\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%f\" stroke-linejoin=\"round\" vector-effect=\"non-scaling-stroke\"/>" % [
				ox, outline_width, ox, ox, outline_width,
			]
	var preserve: String = "none" if shape <= 2 else "none"
	return "<svg class=\"bi bi-prim\" preserveAspectRatio=\"%s\" viewBox=\"0 0 100 100\" xmlns=\"http://www.w3.org/2000/svg\">%s</svg>" % [preserve, inner]


func _bbcode_to_html(bb: String) -> String:
	var s: String = _xml_escape(bb)
	var re: RegEx = RegEx.new()
	re.compile("\\[color=([^\\]]+)\\]")
	s = re.sub(s, "<span style=\"color:$1\">", true)
	s = s.replace("[/color]", "</span>")
	re.compile("\\[font_size=(\\d+)\\]")
	s = re.sub(s, "<span style=\"font-size:$1px\">", true)
	s = s.replace("[/font_size]", "</span>")
	re.compile("\\[bgcolor=([^\\]]+)\\]")
	s = re.sub(s, "<span style=\"background:$1\">", true)
	s = s.replace("[/bgcolor]", "</span>")
	re.compile("\\[font=([^\\]]+)\\]")
	s = re.sub(s, "<span style=\"font-family:$1\">", true)
	s = s.replace("[/font]", "</span>")
	re.compile("\\[url=([^\\]]+)\\]([^\\[]*)\\[/url\\]")
	s = re.sub(s, "<a href=\"$1\" target=\"_blank\" rel=\"noopener\">$2</a>", true)
	re.compile("\\[url\\]([^\\[]+)\\[/url\\]")
	s = re.sub(s, "<a href=\"$1\" target=\"_blank\" rel=\"noopener\">$1</a>", true)
	re.compile("\\[img\\]([^\\[]+)\\[/img\\]")
	s = re.sub(s, "<img src=\"$1\" style=\"max-width:100%;height:auto\"/>", true)
	re.compile("\\[center\\]([\\s\\S]*?)\\[/center\\]")
	s = re.sub(s, "<div style=\"text-align:center\">$1</div>", true)
	re.compile("\\[right\\]([\\s\\S]*?)\\[/right\\]")
	s = re.sub(s, "<div style=\"text-align:right\">$1</div>", true)
	s = s.replace("[b]", "<b>").replace("[/b]", "</b>")
	s = s.replace("[i]", "<i>").replace("[/i]", "</i>")
	s = s.replace("[u]", "<u>").replace("[/u]", "</u>")
	s = s.replace("[s]", "<s>").replace("[/s]", "</s>")
	s = s.replace("[code]", "<code>").replace("[/code]", "</code>")
	s = s.replace("\n", "<br/>")
	return s


# ---------------- asset resolution ----------------


func _resolve_image_path(d: Dictionary, project: Project) -> String:
	var mode: int = int(d.get("source_mode", 0))
	if mode == 1:
		var asset_name: String = String(d.get("asset_name", ""))
		if asset_name == "" or project == null:
			return ""
		var p: String = project.resolve_asset_path(asset_name)
		return p if FileAccess.file_exists(p) else ""
	var sp: String = String(d.get("source_path", ""))
	return sp if sp != "" and FileAccess.file_exists(sp) else ""


func _resolve_sound_path(d: Dictionary, project: Project) -> String:
	return _resolve_image_path(d, project)


func _resolve_block_image_path(b: Dictionary, project: Project) -> String:
	var asset_name: String = String(b.get("asset_name", ""))
	if asset_name != "" and project != null:
		var p: String = project.resolve_asset_path(asset_name)
		if FileAccess.file_exists(p):
			return p
	var sp: String = String(b.get("source_path", ""))
	if sp != "" and FileAccess.file_exists(sp):
		return sp
	return ""


func _file_to_data_uri(absolute_path: String) -> String:
	if absolute_path == "":
		return ""
	var f: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
	if f == null:
		return ""
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	if bytes.size() == 0:
		return ""
	var mime: String = _mime_for_extension(absolute_path.get_extension().to_lower())
	var b64: String = Marshalls.raw_to_base64(bytes)
	return "data:%s;base64,%s" % [mime, b64]


func _mime_for_extension(ext: String) -> String:
	match ext:
		"png":
			return "image/png"
		"jpg", "jpeg":
			return "image/jpeg"
		"gif":
			return "image/gif"
		"webp":
			return "image/webp"
		"svg":
			return "image/svg+xml"
		"bmp":
			return "image/bmp"
		"ico":
			return "image/x-icon"
		"avif":
			return "image/avif"
		"mp3":
			return "audio/mpeg"
		"wav":
			return "audio/wav"
		"ogg":
			return "audio/ogg"
		"m4a":
			return "audio/mp4"
		"flac":
			return "audio/flac"
		"opus":
			return "audio/opus"
	return "application/octet-stream"


# ---------------- shared CSS ----------------


func _item_css() -> String:
	return """
.bi-host { width:100%; height:100%; box-sizing:border-box; position:relative; font-family:Inter,system-ui,-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; color:#f0f4fa; }
.bi { box-sizing:border-box; width:100%; height:100%; overflow:hidden; border-radius:6px; }
.bi-text { padding:10px 12px; background:#272a31; border:1px solid #3a3f48; white-space:pre-wrap; word-break:break-word; line-height:1.35; }
.bi-label { padding:8px 10px; line-height:1.25; }
.bi-sticky { padding:14px; box-shadow:0 4px 10px rgba(0,0,0,0.35); white-space:pre-wrap; word-break:break-word; color:#1a1a1a; line-height:1.35; }
.bi-rich { padding:10px 12px; background:#272a31; border:1px solid #3a3f48; word-break:break-word; line-height:1.4; }
.bi-rich code { background:#1a1c20; padding:0 4px; border-radius:3px; font-family:Consolas,'Courier New',monospace; }
.bi-code { display:flex; flex-direction:column; background:#1b1d22; border:1px solid #2a2e36; }
.bi-code-head { background:#101216; padding:4px 10px; font-size:11px; color:#9aa3b0; font-family:Consolas,monospace; border-bottom:1px solid #2a2e36; flex-shrink:0; }
.bi-code pre { margin:0; padding:8px 10px; font-family:Consolas,'Courier New',monospace; white-space:pre; overflow:auto; flex:1; color:#e6edf3; }
.bi-url { padding:10px 12px; background:#1e2735; border:1px solid #3a6c9a; }
.bi-url a { color:#9ecbff; text-decoration:none; word-break:break-all; }
.bi-url a:hover { text-decoration:underline; }
.bi-url h3 { margin:0 0 4px 0; font-size:14px; color:#e9eef6; }
.bi-url p { margin:6px 0 0 0; font-size:12px; color:#9aa3b0; word-break:break-word; }
.bi-todo, .bi-blocks { display:flex; flex-direction:column; background:#22252c; border:1px solid #3a3f48; }
.bi-head { padding:6px 10px; font-weight:600; font-size:13px; color:#fff; flex-shrink:0; }
.bi-list { padding:6px 10px; font-size:12px; overflow:auto; flex:1; margin:0; }
.bi-todo .bi-list li { list-style:none; padding:3px 0; line-height:1.35; }
.bi-todo .bi-list .mk { color:#9ecbff; margin-right:6px; }
.bi-todo .bi-list li.done { color:#9aa3b0; text-decoration:line-through; }
.bi-blocks .bi-block { padding:4px 6px; margin:2px 0; background:#2a2e36; border-radius:3px; display:flex; align-items:flex-start; gap:6px; }
.bi-blocks .bi-block .bi-block-img { max-height:48px; max-width:64px; object-fit:contain; border-radius:3px; flex-shrink:0; }
.bi-table { display:flex; padding:0; background:#22252c; border:1px solid #3a3f48; overflow:auto; }
.bi-table table { border-collapse:collapse; width:100%; }
.bi-table th, .bi-table td { border:1px solid #3a3f48; padding:4px 6px; font-size:12px; text-align:left; vertical-align:top; }
.bi-table thead th, .bi-table tr:first-child th { background:#2a2e36; }
.bi-eq { display:flex; align-items:center; justify-content:center; padding:8px; background:#22252c; border:1px solid #3a3f48; font-family:'Cambria Math','Latin Modern Math',Cambria,'Times New Roman',serif; font-style:italic; text-align:center; }
.bi-timer { display:flex; flex-direction:column; align-items:center; justify-content:center; gap:4px; padding:6px; background:#22252c; border:1px solid #3a3f48; }
.bi-timer .lbl { font-size:12px; color:#9aa3b0; }
.bi-timer .val { font-size:24px; font-family:Consolas,monospace; color:#e9eef6; letter-spacing:2px; }
.bi-timer .sub { font-size:11px; color:#7a818d; }
.bi-image { padding:0; background:#1a1c20; border:1px solid #3a3f48; display:flex; }
.bi-image img { width:100%; height:100%; object-fit:contain; display:block; }
.bi-image .ph { display:flex; height:100%; width:100%; align-items:center; justify-content:center; color:#7a818d; font-size:12px; }
.bi-sound { display:flex; align-items:center; gap:10px; padding:10px 12px; background:#22252c; border:1px solid #3a3f48; }
.bi-sound .ic { font-size:22px; }
.bi-sound .snd-body { display:flex; flex-direction:column; gap:4px; flex:1; min-width:0; }
.bi-sound .lbl { font-size:13px; color:#e9eef6; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.bi-sound audio { width:100%; height:28px; }
.bi-nav { padding:10px 12px; background:#1e2a38; border:1px solid #4a6b91; cursor:pointer; transition:background 0.15s; }
.bi-nav:hover { background:#26354a; }
.bi-nav h3 { margin:0; font-size:14px; }
.bi-nav .sub { font-size:11px; color:#9aa3b0; margin-top:4px; }
.bi-nav .ic { margin-right:6px; }
.bi-group { display:flex; flex-direction:column; border-radius:6px; overflow:hidden; }
.bi-group-title { padding:6px 10px; font-weight:600; font-size:13px; }
.bi-group-body { flex:1; }
.bi-prim { display:block; width:100%; height:100%; }
"""


func _html_global_css() -> String:
	return """
:root { --bg:#15171b; --fg:#e9ecef; --panel:#1d2026; --border:#2a2e36; --accent:#3a6c9a; }
* { box-sizing:border-box; }
html, body { margin:0; padding:0; height:100%; overflow:hidden; background:var(--bg); color:var(--fg); font-family:Inter,system-ui,-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; }
body { display:flex; }
#sidebar { width:260px; flex-shrink:0; background:var(--panel); border-right:1px solid var(--border); overflow:auto; padding:12px; }
#sidebar h2 { margin:0 0 10px 0; font-size:15px; color:#fff; }
#board-tree .b { padding:5px 8px; cursor:pointer; border-radius:4px; font-size:13px; line-height:1.35; }
#board-tree .b:hover { background:#262a31; }
#board-tree .b.active { background:var(--accent); color:#fff; }
#main { flex:1; display:flex; flex-direction:column; min-width:0; }
#topbar { display:flex; justify-content:space-between; align-items:center; gap:12px; padding:8px 12px; background:var(--panel); border-bottom:1px solid var(--border); flex-shrink:0; }
#crumbs { font-size:13px; color:#9aa3b0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
#crumbs .crumb { color:#cdd5df; cursor:pointer; }
#crumbs .crumb:hover { text-decoration:underline; }
#crumbs .sep { margin:0 6px; color:#5a6270; }
#controls { display:flex; gap:6px; align-items:center; }
#controls button { background:#252932; color:var(--fg); border:1px solid var(--border); border-radius:4px; padding:4px 10px; cursor:pointer; font-size:13px; }
#controls button:hover { background:#2c313b; }
#zoom-label { font-size:12px; color:#9aa3b0; min-width:48px; text-align:center; }
#viewport { flex:1; overflow:auto; position:relative; background-image:linear-gradient(rgba(255,255,255,0.04) 1px, transparent 1px),linear-gradient(90deg, rgba(255,255,255,0.04) 1px, transparent 1px); background-size:24px 24px; }
#world { position:relative; transform-origin:0 0; }
#conn-layer { position:absolute; top:0; left:0; pointer-events:none; overflow:visible; }
#conn-layer .conn-hit { stroke:transparent; stroke-width:14px; fill:none; pointer-events:stroke; cursor:pointer; }
#conn-layer .conn-stroke { fill:none; pointer-events:none; }
#conn-layer text { font-family:Inter,system-ui,sans-serif; }
#items-layer { position:absolute; top:0; left:0; }
.item-host { position:absolute; }
.item-host.has-link { cursor:pointer; }
.item-tags { position:absolute; left:4px; bottom:3px; display:flex; gap:2px; pointer-events:none; }
.item-tag { width:14px; height:4px; border-radius:1px; }
.item-locked { position:absolute; right:6px; top:6px; width:16px; height:16px; background:#7f8087; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:11px; color:#1a1305; }
.item-link { position:absolute; right:6px; top:6px; width:18px; height:18px; background:#f3c74e; border-radius:50%; color:#1a1305; font-size:12px; display:flex; align-items:center; justify-content:center; cursor:pointer; }
"""


func _html_runtime_js() -> String:
	return """
(function(){
const $ = (sel, root) => (root||document).querySelector(sel);
const tree = $('#board-tree');
const sb = $('#sidebar h2.proj-title');
const crumbs = $('#crumbs');
const world = $('#world');
const conn = $('#conn-layer');
const items = $('#items-layer');
const viewport = $('#viewport');
let activeBoardId = PROJECT.root_board_id;
let scale = 1.0;
let history = [];

document.title = PROJECT.name || 'Mind map';
sb.textContent = PROJECT.name || '';

function buildTree() {
  const map = {};
  PROJECT.boards.forEach(b => map[b.id] = Object.assign({}, b, {kids:[]}));
  const roots = [];
  Object.values(map).forEach(b => {
    if (b.parent_board_id && map[b.parent_board_id]) map[b.parent_board_id].kids.push(b);
    else roots.push(b);
  });
  tree.innerHTML = '';
  function emit(b, depth) {
    const div = document.createElement('div');
    div.className = 'b' + (b.id === activeBoardId ? ' active' : '');
    div.style.paddingLeft = (8 + depth*12) + 'px';
    div.textContent = b.name || '(unnamed)';
    div.onclick = () => navigate(b.id, true);
    tree.appendChild(div);
    b.kids.forEach(k => emit(k, depth+1));
  }
  if (roots.length === 0) PROJECT.boards.forEach(b => emit(map[b.id], 0));
  else roots.forEach(r => emit(r, 0));
}

function findBoard(id) { return PROJECT.boards.find(b => b.id === id); }
function rgba(arr) { if(!arr || !arr.length) return 'transparent'; const r=Math.round((arr[0]||0)*255), g=Math.round((arr[1]||0)*255), b=Math.round((arr[2]||0)*255), a=(arr.length<4?1:arr[3]); return `rgba(${r},${g},${b},${a})`; }

function center(it) { return { x: it.x + it.w*0.5, y: it.y + it.h*0.5 }; }
function anchorPos(it, anchor) {
  switch(anchor) {
    case 'N': return { x: it.x + it.w*0.5, y: it.y };
    case 'NE': return { x: it.x + it.w, y: it.y };
    case 'E': return { x: it.x + it.w, y: it.y + it.h*0.5 };
    case 'SE': return { x: it.x + it.w, y: it.y + it.h };
    case 'S': return { x: it.x + it.w*0.5, y: it.y + it.h };
    case 'SW': return { x: it.x, y: it.y + it.h };
    case 'W': return { x: it.x, y: it.y + it.h*0.5 };
    case 'NW': return { x: it.x, y: it.y };
  }
  return center(it);
}
function intersectRect(it, target) {
  const c = center(it);
  const dx = target.x - c.x, dy = target.y - c.y;
  if (dx*dx + dy*dy < 0.0001) return c;
  const hx = it.w*0.5, hy = it.h*0.5;
  if (hx <= 0 || hy <= 0) return c;
  let sx = Infinity, sy = Infinity;
  if (Math.abs(dx) > 0.0001) sx = hx / Math.abs(dx);
  if (Math.abs(dy) > 0.0001) sy = hy / Math.abs(dy);
  const s = Math.min(sx, sy);
  return { x: c.x + dx*s, y: c.y + dy*s };
}
function resolveEndpoint(it, anchor, target) {
  if (!anchor || anchor === 'auto') return intersectRect(it, target);
  return anchorPos(it, anchor);
}

function bezierPair(a, b) {
  const dx = b.x - a.x, dy = b.y - a.y;
  const dist = Math.sqrt(dx*dx + dy*dy);
  const off = Math.max(30, Math.min(220, dist*0.4));
  const horiz = Math.abs(dx) >= Math.abs(dy);
  let c1, c2;
  if (horiz) {
    const sx = dx < 0 ? -1 : 1;
    c1 = { x: a.x + off*sx, y: a.y };
    c2 = { x: b.x - off*sx, y: b.y };
  } else {
    const sy = dy < 0 ? -1 : 1;
    c1 = { x: a.x, y: a.y + off*sy };
    c2 = { x: b.x, y: b.y - off*sy };
  }
  return `M ${a.x} ${a.y} C ${c1.x} ${c1.y}, ${c2.x} ${c2.y}, ${b.x} ${b.y}`;
}
function smoothPath(pts) {
  if (pts.length < 2) return '';
  let s = `M ${pts[0].x} ${pts[0].y}`;
  for (let i = 0; i < pts.length-1; i++) {
    const p0 = pts[Math.max(0, i-1)];
    const p1 = pts[i];
    const p2 = pts[i+1];
    const p3 = pts[Math.min(pts.length-1, i+2)];
    const c1 = { x: p1.x + (p2.x - p0.x)/6, y: p1.y + (p2.y - p0.y)/6 };
    const c2 = { x: p2.x - (p3.x - p1.x)/6, y: p2.y - (p3.y - p1.y)/6 };
    s += ` C ${c1.x} ${c1.y}, ${c2.x} ${c2.y}, ${p2.x} ${p2.y}`;
  }
  return s;
}
function polyD(pts) { return pts.map((p,i) => (i===0?'M':'L') + ` ${p.x} ${p.y}`).join(' '); }
function pathMid(pts) {
  if (pts.length < 2) return pts[0] || {x:0,y:0};
  let total = 0;
  for (let i=0;i<pts.length-1;i++) total += Math.hypot(pts[i+1].x-pts[i].x, pts[i+1].y-pts[i].y);
  if (total <= 0) return pts[0];
  const target = total*0.5;
  let t = 0;
  for (let i=0;i<pts.length-1;i++) {
    const seg = Math.hypot(pts[i+1].x-pts[i].x, pts[i+1].y-pts[i].y);
    if (t+seg >= target) {
      const u = seg <= 0 ? 0 : (target-t)/seg;
      return { x: pts[i].x + (pts[i+1].x-pts[i].x)*u, y: pts[i].y + (pts[i+1].y-pts[i].y)*u };
    }
    t += seg;
  }
  return pts[pts.length-1];
}
function arrowPolygon(prev, tip) {
  const dx = tip.x - prev.x, dy = tip.y - prev.y;
  const len = Math.hypot(dx, dy);
  if (len <= 0.0001) return null;
  const ux = dx/len, uy = dy/len;
  const px = -uy, py = ux;
  const baseX = tip.x - ux*12, baseY = tip.y - uy*12;
  const lx = baseX + px*4, ly = baseY + py*4;
  const rx = baseX - px*4, ry = baseY - py*4;
  return `${tip.x},${tip.y} ${lx},${ly} ${rx},${ry}`;
}

function renderBoard(boardId) {
  const b = findBoard(boardId);
  if (!b) return;
  activeBoardId = boardId;
  document.body.style.background = rgba(b.bg_color);
  viewport.style.background = rgba(b.bg_color);
  const itemMap = {};
  b.items.forEach(it => itemMap[it.id] = it);
  // bounds
  let minx=Infinity,miny=Infinity,maxx=-Infinity,maxy=-Infinity;
  b.items.forEach(it => { minx=Math.min(minx,it.x); miny=Math.min(miny,it.y); maxx=Math.max(maxx,it.x+it.w); maxy=Math.max(maxy,it.y+it.h); });
  if (!isFinite(minx)) { minx=0; miny=0; maxx=800; maxy=600; }
  const pad = 80;
  const ox = minx - pad, oy = miny - pad;
  const ww = (maxx - minx) + pad*2;
  const wh = (maxy - miny) + pad*2;
  world.style.width = ww + 'px';
  world.style.height = wh + 'px';
  conn.setAttribute('width', ww);
  conn.setAttribute('height', wh);
  conn.setAttribute('viewBox', `0 0 ${ww} ${wh}`);
  conn.innerHTML = '';
  items.innerHTML = '';
  // connections
  (b.connections || []).forEach(c => {
    const a = itemMap[c.from_item_id];
    const z = itemMap[c.to_item_id];
    if (!a || !z) return;
    const aLocal = { x: a.x - ox, y: a.y - oy, w: a.w, h: a.h };
    const zLocal = { x: z.x - ox, y: z.y - oy, w: z.w, h: z.h };
    const wps = (c.waypoints || []).map(w => ({ x: (w[0]||0) - ox, y: (w[1]||0) - oy }));
    const toRef = c.to_anchor && c.to_anchor !== 'auto' ? anchorPos(zLocal, c.to_anchor) : center(zLocal);
    const fromRef = c.from_anchor && c.from_anchor !== 'auto' ? anchorPos(aLocal, c.from_anchor) : center(aLocal);
    const firstTarget = wps.length ? wps[0] : toRef;
    const lastTarget = wps.length ? wps[wps.length-1] : fromRef;
    const start = resolveEndpoint(aLocal, c.from_anchor, firstTarget);
    const end = resolveEndpoint(zLocal, c.to_anchor, lastTarget);
    let d;
    let pts = [start, ...wps, end];
    if (wps.length > 0) {
      d = c.style === 'bezier' ? smoothPath(pts) : polyD(pts);
    } else if (c.style === 'bezier') {
      d = bezierPair(start, end);
    } else if (c.style === 'orthogonal') {
      const mx = (start.x + end.x) * 0.5;
      d = `M ${start.x} ${start.y} L ${mx} ${start.y} L ${mx} ${end.y} L ${end.x} ${end.y}`;
    } else {
      d = `M ${start.x} ${start.y} L ${end.x} ${end.y}`;
    }
    const color = rgba(c.color);
    const ns = 'http://www.w3.org/2000/svg';
    const g = document.createElementNS(ns, 'g');
    g.setAttribute('class', 'conn');
    const path = document.createElementNS(ns, 'path');
    path.setAttribute('d', d);
    path.setAttribute('class', 'conn-stroke');
    path.setAttribute('stroke', color);
    path.setAttribute('stroke-width', String(Math.max(1, c.thickness || 2)));
    path.setAttribute('stroke-linecap', 'round');
    path.setAttribute('stroke-linejoin', 'round');
    g.appendChild(path);
    if (c.arrow_end) {
      let prev;
      if (wps.length > 0) prev = wps[wps.length-1];
      else if (c.style === 'orthogonal') prev = { x: (start.x+end.x)*0.5, y: end.y };
      else prev = start;
      const poly = arrowPolygon(prev, end);
      if (poly) {
        const p = document.createElementNS(ns, 'polygon');
        p.setAttribute('points', poly);
        p.setAttribute('fill', color);
        p.setAttribute('stroke', color);
        p.setAttribute('stroke-linejoin', 'round');
        g.appendChild(p);
      }
    }
    if (c.arrow_start) {
      let nxt;
      if (wps.length > 0) nxt = wps[0];
      else if (c.style === 'orthogonal') nxt = { x: (start.x+end.x)*0.5, y: start.y };
      else nxt = end;
      const poly = arrowPolygon(nxt, start);
      if (poly) {
        const p = document.createElementNS(ns, 'polygon');
        p.setAttribute('points', poly);
        p.setAttribute('fill', color);
        p.setAttribute('stroke', color);
        p.setAttribute('stroke-linejoin', 'round');
        g.appendChild(p);
      }
    }
    if (c.label) {
      const mid = pathMid(pts);
      const fs = Math.max(8, c.label_font_size || 12);
      const w = c.label.length * fs * 0.55 + 12;
      const h = fs + 8;
      const r = document.createElementNS(ns, 'rect');
      r.setAttribute('x', mid.x - w*0.5); r.setAttribute('y', mid.y - h*0.5);
      r.setAttribute('width', w); r.setAttribute('height', h);
      r.setAttribute('fill', 'rgba(16,20,28,0.85)'); r.setAttribute('stroke', color); r.setAttribute('rx', '3');
      g.appendChild(r);
      const t = document.createElementNS(ns, 'text');
      t.setAttribute('x', mid.x); t.setAttribute('y', mid.y);
      t.setAttribute('fill', '#f0f4fa'); t.setAttribute('font-size', String(fs));
      t.setAttribute('text-anchor', 'middle'); t.setAttribute('dominant-baseline', 'middle');
      t.textContent = c.label;
      g.appendChild(t);
    }
    conn.appendChild(g);
  });
  // items
  b.items.forEach(it => {
    const host = document.createElement('div');
    host.className = 'item-host type-' + it.type + (it.target_board_id || (it.link_target && it.link_target.kind) ? ' has-link' : '');
    host.style.left = (it.x - ox) + 'px';
    host.style.top = (it.y - oy) + 'px';
    host.style.width = it.w + 'px';
    host.style.height = it.h + 'px';
    host.innerHTML = it.html;
    if (it.target_board_id && (it.type === 'pinboard' || it.type === 'subpage')) {
      host.style.cursor = 'pointer';
      host.addEventListener('click', e => { e.stopPropagation(); navigate(it.target_board_id, true); });
    } else if (it.link_target && it.link_target.kind === 'board' && it.link_target.id) {
      const linkId = it.link_target.id;
      const badge = document.createElement('div');
      badge.className = 'item-link';
      badge.textContent = '↗';
      badge.title = 'Open linked board';
      badge.onclick = e => { e.stopPropagation(); navigate(linkId, true); };
      host.appendChild(badge);
    }
    if (it.tags && it.tags.length) {
      const tagWrap = document.createElement('div');
      tagWrap.className = 'item-tags';
      const palette = ['#e06c75','#e5c07b','#98c379','#56b6c2','#61afef','#c678dd','#d19a66'];
      it.tags.forEach((tag, idx) => {
        const dot = document.createElement('div');
        dot.className = 'item-tag';
        dot.style.background = palette[Math.abs(hashStr(String(tag))) % palette.length];
        dot.title = String(tag);
        tagWrap.appendChild(dot);
      });
      host.appendChild(tagWrap);
    }
    if (it.locked) {
      const lk = document.createElement('div');
      lk.className = 'item-locked';
      lk.textContent = '🔒';
      host.appendChild(lk);
    }
    items.appendChild(host);
  });
  buildTree();
  renderCrumbs(boardId);
}

function hashStr(s) {
  let h = 0;
  for (let i=0;i<s.length;i++) h = ((h<<5)-h) + s.charCodeAt(i) | 0;
  return h;
}

function renderCrumbs(boardId) {
  const chain = [];
  let cur = findBoard(boardId);
  while (cur) {
    chain.unshift(cur);
    cur = cur.parent_board_id ? findBoard(cur.parent_board_id) : null;
  }
  crumbs.innerHTML = '';
  chain.forEach((b, i) => {
    if (i > 0) {
      const sep = document.createElement('span');
      sep.className = 'sep'; sep.textContent = '›';
      crumbs.appendChild(sep);
    }
    const sp = document.createElement('span');
    sp.className = 'crumb';
    sp.textContent = b.name || '(unnamed)';
    sp.onclick = () => navigate(b.id, true);
    crumbs.appendChild(sp);
  });
}

function navigate(boardId, push) {
  if (push && activeBoardId !== boardId) history.push(activeBoardId);
  renderBoard(boardId);
}

function applyScale() {
  world.style.transform = `scale(${scale})`;
  $('#zoom-label').textContent = Math.round(scale*100) + '%';
}
$('#zoom-in').onclick = () => { scale = Math.min(4, scale * 1.15); applyScale(); };
$('#zoom-out').onclick = () => { scale = Math.max(0.1, scale / 1.15); applyScale(); };
$('#zoom-reset').onclick = () => {
  const vw = viewport.clientWidth, vh = viewport.clientHeight;
  const ww = world.offsetWidth, wh = world.offsetHeight;
  if (ww > 0 && wh > 0) scale = Math.min(vw/ww, vh/wh, 1.0);
  else scale = 1;
  applyScale();
};

viewport.addEventListener('wheel', e => {
  if (!e.ctrlKey) return;
  e.preventDefault();
  const factor = e.deltaY < 0 ? 1.1 : 1/1.1;
  scale = Math.max(0.1, Math.min(4, scale * factor));
  applyScale();
}, { passive: false });

window.addEventListener('keydown', e => {
  if (e.key === 'Backspace' && history.length > 0 && document.activeElement === document.body) {
    e.preventDefault();
    const id = history.pop();
    renderBoard(id);
  }
});

renderBoard(activeBoardId);
applyScale();
})();
"""


# ============================================================================
# Markdown export
# ============================================================================


func export_markdown(root_board: Board, project: Project, path: String) -> bool:
	if root_board == null:
		return false
	var sb: String = ""
	sb += "# %s\n\n" % root_board.name
	if project != null:
		sb += "_Exported from project_ **%s** _on_ %s\n\n" % [project.name, Time.get_datetime_string_from_system(false, true)]
	var visited: Dictionary = {}
	sb = _emit_board_md(root_board, project, sb, 0, visited)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(sb)
	f.close()
	return true


func _emit_board_md(board: Board, project: Project, sb: String, depth: int, visited: Dictionary) -> String:
	if board == null or visited.has(board.id):
		return sb
	visited[board.id] = true
	var head_prefix: String = "#".repeat(min(6, depth + 1))
	if depth > 0:
		sb += "\n%s %s\n\n" % [head_prefix, board.name]
	for d in board.items:
		sb = _emit_item_md(d as Dictionary, sb, depth)
	for d in board.items:
		var t: String = String((d as Dictionary).get("type", ""))
		if (t == ItemRegistry.TYPE_PINBOARD or t == ItemRegistry.TYPE_SUBPAGE) and project != null:
			var child_id: String = String((d as Dictionary).get("target_board_id", ""))
			if child_id != "" and not visited.has(child_id):
				var child: Board = project.read_board(child_id)
				if child != null:
					sb = _emit_board_md(child, project, sb, depth + 1, visited)
	return sb


func _emit_item_md(d: Dictionary, sb: String, depth: int) -> String:
	var t: String = String(d.get("type", ""))
	var indent: String = "  ".repeat(depth)
	match t:
		ItemRegistry.TYPE_TEXT, ItemRegistry.TYPE_LABEL, ItemRegistry.TYPE_STICKY:
			sb += "%s- %s\n" % [indent, String(d.get("text", "")).replace("\n", " ")]
		ItemRegistry.TYPE_RICH_TEXT:
			sb += "%s- %s\n" % [indent, _bbcode_to_md(String(d.get("bbcode_text", "")))]
		ItemRegistry.TYPE_CODE:
			sb += "\n```%s\n%s\n```\n\n" % [String(d.get("language", "")), String(d.get("code", ""))]
		ItemRegistry.TYPE_URL:
			sb += "%s- [%s](%s)\n" % [indent, String(d.get("title", "")), String(d.get("url", ""))]
		ItemRegistry.TYPE_TODO_LIST:
			sb += "%s- **%s**\n" % [indent, String(d.get("title", "List"))]
			var cards_raw: Variant = d.get("cards", [])
			if typeof(cards_raw) == TYPE_ARRAY:
				for c in cards_raw:
					var done: bool = bool((c as Dictionary).get("completed", false))
					sb += "%s  - %s %s\n" % [indent, ("[x]" if done else "[ ]"), String((c as Dictionary).get("text", ""))]
		ItemRegistry.TYPE_BLOCK_STACK:
			sb += "%s- **%s**\n" % [indent, String(d.get("title", "Blocks"))]
			var blocks_raw: Variant = d.get("blocks", [])
			if typeof(blocks_raw) == TYPE_ARRAY:
				for b in blocks_raw:
					sb += "%s  - %s\n" % [indent, String((b as Dictionary).get("text", ""))]
		ItemRegistry.TYPE_TABLE:
			var cols: int = int(d.get("cols", 0))
			var cells_raw: Variant = d.get("cells", [])
			if typeof(cells_raw) == TYPE_ARRAY and cols > 0 and (cells_raw as Array).size() > 0:
				sb += "\n"
				var first_row: Array = (cells_raw as Array)[0]
				sb += "| " + " | ".join(_string_row(first_row, cols)) + " |\n"
				sb += "| " + " | ".join(_dashes(cols)) + " |\n"
				for r in range(1, (cells_raw as Array).size()):
					sb += "| " + " | ".join(_string_row((cells_raw as Array)[r], cols)) + " |\n"
				sb += "\n"
		ItemRegistry.TYPE_EQUATION:
			sb += "\n$$\n%s\n$$\n\n" % String(d.get("latex", ""))
		ItemRegistry.TYPE_TIMER:
			var t_label: String = String(d.get("label_text", "Timer"))
			var t_mode: String = String(d.get("mode", "duration"))
			if t_mode == "target":
				var t_unix: int = int(d.get("target_unix", 0))
				if t_unix > 0:
					sb += "%s- ⏱ %s → %s\n" % [indent, t_label, Time.get_datetime_string_from_unix_time(t_unix, true)]
				else:
					sb += "%s- ⏱ %s (target unset)\n" % [indent, t_label]
			else:
				sb += "%s- ⏱ %s (%s)\n" % [indent, t_label, TimerRegistry.format_duration(float(d.get("initial_duration_sec", 0)), false)]
		ItemRegistry.TYPE_GROUP:
			sb += "%s- 📦 %s\n" % [indent, String(d.get("title", "Group"))]
		ItemRegistry.TYPE_IMAGE:
			sb += "%s- ![image](%s)\n" % [indent, String(d.get("source_path", ""))]
		ItemRegistry.TYPE_SOUND:
			sb += "%s- 🔊 %s\n" % [indent, String(d.get("display_label", String(d.get("source_path", ""))))]
		_:
			pass
	return sb


func _string_row(row: Array, cols: int) -> Array:
	var out: Array = []
	for i in range(cols):
		out.append(String(row[i]) if i < row.size() else "")
	return out


func _dashes(cols: int) -> Array:
	var out: Array = []
	for _i in range(cols):
		out.append("---")
	return out


func _bbcode_to_md(bb: String) -> String:
	var s: String = bb
	s = s.replace("[b]", "**").replace("[/b]", "**")
	s = s.replace("[i]", "*").replace("[/i]", "*")
	s = s.replace("[u]", "").replace("[/u]", "")
	s = s.replace("[code]", "`").replace("[/code]", "`")
	return s


# ============================================================================
# PDF export
# ============================================================================


func export_pdf(root_board: Board, project: Project, path: String) -> bool:
	if root_board == null or project == null:
		return false
	var ordered: Array = _collect_boards_breadth_first(root_board, project)
	if ordered.is_empty():
		return false
	var page_images: Array = []
	for b_v in ordered:
		var b: Board = b_v
		var bounds: Rect2 = compute_board_bounds(b)
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
			continue
		var temp_png: String = OS.get_user_data_dir().path_join("__pdf_tmp_%s.png" % b.id)
		var ok: bool = await export_board(b, temp_png)
		if ok:
			var img: Image = Image.load_from_file(temp_png)
			if img != null:
				page_images.append({"name": b.name, "image": img, "tmp": temp_png})
	if page_images.is_empty():
		return false
	return _write_pdf(page_images, path)


func _write_pdf(pages: Array, path: String) -> bool:
	var images: Array = []
	for p in pages:
		var entry: Dictionary = p as Dictionary
		images.append(entry["image"])
	var ok: bool = PdfImageWriter.write_pages(images, path)
	for p in pages:
		var tmp: String = String((p as Dictionary).get("tmp", ""))
		if tmp != "":
			DirAccess.remove_absolute(tmp)
	return ok
