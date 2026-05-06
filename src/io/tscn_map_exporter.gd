class_name TscnMapExporter
extends RefCounted

## Exports a MapPage as a Godot 4 .tscn file.
##
## Two modes:
## - REFERENCE_MODE: tilesets imported from a real .tres are referenced via
##   ext_resource at their original res:// path. Zero duplication.
## - BUNDLE_MODE: every tileset is materialized next to the exported scene as
##   a .tres + texture, regardless of origin. Self-contained.
## Overlay objects (image/label/text/sound) are exported as Godot nodes:
## Sprite2D, Label, Label (text-as-label), AudioStreamPlayer2D.

const EXPORT_MODE_REFERENCE: String = "reference"
const EXPORT_MODE_BUNDLE: String = "bundle"

const RES_PREFIX: String = "res://"


class ExportRequest:
	extends RefCounted
	var page: MapPage = null
	var project: Project = null
	var godot_project_root: String = ""
	var output_dir: String = ""
	var output_filename: String = ""
	var mode: String = EXPORT_MODE_REFERENCE
	var tilesets: Dictionary = {}


class ExportResult:
	extends RefCounted
	var ok: bool = false
	var error_message: String = ""
	var written_paths: PackedStringArray = PackedStringArray()


static func export_map(request: ExportRequest) -> ExportResult:
	var result: ExportResult = ExportResult.new()
	if request == null or request.page == null or request.project == null:
		result.error_message = "Missing request data"
		return result
	if request.output_dir == "":
		result.error_message = "Output directory required"
		return result
	if not DirAccess.dir_exists_absolute(request.output_dir):
		var err: Error = DirAccess.make_dir_recursive_absolute(request.output_dir)
		if err != OK:
			result.error_message = "Could not create output directory"
			return result
	var page: MapPage = request.page
	var output_filename: String = request.output_filename
	if output_filename == "":
		output_filename = _safe_filename(page.name) + ".tscn"
	if not output_filename.ends_with(".tscn"):
		output_filename += ".tscn"
	var output_path: String = request.output_dir.path_join(output_filename)
	var tileset_paths: Dictionary = {}
	for tileset_id: String in page.tilesets_used():
		var ts: TileSetResource = request.tilesets.get(tileset_id, null)
		if ts == null:
			continue
		var tres_relative: String = _materialize_tileset(ts, request, result)
		if tres_relative == "":
			continue
		tileset_paths[tileset_id] = tres_relative
	var object_resource_paths: Dictionary = _materialize_object_assets(page, request, result)
	var scene_text: String = _build_scene_text(page, tileset_paths, object_resource_paths, request)
	var f: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if f == null:
		result.error_message = "Could not open output file"
		return result
	f.store_string(scene_text)
	f.close()
	result.written_paths.append(output_path)
	result.ok = true
	return result


static func _materialize_tileset(
	ts: TileSetResource,
	request: ExportRequest,
	result: ExportResult,
) -> String:
	if request.mode == EXPORT_MODE_REFERENCE and ts.origin_kind == "godot_tres" and ts.godot_tres_relative != "":
		return ts.godot_tres_relative
	var safe: String = _safe_filename(ts.name)
	if safe == "":
		safe = "tileset_" + ts.id.substr(0, 8)
	var tres_filename: String = safe + ".tres"
	var tres_dest: String = request.output_dir.path_join(tres_filename)
	if ts.origin_kind == "godot_tres" and ts.godot_tres_text != "":
		var f: FileAccess = FileAccess.open(tres_dest, FileAccess.WRITE)
		if f == null:
			return ""
		f.store_string(ts.godot_tres_text)
		f.close()
		result.written_paths.append(tres_dest)
		var image_dest: String = _copy_godot_referenced_texture(ts, request, result)
		if image_dest != "":
			result.written_paths.append(image_dest)
	else:
		var image_relative: String = _copy_image_local(ts, request, result)
		if image_relative == "":
			return ""
		var tres_text: String = _build_tileset_tres_text(ts, image_relative)
		var f: FileAccess = FileAccess.open(tres_dest, FileAccess.WRITE)
		if f == null:
			return ""
		f.store_string(tres_text)
		f.close()
		result.written_paths.append(tres_dest)
	return _to_res_path(tres_dest, request.godot_project_root, request.output_dir, tres_filename)


static func _copy_image_local(
	ts: TileSetResource,
	request: ExportRequest,
	result: ExportResult,
) -> String:
	if ts.image_asset_name == "":
		return ""
	var src: String = request.project.resolve_tileset_image_path(ts.id, ts.image_asset_name)
	if src == "" or not FileAccess.file_exists(src):
		return ""
	var ext: String = src.get_extension()
	if ext == "":
		ext = "png"
	var dest_filename: String = _safe_filename(ts.name) + "_image." + ext
	var dest: String = request.output_dir.path_join(dest_filename)
	_copy_file(src, dest)
	result.written_paths.append(dest)
	return dest_filename


static func _copy_godot_referenced_texture(
	ts: TileSetResource,
	request: ExportRequest,
	result: ExportResult,
) -> String:
	if request.mode != EXPORT_MODE_BUNDLE:
		return ""
	if ts.image_asset_name == "":
		return ""
	var src: String = request.project.resolve_tileset_image_path(ts.id, ts.image_asset_name)
	if src == "" or not FileAccess.file_exists(src):
		return ""
	var dest_filename: String = src.get_file()
	var dest: String = request.output_dir.path_join(dest_filename)
	_copy_file(src, dest)
	return dest


static func _materialize_object_assets(
	page: MapPage,
	request: ExportRequest,
	result: ExportResult,
) -> Dictionary:
	var out: Dictionary = {}
	for obj_v: Variant in page.objects:
		if typeof(obj_v) != TYPE_DICTIONARY:
			continue
		var obj: Dictionary = obj_v
		var id: String = String(obj.get("id", ""))
		var type_id: String = String(obj.get("type", ""))
		match type_id:
			ItemRegistry.TYPE_IMAGE:
				var asset: String = String(obj.get("asset_name", ""))
				if asset != "":
					var src: String = request.project.resolve_asset_path(asset)
					if FileAccess.file_exists(src):
						var dest_filename: String = "object_" + id.substr(0, 8) + "_" + asset
						var dest: String = request.output_dir.path_join(dest_filename)
						_copy_file(src, dest)
						result.written_paths.append(dest)
						out[id] = dest_filename
			ItemRegistry.TYPE_SOUND:
				var sound_asset: String = String(obj.get("asset_name", ""))
				if sound_asset != "":
					var src: String = request.project.resolve_asset_path(sound_asset)
					if FileAccess.file_exists(src):
						var dest_filename: String = "sound_" + id.substr(0, 8) + "_" + sound_asset
						var dest: String = request.output_dir.path_join(dest_filename)
						_copy_file(src, dest)
						result.written_paths.append(dest)
						out[id] = dest_filename
	return out


static func _build_scene_text(
	page: MapPage,
	tileset_res_paths: Dictionary,
	object_resource_paths: Dictionary,
	request: ExportRequest,
) -> String:
	var ext_resource_lines: Array[String] = []
	var tileset_id_to_ext_id: Dictionary = {}
	var object_id_to_ext_id: Dictionary = {}
	var ext_counter: int = 1
	for tileset_id: String in tileset_res_paths.keys():
		var res_path: String = tileset_res_paths[tileset_id]
		var ext_id: String = "%d_tileset_%s" % [ext_counter, _short(tileset_id)]
		ext_resource_lines.append(
			"[ext_resource type=\"TileSet\" path=\"%s\" id=\"%s\"]" % [res_path, ext_id]
		)
		tileset_id_to_ext_id[tileset_id] = ext_id
		ext_counter += 1
	for obj_v: Variant in page.objects:
		if typeof(obj_v) != TYPE_DICTIONARY:
			continue
		var obj: Dictionary = obj_v
		var id: String = String(obj.get("id", ""))
		var type_id: String = String(obj.get("type", ""))
		if type_id == ItemRegistry.TYPE_IMAGE and object_resource_paths.has(id):
			var rel: String = object_resource_paths[id]
			var res_path: String = _to_res_path(
				request.output_dir.path_join(rel),
				request.godot_project_root,
				request.output_dir,
				rel,
			)
			var ext_id: String = "%d_tex_%s" % [ext_counter, _short(id)]
			ext_resource_lines.append(
				"[ext_resource type=\"Texture2D\" path=\"%s\" id=\"%s\"]" % [res_path, ext_id]
			)
			object_id_to_ext_id[id] = ext_id
			ext_counter += 1
		elif type_id == ItemRegistry.TYPE_SOUND and object_resource_paths.has(id):
			var rel: String = object_resource_paths[id]
			var res_path: String = _to_res_path(
				request.output_dir.path_join(rel),
				request.godot_project_root,
				request.output_dir,
				rel,
			)
			var ext_id: String = "%d_aud_%s" % [ext_counter, _short(id)]
			var stream_type: String = _audio_stream_type_for(rel)
			ext_resource_lines.append(
				"[ext_resource type=\"%s\" path=\"%s\" id=\"%s\"]" % [stream_type, res_path, ext_id]
			)
			object_id_to_ext_id[id] = ext_id
			ext_counter += 1
	var load_steps: int = ext_resource_lines.size() + 1
	var lines: Array[String] = []
	lines.append("[gd_scene load_steps=%d format=3]" % load_steps)
	lines.append("")
	for line: String in ext_resource_lines:
		lines.append(line)
		lines.append("")
	var root_name: String = _safe_node_name(page.name)
	if root_name == "":
		root_name = "Map"
	lines.append("[node name=\"%s\" type=\"Node2D\"]" % root_name)
	lines.append("")
	for layer: MapLayer in page.layers:
		_append_tile_map_layer_lines(lines, layer, tileset_id_to_ext_id)
	for obj_v: Variant in page.objects:
		if typeof(obj_v) != TYPE_DICTIONARY:
			continue
		_append_overlay_node_lines(lines, obj_v as Dictionary, object_id_to_ext_id)
	return "\n".join(lines) + "\n"


static func _append_tile_map_layer_lines(
	lines: Array[String],
	layer: MapLayer,
	tileset_id_to_ext_id: Dictionary,
) -> void:
	var layer_name: String = _safe_node_name(layer.name)
	if layer_name == "":
		layer_name = "Layer"
	lines.append("[node name=\"%s\" type=\"TileMapLayer\" parent=\".\"]" % layer_name)
	if not layer.visible:
		lines.append("visible = false")
	if abs(layer.opacity - 1.0) > 0.001 or layer.modulate_color != Color(1, 1, 1, 1):
		var modulate: Color = Color(
			layer.modulate_color.r,
			layer.modulate_color.g,
			layer.modulate_color.b,
			layer.modulate_color.a * layer.opacity,
		)
		lines.append("modulate = Color(%f, %f, %f, %f)" % [modulate.r, modulate.g, modulate.b, modulate.a])
	if layer.z_index != 0:
		lines.append("z_index = %d" % layer.z_index)
	var ext_id: String = String(tileset_id_to_ext_id.get(layer.tileset_id, ""))
	if ext_id != "":
		lines.append("tile_set = ExtResource(\"%s\")" % ext_id)
	lines.append("tile_map_data = " + _encode_tile_map_data(layer))
	lines.append("")


static func _append_overlay_node_lines(
	lines: Array[String],
	obj: Dictionary,
	object_id_to_ext_id: Dictionary,
) -> void:
	var id: String = String(obj.get("id", ""))
	var type_id: String = String(obj.get("type", ""))
	var pos_raw: Variant = obj.get("position", [0, 0])
	var size_raw: Variant = obj.get("size", [128, 128])
	var pos: Vector2 = Vector2.ZERO
	if typeof(pos_raw) == TYPE_ARRAY and (pos_raw as Array).size() >= 2:
		var arr: Array = pos_raw
		pos = Vector2(float(arr[0]), float(arr[1]))
	var sz: Vector2 = Vector2(128, 128)
	if typeof(size_raw) == TYPE_ARRAY and (size_raw as Array).size() >= 2:
		var arr: Array = size_raw
		sz = Vector2(float(arr[0]), float(arr[1]))
	var node_name: String = _safe_node_name(_object_node_name(obj, id))
	match type_id:
		ItemRegistry.TYPE_IMAGE:
			var ext_id: String = String(object_id_to_ext_id.get(id, ""))
			lines.append("[node name=\"%s\" type=\"Sprite2D\" parent=\".\"]" % node_name)
			lines.append("position = Vector2(%f, %f)" % [pos.x + sz.x * 0.5, pos.y + sz.y * 0.5])
			if ext_id != "":
				lines.append("texture = ExtResource(\"%s\")" % ext_id)
				lines.append("centered = true")
			lines.append("")
		ItemRegistry.TYPE_LABEL, ItemRegistry.TYPE_TEXT:
			var text_value: String = String(obj.get("text", ""))
			lines.append("[node name=\"%s\" type=\"Label\" parent=\".\"]" % node_name)
			lines.append("offset_left = %f" % pos.x)
			lines.append("offset_top = %f" % pos.y)
			lines.append("offset_right = %f" % (pos.x + sz.x))
			lines.append("offset_bottom = %f" % (pos.y + sz.y))
			lines.append("text = \"%s\"" % _escape_string(text_value))
			lines.append("")
		ItemRegistry.TYPE_RICH_TEXT:
			var bbcode_value: String = String(obj.get("bbcode_text", ""))
			lines.append("[node name=\"%s\" type=\"RichTextLabel\" parent=\".\"]" % node_name)
			lines.append("offset_left = %f" % pos.x)
			lines.append("offset_top = %f" % pos.y)
			lines.append("offset_right = %f" % (pos.x + sz.x))
			lines.append("offset_bottom = %f" % (pos.y + sz.y))
			lines.append("bbcode_enabled = true")
			lines.append("text = \"%s\"" % _escape_string(bbcode_value))
			lines.append("")
		ItemRegistry.TYPE_SOUND:
			var ext_id_a: String = String(object_id_to_ext_id.get(id, ""))
			lines.append("[node name=\"%s\" type=\"AudioStreamPlayer2D\" parent=\".\"]" % node_name)
			lines.append("position = Vector2(%f, %f)" % [pos.x + sz.x * 0.5, pos.y + sz.y * 0.5])
			if ext_id_a != "":
				lines.append("stream = ExtResource(\"%s\")" % ext_id_a)
			lines.append("")


static func _object_node_name(obj: Dictionary, id: String) -> String:
	var type_id: String = String(obj.get("type", ""))
	match type_id:
		ItemRegistry.TYPE_LABEL, ItemRegistry.TYPE_TEXT:
			var t: String = String(obj.get("text", ""))
			if t.strip_edges() != "":
				return t.substr(0, 24)
		ItemRegistry.TYPE_IMAGE:
			return "Image_" + id.substr(0, 6)
		ItemRegistry.TYPE_SOUND:
			return "Sound_" + id.substr(0, 6)
		ItemRegistry.TYPE_RICH_TEXT:
			return "RichText_" + id.substr(0, 6)
	return type_id.capitalize() + "_" + id.substr(0, 6)


static func _encode_tile_map_data(layer: MapLayer) -> String:
	var sb: PackedStringArray = PackedStringArray()
	sb.append("PackedByteArray(")
	var first: bool = true
	var coords: Array = layer.cells.keys()
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	for coord_v: Variant in coords:
		var coord: Vector2i = coord_v
		var data: Vector3i = layer.cells[coord]
		var bytes: Array = _encode_cell_bytes(coord.x, coord.y, 0, data.x, data.y, data.z)
		for b: int in bytes:
			if first:
				sb.append("%d" % b)
				first = false
			else:
				sb.append(", %d" % b)
	sb.append(")")
	return "".join(sb)


static func _encode_cell_bytes(
	x: int,
	y: int,
	source_id: int,
	atlas_x: int,
	atlas_y: int,
	alternative: int,
) -> Array:
	var out: Array = []
	_append_int16_le(out, x)
	_append_int16_le(out, y)
	_append_int16_le(out, source_id)
	_append_uint16_le(out, atlas_x)
	_append_uint16_le(out, atlas_y)
	_append_uint16_le(out, alternative)
	return out


static func _append_int16_le(out: Array, value: int) -> void:
	var v: int = value
	if v < 0:
		v = v + 65536
	out.append(v & 0xff)
	out.append((v >> 8) & 0xff)


static func _append_uint16_le(out: Array, value: int) -> void:
	var v: int = value & 0xffff
	out.append(v & 0xff)
	out.append((v >> 8) & 0xff)


static func _build_tileset_tres_text(ts: TileSetResource, image_relative: String) -> String:
	var lines: Array[String] = []
	lines.append("[gd_resource type=\"TileSet\" load_steps=2 format=3]")
	lines.append("")
	lines.append("[ext_resource type=\"Texture2D\" path=\"%s\" id=\"1_tex\"]" % image_relative)
	lines.append("")
	lines.append("[sub_resource type=\"TileSetAtlasSource\" id=\"TileSetAtlasSource_main\"]")
	lines.append("texture = ExtResource(\"1_tex\")")
	lines.append("margins = Vector2i(%d, %d)" % [ts.margins.x, ts.margins.y])
	lines.append("separation = Vector2i(%d, %d)" % [ts.separation.x, ts.separation.y])
	lines.append("texture_region_size = Vector2i(%d, %d)" % [ts.tile_size.x, ts.tile_size.y])
	var coords: Array = ts.atlas_tiles.keys()
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	for coord_v: Variant in coords:
		var coord: Vector2i = coord_v
		var entry: Dictionary = ts.atlas_tiles[coord]
		lines.append("%d:%d/0 = 0" % [coord.x, coord.y])
		var t_set: int = int(entry.get("terrain_set", -1))
		var t_idx: int = int(entry.get("terrain", -1))
		if t_set >= 0:
			lines.append("%d:%d/0/terrain_set = %d" % [coord.x, coord.y, t_set])
		if t_idx >= 0:
			lines.append("%d:%d/0/terrain = %d" % [coord.x, coord.y, t_idx])
		var peering_v: Variant = entry.get("peering", {})
		if typeof(peering_v) == TYPE_DICTIONARY:
			var peering: Dictionary = peering_v
			for direction_v: Variant in peering.keys():
				var direction: String = String(direction_v)
				var bit_value: int = int(peering[direction_v])
				lines.append(
					"%d:%d/0/terrains_peering_bit/%s = %d" % [coord.x, coord.y, direction, bit_value]
				)
	lines.append("")
	lines.append("[resource]")
	lines.append("tile_size = Vector2i(%d, %d)" % [ts.tile_size.x, ts.tile_size.y])
	for ts_idx in range(ts.terrain_sets.size()):
		var ts_entry: Dictionary = ts.terrain_sets[ts_idx]
		lines.append("terrain_set_%d/mode = %d" % [ts_idx, int(ts_entry.get("mode", 0))])
		var terrains: Array = ts_entry.get("terrains", [])
		for t_i in range(terrains.size()):
			var terrain: Dictionary = terrains[t_i]
			lines.append(
				"terrain_set_%d/terrains/%d/name = \"%s\"" % [ts_idx, t_i, _escape_string(String(terrain.get("name", "")))]
			)
			var color_arr: Variant = terrain.get("color", [1.0, 1.0, 1.0, 1.0])
			var color: Color = Color(1, 1, 1, 1)
			if typeof(color_arr) == TYPE_ARRAY and (color_arr as Array).size() >= 3:
				var arr: Array = color_arr
				var a: float = 1.0 if arr.size() < 4 else float(arr[3])
				color = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
			lines.append(
				"terrain_set_%d/terrains/%d/color = Color(%f, %f, %f, %f)" % [ts_idx, t_i, color.r, color.g, color.b, color.a]
			)
	lines.append("sources/0 = SubResource(\"TileSetAtlasSource_main\")")
	return "\n".join(lines) + "\n"


static func _to_res_path(
	absolute_path: String,
	godot_project_root: String,
	output_dir: String,
	fallback_relative: String,
) -> String:
	if godot_project_root != "" and absolute_path.begins_with(godot_project_root):
		var rel: String = absolute_path.substr(godot_project_root.length()).lstrip("/").lstrip("\\")
		rel = rel.replace("\\", "/")
		return RES_PREFIX + rel
	return RES_PREFIX + fallback_relative.replace("\\", "/")


static func _safe_filename(s: String) -> String:
	var out: String = s.strip_edges()
	var bad: Array = ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]
	for b: String in bad:
		out = out.replace(b, "_")
	out = out.replace(" ", "_")
	if out == "":
		out = "untitled"
	return out


static func _safe_node_name(s: String) -> String:
	var out: String = s.strip_edges()
	var bad: Array = ["<", ">", ":", "\"", "/", "\\", "|", "?", "*", ".", "@", "%", "$", "#", "(", ")", "[", "]", "{", "}", "&", "+"]
	for b: String in bad:
		out = out.replace(b, "_")
	out = out.replace(" ", "_")
	if out == "":
		out = "Node"
	return out


static func _audio_stream_type_for(relative_path: String) -> String:
	var lower: String = relative_path.to_lower()
	if lower.ends_with(".ogg"):
		return "AudioStreamOggVorbis"
	if lower.ends_with(".mp3"):
		return "AudioStreamMP3"
	return "AudioStreamWAV"


static func _escape_string(s: String) -> String:
	var out: String = s
	out = out.replace("\\", "\\\\")
	out = out.replace("\"", "\\\"")
	out = out.replace("\n", "\\n")
	out = out.replace("\r", "")
	out = out.replace("\t", "\\t")
	return out


static func _short(id: String) -> String:
	if id.length() <= 8:
		return id.replace("-", "")
	return id.substr(0, 8).replace("-", "")


static func _copy_file(src: String, dst: String) -> void:
	var src_f: FileAccess = FileAccess.open(src, FileAccess.READ)
	if src_f == null:
		return
	var bytes: PackedByteArray = src_f.get_buffer(src_f.get_length())
	src_f.close()
	var dst_f: FileAccess = FileAccess.open(dst, FileAccess.WRITE)
	if dst_f == null:
		return
	dst_f.store_buffer(bytes)
	dst_f.close()
