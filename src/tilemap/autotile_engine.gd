class_name AutotileEngine
extends RefCounted

## Terrain-bitmask matcher that mirrors Godot 4's TileSet terrain logic.
##
## Given a TileSetResource and a target cell whose neighbours' terrains are
## known, picks the best-fitting tile from that terrain. Supports the three
## square-tile modes:
##   - MATCH_CORNERS_AND_SIDES (mode 0)
##   - MATCH_CORNERS (mode 1)
##   - MATCH_SIDES (mode 2)

const TERRAIN_NONE: int = -1


class CellSnapshot:
	extends RefCounted
	var atlas_coord: Vector2i = Vector2i(-1, -1)
	var alternative: int = 0
	var has_value: bool = false


static func neighbor_offset(direction: String) -> Vector2i:
	match direction:
		"right_side": return Vector2i(1, 0)
		"right_corner": return Vector2i(1, 0)
		"bottom_right_side": return Vector2i(1, 1)
		"bottom_right_corner": return Vector2i(1, 1)
		"bottom_side": return Vector2i(0, 1)
		"bottom_corner": return Vector2i(0, 1)
		"bottom_left_side": return Vector2i(-1, 1)
		"bottom_left_corner": return Vector2i(-1, 1)
		"left_side": return Vector2i(-1, 0)
		"left_corner": return Vector2i(-1, 0)
		"top_left_side": return Vector2i(-1, -1)
		"top_left_corner": return Vector2i(-1, -1)
		"top_side": return Vector2i(0, -1)
		"top_corner": return Vector2i(0, -1)
		"top_right_side": return Vector2i(1, -1)
		"top_right_corner": return Vector2i(1, -1)
	return Vector2i.ZERO


## terrain_at: Callable(Vector2i) -> int  (returns the terrain index for a
##     neighbour cell painted with terrain_set; or TERRAIN_NONE if empty / wrong set)
static func pick_tile_for_terrain(
	tileset: TileSetResource,
	terrain_set: int,
	terrain: int,
	target_coord: Vector2i,
	terrain_at: Callable,
) -> Vector2i:
	if tileset == null:
		return Vector2i(-1, -1)
	if terrain_set < 0 or terrain < 0:
		return Vector2i(-1, -1)
	var directions: Array[String] = tileset.relevant_peering_directions(terrain_set)
	var required: Dictionary = {}
	for direction: String in directions:
		var off: Vector2i = neighbor_offset(direction)
		var nbr: Vector2i = target_coord + off
		var nbr_terrain: int = TERRAIN_NONE
		if terrain_at.is_valid():
			var raw: Variant = terrain_at.call(nbr)
			if typeof(raw) == TYPE_INT:
				nbr_terrain = int(raw)
		required[direction] = nbr_terrain
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: int = -100000
	for coord_v: Variant in tileset.atlas_tiles.keys():
		var coord: Vector2i = coord_v
		var ts_idx: int = tileset.tile_terrain_set(coord)
		var t_idx: int = tileset.tile_terrain(coord)
		if ts_idx != terrain_set:
			continue
		if t_idx != terrain:
			continue
		var score: int = _score_match(tileset, coord, terrain, required, directions)
		if score > best_score:
			best_score = score
			best = coord
	return best


static func _score_match(
	tileset: TileSetResource,
	coord: Vector2i,
	terrain: int,
	required: Dictionary,
	directions: Array[String],
) -> int:
	var peering: Dictionary = tileset.tile_peering(coord)
	var score: int = 0
	for direction: String in directions:
		var required_value: int = int(required.get(direction, TERRAIN_NONE))
		var actual_value: int = TERRAIN_NONE
		if peering.has(direction):
			actual_value = int(peering[direction])
		var resolved_required: int = required_value
		if resolved_required == TERRAIN_NONE:
			resolved_required = terrain
		if actual_value == resolved_required:
			score += 4
		elif actual_value == terrain and resolved_required == TERRAIN_NONE:
			score += 2
		else:
			score -= 3
	return score


static func snapshot_layer_terrains(
	layer: MapLayer,
	tileset: TileSetResource,
	terrain_set: int,
) -> Dictionary:
	var out: Dictionary = {}
	if layer == null or tileset == null:
		return out
	for coord_v: Variant in layer.cells.keys():
		var coord: Vector2i = coord_v
		var data: Vector3i = layer.cells[coord]
		var atlas_coord: Vector2i = Vector2i(data.x, data.y)
		if not tileset.has_tile(atlas_coord):
			continue
		var ts_idx: int = tileset.tile_terrain_set(atlas_coord)
		if ts_idx != terrain_set:
			continue
		out[coord] = tileset.tile_terrain(atlas_coord)
	return out


static func collect_neighbours(target_coord: Vector2i) -> Array:
	var out: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			out.append(target_coord + Vector2i(dx, dy))
	return out


static func neighbours_and_self(target_coord: Vector2i) -> Array:
	var out: Array = collect_neighbours(target_coord)
	out.append(target_coord)
	return out
