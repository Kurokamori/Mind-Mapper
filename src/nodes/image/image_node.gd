class_name ImageNode
extends BoardItem

enum SourceMode { LINKED, EMBEDDED }
enum FilterMode { NONE, GRAYSCALE, SEPIA, INVERT }

const PLACEHOLDER_BG: Color = Color(0.18, 0.18, 0.22, 1.0)
const PLACEHOLDER_FG: Color = Color(0.55, 0.55, 0.6, 1.0)

@export var source_mode: int = SourceMode.LINKED
@export var source_path: String = ""
@export var asset_name: String = ""
@export var crop_rect_norm: Rect2 = Rect2(0, 0, 1, 1)
@export var filter_mode: int = FilterMode.NONE
@export var brightness: float = 0.0
@export var contrast: float = 1.0

@onready var _texture_rect: TextureRect = %TextureRect
@onready var _placeholder_label: Label = %PlaceholderLabel

var _source_image: Image = null


func _ready() -> void:
	super._ready()
	_placeholder_label.add_theme_color_override("font_color", PLACEHOLDER_FG)
	_reload_texture()


func default_size() -> Vector2:
	return Vector2(240, 180)


func display_name() -> String:
	return "Image"


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/image/image_inspector.tscn")
	var inst: ImageInspector = scene.instantiate()
	inst.bind(self)
	return inst


func _draw_body() -> void:
	if _texture_rect == null or _texture_rect.texture == null:
		_draw_rounded_panel(PLACEHOLDER_BG, PLACEHOLDER_BG.darkened(0.3))
	else:
		_draw_rounded_outline(PLACEHOLDER_BG.darkened(0.3))


func set_source_linked(absolute_path: String) -> void:
	source_mode = SourceMode.LINKED
	source_path = absolute_path
	asset_name = ""
	_reload_texture()


func set_source_embedded_from(absolute_path: String) -> void:
	if AppState.current_project == null:
		set_source_linked(absolute_path)
		return
	var copied_name: String = AppState.current_project.copy_asset_into_project(absolute_path)
	if copied_name == "":
		set_source_linked(absolute_path)
		return
	source_mode = SourceMode.EMBEDDED
	asset_name = copied_name
	source_path = ""
	_reload_texture()


func set_source_embedded_from_image(img: Image) -> void:
	if img == null or AppState.current_project == null:
		return
	var asset_id: String = Uuid.v4()
	var dest: String = AppState.current_project.assets_path().path_join(asset_id + ".png")
	if not DirAccess.dir_exists_absolute(AppState.current_project.assets_path()):
		DirAccess.make_dir_recursive_absolute(AppState.current_project.assets_path())
	if img.save_png(dest) != OK:
		return
	source_mode = SourceMode.EMBEDDED
	asset_name = asset_id + ".png"
	source_path = ""
	_reload_texture()


func notify_asset_available(streamed_asset_name: String) -> void:
	if streamed_asset_name == "" or asset_name == "":
		return
	if streamed_asset_name != asset_name:
		return
	if source_mode != SourceMode.EMBEDDED:
		return
	_reload_texture()


func resolve_absolute_path() -> String:
	if source_mode == SourceMode.EMBEDDED:
		if AppState.current_project == null or asset_name == "":
			return ""
		return AppState.current_project.resolve_asset_path(asset_name)
	return source_path


func _reload_texture() -> void:
	var path: String = resolve_absolute_path()
	if path == "" or not FileAccess.file_exists(path):
		_set_placeholder("No image")
		return
	var img: Image = _load_image_from_disk(path)
	if img == null:
		_set_placeholder("Failed to load")
		return
	_source_image = img
	_apply_filters_and_crop()


func _apply_filters_and_crop() -> void:
	if _source_image == null:
		return
	var w: int = _source_image.get_width()
	var h: int = _source_image.get_height()
	var crop_x: int = clampi(int(crop_rect_norm.position.x * float(w)), 0, w - 1)
	var crop_y: int = clampi(int(crop_rect_norm.position.y * float(h)), 0, h - 1)
	var crop_w: int = max(1, int(crop_rect_norm.size.x * float(w)))
	var crop_h: int = max(1, int(crop_rect_norm.size.y * float(h)))
	if crop_x + crop_w > w: crop_w = w - crop_x
	if crop_y + crop_h > h: crop_h = h - crop_y
	var cropped: Image = _source_image.get_region(Rect2i(crop_x, crop_y, crop_w, crop_h))
	if filter_mode != FilterMode.NONE or brightness != 0.0 or contrast != 1.0:
		cropped.convert(Image.FORMAT_RGBA8)
		for y in range(cropped.get_height()):
			for x in range(cropped.get_width()):
				var c: Color = cropped.get_pixel(x, y)
				match filter_mode:
					FilterMode.GRAYSCALE:
						var v: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
						c = Color(v, v, v, c.a)
					FilterMode.SEPIA:
						var nr: float = clampf(c.r * 0.393 + c.g * 0.769 + c.b * 0.189, 0.0, 1.0)
						var ng: float = clampf(c.r * 0.349 + c.g * 0.686 + c.b * 0.168, 0.0, 1.0)
						var nb: float = clampf(c.r * 0.272 + c.g * 0.534 + c.b * 0.131, 0.0, 1.0)
						c = Color(nr, ng, nb, c.a)
					FilterMode.INVERT:
						c = Color(1.0 - c.r, 1.0 - c.g, 1.0 - c.b, c.a)
				if contrast != 1.0:
					c.r = clampf((c.r - 0.5) * contrast + 0.5, 0.0, 1.0)
					c.g = clampf((c.g - 0.5) * contrast + 0.5, 0.0, 1.0)
					c.b = clampf((c.b - 0.5) * contrast + 0.5, 0.0, 1.0)
				if brightness != 0.0:
					c.r = clampf(c.r + brightness, 0.0, 1.0)
					c.g = clampf(c.g + brightness, 0.0, 1.0)
					c.b = clampf(c.b + brightness, 0.0, 1.0)
				cropped.set_pixel(x, y, c)
	var tex: ImageTexture = ImageTexture.create_from_image(cropped)
	_texture_rect.texture = tex
	_placeholder_label.visible = false
	queue_redraw()


func _load_image_from_disk(path: String) -> Image:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() == 0:
		return null
	var fn_name: String = _decoder_for_bytes(bytes)
	if fn_name == "":
		fn_name = _decoder_for_extension(path.get_extension().to_lower())
	if fn_name == "":
		return null
	var img: Image = Image.new()
	var err: int = img.call(fn_name, bytes)
	if err != OK or img.is_empty():
		return null
	return img


func _decoder_for_bytes(bytes: PackedByteArray) -> String:
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


func _decoder_for_extension(ext: String) -> String:
	match ext:
		"png": return "load_png_from_buffer"
		"jpg", "jpeg": return "load_jpg_from_buffer"
		"webp": return "load_webp_from_buffer"
		"bmp": return "load_bmp_from_buffer"
		"tga": return "load_tga_from_buffer"
		"svg": return "load_svg_from_buffer"
		"ktx": return "load_ktx_from_buffer"
	return ""


func _set_placeholder(message: String) -> void:
	if _texture_rect != null:
		_texture_rect.texture = null
	if _placeholder_label != null:
		_placeholder_label.text = message
		_placeholder_label.visible = true
	queue_redraw()


func serialize_payload() -> Dictionary:
	return {
		"source_mode": source_mode,
		"source_path": source_path,
		"asset_name": asset_name,
		"crop_rect_norm": [crop_rect_norm.position.x, crop_rect_norm.position.y, crop_rect_norm.size.x, crop_rect_norm.size.y],
		"filter_mode": filter_mode,
		"brightness": brightness,
		"contrast": contrast,
	}


func deserialize_payload(d: Dictionary) -> void:
	source_mode = int(d.get("source_mode", source_mode))
	source_path = String(d.get("source_path", ""))
	asset_name = String(d.get("asset_name", ""))
	var cr: Variant = d.get("crop_rect_norm", null)
	if typeof(cr) == TYPE_ARRAY and (cr as Array).size() >= 4:
		crop_rect_norm = Rect2(float(cr[0]), float(cr[1]), float(cr[2]), float(cr[3]))
	filter_mode = int(d.get("filter_mode", filter_mode))
	brightness = float(d.get("brightness", brightness))
	contrast = float(d.get("contrast", contrast))
	if _texture_rect != null:
		_reload_texture()


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"source_path":
			source_path = String(value)
			_reload_texture()
		"asset_name":
			asset_name = String(value)
			_reload_texture()
		"source_mode":
			source_mode = int(value)
			_reload_texture()
		"crop_rect_norm":
			if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 4:
				crop_rect_norm = Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
			elif typeof(value) == TYPE_RECT2:
				crop_rect_norm = value
			_apply_filters_and_crop()
		"filter_mode":
			filter_mode = int(value)
			_apply_filters_and_crop()
		"brightness":
			brightness = float(value)
			_apply_filters_and_crop()
		"contrast":
			contrast = float(value)
			_apply_filters_and_crop()
