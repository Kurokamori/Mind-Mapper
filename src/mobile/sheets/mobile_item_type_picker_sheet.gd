class_name MobileItemTypePickerSheet
extends Control

signal type_chosen(type_id: String)

const TYPES: Array[Array] = [
	[ItemRegistry.TYPE_TEXT, "Text", "res://assets/ui/icons/text.png"],
	[ItemRegistry.TYPE_LABEL, "Label", "res://assets/ui/icons/label.png"],
	[ItemRegistry.TYPE_STICKY, "Sticky", "res://assets/ui/icons/sticky-note.png"],
	[ItemRegistry.TYPE_RICH_TEXT, "Rich text", "res://assets/ui/icons/rich-text.png"],
	[ItemRegistry.TYPE_DOCUMENT, "Document", "res://assets/ui/icons/edit.png"],
	[ItemRegistry.TYPE_CODE, "Code", "res://assets/ui/icons/code.png"],
	[ItemRegistry.TYPE_EQUATION, "Equation", "res://assets/ui/icons/latex.png"],
	[ItemRegistry.TYPE_URL, "URL", "res://assets/ui/icons/link.png"],
	[ItemRegistry.TYPE_IMAGE, "Image", "res://assets/ui/icons/image.png"],
	[ItemRegistry.TYPE_SOUND, "Sound", "res://assets/ui/icons/sound.png"],
	[ItemRegistry.TYPE_TODO_LIST, "Todo", "res://assets/ui/icons/to-do.png"],
	[ItemRegistry.TYPE_BLOCK_STACK, "Blocks", "res://assets/ui/icons/blocks.png"],
	[ItemRegistry.TYPE_TABLE, "Table", "res://assets/ui/icons/table.png"],
	[ItemRegistry.TYPE_TIMER, "Timer", "res://assets/ui/icons/callander.png"],
	[ItemRegistry.TYPE_PRIMITIVE, "Shape", "res://assets/ui/icons/primitive-shape.png"],
	[ItemRegistry.TYPE_GROUP, "Group", "res://assets/ui/icons/group.png"],
	[ItemRegistry.TYPE_PINBOARD, "Pinboard", "res://assets/ui/icons/pinboard.png"],
	[ItemRegistry.TYPE_SUBPAGE, "Subpage", "res://assets/ui/icons/sub-page.png"],
	[ItemRegistry.TYPE_MAP_PAGE, "Map page", "res://assets/ui/icons/map.png"],
]

const ICON_SIZE_SCALE: float = 2.0
const TILE_LABEL_SCALE: float = 0.85
const TILE_HEIGHT_SCALE: float = 6.0

@onready var _grid: GridContainer = %TypeGrid


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rebuild()
	if not UserPrefs.theme_changed.is_connected(_on_theme_changed):
		UserPrefs.theme_changed.connect(_on_theme_changed)


func _exit_tree() -> void:
	if UserPrefs != null and UserPrefs.theme_changed.is_connected(_on_theme_changed):
		UserPrefs.theme_changed.disconnect(_on_theme_changed)


func _on_theme_changed() -> void:
	_rebuild()


func _rebuild() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()
	for entry: Array in TYPES:
		var type_id: String = String(entry[0])
		var label: String = String(entry[1])
		var icon_path: String = String(entry[2])
		_grid.add_child(_build_tile(type_id, label, icon_path))


func _build_tile(type_id: String, label: String, icon_path: String) -> Control:
	var base_font: int = ThemeManager.scaled_font_size(1.0)
	var label_font: int = int(round(float(base_font) * TILE_LABEL_SCALE))
	var icon_px: int = int(round(float(base_font) * ICON_SIZE_SCALE))
	var tile_height: float = float(base_font) * TILE_HEIGHT_SCALE
	var btn: Button = Button.new()
	btn.text = label
	btn.icon = _load_icon(icon_path)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.expand_icon = false
	btn.custom_minimum_size = Vector2(0, tile_height)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", label_font)
	btn.add_theme_constant_override("icon_max_width", icon_px)
	btn.pressed.connect(func() -> void: type_chosen.emit(type_id))
	return btn


func _load_icon(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is Texture2D:
		return res as Texture2D
	return null
