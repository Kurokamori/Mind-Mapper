class_name DesktopLanBrowserWindow
extends Window

signal hidden_by_user()

@onready var _panel: DesktopLanBrowserPanel = %BrowserPanel


func _ready() -> void:
	close_requested.connect(_on_close_requested)
	visibility_changed.connect(_on_visibility_changed)


func panel() -> DesktopLanBrowserPanel:
	return _panel


func _on_close_requested() -> void:
	hide()


func _on_visibility_changed() -> void:
	if not visible:
		hidden_by_user.emit()
