class_name AddNodePopup
extends PopupMenu

signal type_chosen(type_id: String)
signal map_page_requested()

const SEPARATOR_TOKEN: String = "__sep__"
const MAP_PAGE_TOKEN: String = "__map_page__"


func _ready() -> void:
	populate_self()
	if not id_pressed.is_connected(_on_id_pressed):
		id_pressed.connect(_on_id_pressed)


func populate_self() -> void:
	populate_into(self)


static func entries() -> Array:
	return [
		[ItemRegistry.TYPE_TEXT, "Text"],
		[ItemRegistry.TYPE_LABEL, "Label"],
		[ItemRegistry.TYPE_RICH_TEXT, "Rich Text"],
		[ItemRegistry.TYPE_DOCUMENT, "Document"],
		[ItemRegistry.TYPE_STICKY, "Sticky Note"],
		[ItemRegistry.TYPE_CODE, "Code Block"],
		[ItemRegistry.TYPE_TABLE, "Table"],
		[ItemRegistry.TYPE_EQUATION, "Equation / LaTeX"],
		[SEPARATOR_TOKEN, ""],
		[ItemRegistry.TYPE_IMAGE, "Image…"],
		[ItemRegistry.TYPE_SOUND, "Sound…"],
		[ItemRegistry.TYPE_URL, "URL Bookmark"],
		[SEPARATOR_TOKEN, ""],
		[ItemRegistry.TYPE_PRIMITIVE, "Primitive Shape"],
		[ItemRegistry.TYPE_GROUP, "Group Frame"],
		[ItemRegistry.TYPE_TIMER, "Timer"],
		[SEPARATOR_TOKEN, ""],
		[ItemRegistry.TYPE_PINBOARD, "Pinboard"],
		[ItemRegistry.TYPE_SUBPAGE, "Subpage"],
		[MAP_PAGE_TOKEN, "Map Page…"],
		[SEPARATOR_TOKEN, ""],
		[ItemRegistry.TYPE_TODO_LIST, "Todo List"],
		[ItemRegistry.TYPE_BLOCK_STACK, "Block Stack"],
	]


static func populate_into(popup: PopupMenu) -> void:
	popup.clear()
	var counter: int = 0
	for entry: Array in entries():
		var token: String = String(entry[0])
		var label: String = String(entry[1])
		if token == SEPARATOR_TOKEN:
			popup.add_separator()
		else:
			popup.add_item(label, counter)
			popup.set_item_metadata(popup.get_item_index(counter), token)
			counter += 1


static func type_for_id(popup: PopupMenu, id: int) -> String:
	var idx: int = popup.get_item_index(id)
	if idx < 0:
		return ""
	var meta: Variant = popup.get_item_metadata(idx)
	return String(meta) if meta != null else ""


func popup_at_screen(screen_pos: Vector2) -> void:
	var pi: Vector2i = Vector2i(int(round(screen_pos.x)), int(round(screen_pos.y)))
	popup(Rect2i(pi, Vector2i.ZERO))


func _on_id_pressed(id: int) -> void:
	var t: String = AddNodePopup.type_for_id(self, id)
	if t == "":
		return
	if t == MAP_PAGE_TOKEN:
		map_page_requested.emit()
		return
	type_chosen.emit(t)
