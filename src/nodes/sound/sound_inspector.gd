class_name SoundInspector
extends VBoxContainer

@onready var _path_label: Label = %PathLabel
@onready var _label_edit: LineEdit = %LabelEdit
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _volume_value: Label = %VolumeValue
@onready var _replace_button: Button = %ReplaceButton
@onready var _file_dialog: FileDialog = %FileDialog
@onready var _embed_choice: ConfirmationDialog = %EmbedChoice

var _item: SoundNode
var _editor: Node
var _binders: Dictionary = {}
var _suppress_signals: bool = false
var _pending_audio_path: String = ""


func bind(item: SoundNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	ThemeManager.apply_relative_font_sizes(self, {"Header": 1.15, "PathLabel": 0.80})
	if _item == null:
		return
	_suppress_signals = true
	_path_label.text = _item.resolve_absolute_path() if _item.source_mode == SoundNode.SourceMode.LINKED else "Embedded: %s" % _item.asset_name
	_label_edit.text = _item.display_label
	_volume_slider.value = _item.volume_db
	_update_volume_text(_item.volume_db)
	_suppress_signals = false
	_binders["display_label"] = PropertyBinder.new(_editor, _item, "display_label", _item.display_label)
	_binders["volume_db"] = PropertyBinder.new(_editor, _item, "volume_db", _item.volume_db)
	_label_edit.text_changed.connect(func(t: String) -> void: _binders["display_label"].live(t))
	_label_edit.focus_exited.connect(func() -> void: _binders["display_label"].commit(_label_edit.text))
	_label_edit.text_submitted.connect(func(t: String) -> void: _binders["display_label"].commit(t))
	_volume_slider.value_changed.connect(_on_volume_changed)
	_volume_slider.drag_ended.connect(_on_volume_drag_ended)
	_replace_button.pressed.connect(_on_replace_pressed)
	_file_dialog.file_selected.connect(_on_file_selected)
	_embed_choice.add_cancel_button("Link")
	_embed_choice.confirmed.connect(_on_embed_confirmed)
	_embed_choice.canceled.connect(_on_link_chosen)


func _find_editor() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("instantiate_item_from_dict"):
			return n
		n = n.get_parent()
	return null


func _update_volume_text(db: float) -> void:
	_volume_value.text = "%+0.1f dB" % db


func _on_volume_changed(v: float) -> void:
	if _suppress_signals:
		return
	_update_volume_text(v)
	_binders["volume_db"].live(v)


func _on_volume_drag_ended(_value_changed: bool) -> void:
	if _suppress_signals:
		return
	_binders["volume_db"].commit(_volume_slider.value)


func _on_replace_pressed() -> void:
	_file_dialog.popup_centered_ratio(0.7)


func _on_file_selected(path: String) -> void:
	_pending_audio_path = path
	_embed_choice.popup_centered()


func _on_embed_confirmed() -> void:
	_apply_replacement(true)


func _on_link_chosen() -> void:
	_apply_replacement(false)


func _apply_replacement(embed: bool) -> void:
	if _pending_audio_path == "" or _item == null:
		return
	var path: String = _pending_audio_path
	_pending_audio_path = ""
	var prev_dict: Dictionary = {
		"source_mode": _item.source_mode,
		"source_path": _item.source_path,
		"asset_name": _item.asset_name,
	}
	if embed and AppState.current_project != null:
		_item.set_source_embedded_from(path)
	else:
		_item.set_source_linked(path)
	if _editor != null:
		History.push_already_done(_make_swap_command(prev_dict))
		if _editor.has_method("request_save"):
			_editor.request_save()
	_path_label.text = _item.resolve_absolute_path() if _item.source_mode == SoundNode.SourceMode.LINKED else "Embedded: %s" % _item.asset_name


func _make_swap_command(prev: Dictionary) -> HistoryCommand:
	return AssetReplaceCommand.new(_editor, _item.item_id, prev, {
		"source_mode": _item.source_mode,
		"source_path": _item.source_path,
		"asset_name": _item.asset_name,
	})
