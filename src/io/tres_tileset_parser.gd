class_name TresTilesetParser
extends RefCounted

## Parses a Godot 4 TileSet (.tres) text resource into a TileSetResource.
##
## We extract only the data needed to *paint* — atlas source dimensions,
## per-tile presence, terrain set definitions, and per-tile terrain assignment
## with peering bits. Physics layers, navigation, occlusion, custom data,
## animations, and scene-collection sources are **read but ignored**; they
## remain in the original .tres and survive round-trip via reference-mode
## export.

const TILE_SUBRESOURCE_TYPE: String = "TileSetAtlasSource"


class ParseResult:
	extends RefCounted
	var ok: bool = false
	var error_message: String = ""
	var tileset: TileSetResource = null
	var ext_resources: Dictionary = {}
	var sub_resources: Dictionary = {}
	var resource_uid: String = ""
	var resource_block: Dictionary = {}


static func parse_text(text: String, base_dir: String) -> ParseResult:
	var result: ParseResult = ParseResult.new()
	if text.strip_edges() == "":
		result.error_message = "Empty tileset"
		return result
	var lines: PackedStringArray = text.split("\n", false)
	var current_block_kind: String = ""
	var current_block_attrs: Dictionary = {}
	var current_block_props: Dictionary = {}
	var i: int = 0
	while i < lines.size():
		var line: String = lines[i]
		var stripped: String = line.strip_edges()
		i += 1
		if stripped == "":
			continue
		if stripped.begins_with("["):
			_close_block(current_block_kind, current_block_attrs, current_block_props, result)
			var header: Dictionary = _parse_header(stripped)
			current_block_kind = String(header.get("kind", ""))
			current_block_attrs = header.get("attrs", {})
			current_block_props = {}
			continue
		var eq: int = stripped.find("=")
		if eq < 0:
			continue
		var key: String = stripped.substr(0, eq).strip_edges()
		var value: String = stripped.substr(eq + 1).strip_edges()
		current_block_props[key] = value
	_close_block(current_block_kind, current_block_attrs, current_block_props, result)
	if result.tileset == null:
		result.error_message = "No [resource] block found"
		return result
	result.ok = true
	if base_dir != "":
		result.tileset.godot_tres_text = text
	return result


static func _close_block(
	kind: String,
	attrs: Dictionary,
	props: Dictionary,
	result: ParseResult,
) -> void:
	if kind == "":
		return
	match kind:
		"gd_resource":
			result.resource_uid = String(attrs.get("uid", ""))
		"ext_resource":
			var rid: String = String(attrs.get("id", ""))
			if rid != "":
				result.ext_resources[rid] = {
					"type": String(attrs.get("type", "")),
					"uid": String(attrs.get("uid", "")),
					"path": String(attrs.get("path", "")),
				}
		"sub_resource":
			var sid: String = String(attrs.get("id", ""))
			var stype: String = String(attrs.get("type", ""))
			if sid != "":
				result.sub_resources[sid] = {
					"type": stype,
					"props": props.duplicate(true),
				}
		"resource":
			result.resource_block = props.duplicate(true)
			result.tileset = _build_tileset_from(result)


static func _build_tileset_from(result: ParseResult) -> TileSetResource:
	var ts: TileSetResource = TileSetResource.new()
	ts.origin_kind = "godot_tres"
	ts.godot_uid = result.resource_uid
	var props: Dictionary = result.resource_block
	if props.has("tile_size"):
		ts.tile_size = _parse_vector2i(String(props["tile_size"]))
	var terrain_set_indices: Dictionary = {}
	for key_v: Variant in props.keys():
		var key: String = String(key_v)
		if not key.begins_with("terrain_set_"):
			continue
		var rest: String = key.substr("terrain_set_".length())
		var slash_idx: int = rest.find("/")
		if slash_idx < 0:
			continue
		var idx_str: String = rest.substr(0, slash_idx)
		if not idx_str.is_valid_int():
			continue
		var ts_idx: int = idx_str.to_int()
		var tail: String = rest.substr(slash_idx + 1)
		var entry: Dictionary = ts.ensure_terrain_set(ts_idx)
		terrain_set_indices[ts_idx] = true
		if tail == "mode":
			entry["mode"] = _parse_int_value(String(props[key]))
		elif tail.begins_with("terrains/"):
			var ttail: String = tail.substr("terrains/".length())
			var ts_slash: int = ttail.find("/")
			if ts_slash < 0:
				continue
			var t_idx_str: String = ttail.substr(0, ts_slash)
			if not t_idx_str.is_valid_int():
				continue
			var t_idx: int = t_idx_str.to_int()
			var t_tail: String = ttail.substr(ts_slash + 1)
			var arr: Array = entry.get("terrains", [])
			while arr.size() <= t_idx:
				arr.append({"name": "", "color": [1.0, 1.0, 1.0, 1.0]})
			var terrain_entry: Dictionary = arr[t_idx]
			if t_tail == "name":
				terrain_entry["name"] = _strip_quotes(String(props[key]))
			elif t_tail == "color":
				var col: Color = _parse_color(String(props[key]))
				terrain_entry["color"] = [col.r, col.g, col.b, col.a]
			arr[t_idx] = terrain_entry
			entry["terrains"] = arr
	for key_v: Variant in props.keys():
		var key: String = String(key_v)
		if not key.begins_with("sources/"):
			continue
		var idx_str: String = key.substr("sources/".length())
		if not idx_str.is_valid_int():
			continue
		var src_id_int: int = idx_str.to_int()
		var ref_value: String = String(props[key])
		var sub_id: String = _extract_subresource_id(ref_value)
		if sub_id == "" or not result.sub_resources.has(sub_id):
			continue
		var sub: Dictionary = result.sub_resources[sub_id]
		if String(sub.get("type", "")) != TILE_SUBRESOURCE_TYPE:
			continue
		_apply_atlas_source(ts, src_id_int, sub.get("props", {}), result.ext_resources)
		break
	ts.name = "Imported Tileset"
	return ts


static func _apply_atlas_source(
	ts: TileSetResource,
	src_id: int,
	atlas_props: Dictionary,
	ext_resources: Dictionary,
) -> void:
	ts.source_id = src_id
	if atlas_props.has("texture"):
		var tex_ref: String = String(atlas_props["texture"])
		var ext_id: String = _extract_extresource_id(tex_ref)
		if ext_id != "" and ext_resources.has(ext_id):
			ts.godot_tres_relative = String((ext_resources[ext_id] as Dictionary).get("path", ""))
	if atlas_props.has("texture_region_size"):
		ts.tile_size = _parse_vector2i(String(atlas_props["texture_region_size"]))
	if atlas_props.has("margins"):
		ts.margins = _parse_vector2i(String(atlas_props["margins"]))
	if atlas_props.has("separation"):
		ts.separation = _parse_vector2i(String(atlas_props["separation"]))
	for key_v: Variant in atlas_props.keys():
		var key: String = String(key_v)
		var coord: Vector2i = _try_parse_tile_key(key)
		if coord.x < 0 and coord.y < 0:
			continue
		var entry: Dictionary = ts.ensure_tile(coord)
		if not key.contains("/terrain_set") and not key.contains("/terrain") and not key.contains("/peering") and not key.contains("/terrains_peering_bit"):
			continue
		if key.ends_with("/terrain_set"):
			entry["terrain_set"] = _parse_int_value(String(atlas_props[key]))
		elif key.ends_with("/terrain"):
			entry["terrain"] = _parse_int_value(String(atlas_props[key]))
		elif key.contains("/terrains_peering_bit/"):
			var slash: int = key.rfind("/")
			var direction: String = key.substr(slash + 1)
			var peering: Dictionary = entry.get("peering", {})
			peering[direction] = _parse_int_value(String(atlas_props[key]))
			entry["peering"] = peering


static func _try_parse_tile_key(key: String) -> Vector2i:
	var first_slash: int = key.find("/")
	var base: String = key
	if first_slash >= 0:
		base = key.substr(0, first_slash)
	var colon: int = base.find(":")
	if colon < 0:
		return Vector2i(-1, -1)
	var x_str: String = base.substr(0, colon)
	var y_str: String = base.substr(colon + 1)
	if not x_str.is_valid_int() or not y_str.is_valid_int():
		return Vector2i(-1, -1)
	return Vector2i(x_str.to_int(), y_str.to_int())


static func _parse_header(line: String) -> Dictionary:
	var inner: String = line.lstrip("[").rstrip("]")
	inner = inner.strip_edges()
	var space_idx: int = inner.find(" ")
	var kind: String
	var attrs_text: String
	if space_idx < 0:
		kind = inner
		attrs_text = ""
	else:
		kind = inner.substr(0, space_idx)
		attrs_text = inner.substr(space_idx + 1)
	var attrs: Dictionary = _parse_attrs(attrs_text)
	return {"kind": kind, "attrs": attrs}


static func _parse_attrs(text: String) -> Dictionary:
	var out: Dictionary = {}
	var i: int = 0
	while i < text.length():
		while i < text.length() and text[i] == " ":
			i += 1
		var eq: int = text.find("=", i)
		if eq < 0:
			break
		var key: String = text.substr(i, eq - i).strip_edges()
		i = eq + 1
		if i >= text.length():
			break
		var value: String
		if text[i] == "\"":
			var end_quote: int = text.find("\"", i + 1)
			if end_quote < 0:
				value = text.substr(i + 1)
				i = text.length()
			else:
				value = text.substr(i + 1, end_quote - i - 1)
				i = end_quote + 1
		else:
			var end_pos: int = text.find(" ", i)
			if end_pos < 0:
				value = text.substr(i)
				i = text.length()
			else:
				value = text.substr(i, end_pos - i)
				i = end_pos + 1
		out[key] = value
	return out


static func _parse_vector2i(value: String) -> Vector2i:
	var inner: String = _strip_call(value, "Vector2i")
	if inner == "":
		return Vector2i.ZERO
	var parts: PackedStringArray = inner.split(",")
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))


static func _parse_color(value: String) -> Color:
	var inner: String = _strip_call(value, "Color")
	if inner == "":
		return Color(1, 1, 1, 1)
	var parts: PackedStringArray = inner.split(",")
	var r: float = float(parts[0].strip_edges()) if parts.size() > 0 else 1.0
	var g: float = float(parts[1].strip_edges()) if parts.size() > 1 else 1.0
	var b: float = float(parts[2].strip_edges()) if parts.size() > 2 else 1.0
	var a: float = float(parts[3].strip_edges()) if parts.size() > 3 else 1.0
	return Color(r, g, b, a)


static func _parse_int_value(value: String) -> int:
	var trimmed: String = value.strip_edges()
	if trimmed.is_valid_int():
		return trimmed.to_int()
	if trimmed.is_valid_float():
		return int(trimmed.to_float())
	return 0


static func _strip_call(value: String, prefix: String) -> String:
	var trimmed: String = value.strip_edges()
	if not trimmed.begins_with(prefix + "("):
		return ""
	if not trimmed.ends_with(")"):
		return ""
	return trimmed.substr(prefix.length() + 1, trimmed.length() - prefix.length() - 2)


static func _strip_quotes(value: String) -> String:
	var trimmed: String = value.strip_edges()
	if trimmed.length() >= 2 and trimmed.begins_with("\"") and trimmed.ends_with("\""):
		return trimmed.substr(1, trimmed.length() - 2)
	return trimmed


static func _extract_subresource_id(value: String) -> String:
	var inner: String = _strip_call(value, "SubResource")
	if inner == "":
		return ""
	return _strip_quotes(inner)


static func _extract_extresource_id(value: String) -> String:
	var inner: String = _strip_call(value, "ExtResource")
	if inner == "":
		return ""
	return _strip_quotes(inner)
