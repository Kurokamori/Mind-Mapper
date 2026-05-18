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
		[ItemRegistry.TYPE_TEXT, "Text", "res://assets/ui/icons/text.png"],
		[ItemRegistry.TYPE_LABEL, "Label", "res://assets/ui/icons/label.png"],
		[ItemRegistry.TYPE_RICH_TEXT, "Rich Text", "res://assets/ui/icons/rich-text.png"],
		[ItemRegistry.TYPE_DOCUMENT, "Document", "res://assets/ui/icons/edit.png"],
		[ItemRegistry.TYPE_STICKY, "Sticky Note", "res://assets/ui/icons/sticky-note.png"],
		[ItemRegistry.TYPE_CODE, "Code Block", "res://assets/ui/icons/code.png"],
		[ItemRegistry.TYPE_TABLE, "Table", "res://assets/ui/icons/table.png"],
		[ItemRegistry.TYPE_EQUATION, "Equation / LaTeX", "res://assets/ui/icons/latex.png"],
		[SEPARATOR_TOKEN, "", ""],
		[ItemRegistry.TYPE_IMAGE, "Image…", "res://assets/ui/icons/image.png"],
		[ItemRegistry.TYPE_SOUND, "Sound…", "res://assets/ui/icons/sound.png"],
		[ItemRegistry.TYPE_URL, "URL Bookmark", "res://assets/ui/icons/link.png"],
		[SEPARATOR_TOKEN, "", ""],
		[ItemRegistry.TYPE_PRIMITIVE, "Primitive Shape", "res://assets/ui/icons/primitive-shape.png"],
		[ItemRegistry.TYPE_CONNECTOR, "Line / Arrow", "res://assets/ui/icons/primitive-shape.png"],
		[ItemRegistry.TYPE_GROUP, "Group Frame", "res://assets/ui/icons/group.png"],
		[ItemRegistry.TYPE_TIMER, "Timer", "res://assets/ui/icons/callander.png"],
		[SEPARATOR_TOKEN, "", ""],
		[ItemRegistry.TYPE_PINBOARD, "Pinboard", "res://assets/ui/icons/pinboard.png"],
		[ItemRegistry.TYPE_SUBPAGE, "Subpage", "res://assets/ui/icons/sub-page.png"],
		[MAP_PAGE_TOKEN, "Map Page…", "res://assets/ui/icons/map.png"],
		[SEPARATOR_TOKEN, "", ""],
		[ItemRegistry.TYPE_TODO_LIST, "Todo List", "res://assets/ui/icons/to-do.png"],
		[ItemRegistry.TYPE_BLOCK_STACK, "Block Stack", "res://assets/ui/icons/blocks.png"],
	]


static func _load_entry_icon(icon_path: String) -> Texture2D:
	if icon_path == "":
		return null
	if not ResourceLoader.exists(icon_path):
		return null
	var res: Resource = load(icon_path)
	if res is Texture2D:
		return res as Texture2D
	return null


static func populate_into(popup: PopupMenu) -> void:
	popup.clear()
	var counter: int = 0
	for entry: Array in entries():
		var token: String = String(entry[0])
		var label: String = String(entry[1])
		var icon_path: String = String(entry[2]) if entry.size() > 2 else ""
		if token == SEPARATOR_TOKEN:
			popup.add_separator()
		else:
			var icon_tex: Texture2D = _load_entry_icon(icon_path)
			if icon_tex != null:
				popup.add_icon_item(icon_tex, label, counter)
			else:
				popup.add_item(label, counter)
			popup.set_item_metadata(popup.get_item_index(counter), token)
			counter += 1
	apply_theme_icon_tint(popup)
	_bind_theme_icon_tint(popup)


## Recolors every item icon to ThemeManager.icon_color() so the white source
## glyphs match the per-theme tint used by AutomaticButton.use_theme_icon_color.
## Safe to call repeatedly; called once after populate_into and again whenever
## ThemeManager emits theme_applied.
static func apply_theme_icon_tint(popup: PopupMenu) -> void:
	if popup == null:
		return
	var tint: Color = _resolve_icon_tint(popup)
	var count: int = popup.item_count
	for i: int in range(count):
		if popup.is_item_separator(i):
			continue
		if popup.get_item_icon(i) == null:
			continue
		popup.set_item_icon_modulate(i, tint)


static func _resolve_icon_tint(popup: PopupMenu) -> Color:
	var tm: Node = _theme_manager_for(popup)
	if tm != null and tm.has_method(&"icon_color"):
		var raw: Variant = tm.call(&"icon_color")
		if typeof(raw) == TYPE_COLOR:
			return raw
	return Color.WHITE


static func _theme_manager_for(popup: PopupMenu) -> Node:
	if popup == null or not popup.is_inside_tree():
		return null
	return popup.get_tree().root.get_node_or_null(^"ThemeManager")


## Wires the popup so it re-tints whenever ThemeManager.theme_applied fires.
## Idempotent — calling twice on the same popup does not duplicate the
## connection. Cleans up automatically when the popup leaves the tree.
static func _bind_theme_icon_tint(popup: PopupMenu) -> void:
	if popup == null:
		return
	if popup.has_meta(&"_add_node_popup_theme_bound"):
		return
	popup.set_meta(&"_add_node_popup_theme_bound", true)
	var connect_callable: Callable = func() -> void:
		var tm: Node = AddNodePopup._theme_manager_for(popup)
		if tm == null or not tm.has_signal(&"theme_applied"):
			return
		var cb: Callable = Callable(AddNodePopup, &"apply_theme_icon_tint").bind(popup)
		if not tm.is_connected(&"theme_applied", cb):
			tm.connect(&"theme_applied", cb)
		popup.tree_exiting.connect(Callable(AddNodePopup, &"_unbind_theme_icon_tint").bind(popup), CONNECT_ONE_SHOT)
	if popup.is_inside_tree():
		connect_callable.call()
	else:
		popup.ready.connect(connect_callable, CONNECT_ONE_SHOT)


static func _unbind_theme_icon_tint(popup: PopupMenu) -> void:
	if popup == null:
		return
	var tm: Node = _theme_manager_for(popup)
	if tm == null or not tm.has_signal(&"theme_applied"):
		return
	for conn: Dictionary in tm.get_signal_connection_list(&"theme_applied"):
		var cb: Callable = conn.get("callable", Callable())
		if cb.is_valid() and cb.get_method() == &"apply_theme_icon_tint":
			var bound: Array = cb.get_bound_arguments()
			if bound.size() == 1 and bound[0] == popup:
				tm.disconnect(&"theme_applied", cb)


static func type_for_id(popup: PopupMenu, id: int) -> String:
	var idx: int = popup.get_item_index(id)
	if idx < 0:
		return ""
	var meta: Variant = popup.get_item_metadata(idx)
	return String(meta) if meta != null else ""


func popup_at_screen(_screen_pos: Vector2) -> void:
	reset_size()
	position = DisplayServer.mouse_get_position()
	popup()


func _on_id_pressed(id: int) -> void:
	var t: String = AddNodePopup.type_for_id(self, id)
	if t == "":
		return
	if t == MAP_PAGE_TOKEN:
		map_page_requested.emit()
		return
	type_chosen.emit(t)
