class_name ImageCropPanel
extends Control

const HANDLE_SIZE: float = 8.0

var _item: ImageNode = null
var _editor: Node = null
var _texture: Texture2D = null
var _crop_pixels: Rect2 = Rect2()
var _img_w: int = 0
var _img_h: int = 0
var _drag_mode: String = ""
var _drag_start: Vector2 = Vector2.ZERO
var _drag_start_rect: Rect2 = Rect2()


func bind(item: ImageNode, editor: Node) -> void:
	_item = item
	_editor = editor
	_load_source()


func _load_source() -> void:
	if _item == null or _item._source_image == null:
		return
	var img: Image = _item._source_image
	_img_w = img.get_width()
	_img_h = img.get_height()
	_texture = ImageTexture.create_from_image(img)
	_crop_pixels = Rect2(
		_item.crop_rect_norm.position.x * float(_img_w),
		_item.crop_rect_norm.position.y * float(_img_h),
		_item.crop_rect_norm.size.x * float(_img_w),
		_item.crop_rect_norm.size.y * float(_img_h),
	)
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	var preview_rect: Rect2 = _preview_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.07), true)
	draw_texture_rect(_texture, preview_rect, false)
	var crop_screen: Rect2 = _pixels_to_screen(_crop_pixels, preview_rect)
	var dim: Color = Color(0, 0, 0, 0.55)
	draw_rect(Rect2(preview_rect.position, Vector2(preview_rect.size.x, crop_screen.position.y - preview_rect.position.y)), dim, true)
	draw_rect(Rect2(Vector2(preview_rect.position.x, crop_screen.position.y + crop_screen.size.y), Vector2(preview_rect.size.x, preview_rect.position.y + preview_rect.size.y - (crop_screen.position.y + crop_screen.size.y))), dim, true)
	draw_rect(Rect2(Vector2(preview_rect.position.x, crop_screen.position.y), Vector2(crop_screen.position.x - preview_rect.position.x, crop_screen.size.y)), dim, true)
	draw_rect(Rect2(Vector2(crop_screen.position.x + crop_screen.size.x, crop_screen.position.y), Vector2(preview_rect.position.x + preview_rect.size.x - (crop_screen.position.x + crop_screen.size.x), crop_screen.size.y)), dim, true)
	draw_rect(crop_screen, Color(0.4, 0.78, 1.0), false, 2.0)
	for h in _handles(crop_screen):
		draw_rect(h, Color(0.95, 0.97, 1.0), true)
		draw_rect(h, Color(0.4, 0.78, 1.0), false, 1.0)


func _handles(rect: Rect2) -> Array:
	var hs: float = HANDLE_SIZE
	return [
		Rect2(rect.position - Vector2(hs * 0.5, hs * 0.5), Vector2(hs, hs)),
		Rect2(rect.position + Vector2(rect.size.x * 0.5 - hs * 0.5, -hs * 0.5), Vector2(hs, hs)),
		Rect2(rect.position + Vector2(rect.size.x - hs * 0.5, -hs * 0.5), Vector2(hs, hs)),
		Rect2(rect.position + Vector2(-hs * 0.5, rect.size.y * 0.5 - hs * 0.5), Vector2(hs, hs)),
		Rect2(rect.position + Vector2(rect.size.x - hs * 0.5, rect.size.y * 0.5 - hs * 0.5), Vector2(hs, hs)),
		Rect2(rect.position + Vector2(-hs * 0.5, rect.size.y - hs * 0.5), Vector2(hs, hs)),
		Rect2(rect.position + Vector2(rect.size.x * 0.5 - hs * 0.5, rect.size.y - hs * 0.5), Vector2(hs, hs)),
		Rect2(rect.position + Vector2(rect.size.x - hs * 0.5, rect.size.y - hs * 0.5), Vector2(hs, hs)),
	]


func _preview_rect() -> Rect2:
	if _img_w == 0 or _img_h == 0:
		return Rect2(Vector2.ZERO, size)
	var img_aspect: float = float(_img_w) / float(_img_h)
	var widget_aspect: float = size.x / size.y
	var draw_size: Vector2
	if img_aspect > widget_aspect:
		draw_size = Vector2(size.x - 24.0, (size.x - 24.0) / img_aspect)
	else:
		draw_size = Vector2((size.y - 24.0) * img_aspect, size.y - 24.0)
	var draw_pos: Vector2 = Vector2((size.x - draw_size.x) * 0.5, (size.y - draw_size.y) * 0.5)
	return Rect2(draw_pos, draw_size)


func _pixels_to_screen(rect: Rect2, preview_rect: Rect2) -> Rect2:
	var sx: float = preview_rect.size.x / float(_img_w)
	var sy: float = preview_rect.size.y / float(_img_h)
	return Rect2(
		preview_rect.position + Vector2(rect.position.x * sx, rect.position.y * sy),
		Vector2(rect.size.x * sx, rect.size.y * sy),
	)


func _screen_to_pixels(p: Vector2, preview_rect: Rect2) -> Vector2:
	var sx: float = float(_img_w) / preview_rect.size.x
	var sy: float = float(_img_h) / preview_rect.size.y
	return Vector2((p.x - preview_rect.position.x) * sx, (p.y - preview_rect.position.y) * sy)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var preview: Rect2 = _preview_rect()
				var crop_screen: Rect2 = _pixels_to_screen(_crop_pixels, preview)
				_drag_start = mb.position
				_drag_start_rect = _crop_pixels
				_drag_mode = _hit_handle(mb.position, crop_screen)
				if _drag_mode == "":
					if crop_screen.has_point(mb.position):
						_drag_mode = "move"
					elif preview.has_point(mb.position):
						_drag_mode = "new"
						var p: Vector2 = _screen_to_pixels(mb.position, preview)
						_crop_pixels = Rect2(p, Vector2(1, 1))
						queue_redraw()
			else:
				if _drag_mode != "":
					_commit()
				_drag_mode = ""
	elif event is InputEventMouseMotion:
		if _drag_mode == "":
			return
		var preview: Rect2 = _preview_rect()
		var delta: Vector2 = (event as InputEventMouseMotion).relative
		var sx: float = float(_img_w) / preview.size.x
		var sy: float = float(_img_h) / preview.size.y
		var dpix: Vector2 = Vector2(delta.x * sx, delta.y * sy)
		match _drag_mode:
			"move":
				_crop_pixels.position += dpix
			"new":
				var p: Vector2 = _screen_to_pixels((event as InputEventMouseMotion).position, preview)
				var origin: Vector2 = _drag_start_rect.position
				_crop_pixels = Rect2(Vector2(min(origin.x, p.x), min(origin.y, p.y)), Vector2(abs(p.x - origin.x), abs(p.y - origin.y)))
			"left":
				_crop_pixels.position.x += dpix.x
				_crop_pixels.size.x -= dpix.x
			"right":
				_crop_pixels.size.x += dpix.x
			"top":
				_crop_pixels.position.y += dpix.y
				_crop_pixels.size.y -= dpix.y
			"bottom":
				_crop_pixels.size.y += dpix.y
		_clamp_crop()
		queue_redraw()


func _clamp_crop() -> void:
	if _crop_pixels.size.x < 4: _crop_pixels.size.x = 4
	if _crop_pixels.size.y < 4: _crop_pixels.size.y = 4
	_crop_pixels.position.x = clampf(_crop_pixels.position.x, 0, _img_w - _crop_pixels.size.x)
	_crop_pixels.position.y = clampf(_crop_pixels.position.y, 0, _img_h - _crop_pixels.size.y)
	if _crop_pixels.position.x + _crop_pixels.size.x > _img_w:
		_crop_pixels.size.x = _img_w - _crop_pixels.position.x
	if _crop_pixels.position.y + _crop_pixels.size.y > _img_h:
		_crop_pixels.size.y = _img_h - _crop_pixels.position.y


func _hit_handle(p: Vector2, rect: Rect2) -> String:
	var hs: float = HANDLE_SIZE
	if Rect2(rect.position + Vector2(-hs, -hs), Vector2(hs * 2, hs * 2)).has_point(p): return "left"
	if Rect2(rect.position + Vector2(rect.size.x - hs, -hs), Vector2(hs * 2, hs * 2)).has_point(p): return "right"
	if Rect2(rect.position + Vector2(-hs, rect.size.y - hs), Vector2(hs * 2, hs * 2)).has_point(p): return "left"
	if Rect2(rect.position + Vector2(-hs, -hs), Vector2(rect.size.x + hs * 2, hs * 2)).has_point(p): return "top"
	if Rect2(rect.position + Vector2(-hs, rect.size.y - hs), Vector2(rect.size.x + hs * 2, hs * 2)).has_point(p): return "bottom"
	return ""


func _commit() -> void:
	if _item == null or _editor == null:
		return
	var nr: Rect2 = Rect2(
		_crop_pixels.position.x / float(_img_w),
		_crop_pixels.position.y / float(_img_h),
		_crop_pixels.size.x / float(_img_w),
		_crop_pixels.size.y / float(_img_h),
	)
	if nr == _item.crop_rect_norm:
		return
	var before: Array = [_item.crop_rect_norm.position.x, _item.crop_rect_norm.position.y, _item.crop_rect_norm.size.x, _item.crop_rect_norm.size.y]
	var after: Array = [nr.position.x, nr.position.y, nr.size.x, nr.size.y]
	History.push(ModifyPropertyCommand.new(_editor, _item.item_id, "crop_rect_norm", before, after))
