class_name Board
extends RefCounted

const DEFAULT_BG_COLOR = Color(0.077, 0.107, 0.179, 1.0)

var id: String = ""
var name: String = "Board"
var parent_board_id: String = ""
var items: Array = []
var connections: Array = []
var comments: Array = []
var background_image_asset: String = ""
var background_image_mode: int = 0
var background_color_override: Color = Color(0.0, 0.0, 0.0, 0.0)


static func from_dict(d: Dictionary) -> Board:
	var b: Board = Board.new()
	b.id = String(d.get("id", ""))
	b.name = String(d.get("name", "Board"))
	b.parent_board_id = String(d.get("parent_board_id", ""))
	var items_raw: Variant = d.get("items", [])
	if typeof(items_raw) == TYPE_ARRAY:
		b.items = items_raw.duplicate(true)
	var conns_raw: Variant = d.get("connections", [])
	if typeof(conns_raw) == TYPE_ARRAY:
		b.connections = conns_raw.duplicate(true)
	var comments_raw: Variant = d.get("comments", [])
	if typeof(comments_raw) == TYPE_ARRAY:
		b.comments = comments_raw.duplicate(true)
	b.background_image_asset = String(d.get("background_image_asset", ""))
	b.background_image_mode = int(d.get("background_image_mode", 0))
	var bg_raw: Variant = d.get("background_color_override", null)
	if typeof(bg_raw) == TYPE_ARRAY and (bg_raw as Array).size() >= 3:
		var arr: Array = bg_raw
		var a: float = 1.0 if arr.size() < 4 else float(arr[3])
		b.background_color_override = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
	return b


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"parent_board_id": parent_board_id,
		"items": items.duplicate(true),
		"connections": connections.duplicate(true),
		"comments": comments.duplicate(true),
		"background_image_asset": background_image_asset,
		"background_image_mode": background_image_mode,
		"background_color_override": [
			background_color_override.r,
			background_color_override.g,
			background_color_override.b,
			background_color_override.a,
		],
	}


func has_background_color_override() -> bool:
	return background_color_override.a > 0.0


func get_background_color() -> Color:
	if has_background_color_override():
		return background_color_override
	return ThemeManager.background_color()
