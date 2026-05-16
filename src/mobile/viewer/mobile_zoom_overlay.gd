class_name MobileZoomOverlay
extends PanelContainer

signal zoom_in_requested()
signal zoom_out_requested()
signal fit_requested()

@onready var _zoom_in_button: Button = %ZoomInButton
@onready var _zoom_out_button: Button = %ZoomOutButton
@onready var _zoom_fit_button: Button = %ZoomFitButton
@onready var _zoom_label: Label = %ZoomOverlayLabel


func _ready() -> void:
	_zoom_in_button.pressed.connect(func() -> void: zoom_in_requested.emit())
	_zoom_out_button.pressed.connect(func() -> void: zoom_out_requested.emit())
	_zoom_fit_button.pressed.connect(func() -> void: fit_requested.emit())


func update_zoom(value: float) -> void:
	if _zoom_label == null:
		return
	_zoom_label.text = "%d%%" % int(round(value * 100.0))
