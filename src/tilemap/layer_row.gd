class_name LayerRow
extends VBoxContainer

signal selected()
signal visibility_toggled(value: bool)
signal moved_up()
signal moved_down()
signal removed()
signal tileset_chosen(tileset_id: String)
signal opacity_changed(value: float)

var _layer: MapLayer = null
var _index: int = 0
var _layer_count: int = 0
var _tilesets_lookup: Dictionary = {}
var _is_selected_row: bool = false

var _row: PanelContainer
var _visibility: CheckButton
var _name_edit: LineEdit
var _up_btn: Button
var _down_btn: Button
var _del_btn: Button
var _ts_option: OptionButton
var _opacity_slider: HSlider


func bind(layer: MapLayer, index: int, layer_count: int, tilesets: Dictionary, is_selected: bool) -> void:
	_layer = layer
	_index = index
	_layer_count = layer_count
	_tilesets_lookup = tilesets
	_is_selected_row = is_selected
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	add_theme_constant_override("separation", 2)
	_row = PanelContainer.new()
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = ThemeManager.panel_color()
	bg.set_corner_radius_all(4)
	if _is_selected_row:
		bg.bg_color = ThemeManager.selection_highlight_color()
		bg.border_color = ThemeManager.accent_color()
		bg.set_border_width_all(1)
	_row.add_theme_stylebox_override("panel", bg)
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	_row.add_child(hbox)
	_visibility = CheckButton.new()
	_visibility.button_pressed = _layer.visible
	_visibility.tooltip_text = "Visible"
	_visibility.focus_mode = Control.FOCUS_NONE
	_visibility.toggled.connect(_on_visibility_toggled)
	hbox.add_child(_visibility)
	_name_edit = LineEdit.new()
	_name_edit.text = _layer.name
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(_on_name_submitted)
	_name_edit.focus_exited.connect(_on_name_focus_exited)
	_name_edit.gui_input.connect(_on_name_gui_input)
	hbox.add_child(_name_edit)
	_up_btn = Button.new()
	_up_btn.text = "↑"
	_up_btn.focus_mode = Control.FOCUS_NONE
	_up_btn.disabled = _index == 0
	_up_btn.pressed.connect(_on_up_pressed)
	hbox.add_child(_up_btn)
	_down_btn = Button.new()
	_down_btn.text = "↓"
	_down_btn.focus_mode = Control.FOCUS_NONE
	_down_btn.disabled = _index == _layer_count - 1
	_down_btn.pressed.connect(_on_down_pressed)
	hbox.add_child(_down_btn)
	_del_btn = Button.new()
	_del_btn.text = "🗑"
	_del_btn.focus_mode = Control.FOCUS_NONE
	_del_btn.disabled = _layer_count <= 1
	_del_btn.pressed.connect(_on_del_pressed)
	hbox.add_child(_del_btn)
	add_child(_row)
	var lower: HBoxContainer = HBoxContainer.new()
	lower.add_theme_constant_override("separation", 4)
	var ts_label: Label = Label.new()
	ts_label.text = "Tileset:"
	lower.add_child(ts_label)
	_ts_option = OptionButton.new()
	_ts_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ts_option.focus_mode = Control.FOCUS_NONE
	var ts_ids: Array = _tilesets_lookup.keys()
	var current_idx: int = -1
	for i in range(ts_ids.size()):
		var ts_id: String = ts_ids[i]
		var ts: TileSetResource = _tilesets_lookup[ts_id]
		_ts_option.add_item(ts.name, i)
		_ts_option.set_item_metadata(i, ts_id)
		if ts_id == _layer.tileset_id:
			current_idx = i
	if current_idx >= 0:
		_ts_option.select(current_idx)
	_ts_option.item_selected.connect(_on_ts_option_selected)
	lower.add_child(_ts_option)
	_opacity_slider = HSlider.new()
	_opacity_slider.min_value = 0.0
	_opacity_slider.max_value = 1.0
	_opacity_slider.step = 0.05
	_opacity_slider.value = _layer.opacity
	_opacity_slider.custom_minimum_size = Vector2(60, 0)
	_opacity_slider.tooltip_text = "Opacity"
	_opacity_slider.focus_mode = Control.FOCUS_NONE
	_opacity_slider.drag_ended.connect(_on_opacity_drag_ended)
	lower.add_child(_opacity_slider)
	add_child(lower)


func _on_visibility_toggled(p: bool) -> void:
	emit_signal("visibility_toggled", p)


func _on_name_submitted(s: String) -> void:
	var trimmed: String = s.strip_edges()
	if trimmed == "" or trimmed == _layer.name:
		return
	emit_signal("renamed", trimmed)


func _on_name_focus_exited() -> void:
	var current: String = _name_edit.text.strip_edges()
	if current == "" or current == _layer.name:
		return
	emit_signal("renamed", current)


func _on_name_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev
		if mb.pressed:
			emit_signal("selected")


func _on_up_pressed() -> void:
	emit_signal("moved_up")


func _on_down_pressed() -> void:
	emit_signal("moved_down")


func _on_del_pressed() -> void:
	emit_signal("removed")


func _on_ts_option_selected(idx: int) -> void:
	var meta: Variant = _ts_option.get_item_metadata(idx)
	if typeof(meta) != TYPE_STRING:
		return
	emit_signal("tileset_chosen", String(meta))


func _on_opacity_drag_ended(_changed: bool) -> void:
	emit_signal("opacity_changed", _opacity_slider.value)
