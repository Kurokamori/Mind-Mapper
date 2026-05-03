extends Window

@onready var _list: VBoxContainer = %BindingsList
@onready var _close_btn: Button = %CloseButton
@onready var _reset_btn: Button = %ResetAllButton

const ACTION_LABELS: Dictionary = {
	KeybindingService.ACTION_UNDO: "Undo",
	KeybindingService.ACTION_REDO: "Redo",
	KeybindingService.ACTION_COPY: "Copy",
	KeybindingService.ACTION_PASTE: "Paste",
	KeybindingService.ACTION_CUT: "Cut",
	KeybindingService.ACTION_DUPLICATE: "Duplicate",
	KeybindingService.ACTION_SAVE: "Save",
	KeybindingService.ACTION_SELECT_ALL: "Select all",
	KeybindingService.ACTION_GROUP: "Group selection",
	KeybindingService.ACTION_DELETE: "Delete",
	KeybindingService.ACTION_NUDGE_LEFT: "Nudge left",
	KeybindingService.ACTION_NUDGE_RIGHT: "Nudge right",
	KeybindingService.ACTION_NUDGE_UP: "Nudge up",
	KeybindingService.ACTION_NUDGE_DOWN: "Nudge down",
	KeybindingService.ACTION_OPEN_PALETTE: "Open command palette",
	KeybindingService.ACTION_PRESENT: "Presentation mode",
	KeybindingService.ACTION_BRING_FORWARD: "Bring forward",
	KeybindingService.ACTION_BRING_TO_FRONT: "Bring to front",
	KeybindingService.ACTION_SEND_BACKWARD: "Send backward",
	KeybindingService.ACTION_SEND_TO_BACK: "Send to back",
	KeybindingService.ACTION_LOCK_TOGGLE: "Toggle item lock",
}

var _capturing_action: String = ""
var _capture_button: Button = null


func _ready() -> void:
	close_requested.connect(queue_free)
	_close_btn.pressed.connect(queue_free)
	_reset_btn.pressed.connect(_on_reset_all)
	_rebuild()


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	for action in KeybindingService.ALL_ACTIONS:
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		var name_label: Label = Label.new()
		name_label.text = String(ACTION_LABELS.get(action, action))
		name_label.custom_minimum_size = Vector2(220, 0)
		row.add_child(name_label)
		var binding_btn: Button = Button.new()
		binding_btn.text = KeybindingService.display_label(action)
		binding_btn.custom_minimum_size = Vector2(160, 0)
		var act_id: String = action
		binding_btn.pressed.connect(func() -> void: _begin_capture(act_id, binding_btn))
		row.add_child(binding_btn)
		var clear_btn: Button = Button.new()
		clear_btn.text = "Reset"
		clear_btn.pressed.connect(func() -> void:
			UserPrefs.set_keybinding(act_id, null)
			_rebuild()
		)
		row.add_child(clear_btn)
		_list.add_child(row)


func _begin_capture(action_id: String, btn: Button) -> void:
	_capturing_action = action_id
	_capture_button = btn
	btn.text = "Press a key…"


func _input(event: InputEvent) -> void:
	if _capturing_action == "":
		return
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return
	if k.keycode == KEY_ESCAPE:
		_capturing_action = ""
		_capture_button = null
		_rebuild()
		get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_SHIFT or k.keycode == KEY_CTRL or k.keycode == KEY_ALT or k.keycode == KEY_META:
		return
	UserPrefs.set_keybinding(_capturing_action, k)
	_capturing_action = ""
	_capture_button = null
	_rebuild()
	get_viewport().set_input_as_handled()


func _on_reset_all() -> void:
	UserPrefs.reset_keybindings()
	_rebuild()
