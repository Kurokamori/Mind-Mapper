class_name TilesetImporter
extends RefCounted

## Project-level helpers that turn a Godot 4 TileSet (.tres) or a raw atlas image
## into a TileSetResource owned by the Project. Used by both the board editor
## and the tilemap editor so neither owns the format-specific logic.

const _TILE_SUBRESOURCE_TYPE: String = "TileSetAtlasSource"


class ImportResult:
	extends RefCounted
	var ok: bool = false
	var error_message: String = ""
	var tileset: TileSetResource = null
	var tile_count: int = 0


static func import_from_tres(project: Project, tileset_name: String, tres_path: String, godot_project_root: String) -> ImportResult:
	var result: ImportResult = ImportResult.new()
	if project == null:
		result.error_message = "No project open."
		return result
	if tres_path.strip_edges() == "":
		result.error_message = "Tileset path is empty."
		return result
	if not FileAccess.file_exists(tres_path):
		result.error_message = "Tileset file does not exist."
		return result
	var f: FileAccess = FileAccess.open(tres_path, FileAccess.READ)
	if f == null:
		result.error_message = "Could not open .tres file."
		return result
	var raw: String = f.get_as_text()
	f.close()
	var parse: TresTilesetParser.ParseResult = TresTilesetParser.parse_text(raw, tres_path.get_base_dir())
	if not parse.ok:
		result.error_message = "Failed to parse .tres: " + parse.error_message
		return result
	var ts: TileSetResource = parse.tileset
	if ts == null:
		result.error_message = "Parsed tileset was empty."
		return result
	ts.id = Uuid.v4()
	ts.name = _coalesce_name(tileset_name, "Tileset")
	ts.origin_kind = "godot_tres"
	ts.godot_tres_text = raw
	ts.godot_tres_relative = _to_res_path(tres_path, godot_project_root)
	var image_relative: String = _find_first_atlas_image_relative(parse)
	if image_relative.begins_with("res://") and godot_project_root.strip_edges() != "":
		var image_abs: String = godot_project_root.path_join(image_relative.substr(6))
		if FileAccess.file_exists(image_abs):
			var copied: String = project.copy_image_into_tileset(ts.id, image_abs)
			if copied != "":
				ts.image_asset_name = copied
				var img: Image = Image.load_from_file(image_abs)
				if img != null:
					ts.recompute_atlas_dimensions(img.get_width(), img.get_height())
	if ts.atlas_columns == 0 or ts.atlas_rows == 0:
		var max_x: int = 0
		var max_y: int = 0
		for coord_v: Variant in ts.atlas_tiles.keys():
			var coord: Vector2i = coord_v
			max_x = max(max_x, coord.x)
			max_y = max(max_y, coord.y)
		ts.atlas_columns = max_x + 1
		ts.atlas_rows = max_y + 1
	var write_err: Error = project.write_tileset(ts)
	if write_err != OK:
		result.error_message = "Failed to write tileset (error %d)." % int(write_err)
		return result
	_broadcast_tileset_create(ts)
	result.ok = true
	result.tileset = ts
	result.tile_count = ts.atlas_tiles.size()
	return result


static func create_from_image(
	project: Project,
	tileset_name: String,
	image_source_path: String,
	tile_size: Vector2i,
	margins: Vector2i,
	separation: Vector2i,
) -> ImportResult:
	var result: ImportResult = ImportResult.new()
	if project == null:
		result.error_message = "No project open."
		return result
	if image_source_path.strip_edges() == "":
		result.error_message = "Image path is empty."
		return result
	if not FileAccess.file_exists(image_source_path):
		result.error_message = "Image file does not exist."
		return result
	var safe_tile_size: Vector2i = tile_size
	if safe_tile_size.x <= 0 or safe_tile_size.y <= 0:
		safe_tile_size = Vector2i(16, 16)
	var ts: TileSetResource = TileSetResource.make_new(Uuid.v4(), _coalesce_name(tileset_name, "Tileset"))
	ts.origin_kind = "image"
	ts.tile_size = safe_tile_size
	ts.margins = margins
	ts.separation = separation
	var copied: String = project.copy_image_into_tileset(ts.id, image_source_path)
	if copied == "":
		result.error_message = "Could not copy image into project."
		return result
	ts.image_asset_name = copied
	var img: Image = Image.load_from_file(image_source_path)
	if img == null:
		result.error_message = "Could not read image dimensions."
		return result
	ts.recompute_atlas_dimensions(img.get_width(), img.get_height())
	for y: int in range(ts.atlas_rows):
		for x: int in range(ts.atlas_columns):
			ts.ensure_tile(Vector2i(x, y))
	var write_err: Error = project.write_tileset(ts)
	if write_err != OK:
		result.error_message = "Failed to write tileset (error %d)." % int(write_err)
		return result
	_broadcast_tileset_create(ts)
	result.ok = true
	result.tileset = ts
	result.tile_count = ts.atlas_tiles.size()
	return result


static func _broadcast_tileset_create(ts: TileSetResource) -> void:
	if ts == null or ts.id == "":
		return
	if not OpBus.has_project() or OpBus.is_applying_remote():
		return
	OpBus.record_local_change(OpKinds.CREATE_TILESET, {
		"tileset_id": ts.id,
		"tileset": ts.to_dict(),
	}, "")


static func _find_first_atlas_image_relative(parse: TresTilesetParser.ParseResult) -> String:
	for sub_id_v: Variant in parse.sub_resources.keys():
		var sub_v: Variant = parse.sub_resources[sub_id_v]
		if typeof(sub_v) != TYPE_DICTIONARY:
			continue
		var sub: Dictionary = sub_v
		if String(sub.get("type", "")) != _TILE_SUBRESOURCE_TYPE:
			continue
		var props: Dictionary = sub.get("props", {})
		var tex_ref: String = String(props.get("texture", ""))
		var ext_id: String = _parse_ext_id(tex_ref)
		if ext_id == "":
			continue
		if not parse.ext_resources.has(ext_id):
			continue
		var ext_entry_v: Variant = parse.ext_resources[ext_id]
		if typeof(ext_entry_v) != TYPE_DICTIONARY:
			continue
		var ext_entry: Dictionary = ext_entry_v
		var p: String = String(ext_entry.get("path", ""))
		if p != "":
			return p
	return ""


static func _to_res_path(absolute: String, godot_root: String) -> String:
	if godot_root.strip_edges() == "":
		return ""
	if absolute.begins_with(godot_root):
		var rel: String = absolute.substr(godot_root.length()).lstrip("/").lstrip("\\")
		rel = rel.replace("\\", "/")
		return "res://" + rel
	return ""


static func _parse_ext_id(value: String) -> String:
	var trimmed: String = value.strip_edges()
	if not trimmed.begins_with("ExtResource("):
		return ""
	var inner: String = trimmed.substr("ExtResource(".length(), trimmed.length() - "ExtResource(".length() - 1)
	if inner.begins_with("\"") and inner.ends_with("\""):
		return inner.substr(1, inner.length() - 2)
	return inner


static func _coalesce_name(value: String, fallback: String) -> String:
	var s: String = value.strip_edges()
	return s if s != "" else fallback
