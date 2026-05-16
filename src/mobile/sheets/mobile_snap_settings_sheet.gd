class_name MobileSnapSettingsSheet
extends Control

signal settings_changed()

@onready var _snap_enabled_check: CheckBox = %SnapEnabledCheck
@onready var _snap_grid_check: CheckBox = %SnapGridCheck
@onready var _snap_items_check: CheckBox = %SnapItemsCheck
@onready var _grid_size_spin: SpinBox = %GridSizeSpin
@onready var _alignment_check: CheckBox = %AlignmentCheck

var _applying: bool = false


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_snap_enabled_check.toggled.connect(_on_snap_enabled_toggled)
	_snap_grid_check.toggled.connect(_on_snap_grid_toggled)
	_snap_items_check.toggled.connect(_on_snap_items_toggled)
	_grid_size_spin.value_changed.connect(_on_grid_size_changed)
	_alignment_check.toggled.connect(_on_alignment_toggled)
	if not SnapService.changed.is_connected(_refresh):
		SnapService.changed.connect(_refresh)
	if not AlignmentGuideService.changed.is_connected(_refresh):
		AlignmentGuideService.changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	if SnapService.changed.is_connected(_refresh):
		SnapService.changed.disconnect(_refresh)
	if AlignmentGuideService.changed.is_connected(_refresh):
		AlignmentGuideService.changed.disconnect(_refresh)


func _refresh() -> void:
	_applying = true
	_snap_enabled_check.button_pressed = SnapService.enabled
	_snap_grid_check.button_pressed = SnapService.snap_to_grid
	_snap_items_check.button_pressed = SnapService.snap_to_items
	_grid_size_spin.min_value = 4.0
	_grid_size_spin.max_value = 256.0
	_grid_size_spin.step = 1.0
	_grid_size_spin.value = float(SnapService.grid_size)
	_alignment_check.button_pressed = AlignmentGuideService.enabled
	_snap_grid_check.disabled = not SnapService.enabled
	_snap_items_check.disabled = not SnapService.enabled
	_grid_size_spin.editable = SnapService.enabled and SnapService.snap_to_grid
	_applying = false


func _on_snap_enabled_toggled(pressed: bool) -> void:
	if _applying:
		return
	SnapService.set_enabled(pressed)
	settings_changed.emit()


func _on_snap_grid_toggled(pressed: bool) -> void:
	if _applying:
		return
	SnapService.set_snap_to_grid(pressed)
	settings_changed.emit()


func _on_snap_items_toggled(pressed: bool) -> void:
	if _applying:
		return
	SnapService.set_snap_to_items(pressed)
	settings_changed.emit()


func _on_grid_size_changed(value: float) -> void:
	if _applying:
		return
	SnapService.set_grid_size(int(value))
	settings_changed.emit()


func _on_alignment_toggled(pressed: bool) -> void:
	if _applying:
		return
	AlignmentGuideService.set_enabled(pressed)
	settings_changed.emit()
