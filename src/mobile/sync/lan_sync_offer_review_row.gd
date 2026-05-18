class_name LanSyncOfferReviewRow
extends PanelContainer

signal choice_changed(relative_path: String, choice: String)

@onready var _path_label: Label = %PathLabel
@onready var _keep_mine_button: Button = %KeepMineButton
@onready var _keep_theirs_button: Button = %KeepTheirsButton
@onready var _state_label: Label = %StateLabel

var _relative_path: String = ""
var _current_choice: String = LanSyncOfferDialog.RESOLUTION_KEEP_MINE


func _ready() -> void:
	_keep_mine_button.pressed.connect(_on_keep_mine_pressed)
	_keep_theirs_button.pressed.connect(_on_keep_theirs_pressed)
	_sync_toggle_buttons()
	_refresh_state_label()


func bind(relative_path: String) -> void:
	_relative_path = relative_path
	_path_label.text = relative_path


func set_choice(choice: String) -> void:
	if _current_choice == choice:
		_sync_toggle_buttons()
		return
	_current_choice = choice
	_sync_toggle_buttons()
	_refresh_state_label()


func relative_path() -> String:
	return _relative_path


func _on_keep_mine_pressed() -> void:
	_current_choice = LanSyncOfferDialog.RESOLUTION_KEEP_MINE
	_sync_toggle_buttons()
	_refresh_state_label()
	emit_signal("choice_changed", _relative_path, _current_choice)


func _on_keep_theirs_pressed() -> void:
	_current_choice = LanSyncOfferDialog.RESOLUTION_KEEP_THEIRS
	_sync_toggle_buttons()
	_refresh_state_label()
	emit_signal("choice_changed", _relative_path, _current_choice)


func _sync_toggle_buttons() -> void:
	if _keep_mine_button == null or _keep_theirs_button == null:
		return
	var mine_active: bool = _current_choice == LanSyncOfferDialog.RESOLUTION_KEEP_MINE
	_keep_mine_button.set_pressed_no_signal(mine_active)
	_keep_theirs_button.set_pressed_no_signal(not mine_active)


func _refresh_state_label() -> void:
	if _state_label == null:
		return
	if _current_choice == LanSyncOfferDialog.RESOLUTION_KEEP_MINE:
		_state_label.text = "→ Keeping my (desktop) version"
	else:
		_state_label.text = "→ Accepting incoming version"
