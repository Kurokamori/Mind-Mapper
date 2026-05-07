class_name CoauthorSyncOfferDialog
extends Window

signal sync_accepted(steam_id: int, friend_lobby_id: int)
signal sync_dismissed(steam_id: int)
signal discovery_disabled_requested()

@onready var _persona_label: Label = %PersonaLabel
@onready var _project_label: Label = %ProjectLabel
@onready var _divergence_label: Label = %DivergenceLabel
@onready var _action_label: Label = %ActionLabel
@onready var _accept_button: Button = %AcceptButton
@onready var _dismiss_button: Button = %DismissButton
@onready var _disable_button: Button = %DisableDiscoveryButton

var _steam_id: int = 0
var _friend_lobby_id: int = 0


func _ready() -> void:
	close_requested.connect(_on_close_requested)
	ThemeManager.apply_relative_font_sizes(self, {"Root/VBox/HeaderLabel": 1.15})
	ThemeManager.apply_relative_font_size(_divergence_label, 0.80)
	_accept_button.pressed.connect(_on_accept_pressed)
	_dismiss_button.pressed.connect(_on_dismiss_pressed)
	_disable_button.pressed.connect(_on_disable_pressed)


func setup(steam_id: int, persona: String, project_name: String, friend_lobby_id: int, divergence: String) -> void:
	_steam_id = steam_id
	_friend_lobby_id = friend_lobby_id
	_persona_label.text = "Co-author: %s" % persona
	_project_label.text = "Project: %s" % project_name
	_divergence_label.text = "Divergence: %s" % divergence
	if friend_lobby_id != 0:
		_action_label.text = "They're hosting a session. Click \"Sync Now\" to join their lobby and merge."
		_accept_button.text = "Join their session"
	else:
		_action_label.text = "Start a Steam session and they'll be able to join via Steam Friends."
		_accept_button.text = "Host a session"


func _on_accept_pressed() -> void:
	emit_signal("sync_accepted", _steam_id, _friend_lobby_id)
	hide()


func _on_dismiss_pressed() -> void:
	emit_signal("sync_dismissed", _steam_id)
	hide()


func _on_disable_pressed() -> void:
	emit_signal("discovery_disabled_requested")
	hide()


func _on_close_requested() -> void:
	emit_signal("sync_dismissed", _steam_id)
	hide()
