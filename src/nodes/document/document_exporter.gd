class_name DocumentExporter
extends RefCounted

const DEFAULT_PAGE_WIDTH: int = 800
const PAGE_HORIZONTAL_PADDING: int = 32
const PAGE_VERTICAL_PADDING: int = 32
const TITLE_GAP: int = 16
const DEFAULT_BG_COLOR: Color = Color(1, 1, 1, 1)
const DEFAULT_FG_COLOR: Color = Color(0.06, 0.07, 0.10, 1.0)
const MIN_PAGE_HEIGHT: int = 320
const MAX_PAGE_HEIGHT: int = 32768


static func export_markdown(node: DocumentNode, path: String) -> bool:
	if node == null:
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var title_line: String = ""
	if node.title.strip_edges() != "":
		title_line = "# %s\n\n" % node.title
	file.store_string(title_line + node.markdown_text)
	file.close()
	return true


static func export_pdf(node: DocumentNode, host: Node, path: String) -> bool:
	if node == null or host == null:
		return false
	var page_image: Image = await _render_document_to_image(node, host)
	if page_image == null:
		return false
	return PdfImageWriter.write_pages([page_image], path)


static func suggested_basename(node: DocumentNode) -> String:
	var name: String = node.title.strip_edges() if node != null else ""
	if name == "":
		name = "Document"
	return _sanitize_filename(name)


static func _sanitize_filename(name: String) -> String:
	var out: String = ""
	for i in range(name.length()):
		var ch: String = name[i]
		var code: int = ch.unicode_at(0)
		if ch == "/" or ch == "\\" or ch == ":" or ch == "*" or ch == "?" or ch == "\"" or ch == "<" or ch == ">" or ch == "|":
			out += "_"
		elif code < 32:
			out += "_"
		else:
			out += ch
	out = out.strip_edges()
	if out == "":
		out = "Document"
	return out


static func _render_document_to_image(node: DocumentNode, host: Node) -> Image:
	var page_width: int = DEFAULT_PAGE_WIDTH
	var bg_color: Color = node.resolved_bg_color() if node.bg_color_custom else DEFAULT_BG_COLOR
	var fg_color: Color = node.resolved_fg_color() if node.fg_color_custom else DEFAULT_FG_COLOR
	var content_width: int = page_width - PAGE_HORIZONTAL_PADDING * 2
	var sub: SubViewport = SubViewport.new()
	sub.size = Vector2i(page_width, MIN_PAGE_HEIGHT)
	sub.transparent_bg = false
	sub.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub.disable_3d = true
	sub.handle_input_locally = false
	host.add_child(sub)
	var canvas: ColorRect = ColorRect.new()
	canvas.color = bg_color
	canvas.size = Vector2(page_width, MIN_PAGE_HEIGHT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_child(canvas)
	var title_label: Label = Label.new()
	title_label.text = node.title if node.title.strip_edges() != "" else DocumentNode.DEFAULT_TITLE
	title_label.add_theme_color_override("font_color", fg_color)
	title_label.add_theme_font_size_override("font_size", node.title_font_size)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.position = Vector2(PAGE_HORIZONTAL_PADDING, PAGE_VERTICAL_PADDING)
	title_label.size = Vector2(content_width, 0)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(title_label)
	var body_label: RichTextLabel = RichTextLabel.new()
	body_label.bbcode_enabled = true
	body_label.fit_content = true
	body_label.scroll_active = false
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_color_override("default_color", fg_color)
	body_label.add_theme_font_size_override("normal_font_size", node.font_size)
	body_label.add_theme_font_size_override("bold_font_size", node.font_size)
	body_label.add_theme_font_size_override("italics_font_size", node.font_size)
	body_label.add_theme_font_size_override("mono_font_size", node.font_size)
	body_label.size = Vector2(content_width, 0)
	body_label.custom_minimum_size = Vector2(content_width, 0)
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bbcode: String = MarkdownConverter.markdown_to_bbcode(node.markdown_text, node.heading_sizes())
	var asset_root: String = ""
	if AppState.current_project != null:
		asset_root = AppState.current_project.assets_path()
	MarkdownImageRenderer.render_bbcode_with_images(body_label, bbcode, asset_root, node.max_image_width)
	canvas.add_child(body_label)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var title_height: float = title_label.get_combined_minimum_size().y
	if title_height <= 0.0:
		title_height = float(node.title_font_size) + 8.0
	title_label.size = Vector2(content_width, title_height)
	body_label.position = Vector2(PAGE_HORIZONTAL_PADDING, PAGE_VERTICAL_PADDING + title_height + TITLE_GAP)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var body_height: float = body_label.get_content_height()
	if body_height <= 0.0:
		body_height = body_label.size.y
	var total_height: int = int(ceil(PAGE_VERTICAL_PADDING + title_height + TITLE_GAP + body_height + PAGE_VERTICAL_PADDING))
	total_height = clamp(total_height, MIN_PAGE_HEIGHT, MAX_PAGE_HEIGHT)
	sub.size = Vector2i(page_width, total_height)
	canvas.size = Vector2(page_width, total_height)
	body_label.size = Vector2(content_width, body_height)
	sub.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var texture: ViewportTexture = sub.get_texture()
	var image: Image = null
	if texture != null:
		image = texture.get_image()
	sub.queue_free()
	return image
