class_name OverlayObject
extends Control

signal selection_requested(node: OverlayObject)
signal drag_started(node: OverlayObject)
signal drag_updated(node: OverlayObject)
signal drag_ended(node: OverlayObject)

const SELECTION_OUTLINE_COLOR: Color = Color(0.35, 0.7, 1.0, 1.0)

@onready var _texture_rect: TextureRect = %TextureRect
@onready var _label: Label = %Label
@onready var _rich: RichTextLabel = %Rich
@onready var _audio_label: Label = %AudioLabel

var _data: Dictionary = {}
var _selected: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind_object(d: Dictionary) -> void:
	_data = d.duplicate(true)
	refresh()


func object_id() -> String:
	return String(_data.get("id", ""))


func object_type() -> String:
	return String(_data.get("type", ""))


func object_dict() -> Dictionary:
	return _data.duplicate(true)


func world_position() -> Vector2:
	return position


func world_size() -> Vector2:
	return size


func set_world_position(p: Vector2) -> void:
	position = p
	_data["position"] = [p.x, p.y]


func set_selected_state(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	queue_redraw()


func refresh() -> void:
	var pos_raw: Variant = _data.get("position", [0, 0])
	if typeof(pos_raw) == TYPE_ARRAY and (pos_raw as Array).size() >= 2:
		var arr: Array = pos_raw
		position = Vector2(float(arr[0]), float(arr[1]))
	var size_raw: Variant = _data.get("size", [128, 64])
	if typeof(size_raw) == TYPE_ARRAY and (size_raw as Array).size() >= 2:
		var arr: Array = size_raw
		size = Vector2(float(arr[0]), float(arr[1]))
	if _texture_rect == null:
		return
	_texture_rect.visible = false
	_label.visible = false
	_rich.visible = false
	_audio_label.visible = false
	match object_type():
		ItemRegistry.TYPE_IMAGE:
			_texture_rect.visible = true
			_apply_image()
		ItemRegistry.TYPE_LABEL, ItemRegistry.TYPE_TEXT:
			_label.visible = true
			_label.text = String(_data.get("text", ""))
		ItemRegistry.TYPE_RICH_TEXT:
			_rich.visible = true
			_rich.text = String(_data.get("bbcode_text", ""))
		ItemRegistry.TYPE_SOUND:
			_audio_label.visible = true
			_audio_label.text = "♪ " + String(_data.get("display_label", "sound"))
	queue_redraw()


func _apply_image() -> void:
	if AppState.current_project == null:
		return
	var asset: String = String(_data.get("asset_name", ""))
	if asset == "":
		return
	var path: String = AppState.current_project.resolve_asset_path(asset)
	if not FileAccess.file_exists(path):
		return
	var img: Image = Image.load_from_file(path)
	if img == null or img.is_empty():
		return
	_texture_rect.texture = ImageTexture.create_from_image(img)


func _draw() -> void:
	if not _selected:
		return
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = SELECTION_OUTLINE_COLOR
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
