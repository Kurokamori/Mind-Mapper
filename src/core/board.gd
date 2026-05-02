class_name Board
extends RefCounted

var id: String = ""
var name: String = "Board"
var parent_board_id: String = ""
var items: Array = []
var connections: Array = []


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
	return b


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"parent_board_id": parent_board_id,
		"items": items.duplicate(true),
		"connections": connections.duplicate(true),
	}
