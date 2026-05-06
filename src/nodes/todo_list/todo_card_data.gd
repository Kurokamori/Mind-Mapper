class_name TodoCardData
extends RefCounted


static func make_default() -> Dictionary:
	return {
		"id": Uuid.v4(),
		"text": "",
		"completed": false,
		"description": "",
		"details": [],
		"subcards": [],
		"expanded": true,
	}


static func make_default_detail() -> Dictionary:
	return {
		"id": Uuid.v4(),
		"header": "",
		"content": "",
	}


static func normalize(card: Dictionary) -> Dictionary:
	var out: Dictionary = card.duplicate(true)
	if not out.has("id") or String(out.get("id", "")) == "":
		out["id"] = Uuid.v4()
	if not out.has("text"):
		out["text"] = ""
	if not out.has("completed"):
		out["completed"] = false
	if not out.has("description"):
		out["description"] = ""
	var details_raw: Variant = out.get("details", [])
	var details: Array = details_raw if typeof(details_raw) == TYPE_ARRAY else []
	var clean_details: Array = []
	for d in details:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var dd: Dictionary = d
		var entry: Dictionary = {
			"id": String(dd.get("id", Uuid.v4())),
			"header": String(dd.get("header", "")),
			"content": String(dd.get("content", "")),
		}
		clean_details.append(entry)
	out["details"] = clean_details
	var subcards_raw: Variant = out.get("subcards", [])
	var subcards: Array = subcards_raw if typeof(subcards_raw) == TYPE_ARRAY else []
	var clean_subs: Array = []
	for s in subcards:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		clean_subs.append(normalize(s))
	out["subcards"] = clean_subs
	if not out.has("expanded"):
		out["expanded"] = true
	return out


static func normalize_array(cards: Array) -> Array:
	var out: Array = []
	for c in cards:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		out.append(normalize(c))
	return out


static func find_path(cards: Array, card_id: String) -> Array:
	for i in range(cards.size()):
		var c: Dictionary = cards[i]
		if String(c.get("id", "")) == card_id:
			return [i]
		var sub: Array = c.get("subcards", []) as Array
		var inner: Array = find_path(sub, card_id)
		if inner.size() > 0:
			var path: Array = [i]
			path.append_array(inner)
			return path
	return []


static func get_at_path(cards: Array, path: Array) -> Dictionary:
	if path.is_empty():
		return {}
	var arr: Array = cards
	var node: Dictionary = {}
	for i in range(path.size()):
		var idx: int = int(path[i])
		if idx < 0 or idx >= arr.size():
			return {}
		node = arr[idx]
		if i < path.size() - 1:
			arr = node.get("subcards", []) as Array
	return node


static func find_card(cards: Array, card_id: String) -> Dictionary:
	var path: Array = find_path(cards, card_id)
	if path.is_empty():
		return {}
	return get_at_path(cards, path)


static func mutate_card(cards: Array, card_id: String, mutator: Callable) -> Array:
	var out: Array = cards.duplicate(true)
	if _mutate_recursive(out, card_id, mutator):
		return out
	return cards


static func _mutate_recursive(arr: Array, card_id: String, mutator: Callable) -> bool:
	for i in range(arr.size()):
		var c: Dictionary = arr[i]
		if String(c.get("id", "")) == card_id:
			mutator.call(c)
			arr[i] = c
			return true
		var sub: Array = c.get("subcards", []) as Array
		if _mutate_recursive(sub, card_id, mutator):
			c["subcards"] = sub
			arr[i] = c
			return true
	return false


static func remove_card(cards: Array, card_id: String) -> Dictionary:
	var out: Array = cards.duplicate(true)
	var removed: Dictionary = {}
	if _remove_recursive(out, card_id, removed):
		return {"cards": out, "removed": removed.get("card", {})}
	return {"cards": cards, "removed": {}}


static func _remove_recursive(arr: Array, card_id: String, captured: Dictionary) -> bool:
	for i in range(arr.size()):
		var c: Dictionary = arr[i]
		if String(c.get("id", "")) == card_id:
			captured["card"] = c.duplicate(true)
			arr.remove_at(i)
			return true
		var sub: Array = c.get("subcards", []) as Array
		if _remove_recursive(sub, card_id, captured):
			c["subcards"] = sub
			arr[i] = c
			return true
	return false


static func insert_at_path(cards: Array, parent_path: Array, index: int, card: Dictionary) -> Array:
	var out: Array = cards.duplicate(true)
	if parent_path.is_empty():
		var clamped: int = clamp(index, 0, out.size())
		out.insert(clamped, card)
		return out
	var arr: Array = out
	var node: Dictionary = {}
	for i in range(parent_path.size()):
		var idx: int = int(parent_path[i])
		if idx < 0 or idx >= arr.size():
			return cards
		node = arr[idx]
		var sub: Array = node.get("subcards", []) as Array
		if i == parent_path.size() - 1:
			var clamped2: int = clamp(index, 0, sub.size())
			sub.insert(clamped2, card)
			node["subcards"] = sub
			arr[idx] = node
			return out
		arr = sub
	return cards


static func count_completed(cards: Array) -> Vector2i:
	var done: int = 0
	var total: int = 0
	for c in cards:
		total += 1
		if bool(c.get("completed", false)):
			done += 1
		var sub: Array = c.get("subcards", []) as Array
		var inner: Vector2i = count_completed(sub)
		done += inner.x
		total += inner.y
	return Vector2i(done, total)


static func is_ancestor(cards: Array, ancestor_id: String, descendant_id: String) -> bool:
	var path: Array = find_path(cards, ancestor_id)
	if path.is_empty():
		return false
	var node: Dictionary = get_at_path(cards, path)
	var sub: Array = node.get("subcards", []) as Array
	if not find_path(sub, descendant_id).is_empty():
		return true
	return ancestor_id == descendant_id
