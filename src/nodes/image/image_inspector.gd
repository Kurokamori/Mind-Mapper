class_name ImageInspector
extends VBoxContainer

@onready var _path_label: Label = %PathLabel
@onready var _replace_button: Button = %ReplaceButton
@onready var _file_dialog: FileDialog = %FileDialog
@onready var _embed_choice: ConfirmationDialog = %EmbedChoice
@onready var _crop_button: Button = %CropButton
@onready var _filter_opt: OptionButton = %FilterOpt
@onready var _brightness_spin: SpinBox = %BrightnessSpin
@onready var _contrast_spin: SpinBox = %ContrastSpin
@onready var _reset_filters_btn: Button = %ResetFiltersBtn
@onready var _crop_x_spin: SpinBox = %CropXSpin
@onready var _crop_y_spin: SpinBox = %CropYSpin
@onready var _crop_w_spin: SpinBox = %CropWSpin
@onready var _crop_h_spin: SpinBox = %CropHSpin
@onready var _crop_reset_btn: Button = %CropResetBtn

var _item: ImageNode
var _editor: Node
var _pending_image_path: String = ""


func bind(item: ImageNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	ThemeManager.apply_relative_font_sizes(self, {"Header": 1.15, "PathLabel": 0.80})
	if _item == null:
		return
	_refresh_path_label()
	_replace_button.pressed.connect(_on_replace_pressed)
	_file_dialog.file_selected.connect(_on_file_selected)
	_embed_choice.add_cancel_button("Link")
	_embed_choice.confirmed.connect(_on_embed_confirmed)
	_embed_choice.canceled.connect(_on_link_chosen)
	_filter_opt.add_item("None", ImageNode.FilterMode.NONE)
	_filter_opt.add_item("Grayscale", ImageNode.FilterMode.GRAYSCALE)
	_filter_opt.add_item("Sepia", ImageNode.FilterMode.SEPIA)
	_filter_opt.add_item("Invert", ImageNode.FilterMode.INVERT)
	_filter_opt.select(_filter_opt.get_item_index(_item.filter_mode))
	_filter_opt.item_selected.connect(_on_filter_selected)
	_brightness_spin.min_value = -1.0
	_brightness_spin.max_value = 1.0
	_brightness_spin.step = 0.05
	_brightness_spin.value = _item.brightness
	_brightness_spin.value_changed.connect(_on_brightness_changed)
	_contrast_spin.min_value = 0.1
	_contrast_spin.max_value = 3.0
	_contrast_spin.step = 0.05
	_contrast_spin.value = _item.contrast
	_contrast_spin.value_changed.connect(_on_contrast_changed)
	_reset_filters_btn.pressed.connect(_on_reset_filters)
	for spin in [_crop_x_spin, _crop_y_spin, _crop_w_spin, _crop_h_spin]:
		spin.min_value = 0.0
		spin.max_value = 1.0
		spin.step = 0.01
	_crop_x_spin.value = _item.crop_rect_norm.position.x
	_crop_y_spin.value = _item.crop_rect_norm.position.y
	_crop_w_spin.value = _item.crop_rect_norm.size.x
	_crop_h_spin.value = _item.crop_rect_norm.size.y
	for spin in [_crop_x_spin, _crop_y_spin, _crop_w_spin, _crop_h_spin]:
		spin.value_changed.connect(func(_v: float) -> void: _on_crop_changed())
	_crop_reset_btn.pressed.connect(_on_crop_reset)
	_crop_button.pressed.connect(_on_crop_visual)


func _find_editor() -> Node:
	return EditorLocator.find_for(_item)


func _refresh_path_label() -> void:
	if _item.source_mode == ImageNode.SourceMode.EMBEDDED:
		_path_label.text = "Embedded: %s" % _item.asset_name
	elif _item.source_path != "":
		_path_label.text = "Linked: %s" % _item.source_path
	else:
		_path_label.text = "No image"


func _on_replace_pressed() -> void:
	PopupSizer.popup_fit(_file_dialog, {"ratio": Vector2(0.7, 0.7)})


func _on_file_selected(path: String) -> void:
	_pending_image_path = path
	PopupSizer.popup_fit(_embed_choice)


func _on_embed_confirmed() -> void:
	_apply_replacement(true)


func _on_link_chosen() -> void:
	_apply_replacement(false)


func _apply_replacement(embed: bool) -> void:
	if _pending_image_path == "" or _item == null:
		return
	var path: String = _pending_image_path
	_pending_image_path = ""
	var prev: Dictionary = {
		"source_mode": _item.source_mode,
		"source_path": _item.source_path,
		"asset_name": _item.asset_name,
	}
	if embed and AppState.current_project != null:
		_item.set_source_embedded_from(path)
	else:
		_item.set_source_linked(path)
	if _editor != null:
		History.push_already_done(AssetReplaceCommand.new(_editor, _item.item_id, prev, {
			"source_mode": _item.source_mode,
			"source_path": _item.source_path,
			"asset_name": _item.asset_name,
		}))
		if _editor.has_method("request_save"):
			_editor.request_save()
	_refresh_path_label()


func _on_filter_selected(idx: int) -> void:
	var new_filter: int = _filter_opt.get_item_id(idx)
	if new_filter == _item.filter_mode:
		return
	if _editor == null:
		_item.apply_property("filter_mode", new_filter)
		return
	History.push(ModifyPropertyCommand.new(_editor, _item.item_id, "filter_mode", _item.filter_mode, new_filter))


func _on_brightness_changed(v: float) -> void:
	if v == _item.brightness:
		return
	if _editor == null:
		_item.apply_property("brightness", v)
		return
	History.push_already_done(ModifyPropertyCommand.new(_editor, _item.item_id, "brightness", _item.brightness, v))
	_item.apply_property("brightness", v)
	if _editor.has_method("request_save"):
		_editor.request_save()


func _on_contrast_changed(v: float) -> void:
	if v == _item.contrast:
		return
	if _editor == null:
		_item.apply_property("contrast", v)
		return
	History.push_already_done(ModifyPropertyCommand.new(_editor, _item.item_id, "contrast", _item.contrast, v))
	_item.apply_property("contrast", v)
	if _editor.has_method("request_save"):
		_editor.request_save()


func _on_reset_filters() -> void:
	if _editor == null:
		_item.apply_property("filter_mode", ImageNode.FilterMode.NONE)
		_item.apply_property("brightness", 0.0)
		_item.apply_property("contrast", 1.0)
		return
	if _item.filter_mode != ImageNode.FilterMode.NONE:
		History.push(ModifyPropertyCommand.new(_editor, _item.item_id, "filter_mode", _item.filter_mode, ImageNode.FilterMode.NONE))
	if _item.brightness != 0.0:
		History.push(ModifyPropertyCommand.new(_editor, _item.item_id, "brightness", _item.brightness, 0.0))
	if _item.contrast != 1.0:
		History.push(ModifyPropertyCommand.new(_editor, _item.item_id, "contrast", _item.contrast, 1.0))
	_filter_opt.select(_filter_opt.get_item_index(ImageNode.FilterMode.NONE))
	_brightness_spin.value = 0.0
	_contrast_spin.value = 1.0


func _on_crop_changed() -> void:
	var nr: Rect2 = Rect2(_crop_x_spin.value, _crop_y_spin.value, max(0.01, _crop_w_spin.value), max(0.01, _crop_h_spin.value))
	if nr == _item.crop_rect_norm:
		return
	var before: Array = [_item.crop_rect_norm.position.x, _item.crop_rect_norm.position.y, _item.crop_rect_norm.size.x, _item.crop_rect_norm.size.y]
	var after: Array = [nr.position.x, nr.position.y, nr.size.x, nr.size.y]
	if _editor == null:
		_item.apply_property("crop_rect_norm", after)
		return
	History.push_already_done(ModifyPropertyCommand.new(_editor, _item.item_id, "crop_rect_norm", before, after))
	_item.apply_property("crop_rect_norm", after)
	if _editor.has_method("request_save"):
		_editor.request_save()


func _on_crop_reset() -> void:
	_crop_x_spin.value = 0.0
	_crop_y_spin.value = 0.0
	_crop_w_spin.value = 1.0
	_crop_h_spin.value = 1.0
	_on_crop_changed()


func _on_crop_visual() -> void:
	var dlg: Window = Window.new()
	dlg.title = "Crop image"
	dlg.size = Vector2i(560, 480)
	var ic: ImageCropPanel = ImageCropPanel.new()
	ic.bind(_item, _editor)
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dlg.add_child(ic)
	dlg.close_requested.connect(func() -> void: dlg.queue_free())
	add_child(dlg)
	PopupSizer.popup_fit(dlg, {"preferred": Vector2i(560, 480)})
