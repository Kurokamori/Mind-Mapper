class_name MobileExportDialog
extends Window

signal mode_chosen(mode: String)
signal cancelled()

const MODE_PNG_CURRENT: String = "png_current"
const MODE_PNG_UNFOLDED: String = "png_unfolded"
const MODE_SVG: String = "svg"
const MODE_PDF: String = "pdf"
const MODE_MARKDOWN: String = "markdown"
const MODE_HTML: String = "html"

@onready var _png_current_button: Button = %PngCurrentButton
@onready var _png_unfolded_button: Button = %PngUnfoldedButton
@onready var _svg_button: Button = %SvgButton
@onready var _pdf_button: Button = %PdfButton
@onready var _markdown_button: Button = %MarkdownButton
@onready var _html_button: Button = %HtmlButton
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	close_requested.connect(_on_close_requested)
	_close_button.pressed.connect(_on_close_requested)
	_png_current_button.pressed.connect(func() -> void: _on_mode_pressed(MODE_PNG_CURRENT))
	_png_unfolded_button.pressed.connect(func() -> void: _on_mode_pressed(MODE_PNG_UNFOLDED))
	_svg_button.pressed.connect(func() -> void: _on_mode_pressed(MODE_SVG))
	_pdf_button.pressed.connect(func() -> void: _on_mode_pressed(MODE_PDF))
	_markdown_button.pressed.connect(func() -> void: _on_mode_pressed(MODE_MARKDOWN))
	_html_button.pressed.connect(func() -> void: _on_mode_pressed(MODE_HTML))


func _on_mode_pressed(mode_id: String) -> void:
	mode_chosen.emit(mode_id)
	hide()
	queue_free()


func _on_close_requested() -> void:
	cancelled.emit()
	hide()
	queue_free()
