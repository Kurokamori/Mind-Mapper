class_name PlainTextOutline
extends RefCounted

const MAX_BLOCK_INDENT: int = 6


static func encode_blocks(blocks: Array) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for raw in blocks:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var b: Dictionary = raw
		var lvl: int = clamp(int(b.get("indent_level", 0)), 0, MAX_BLOCK_INDENT)
		var prefix: String = "".lpad(lvl + 1, "-")
		lines.append("%s %s" % [prefix, String(b.get("text", ""))])
	return "\n".join(lines)


static func decode_blocks(text: String, existing: Array) -> Array:
	var pool: Dictionary = _build_text_pool(existing, "_block_pool_collect")
	var out: Array = []
	for parsed in _parse_lines(text):
		var depth: int = int(parsed["depth"])
		var content: String = String(parsed["content"])
		var indent_level: int = clamp(depth - 1, 0, MAX_BLOCK_INDENT)
		var reused: Dictionary = _take_from_pool(pool, content)
		if reused.is_empty():
			out.append({
				"id": Uuid.v4(),
				"text": content,
				"indent_level": indent_level,
				"asset_name": "",
				"source_path": "",
				"link_target": {},
			})
		else:
			reused["text"] = content
			reused["indent_level"] = indent_level
			out.append(reused)
	return out


static func encode_todos(cards: Array) -> String:
	var lines: PackedStringArray = PackedStringArray()
	_encode_todos_recursive(cards, 1, lines)
	return "\n".join(lines)


static func _encode_todos_recursive(cards: Array, depth: int, lines: PackedStringArray) -> void:
	for raw in cards:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var c: Dictionary = raw
		var prefix: String = "".lpad(depth, "-")
		lines.append("%s %s" % [prefix, String(c.get("text", ""))])
		var sub: Array = c.get("subcards", []) as Array
		if sub.size() > 0:
			_encode_todos_recursive(sub, depth + 1, lines)


static func decode_todos(text: String, existing: Array) -> Array:
	var pool: Dictionary = _build_text_pool(existing, "_todo_pool_collect")
	var parsed_lines: Array = _parse_lines(text)
	var root: Array = []
	var stack: Array = [{"depth": 0, "children": root}]
	for parsed in parsed_lines:
		var depth: int = int(parsed["depth"])
		var content: String = String(parsed["content"])
		while stack.size() > 1 and int((stack[stack.size() - 1] as Dictionary)["depth"]) >= depth:
			stack.pop_back()
		var card: Dictionary = _take_from_pool(pool, content)
		if card.is_empty():
			card = TodoCardData.make_default()
		card["text"] = content
		card["subcards"] = []
		var parent: Dictionary = stack[stack.size() - 1]
		(parent["children"] as Array).append(card)
		stack.append({"depth": depth, "children": card["subcards"]})
	return root


static func _parse_lines(text: String) -> Array:
	var raw_lines: PackedStringArray = text.split("\n")
	var out: Array = []
	for line in raw_lines:
		var stripped: String = line.strip_edges(true, false)
		if stripped == "":
			continue
		var depth: int = 0
		while depth < stripped.length() and stripped[depth] == "-":
			depth += 1
		if depth == 0:
			continue
		var content: String = stripped.substr(depth).strip_edges(true, true)
		out.append({"depth": depth, "content": content})
	return out


static func _build_text_pool(existing: Array, collector: String) -> Dictionary:
	var pool: Dictionary = {}
	if collector == "_block_pool_collect":
		_block_pool_collect(existing, pool)
	else:
		_todo_pool_collect(existing, pool)
	return pool


static func _block_pool_collect(blocks: Array, pool: Dictionary) -> void:
	for raw in blocks:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var b: Dictionary = raw
		var key: String = String(b.get("text", ""))
		var bucket: Array = pool.get(key, []) as Array
		bucket.append(b.duplicate(true))
		pool[key] = bucket


static func _todo_pool_collect(cards: Array, pool: Dictionary) -> void:
	for raw in cards:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var c: Dictionary = raw
		var key: String = String(c.get("text", ""))
		var bucket: Array = pool.get(key, []) as Array
		var copy: Dictionary = c.duplicate(true)
		copy["subcards"] = []
		bucket.append(copy)
		pool[key] = bucket
		_todo_pool_collect(c.get("subcards", []) as Array, pool)


static func _take_from_pool(pool: Dictionary, key: String) -> Dictionary:
	if not pool.has(key):
		return {}
	var bucket: Array = pool[key] as Array
	if bucket.is_empty():
		return {}
	var item: Dictionary = bucket.pop_front()
	if bucket.is_empty():
		pool.erase(key)
	else:
		pool[key] = bucket
	return item
