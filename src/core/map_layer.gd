class_name MapLayer
extends RefCounted

## A single tile-paintable layer on a MapPage. Each layer references one
## TileSetResource and stores its painted cells in a Dictionary keyed by
## Vector2i grid coordinates.

var id: String = ""
var name: String = "Layer"
var tileset_id: String = ""
var z_index: int = 0
var opacity: float = 1.0
var visible: bool = true
var locked: bool = false
var modulate_color: Color = Color(1, 1, 1, 1)
var cells: Dictionary = {}


static func make_new(layer_id: String, layer_name: String) -> MapLayer:
	var l: MapLayer = MapLayer.new()
	l.id = layer_id
	l.name = layer_name
	return l


static func from_dict(d: Dictionary) -> MapLayer:
	var l: MapLayer = MapLayer.new()
	l.id = String(d.get("id", ""))
	l.name = String(d.get("name", "Layer"))
	l.tileset_id = String(d.get("tileset_id", ""))
	l.z_index = int(d.get("z_index", 0))
	l.opacity = float(d.get("opacity", 1.0))
	l.visible = bool(d.get("visible", true))
	l.locked = bool(d.get("locked", false))
	var mod_raw: Variant = d.get("modulate", null)
	if typeof(mod_raw) == TYPE_ARRAY and (mod_raw as Array).size() >= 3:
		var arr: Array = mod_raw
		var a: float = 1.0 if arr.size() < 4 else float(arr[3])
		l.modulate_color = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
	var cells_raw: Variant = d.get("cells", [])
	l.cells.clear()
	if typeof(cells_raw) == TYPE_ARRAY:
		for entry_v: Variant in (cells_raw as Array):
			if typeof(entry_v) != TYPE_ARRAY:
				continue
			var arr: Array = entry_v
			if arr.size() < 4:
				continue
			var coord: Vector2i = Vector2i(int(arr[0]), int(arr[1]))
			var atlas_x: int = int(arr[2])
			var atlas_y: int = int(arr[3])
			var alt: int = int(arr[4]) if arr.size() > 4 else 0
			l.cells[coord] = Vector3i(atlas_x, atlas_y, alt)
	return l


func to_dict() -> Dictionary:
	var cells_out: Array = []
	var coords: Array = cells.keys()
	coords.sort_custom(_compare_coords)
	for coord_v: Variant in coords:
		var coord: Vector2i = coord_v
		var data: Vector3i = cells[coord]
		cells_out.append([coord.x, coord.y, data.x, data.y, data.z])
	return {
		"id": id,
		"name": name,
		"tileset_id": tileset_id,
		"z_index": z_index,
		"opacity": opacity,
		"visible": visible,
		"locked": locked,
		"modulate": [
			modulate_color.r,
			modulate_color.g,
			modulate_color.b,
			modulate_color.a,
		],
		"cells": cells_out,
	}


static func _compare_coords(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


func has_cell(coord: Vector2i) -> bool:
	return cells.has(coord)


func get_cell(coord: Vector2i) -> Vector3i:
	if not cells.has(coord):
		return Vector3i(-1, -1, 0)
	return cells[coord]


func set_cell(coord: Vector2i, atlas_coord: Vector2i, alternative: int) -> void:
	cells[coord] = Vector3i(atlas_coord.x, atlas_coord.y, alternative)


func erase_cell(coord: Vector2i) -> void:
	cells.erase(coord)


func used_rect() -> Rect2i:
	if cells.is_empty():
		return Rect2i(0, 0, 0, 0)
	var min_x: int = 2147483647
	var min_y: int = 2147483647
	var max_x: int = -2147483648
	var max_y: int = -2147483648
	for coord_v: Variant in cells.keys():
		var coord: Vector2i = coord_v
		min_x = min(min_x, coord.x)
		min_y = min(min_y, coord.y)
		max_x = max(max_x, coord.x)
		max_y = max(max_y, coord.y)
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))
