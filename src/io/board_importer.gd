class_name BoardImporter
extends RefCounted

const NODE_WIDTH: float = 200.0
const NODE_HEIGHT: float = 56.0
const COL_GAP: float = 70.0
const ROW_GAP: float = 24.0
const ORIGIN: Vector2 = Vector2(-2400, -1600)

var _editor: Node


func _init(editor: Node) -> void:
	_editor = editor


func import_file(path: String, mode: String) -> bool:
	if AppState.current_project == null or AppState.current_board == null:
		return false
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var raw: String = f.get_as_text()
	f.close()
	match mode:
		"markdown":
			return import_markdown_text(raw)
		"json":
			return import_json_text(raw)
	return false


func import_markdown_text(text: String) -> bool:
	var root: Dictionary = {"text": "Imported", "children": []}
	var stack: Array = [root]
	var levels: Array = [0]
	var lines: PackedStringArray = text.split("\n")
	for line_v in lines:
		var line: String = String(line_v)
		var trimmed: String = line.strip_edges()
		if trimmed == "":
			continue
		if trimmed.begins_with("#"):
			var depth: int = 0
			while depth < trimmed.length() and trimmed[depth] == "#":
				depth += 1
			var label: String = trimmed.substr(depth).strip_edges()
			_pop_stack_to(stack, levels, depth)
			var node: Dictionary = {"text": label, "children": []}
			(stack[stack.size() - 1] as Dictionary).children.append(node)
			stack.append(node)
			levels.append(depth + 100)
		elif trimmed.begins_with("- ") or trimmed.begins_with("* "):
			var indent_count: int = 0
			while indent_count < line.length() and (line[indent_count] == " " or line[indent_count] == "\t"):
				indent_count += 1
			var label2: String = trimmed.substr(2).strip_edges()
			var bullet_depth: int = 200 + (indent_count / 2)
			_pop_stack_to(stack, levels, bullet_depth)
			var node2: Dictionary = {"text": label2, "children": []}
			(stack[stack.size() - 1] as Dictionary).children.append(node2)
			stack.append(node2)
			levels.append(bullet_depth)
	return _instantiate_tree(root)


func _pop_stack_to(stack: Array, levels: Array, depth: int) -> void:
	while levels.size() > 1 and int(levels[levels.size() - 1]) >= depth:
		stack.pop_back()
		levels.pop_back()


func import_json_text(text: String) -> bool:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	var items_v: Variant = d.get("items", null)
	var connections_v: Variant = d.get("connections", null)
	if typeof(items_v) != TYPE_ARRAY:
		var boards_v: Variant = d.get("boards", null)
		if typeof(boards_v) == TYPE_ARRAY and (boards_v as Array).size() > 0:
			var first: Dictionary = (boards_v as Array)[0]
			items_v = first.get("items", [])
			connections_v = first.get("connections", [])
		else:
			return false
	var item_dicts: Array = []
	var id_remap: Dictionary = {}
	for it_v in (items_v as Array):
		if typeof(it_v) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = (it_v as Dictionary).duplicate(true)
		var old_id: String = String(copy.get("id", ""))
		var new_id: String = Uuid.v4()
		copy["id"] = new_id
		if old_id != "":
			id_remap[old_id] = new_id
		item_dicts.append(copy)
	History.push(AddItemsCommand.new(_editor, item_dicts))
	if typeof(connections_v) == TYPE_ARRAY:
		var conn_dicts: Array = []
		for c_v in (connections_v as Array):
			if typeof(c_v) != TYPE_DICTIONARY:
				continue
			var c_copy: Dictionary = (c_v as Dictionary).duplicate(true)
			c_copy["id"] = Uuid.v4()
			if id_remap.has(c_copy.get("from_item_id", "")):
				c_copy["from_item_id"] = id_remap[c_copy["from_item_id"]]
			if id_remap.has(c_copy.get("to_item_id", "")):
				c_copy["to_item_id"] = id_remap[c_copy["to_item_id"]]
			conn_dicts.append(c_copy)
		if not conn_dicts.is_empty():
			History.push(AddConnectionsCommand.new(_editor, conn_dicts))
	return true


func _instantiate_tree(root: Dictionary) -> bool:
	if (root.children as Array).is_empty():
		return false
	var item_dicts: Array = []
	var conn_dicts: Array = []
	var depth_x: Dictionary = {0: ORIGIN.x}
	var next_y: Array = [ORIGIN.y]
	_layout_subtree(root, 0, item_dicts, conn_dicts, "", depth_x, next_y)
	if item_dicts.is_empty():
		return false
	History.push(AddItemsCommand.new(_editor, item_dicts))
	if not conn_dicts.is_empty():
		History.push(AddConnectionsCommand.new(_editor, conn_dicts))
	return true


func _layout_subtree(node: Dictionary, depth: int, item_dicts: Array, conn_dicts: Array, parent_id: String, depth_x: Dictionary, next_y: Array) -> Vector2:
	if depth == 0:
		for child_v in node.children:
			_layout_subtree(child_v, 1, item_dicts, conn_dicts, "", depth_x, next_y)
		return Vector2.ZERO
	var x: float = ORIGIN.x + float(depth) * (NODE_WIDTH + COL_GAP)
	var y: float = float(next_y[0])
	if (node.children as Array).is_empty():
		var d: Dictionary = _make_text_node(String(node.text), Vector2(x, y))
		item_dicts.append(d)
		next_y[0] = y + NODE_HEIGHT + ROW_GAP
		if parent_id != "":
			conn_dicts.append(_make_connection(parent_id, String(d["id"])))
		return Vector2(x, y)
	var child_top: float = float(next_y[0])
	var child_centers_y: Array = []
	var child_ids: Array = []
	for child_v in node.children:
		var c_pos: Vector2 = _layout_subtree(child_v, depth + 1, item_dicts, conn_dicts, "__placeholder__", depth_x, next_y)
		child_centers_y.append(c_pos.y + NODE_HEIGHT * 0.5)
		child_ids.append(String((item_dicts[item_dicts.size() - 1] as Dictionary).get("id", "")))
	var avg_y: float = 0.0
	for cy in child_centers_y:
		avg_y += float(cy)
	avg_y /= max(1, child_centers_y.size())
	y = avg_y - NODE_HEIGHT * 0.5
	var d2: Dictionary = _make_text_node(String(node.text), Vector2(x, y))
	item_dicts.append(d2)
	if parent_id != "" and parent_id != "__placeholder__":
		conn_dicts.append(_make_connection(parent_id, String(d2["id"])))
	for child_id in child_ids:
		conn_dicts.append(_make_connection(String(d2["id"]), String(child_id)))
	return Vector2(x, y)


func _make_text_node(label: String, pos: Vector2) -> Dictionary:
	return {
		"id": Uuid.v4(),
		"type": ItemRegistry.TYPE_TEXT,
		"position": [pos.x, pos.y],
		"size": [NODE_WIDTH, NODE_HEIGHT],
		"text": label,
		"font_size": 16,
	}


func _make_connection(from_id: String, to_id: String) -> Dictionary:
	return {
		"id": Uuid.v4(),
		"from_item_id": from_id,
		"to_item_id": to_id,
		"from_anchor": Connection.ANCHOR_AUTO,
		"to_anchor": Connection.ANCHOR_AUTO,
		"style": Connection.STYLE_BEZIER,
		"thickness": Connection.DEFAULT_THICKNESS,
		"color": ColorUtil.to_array(Connection.DEFAULT_COLOR),
		"arrow_end": true,
		"arrow_start": false,
	}
