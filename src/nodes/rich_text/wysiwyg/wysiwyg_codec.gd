class_name WysiwygCodec
extends RefCounted


const IMAGE_PLACEHOLDER: String = "￼"


static func empty_attrs() -> Dictionary:
	return {
		"bold": false,
		"italic": false,
		"underline": false,
		"strike": false,
		"code": false,
		"color": null,
		"size": 0,
		"link": "",
		"image": "",
		"img_w": 0,
		"img_h": 0,
	}


static func attrs_equal(a: Dictionary, b: Dictionary) -> bool:
	return (
		a["bold"] == b["bold"]
		and a["italic"] == b["italic"]
		and a["underline"] == b["underline"]
		and a["strike"] == b["strike"]
		and a["code"] == b["code"]
		and a["color"] == b["color"]
		and a["size"] == b["size"]
		and a["link"] == b["link"]
		and a.get("image", "") == b.get("image", "")
		and a.get("img_w", 0) == b.get("img_w", 0)
		and a.get("img_h", 0) == b.get("img_h", 0)
	)


static func make_image_run(path: String, width: int, height: int) -> Dictionary:
	var attrs: Dictionary = empty_attrs()
	attrs["image"] = path
	attrs["img_w"] = max(0, width)
	attrs["img_h"] = max(0, height)
	return make_run(IMAGE_PLACEHOLDER, attrs)


static func _format_image_size_spec(width: int, height: int) -> String:
	if width <= 0 and height <= 0:
		return ""
	if height <= 0:
		return str(width)
	if width <= 0:
		return "0x%d" % height
	return "%dx%d" % [width, height]


static func make_run(text: String, attrs: Dictionary) -> Dictionary:
	var r: Dictionary = attrs.duplicate()
	r["text"] = text
	return r


static func attrs_of(run: Dictionary) -> Dictionary:
	var a: Dictionary = run.duplicate()
	a.erase("text")
	return a


static func parse(source: String) -> Array:
	if source == "":
		return [make_run("", empty_attrs())]
	var bb: String = source
	if not MarkdownConverter.contains_bbcode(bb):
		bb = MarkdownConverter.markdown_to_bbcode(bb)
	bb = _expand_lists(bb)
	return _tokenize_bbcode(bb)


static func serialize(runs: Array) -> String:
	var out: String = ""
	for r: Dictionary in runs:
		var text: String = String(r["text"])
		if text == "":
			continue
		var image_path: String = String(r.get("image", ""))
		if image_path != "":
			var img_w: int = int(r.get("img_w", 0))
			var img_h: int = int(r.get("img_h", 0))
			var spec: String = _format_image_size_spec(img_w, img_h)
			var image_glyph_count: int = text.length()
			for _i in range(image_glyph_count):
				if spec != "":
					out += "[img=%s]%s[/img]" % [spec, image_path]
				else:
					out += "[img]%s[/img]" % image_path
			continue
		var opening: String = ""
		var closing: String = ""
		if String(r["link"]) != "":
			opening += "[url=%s]" % String(r["link"])
			closing = "[/url]" + closing
		if int(r["size"]) != 0:
			opening += "[font_size=%d]" % int(r["size"])
			closing = "[/font_size]" + closing
		if r["color"] != null:
			var c: Color = r["color"] as Color
			opening += "[color=#%02x%02x%02x]" % [int(round(c.r * 255.0)), int(round(c.g * 255.0)), int(round(c.b * 255.0))]
			closing = "[/color]" + closing
		if bool(r["bold"]):
			opening += "[b]"
			closing = "[/b]" + closing
		if bool(r["italic"]):
			opening += "[i]"
			closing = "[/i]" + closing
		if bool(r["underline"]):
			opening += "[u]"
			closing = "[/u]" + closing
		if bool(r["strike"]):
			opening += "[s]"
			closing = "[/s]" + closing
		if bool(r["code"]):
			opening += "[code]"
			closing = "[/code]" + closing
		out += opening + text + closing
	return out


static func plain_text(runs: Array) -> String:
	var s: String = ""
	for r: Dictionary in runs:
		s += String(r["text"])
	return s


static func total_length(runs: Array) -> int:
	var n: int = 0
	for r: Dictionary in runs:
		n += String(r["text"]).length()
	return n


static func merge_runs(runs: Array) -> Array:
	var merged: Array = []
	for r: Dictionary in runs:
		if String(r["text"]) == "":
			continue
		if merged.size() == 0:
			merged.append(r.duplicate())
			continue
		var last: Dictionary = merged[merged.size() - 1]
		if attrs_equal(attrs_of(last), attrs_of(r)):
			last["text"] = String(last["text"]) + String(r["text"])
			merged[merged.size() - 1] = last
		else:
			merged.append(r.duplicate())
	if merged.size() == 0:
		merged.append(make_run("", empty_attrs()))
	return merged


static func _expand_lists(text: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	var out: PackedStringArray = PackedStringArray()
	var ul_depth: int = 0
	var ol_depth: int = 0
	var ol_counter: int = 1
	for line: String in lines:
		var stripped_left: String = line.strip_edges(true, false)
		if stripped_left == "[ul]":
			ul_depth += 1
			continue
		if stripped_left == "[/ul]":
			ul_depth = max(0, ul_depth - 1)
			continue
		if stripped_left == "[ol]":
			ol_depth += 1
			ol_counter = 1
			continue
		if stripped_left == "[/ol]":
			ol_depth = max(0, ol_depth - 1)
			continue
		if (ul_depth > 0 or ol_depth > 0) and line.begins_with("  "):
			var item_text: String = line.substr(2)
			if ol_depth > 0:
				out.append("%d. %s" % [ol_counter, item_text])
				ol_counter += 1
			else:
				out.append("• " + item_text)
			continue
		out.append(line)
	return "\n".join(out)


static func _tokenize_bbcode(text: String) -> Array:
	var runs: Array = []
	var stack: Array = [empty_attrs()]
	var buf: String = ""
	var i: int = 0
	var n: int = text.length()
	while i < n:
		var ch: String = text[i]
		if ch == "[":
			var close_idx: int = text.find("]", i + 1)
			if close_idx > i:
				var tag: String = text.substr(i + 1, close_idx - i - 1)
				var tag_name: String = tag
				var eq_idx: int = tag_name.find("=")
				if eq_idx >= 0:
					tag_name = tag_name.substr(0, eq_idx)
				if tag_name == "img":
					var content_end: int = text.find("[/img]", close_idx + 1)
					if content_end > close_idx:
						if buf != "":
							runs.append(make_run(buf, stack[stack.size() - 1]))
							buf = ""
						var path: String = text.substr(close_idx + 1, content_end - close_idx - 1).strip_edges()
						var spec: String = ""
						if eq_idx >= 0:
							spec = tag.substr(eq_idx + 1)
						var dims: Vector2i = _parse_image_size_spec(spec)
						var img_attrs: Dictionary = (stack[stack.size() - 1] as Dictionary).duplicate()
						img_attrs["image"] = path
						img_attrs["img_w"] = dims.x
						img_attrs["img_h"] = dims.y
						runs.append(make_run(IMAGE_PLACEHOLDER, img_attrs))
						i = content_end + 6
						continue
				if _is_supported_tag(tag):
					if buf != "":
						runs.append(make_run(buf, stack[stack.size() - 1]))
						buf = ""
					_apply_tag(tag, stack)
					i = close_idx + 1
					continue
		buf += ch
		i += 1
	if buf != "":
		runs.append(make_run(buf, stack[stack.size() - 1]))
	return merge_runs(runs)


static func _parse_image_size_spec(spec: String) -> Vector2i:
	var trimmed: String = spec.strip_edges()
	if trimmed == "":
		return Vector2i.ZERO
	var x_index: int = trimmed.find("x")
	if x_index < 0:
		if trimmed.is_valid_int():
			return Vector2i(int(trimmed), 0)
		return Vector2i.ZERO
	var width_part: String = trimmed.substr(0, x_index)
	var height_part: String = trimmed.substr(x_index + 1)
	var width_value: int = int(width_part) if width_part.is_valid_int() else 0
	var height_value: int = int(height_part) if height_part.is_valid_int() else 0
	return Vector2i(width_value, height_value)


static func _is_supported_tag(tag_content: String) -> bool:
	var name: String = tag_content
	if name.begins_with("/"):
		name = name.substr(1)
	var eq_idx: int = name.find("=")
	if eq_idx >= 0:
		name = name.substr(0, eq_idx)
	match name:
		"b", "i", "u", "s", "code", "color", "font_size", "url":
			return true
		_:
			return false


static func _apply_tag(tag_content: String, stack: Array) -> void:
	var is_closing: bool = tag_content.begins_with("/")
	var body: String = tag_content.substr(1) if is_closing else tag_content
	var name: String = body
	var value: String = ""
	var eq_idx: int = body.find("=")
	if eq_idx >= 0:
		name = body.substr(0, eq_idx)
		value = body.substr(eq_idx + 1)
	if is_closing:
		if stack.size() > 1:
			stack.pop_back()
		return
	var top: Dictionary = (stack[stack.size() - 1] as Dictionary).duplicate()
	match name:
		"b":
			top["bold"] = true
		"i":
			top["italic"] = true
		"u":
			top["underline"] = true
		"s":
			top["strike"] = true
		"code":
			top["code"] = true
		"color":
			top["color"] = _parse_color(value)
		"font_size":
			top["size"] = int(value)
		"url":
			top["link"] = value if value != "" else "__self__"
	stack.append(top)


static func _parse_color(value: String) -> Variant:
	if value == "":
		return null
	if value.begins_with("#"):
		return Color.html(value)
	if Color.html_is_valid(value):
		return Color.html(value)
	var c: Color = Color(value)
	return c
