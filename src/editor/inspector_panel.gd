class_name InspectorPanel
extends PanelContainer

const CONNECTION_INSPECTOR_SCENE: PackedScene = preload("res://src/editor/connection_inspector.tscn")

@onready var _title_label: Label = %TitleLabel
@onready var _content: VBoxContainer = %Content
@onready var _empty_label: Label = %EmptyLabel
@onready var _scroll: ScrollContainer = %Scroll

var _current_item: BoardItem = null
var _current_connection: Connection = null


func _ready() -> void:
	SelectionBus.selection_changed.connect(_on_selection_changed)
	_render_for([])


func _on_selection_changed(selected: Array) -> void:
	if not selected.is_empty():
		_current_connection = null
	_render_for(selected)


func show_connection(connection: Connection, editor: Node) -> void:
	_current_connection = connection
	_clear_content()
	if connection == null:
		_render_for(SelectionBus.current())
		return
	_title_label.text = "Connection"
	_empty_label.visible = false
	_scroll.visible = true
	var inspector: ConnectionInspector = CONNECTION_INSPECTOR_SCENE.instantiate()
	inspector.bind(connection, editor)
	_content.add_child(inspector)


func _render_for(selected: Array) -> void:
	_clear_content()
	if _current_connection != null:
		return
	if selected.size() == 0:
		_title_label.text = "Inspector"
		_empty_label.text = "No selection"
		_empty_label.visible = true
		_scroll.visible = false
		_current_item = null
		return
	if selected.size() > 1:
		_title_label.text = "Inspector"
		_empty_label.text = "%d items selected" % selected.size()
		_empty_label.visible = true
		_scroll.visible = false
		_current_item = null
		return
	var item: BoardItem = selected[0]
	_current_item = item
	_title_label.text = item.display_name()
	_empty_label.visible = false
	_scroll.visible = true
	var inspector: Control = item.build_inspector()
	if inspector != null:
		_content.add_child(inspector)
	else:
		var note: Label = Label.new()
		note.text = "No inspector"
		note.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
		_content.add_child(note)
	_attach_link_section(item)
	_attach_backlinks_section(item)


func _attach_link_section(item: BoardItem) -> void:
	var scene: PackedScene = preload("res://src/editor/link_section.tscn")
	var link_section: LinkSection = scene.instantiate()
	var editor: Node = _find_editor_node()
	link_section.bind(item, editor)
	_content.add_child(link_section)


func _attach_backlinks_section(item: BoardItem) -> void:
	var scene: PackedScene = preload("res://src/editor/backlinks_section.tscn")
	var section: BacklinksSection = scene.instantiate()
	var editor: Node = _find_editor_node()
	section.bind(item, editor)
	_content.add_child(section)


func _find_editor_node() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null


func _clear_content() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()
