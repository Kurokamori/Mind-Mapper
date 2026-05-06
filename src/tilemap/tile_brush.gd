class_name TileBrush
extends RefCounted

## Holds the user's currently-selected painting state: tool, source tileset,
## chosen tile (or terrain), and tile-layer target.

const MODE_NONE: String = "none"
const MODE_ATLAS_TILE: String = "atlas_tile"
const MODE_TERRAIN: String = "terrain"

const TOOL_PAINT: String = "paint"
const TOOL_ERASE: String = "erase"
const TOOL_FILL: String = "fill"
const TOOL_RECT: String = "rect"
const TOOL_PICK: String = "pick"
const TOOL_SELECT: String = "select"

var tool: String = TOOL_PAINT
var mode: String = MODE_NONE
var tileset_id: String = ""
var atlas_coord: Vector2i = Vector2i(-1, -1)
var alternative: int = 0
var terrain_set: int = -1
var terrain_index: int = -1


func clear() -> void:
	mode = MODE_NONE
	tileset_id = ""
	atlas_coord = Vector2i(-1, -1)
	alternative = 0
	terrain_set = -1
	terrain_index = -1


func set_atlas_tile(p_tileset_id: String, coord: Vector2i, alt: int) -> void:
	mode = MODE_ATLAS_TILE
	tileset_id = p_tileset_id
	atlas_coord = coord
	alternative = alt
	terrain_set = -1
	terrain_index = -1


func set_terrain(p_tileset_id: String, ts_idx: int, t_idx: int) -> void:
	mode = MODE_TERRAIN
	tileset_id = p_tileset_id
	atlas_coord = Vector2i(-1, -1)
	alternative = 0
	terrain_set = ts_idx
	terrain_index = t_idx


func is_paintable() -> bool:
	return mode != MODE_NONE
