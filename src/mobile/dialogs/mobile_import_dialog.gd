class_name MobileImportDialog
extends Window

signal mode_chosen(mode: String)
signal cancelled()

const MODE_MARKDOWN: String = "markdown"
const MODE_JSON: String = "json"
const MODE_DOCUMENT: String = "document"
const MODE_IMAGE: String = "image"
const MODE_SOUND: String = "sound"

@onready var _markdown_button: Button = %MarkdownButton
@onready var _json_button: Button = %JsonButton
@onready var _document_button: Button = %DocumentButton
@onready var _image_button: Button = %ImageButton
@onready var _sound_button: Button = %SoundButton
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	close_requested.connect(_on_close_requested)
	_close_button.pressed.connect(_on_close_requested)
	_markdown_button.pressed.connect(func() -> void: _on_mode_pressed(MODE_MARKDOWN))
	_json_button.pressed.connect(func() -> void: _on_mode_pressed(MODE_JSON))
	_document_button.pressed.connect(func() -> void: _on_mode_pressed(MODE_DOCUMENT))
	_image_button.pressed.connect(func() -> void: _on_mode_pressed(MODE_IMAGE))
	_sound_button.pressed.connect(func() -> void: _on_mode_pressed(MODE_SOUND))


func _on_mode_pressed(mode_id: String) -> void:
	mode_chosen.emit(mode_id)
	hide()
	queue_free()


func _on_close_requested() -> void:
	cancelled.emit()
	hide()
	queue_free()
