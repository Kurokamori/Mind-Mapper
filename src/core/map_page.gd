class_name MapPage
extends RefCounted

## A 2D grid-based page that paints tiles from one or more TileSetResources
## and overlays existing board-item nodes (image, label, text, sound, etc.)
## at world coordinates above the grid.

const DEFAULT_TILE_SIZE: Vector2i = Vector2i(16, 16)
const DEFAULT_BG_COLOR: Color = Color(0.085, 0.08, 0.105, 1.0)

var id: String = ""
var name: String = "Map"
var tile_size: Vector2i = DEFAULT_TILE_SIZE
var background_color: Color = DEFAULT_BG_COLOR
var layers: Array = []
var objects: Array = []
var camera_position: Vector2 = Vector2.ZERO
var camera_zoom: float = 1.0


static func make_new(map_id: String, map_name: String, tile_size_: Vector2i) -> MapPage:
	var m: MapPage = MapPage.new()
	m.id = map_id
	m.name = map_name
	m.tile_size = tile_size_
	var first_layer: MapLayer = MapLayer.make_new(Uuid.v4(), "Tiles")
	m.layers.append(first_layer)
	return m


static func from_dict(d: Dictionary) -> MapPage:
	var m: MapPage = MapPage.new()
	m.id = String(d.get("id", ""))
	m.name = String(d.get("name", "Map"))
	var ts_raw: Variant = d.get("tile_size", null)
	if typeof(ts_raw) == TYPE_ARRAY and (ts_raw as Array).size() >= 2:
		var arr: Array = ts_raw
		m.tile_size = Vector2i(int(arr[0]), int(arr[1]))
	var bg_raw: Variant = d.get("background_color", null)
	if typeof(bg_raw) == TYPE_ARRAY and (bg_raw as Array).size() >= 3:
		var arr_bg: Array = bg_raw
		var a: float = 1.0 if arr_bg.size() < 4 else float(arr_bg[3])
		m.background_color = Color(float(arr_bg[0]), float(arr_bg[1]), float(arr_bg[2]), a)
	var layers_raw: Variant = d.get("layers", [])
	m.layers.clear()
	if typeof(layers_raw) == TYPE_ARRAY:
		for entry_v: Variant in (layers_raw as Array):
			if typeof(entry_v) == TYPE_DICTIONARY:
				m.layers.append(MapLayer.from_dict(entry_v))
	var objects_raw: Variant = d.get("objects", [])
	m.objects.clear()
	if typeof(objects_raw) == TYPE_ARRAY:
		m.objects = (objects_raw as Array).duplicate(true)
	var cam_raw: Variant = d.get("camera_position", null)
	if typeof(cam_raw) == TYPE_ARRAY and (cam_raw as Array).size() >= 2:
		var arr_cam: Array = cam_raw
		m.camera_position = Vector2(float(arr_cam[0]), float(arr_cam[1]))
	m.camera_zoom = float(d.get("camera_zoom", 1.0))
	return m


func to_dict() -> Dictionary:
	var layer_dicts: Array = []
	for l: MapLayer in layers:
		layer_dicts.append(l.to_dict())
	return {
		"id": id,
		"name": name,
		"tile_size": [tile_size.x, tile_size.y],
		"background_color": [
			background_color.r,
			background_color.g,
			background_color.b,
			background_color.a,
		],
		"layers": layer_dicts,
		"objects": objects.duplicate(true),
		"camera_position": [camera_position.x, camera_position.y],
		"camera_zoom": camera_zoom,
	}


func find_layer(layer_id: String) -> MapLayer:
	for l: MapLayer in layers:
		if l.id == layer_id:
			return l
	return null


func layer_index_of(layer_id: String) -> int:
	for i in range(layers.size()):
		var l: MapLayer = layers[i]
		if l.id == layer_id:
			return i
	return -1


func tilesets_used() -> Array[String]:
	var seen: Dictionary = {}
	var out: Array[String] = []
	for l: MapLayer in layers:
		if l.tileset_id != "" and not seen.has(l.tileset_id):
			seen[l.tileset_id] = true
			out.append(l.tileset_id)
	return out


func remove_layer(layer_id: String) -> bool:
	var idx: int = layer_index_of(layer_id)
	if idx < 0:
		return false
	layers.remove_at(idx)
	return true


func move_layer(layer_id: String, new_index: int) -> bool:
	var idx: int = layer_index_of(layer_id)
	if idx < 0:
		return false
	var clamped: int = clamp(new_index, 0, layers.size() - 1)
	if clamped == idx:
		return false
	var l: MapLayer = layers[idx]
	layers.remove_at(idx)
	layers.insert(clamped, l)
	return true
