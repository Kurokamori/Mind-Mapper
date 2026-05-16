class_name MobileViewportBackground
extends ColorRect


func _ready() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.size_changed.connect(_apply_viewport_size)
	_apply_viewport_size()


func _apply_viewport_size() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var visible_rect: Rect2 = viewport.get_visible_rect()
	offset_left = visible_rect.position.x
	offset_top = visible_rect.position.y
	offset_right = visible_rect.position.x + visible_rect.size.x
	offset_bottom = visible_rect.position.y + visible_rect.size.y
	position = visible_rect.position
	size = visible_rect.size
