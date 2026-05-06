class_name UrlInspector
extends VBoxContainer

@onready var _title_edit: LineEdit = %TitleEdit
@onready var _url_edit: LineEdit = %UrlEdit
@onready var _description_edit: TextEdit = %DescriptionEdit
@onready var _open_button: Button = %OpenButton

var _item: UrlNode = null
var _editor: Node = null
var _binders: Dictionary = {}
var _suppress_signals: bool = false


func bind(item: UrlNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	if _item == null:
		return
	_suppress_signals = true
	_title_edit.text = _item.title
	_url_edit.text = _item.url
	_description_edit.text = _item.description
	_suppress_signals = false
	_binders["title"] = PropertyBinder.new(_editor, _item, "title", _item.title)
	_binders["url"] = PropertyBinder.new(_editor, _item, "url", _item.url)
	_binders["description"] = PropertyBinder.new(_editor, _item, "description", _item.description)
	_title_edit.text_changed.connect(_on_title_changed)
	_title_edit.focus_exited.connect(_on_title_committed)
	_title_edit.text_submitted.connect(func(_t: String) -> void: _on_title_committed())
	_url_edit.text_changed.connect(_on_url_changed)
	_url_edit.focus_exited.connect(_on_url_committed)
	_url_edit.text_submitted.connect(func(_t: String) -> void: _on_url_committed())
	_description_edit.text_changed.connect(_on_description_changed)
	_description_edit.focus_exited.connect(_on_description_committed)
	_open_button.pressed.connect(_on_open_pressed)


func _on_title_changed(_text: String) -> void:
	if _suppress_signals:
		return
	_binders["title"].live(_title_edit.text)


func _on_title_committed() -> void:
	if _suppress_signals:
		return
	_binders["title"].commit(_title_edit.text)


func _on_url_changed(_text: String) -> void:
	if _suppress_signals:
		return
	_binders["url"].live(_url_edit.text)


func _on_url_committed() -> void:
	if _suppress_signals:
		return
	_binders["url"].commit(_url_edit.text)


func _on_description_changed() -> void:
	if _suppress_signals:
		return
	_binders["description"].live(_description_edit.text)


func _on_description_committed() -> void:
	if _suppress_signals:
		return
	_binders["description"].commit(_description_edit.text)


func _on_open_pressed() -> void:
	if _item == null:
		return
	var target: String = _item.url.strip_edges()
	if target != "":
		OS.shell_open(target)


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null
