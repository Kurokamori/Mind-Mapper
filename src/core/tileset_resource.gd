class_name TileSetResource
extends RefCounted

## Project-level tile set asset.
##
## Stores everything needed to *paint* a Godot-compatible TileMap in this app
## without simulating physics, navigation, occlusion, animations, or scene
## collection sources. Those payloads live on the original Godot .tres (when
## imported from one) and survive round-trip via reference-mode export.

const TERRAIN_PEERING_DIRECTIONS: Array[String] = [
	"right_side",
	"right_corner",
	"bottom_right_side",
	"bottom_right_corner",
	"bottom_side",
	"bottom_corner",
	"bottom_left_side",
	"bottom_left_corner",
	"left_side",
	"left_corner",
	"top_left_side",
	"top_left_corner",
	"top_side",
	"top_corner",
	"top_right_side",
	"top_right_corner",
]

const PEERING_FOR_SQUARE_MATCH_CORNERS_AND_SIDES: Array[String] = [
	"right_side",
	"bottom_right_corner",
	"bottom_side",
	"bottom_left_corner",
	"left_side",
	"top_left_corner",
	"top_side",
	"top_right_corner",
]

const PEERING_FOR_SQUARE_MATCH_CORNERS: Array[String] = [
	"bottom_right_corner",
	"bottom_left_corner",
	"top_left_corner",
	"top_right_corner",
]

const PEERING_FOR_SQUARE_MATCH_SIDES: Array[String] = [
	"right_side",
	"bottom_side",
	"left_side",
	"top_side",
]

const TERRAIN_MODE_MATCH_CORNERS_AND_SIDES: int = 0
const TERRAIN_MODE_MATCH_CORNERS: int = 1
const TERRAIN_MODE_MATCH_SIDES: int = 2

var id: String = ""
var name: String = "Tileset"
var origin_kind: String = "image"
var image_asset_name: String = ""
var godot_tres_relative: String = ""
var godot_tres_text: String = ""
var godot_uid: String = ""
var source_id: int = 0
var tile_size: Vector2i = Vector2i(16, 16)
var margins: Vector2i = Vector2i.ZERO
var separation: Vector2i = Vector2i.ZERO
var atlas_columns: int = 0
var atlas_rows: int = 0
var atlas_tiles: Dictionary = {}
var terrain_sets: Array = []

var _cached_image: Image = null
var _cached_image_path: String = ""
var _cached_texture: ImageTexture = null


static func make_new(p_id: String, p_name: String) -> TileSetResource:
	var r: TileSetResource = TileSetResource.new()
	r.id = p_id
	r.name = p_name
	return r


static func from_dict(d: Dictionary) -> TileSetResource:
	var r: TileSetResource = TileSetResource.new()
	r.id = String(d.get("id", ""))
	r.name = String(d.get("name", "Tileset"))
	r.origin_kind = String(d.get("origin_kind", "image"))
	r.image_asset_name = String(d.get("image_asset_name", ""))
	r.godot_tres_relative = String(d.get("godot_tres_relative", ""))
	r.godot_uid = String(d.get("godot_uid", ""))
	r.source_id = int(d.get("source_id", 0))
	r.tile_size = _read_vector2i(d.get("tile_size", null), Vector2i(16, 16))
	r.margins = _read_vector2i(d.get("margins", null), Vector2i.ZERO)
	r.separation = _read_vector2i(d.get("separation", null), Vector2i.ZERO)
	r.atlas_columns = int(d.get("atlas_columns", 0))
	r.atlas_rows = int(d.get("atlas_rows", 0))
	var tiles_raw: Variant = d.get("atlas_tiles", {})
	if typeof(tiles_raw) == TYPE_DICTIONARY:
		for key_v: Variant in (tiles_raw as Dictionary).keys():
			var entry_v: Variant = (tiles_raw as Dictionary)[key_v]
			if typeof(entry_v) != TYPE_DICTIONARY:
				continue
			var coord: Vector2i = _coord_key_to_vector(String(key_v))
			r.atlas_tiles[coord] = (entry_v as Dictionary).duplicate(true)
	var ts_raw: Variant = d.get("terrain_sets", [])
	if typeof(ts_raw) == TYPE_ARRAY:
		for entry_v: Variant in (ts_raw as Array):
			if typeof(entry_v) == TYPE_DICTIONARY:
				r.terrain_sets.append((entry_v as Dictionary).duplicate(true))
	return r


func to_dict() -> Dictionary:
	var tiles_out: Dictionary = {}
	for coord_v: Variant in atlas_tiles.keys():
		var coord: Vector2i = coord_v
		var key: String = "%d,%d" % [coord.x, coord.y]
		var entry: Dictionary = atlas_tiles[coord]
		tiles_out[key] = entry.duplicate(true)
	var ts_out: Array = []
	for entry: Dictionary in terrain_sets:
		ts_out.append(entry.duplicate(true))
	return {
		"id": id,
		"name": name,
		"origin_kind": origin_kind,
		"image_asset_name": image_asset_name,
		"godot_tres_relative": godot_tres_relative,
		"godot_uid": godot_uid,
		"source_id": source_id,
		"tile_size": [tile_size.x, tile_size.y],
		"margins": [margins.x, margins.y],
		"separation": [separation.x, separation.y],
		"atlas_columns": atlas_columns,
		"atlas_rows": atlas_rows,
		"atlas_tiles": tiles_out,
		"terrain_sets": ts_out,
	}


func has_tile(coord: Vector2i) -> bool:
	return atlas_tiles.has(coord)


func ensure_tile(coord: Vector2i) -> Dictionary:
	if not atlas_tiles.has(coord):
		atlas_tiles[coord] = _default_tile_entry()
	return atlas_tiles[coord] as Dictionary


func tile_terrain_set(coord: Vector2i) -> int:
	if not atlas_tiles.has(coord):
		return -1
	var d: Dictionary = atlas_tiles[coord]
	return int(d.get("terrain_set", -1))


func tile_terrain(coord: Vector2i) -> int:
	if not atlas_tiles.has(coord):
		return -1
	var d: Dictionary = atlas_tiles[coord]
	return int(d.get("terrain", -1))


func tile_peering(coord: Vector2i) -> Dictionary:
	if not atlas_tiles.has(coord):
		return {}
	var d: Dictionary = atlas_tiles[coord]
	var p_raw: Variant = d.get("peering", {})
	if typeof(p_raw) == TYPE_DICTIONARY:
		return (p_raw as Dictionary).duplicate(true)
	return {}


func set_tile_terrain(coord: Vector2i, terrain_set: int, terrain: int) -> void:
	var entry: Dictionary = ensure_tile(coord)
	entry["terrain_set"] = terrain_set
	entry["terrain"] = terrain


func set_tile_peering(coord: Vector2i, direction: String, terrain_index: int) -> void:
	var entry: Dictionary = ensure_tile(coord)
	var peering: Dictionary = entry.get("peering", {})
	if terrain_index < 0:
		peering.erase(direction)
	else:
		peering[direction] = terrain_index
	entry["peering"] = peering


func ensure_terrain_set(index: int) -> Dictionary:
	while terrain_sets.size() <= index:
		terrain_sets.append({
			"mode": TERRAIN_MODE_MATCH_CORNERS_AND_SIDES,
			"terrains": [],
		})
	return terrain_sets[index] as Dictionary


func add_terrain(terrain_set_index: int, terrain_name: String, terrain_color: Color) -> int:
	var ts: Dictionary = ensure_terrain_set(terrain_set_index)
	var arr: Array = ts.get("terrains", [])
	arr.append({
		"name": terrain_name,
		"color": [terrain_color.r, terrain_color.g, terrain_color.b, terrain_color.a],
	})
	ts["terrains"] = arr
	return arr.size() - 1


func remove_terrain(terrain_set_index: int, terrain_index: int) -> void:
	if terrain_set_index < 0 or terrain_set_index >= terrain_sets.size():
		return
	var ts: Dictionary = terrain_sets[terrain_set_index]
	var arr: Array = ts.get("terrains", [])
	if terrain_index < 0 or terrain_index >= arr.size():
		return
	arr.remove_at(terrain_index)
	ts["terrains"] = arr
	for coord_v: Variant in atlas_tiles.keys():
		var coord: Vector2i = coord_v
		var d: Dictionary = atlas_tiles[coord]
		if int(d.get("terrain_set", -1)) == terrain_set_index:
			var t_idx: int = int(d.get("terrain", -1))
			if t_idx == terrain_index:
				d["terrain"] = -1
				d["terrain_set"] = -1
			elif t_idx > terrain_index:
				d["terrain"] = t_idx - 1
		var peering: Dictionary = d.get("peering", {})
		var changed_keys: Array = []
		for direction_v: Variant in peering.keys():
			var v: int = int(peering[direction_v])
			if v == terrain_index:
				changed_keys.append(direction_v)
			elif v > terrain_index:
				peering[direction_v] = v - 1
		for k_v: Variant in changed_keys:
			peering.erase(k_v)
		d["peering"] = peering


func terrain_count(terrain_set_index: int) -> int:
	if terrain_set_index < 0 or terrain_set_index >= terrain_sets.size():
		return 0
	var ts: Dictionary = terrain_sets[terrain_set_index]
	var arr: Array = ts.get("terrains", [])
	return arr.size()


func terrain_set_mode(terrain_set_index: int) -> int:
	if terrain_set_index < 0 or terrain_set_index >= terrain_sets.size():
		return TERRAIN_MODE_MATCH_CORNERS_AND_SIDES
	var ts: Dictionary = terrain_sets[terrain_set_index]
	return int(ts.get("mode", TERRAIN_MODE_MATCH_CORNERS_AND_SIDES))


func terrain_color(terrain_set_index: int, terrain_index: int) -> Color:
	if terrain_set_index < 0 or terrain_set_index >= terrain_sets.size():
		return Color(1, 1, 1, 1)
	var ts: Dictionary = terrain_sets[terrain_set_index]
	var arr: Array = ts.get("terrains", [])
	if terrain_index < 0 or terrain_index >= arr.size():
		return Color(1, 1, 1, 1)
	var entry: Dictionary = arr[terrain_index]
	var raw: Variant = entry.get("color", null)
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 3:
		var arr_v: Array = raw
		var a: float = 1.0 if arr_v.size() < 4 else float(arr_v[3])
		return Color(float(arr_v[0]), float(arr_v[1]), float(arr_v[2]), a)
	return Color(1, 1, 1, 1)


func terrain_name(terrain_set_index: int, terrain_index: int) -> String:
	if terrain_set_index < 0 or terrain_set_index >= terrain_sets.size():
		return ""
	var ts: Dictionary = terrain_sets[terrain_set_index]
	var arr: Array = ts.get("terrains", [])
	if terrain_index < 0 or terrain_index >= arr.size():
		return ""
	var entry: Dictionary = arr[terrain_index]
	return String(entry.get("name", ""))


func relevant_peering_directions(terrain_set_index: int) -> Array[String]:
	match terrain_set_mode(terrain_set_index):
		TERRAIN_MODE_MATCH_CORNERS:
			return PEERING_FOR_SQUARE_MATCH_CORNERS
		TERRAIN_MODE_MATCH_SIDES:
			return PEERING_FOR_SQUARE_MATCH_SIDES
		_:
			return PEERING_FOR_SQUARE_MATCH_CORNERS_AND_SIDES


func texture_pixel_size_for(coord: Vector2i) -> Rect2:
	var origin: Vector2 = Vector2(
		float(margins.x + coord.x * (tile_size.x + separation.x)),
		float(margins.y + coord.y * (tile_size.y + separation.y)),
	)
	return Rect2(origin, Vector2(tile_size.x, tile_size.y))


func texture_for_project(project_root: String) -> ImageTexture:
	var image_path: String = resolve_image_path(project_root)
	if image_path == "":
		return null
	if _cached_texture != null and _cached_image_path == image_path:
		return _cached_texture
	var img: Image = Image.load_from_file(image_path)
	if img == null or img.is_empty():
		return null
	_cached_image = img
	_cached_image_path = image_path
	_cached_texture = ImageTexture.create_from_image(img)
	return _cached_texture


func image_for_project(project_root: String) -> Image:
	if _cached_image != null and _cached_image_path != "" and FileAccess.file_exists(_cached_image_path):
		return _cached_image
	var image_path: String = resolve_image_path(project_root)
	if image_path == "":
		return null
	var img: Image = Image.load_from_file(image_path)
	if img == null or img.is_empty():
		return null
	_cached_image = img
	_cached_image_path = image_path
	_cached_texture = null
	return img


func resolve_image_path(project_root: String) -> String:
	if image_asset_name == "" or project_root == "":
		return ""
	return project_root.path_join(Project.TILESETS_DIR).path_join(id).path_join(image_asset_name)


func recompute_atlas_dimensions(image_width: int, image_height: int) -> void:
	if tile_size.x <= 0 or tile_size.y <= 0:
		atlas_columns = 0
		atlas_rows = 0
		return
	var step_x: int = tile_size.x + separation.x
	var step_y: int = tile_size.y + separation.y
	if step_x <= 0 or step_y <= 0:
		atlas_columns = 0
		atlas_rows = 0
		return
	var usable_w: int = image_width - margins.x
	var usable_h: int = image_height - margins.y
	atlas_columns = max(0, (usable_w + separation.x) / step_x)
	atlas_rows = max(0, (usable_h + separation.y) / step_y)


func clear_image_cache() -> void:
	_cached_image = null
	_cached_image_path = ""
	_cached_texture = null


static func _default_tile_entry() -> Dictionary:
	return {
		"terrain_set": -1,
		"terrain": -1,
		"peering": {},
		"display_name": "",
	}


static func _coord_key_to_vector(s: String) -> Vector2i:
	var parts: PackedStringArray = s.split(",")
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


static func _read_vector2i(raw: Variant, fallback: Vector2i) -> Vector2i:
	if typeof(raw) != TYPE_ARRAY:
		return fallback
	var arr: Array = raw
	if arr.size() < 2:
		return fallback
	return Vector2i(int(arr[0]), int(arr[1]))
