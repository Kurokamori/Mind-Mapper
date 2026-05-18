class_name MobileEmbedChoiceDialog
extends Window

signal choice_made(embed: bool)
signal cancelled()

@onready var _prompt_label: Label = %PromptLabel
@onready var _embed_button: Button = %EmbedButton
@onready var _link_button: Button = %LinkButton
@onready var _cancel_button: Button = %CancelButton


func _ready() -> void:
	close_requested.connect(_on_cancel_pressed)
	_embed_button.pressed.connect(_on_embed_pressed)
	_link_button.pressed.connect(_on_link_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)


func configure(prompt: String) -> void:
	if _prompt_label == null:
		await ready
	_prompt_label.text = prompt


func _on_embed_pressed() -> void:
	choice_made.emit(true)
	hide()
	queue_free()


func _on_link_pressed() -> void:
	choice_made.emit(false)
	hide()
	queue_free()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	hide()
	queue_free()
