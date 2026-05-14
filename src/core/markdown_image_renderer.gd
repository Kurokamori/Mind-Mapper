class_name MarkdownImageRenderer
extends RefCounted

const ASSET_SCHEME: String = "asset://"
const FILE_SCHEME: String = "file://"
const MISSING_IMAGE_TEMPLATE: String = "[i][color=#c97a7a]\\[image unavailable: %s\\][/color][/i]"


static func render_bbcode_with_images(label: RichTextLabel, bbcode: String, document_dir: String = "", max_width: int = 0) -> void:
	if label == null:
		return
	label.clear()
	if bbcode == "":
		return
	var regex: RegEx = RegEx.new()
	if regex.compile("\\[img(?:=([^\\]]+))?\\]([^\\[]+)\\[/img\\]") != OK:
		label.append_text(bbcode)
		return
	var matches: Array = regex.search_all(bbcode)
	if matches.is_empty():
		label.append_text(bbcode)
		return
	var cursor: int = 0
	for m: RegExMatch in matches:
		var before: String = bbcode.substr(cursor, m.get_start() - cursor)
		if before != "":
			label.append_text(before)
		var size_spec: String = m.get_string(1)
		var raw_path: String = m.get_string(2).strip_edges()
		var texture: Texture2D = resolve_texture(raw_path, document_dir)
		if texture != null:
			var width: int = 0
			var height: int = 0
			if size_spec != "":
				var parsed: Vector2i = _parse_size_spec(size_spec)
				width = parsed.x
				height = parsed.y
			if width <= 0 and height <= 0 and max_width > 0:
				var native_size: Vector2i = texture.get_size()
				if native_size.x > max_width:
					width = max_width
			if width > 0 or height > 0:
				label.add_image(texture, width, height)
			else:
				label.add_image(texture)
		else:
			label.append_text(MISSING_IMAGE_TEMPLATE % raw_path)
		cursor = m.get_end()
	var tail: String = bbcode.substr(cursor, bbcode.length() - cursor)
	if tail != "":
		label.append_text(tail)


static func resolve_texture(raw_path: String, document_dir: String = "") -> Texture2D:
	if raw_path == "":
		return null
	if raw_path.begins_with("res://") or raw_path.begins_with("user://"):
		var res: Resource = ResourceLoader.load(raw_path)
		if res is Texture2D:
			return res
		return null
	if raw_path.begins_with("http://") or raw_path.begins_with("https://"):
		return null
	var absolute_path: String = _to_absolute_path(raw_path, document_dir)
	if absolute_path == "":
		return null
	if not FileAccess.file_exists(absolute_path):
		return null
	var img: Image = _load_image_from_disk(absolute_path)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)


static func _to_absolute_path(raw_path: String, document_dir: String) -> String:
	if raw_path.begins_with(ASSET_SCHEME):
		var asset_name: String = raw_path.substr(ASSET_SCHEME.length())
		if AppState.current_project == null or asset_name == "":
			return ""
		return AppState.current_project.resolve_asset_path(asset_name)
	if raw_path.begins_with(FILE_SCHEME):
		var stripped: String = raw_path.substr(FILE_SCHEME.length())
		if stripped.begins_with("/") and stripped.length() >= 3 and stripped[2] == ":":
			stripped = stripped.substr(1)
		return stripped
	if raw_path.is_absolute_path() or (raw_path.length() >= 2 and raw_path[1] == ":"):
		return raw_path
	if AppState.current_project != null:
		var asset_candidate: String = AppState.current_project.resolve_asset_path(raw_path)
		if FileAccess.file_exists(asset_candidate):
			return asset_candidate
	if document_dir != "":
		var doc_candidate: String = document_dir.path_join(raw_path)
		if FileAccess.file_exists(doc_candidate):
			return doc_candidate
	return raw_path


static func _parse_size_spec(spec: String) -> Vector2i:
	var trimmed: String = spec.strip_edges()
	var x_index: int = trimmed.find("x")
	if x_index < 0:
		if trimmed.is_valid_int():
			return Vector2i(int(trimmed), 0)
		return Vector2i.ZERO
	var width_part: String = trimmed.substr(0, x_index)
	var height_part: String = trimmed.substr(x_index + 1)
	var width_value: int = int(width_part) if width_part.is_valid_int() else 0
	var height_value: int = int(height_part) if height_part.is_valid_int() else 0
	return Vector2i(width_value, height_value)


static func _load_image_from_disk(path: String) -> Image:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() == 0:
		return null
	var decoder: String = _decoder_for_bytes(bytes)
	if decoder == "":
		decoder = _decoder_for_extension(path.get_extension().to_lower())
	if decoder == "":
		return null
	var img: Image = Image.new()
	var err: int = img.call(decoder, bytes)
	if err != OK or img.is_empty():
		return null
	return img


static func _decoder_for_bytes(bytes: PackedByteArray) -> String:
	if bytes.size() >= 8 and bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47 and bytes[4] == 0x0D and bytes[5] == 0x0A and bytes[6] == 0x1A and bytes[7] == 0x0A:
		return "load_png_from_buffer"
	if bytes.size() >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF:
		return "load_jpg_from_buffer"
	if bytes.size() >= 12 and bytes[0] == 0x52 and bytes[1] == 0x49 and bytes[2] == 0x46 and bytes[3] == 0x46 and bytes[8] == 0x57 and bytes[9] == 0x45 and bytes[10] == 0x42 and bytes[11] == 0x50:
		return "load_webp_from_buffer"
	if bytes.size() >= 2 and bytes[0] == 0x42 and bytes[1] == 0x4D:
		return "load_bmp_from_buffer"
	if bytes.size() >= 12 and bytes[0] == 0xAB and bytes[1] == 0x4B and bytes[2] == 0x54 and bytes[3] == 0x58:
		return "load_ktx_from_buffer"
	if bytes.size() >= 5 and bytes[0] == 0x3C and (bytes[1] == 0x3F or bytes[1] == 0x73):
		return "load_svg_from_buffer"
	return ""


static func _decoder_for_extension(ext: String) -> String:
	match ext:
		"png": return "load_png_from_buffer"
		"jpg", "jpeg": return "load_jpg_from_buffer"
		"webp": return "load_webp_from_buffer"
		"bmp": return "load_bmp_from_buffer"
		"tga": return "load_tga_from_buffer"
		"svg": return "load_svg_from_buffer"
		"ktx": return "load_ktx_from_buffer"
	return ""
