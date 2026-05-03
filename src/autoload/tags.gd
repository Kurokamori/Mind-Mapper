extends Node

signal tags_changed()

const PALETTE: Array = [
	Color(0.95, 0.36, 0.36),
	Color(0.95, 0.62, 0.27),
	Color(0.95, 0.85, 0.30),
	Color(0.45, 0.85, 0.50),
	Color(0.30, 0.78, 0.85),
	Color(0.40, 0.55, 0.95),
	Color(0.65, 0.45, 0.95),
	Color(0.95, 0.45, 0.78),
]


func color_for(tag: String) -> Color:
	if tag == "":
		return Color(0.55, 0.55, 0.6)
	var h: int = 0
	for i in range(tag.length()):
		h = (h * 31 + tag.unicode_at(i)) & 0x7fffffff
	return PALETTE[h % PALETTE.size()]


func collect_from_project(project: Project) -> PackedStringArray:
	var seen: Dictionary = {}
	if project == null:
		return PackedStringArray()
	for entry in project.list_boards():
		var b: Board = project.read_board(String(entry.id))
		if b == null:
			continue
		for item_d_v in b.items:
			if typeof(item_d_v) != TYPE_DICTIONARY:
				continue
			var raw: Variant = (item_d_v as Dictionary).get("tags", null)
			if typeof(raw) == TYPE_ARRAY:
				for t in (raw as Array):
					var s: String = String(t).strip_edges()
					if s != "":
						seen[s] = true
	var out: PackedStringArray = PackedStringArray()
	var keys: Array = seen.keys()
	keys.sort()
	for k in keys:
		out.append(String(k))
	return out


func notify_changed() -> void:
	emit_signal("tags_changed")
