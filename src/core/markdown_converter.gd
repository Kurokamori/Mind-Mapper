class_name MarkdownConverter
extends RefCounted

const HEADING_FONT_SIZES: Array[int] = [28, 24, 20, 18, 16, 15]


static func default_heading_sizes() -> Array[int]:
	return [
		HEADING_FONT_SIZES[0],
		HEADING_FONT_SIZES[1],
		HEADING_FONT_SIZES[2],
		HEADING_FONT_SIZES[3],
		HEADING_FONT_SIZES[4],
		HEADING_FONT_SIZES[5],
	]


static func markdown_to_bbcode(md: String, heading_sizes: Array[int] = default_heading_sizes()) -> String:
	if md == "":
		return ""
	var lines: PackedStringArray = md.split("\n")
	var out_lines: PackedStringArray = PackedStringArray()
	var in_code_block: bool = false
	var code_buffer: PackedStringArray = PackedStringArray()
	var in_list: bool = false
	var list_is_ordered: bool = false
	var i: int = 0
	while i < lines.size():
		var raw_line: String = lines[i]
		if in_code_block:
			if raw_line.strip_edges().begins_with("```"):
				out_lines.append("[code]" + "\n".join(code_buffer) + "[/code]")
				code_buffer = PackedStringArray()
				in_code_block = false
			else:
				code_buffer.append(raw_line)
			i += 1
			continue
		var stripped: String = raw_line.strip_edges()
		if stripped.begins_with("```"):
			if in_list:
				out_lines.append("[/ol]" if list_is_ordered else "[/ul]")
				in_list = false
			in_code_block = true
			i += 1
			continue
		var heading_level: int = _heading_level(raw_line)
		if heading_level > 0:
			if in_list:
				out_lines.append("[/ol]" if list_is_ordered else "[/ul]")
				in_list = false
			var heading_text: String = raw_line.substr(heading_level).lstrip(" ").strip_edges()
			var size_idx: int = clampi(heading_level - 1, 0, heading_sizes.size() - 1)
			var font_size: int = heading_sizes[size_idx]
			out_lines.append("[font_size=%d][b]%s[/b][/font_size]" % [font_size, _convert_inline(heading_text)])
			i += 1
			continue
		if stripped.begins_with("> "):
			if in_list:
				out_lines.append("[/ol]" if list_is_ordered else "[/ul]")
				in_list = false
			out_lines.append("[i][color=#9aa3b2]%s[/color][/i]" % _convert_inline(stripped.substr(2)))
			i += 1
			continue
		if stripped == "---" or stripped == "***" or stripped == "___":
			if in_list:
				out_lines.append("[/ol]" if list_is_ordered else "[/ul]")
				in_list = false
			out_lines.append("[color=#5a6170]────────────────────[/color]")
			i += 1
			continue
		var unordered_item_text: String = _match_unordered_item(stripped)
		var ordered_item_text: String = _match_ordered_item(stripped)
		if unordered_item_text != "":
			if in_list and list_is_ordered:
				out_lines.append("[/ol]")
				in_list = false
			if not in_list:
				out_lines.append("[ul]")
				in_list = true
				list_is_ordered = false
			out_lines.append("  " + _convert_inline(unordered_item_text))
			i += 1
			continue
		if ordered_item_text != "":
			if in_list and not list_is_ordered:
				out_lines.append("[/ul]")
				in_list = false
			if not in_list:
				out_lines.append("[ol]")
				in_list = true
				list_is_ordered = true
			out_lines.append("  " + _convert_inline(ordered_item_text))
			i += 1
			continue
		if in_list:
			out_lines.append("[/ol]" if list_is_ordered else "[/ul]")
			in_list = false
		if stripped == "":
			out_lines.append("")
		else:
			out_lines.append(_convert_inline(raw_line))
		i += 1
	if in_code_block:
		out_lines.append("[code]" + "\n".join(code_buffer) + "[/code]")
	if in_list:
		out_lines.append("[/ol]" if list_is_ordered else "[/ul]")
	return "\n".join(out_lines)


static func bbcode_to_markdown(bb: String) -> String:
	if bb == "":
		return ""
	var text: String = bb
	text = _replace_code_blocks_to_markdown(text)
	text = _replace_headings_to_markdown(text)
	text = _replace_lists_to_markdown(text)
	text = _replace_pair_tag(text, "b", "**", "**")
	text = _replace_pair_tag(text, "i", "*", "*")
	text = _replace_pair_tag(text, "u", "__", "__")
	text = _replace_pair_tag(text, "s", "~~", "~~")
	text = _replace_pair_tag(text, "code", "`", "`")
	text = _replace_url_tag_to_markdown(text)
	text = _replace_img_tag_to_markdown(text)
	text = _strip_attribute_tag(text, "color")
	text = _strip_attribute_tag(text, "font_size")
	text = _strip_attribute_tag(text, "bgcolor")
	text = _strip_attribute_tag(text, "font")
	text = text.replace("[hr]", "\n---\n")
	return text


static func _heading_level(line: String) -> int:
	var trimmed_left: String = line.lstrip(" \t")
	if not trimmed_left.begins_with("#"):
		return 0
	var level: int = 0
	while level < trimmed_left.length() and trimmed_left[level] == "#":
		level += 1
	if level == 0 or level > 6:
		return 0
	if level >= trimmed_left.length():
		return 0
	if trimmed_left[level] != " " and trimmed_left[level] != "\t":
		return 0
	return level


static func _match_unordered_item(stripped: String) -> String:
	if stripped.length() < 2:
		return ""
	var first: String = stripped.substr(0, 1)
	if (first == "-" or first == "*" or first == "+") and stripped[1] == " ":
		return stripped.substr(2)
	return ""


static func _match_ordered_item(stripped: String) -> String:
	var dot_index: int = stripped.find(".")
	if dot_index <= 0 or dot_index >= stripped.length() - 1:
		return ""
	if stripped[dot_index + 1] != " ":
		return ""
	var num_part: String = stripped.substr(0, dot_index)
	if not num_part.is_valid_int():
		return ""
	return stripped.substr(dot_index + 2)


static func _convert_inline(line: String) -> String:
	var text: String = line
	text = _replace_inline_pattern(text, "(\\*\\*|__)(.+?)\\1", "[b]$2[/b]")
	text = _replace_inline_pattern(text, "(?<!\\*)\\*([^*\\n]+?)\\*(?!\\*)", "[i]$1[/i]")
	text = _replace_inline_pattern(text, "(?<!_)_([^_\\n]+?)_(?!_)", "[i]$1[/i]")
	text = _replace_inline_pattern(text, "~~(.+?)~~", "[s]$1[/s]")
	text = _replace_inline_pattern(text, "`([^`\\n]+?)`", "[code]$1[/code]")
	text = _replace_inline_pattern(text, "!\\[([^\\]]*)\\]\\(([^)\\s]+)\\)", "[img]$2[/img]")
	text = _replace_inline_pattern(text, "\\[([^\\]]+)\\]\\(([^)\\s]+)\\)", "[url=$2]$1[/url]")
	return text


static func _replace_inline_pattern(text: String, pattern: String, replacement: String) -> String:
	var regex: RegEx = RegEx.new()
	if regex.compile(pattern) != OK:
		return text
	return regex.sub(text, replacement, true)


static func _replace_code_blocks_to_markdown(text: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("\\[code\\]([\\s\\S]*?)\\[/code\\]")
	var result: String = text
	var match_result: RegExMatch = regex.search(result)
	while match_result != null:
		var inner: String = match_result.get_string(1)
		var replacement: String
		if inner.find("\n") >= 0:
			replacement = "\n```\n" + inner + "\n```\n"
		else:
			replacement = "`" + inner + "`"
		result = result.substr(0, match_result.get_start()) + replacement + result.substr(match_result.get_end())
		match_result = regex.search(result)
	return result


static func _replace_headings_to_markdown(text: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("\\[font_size=(\\d+)\\]\\[b\\]([\\s\\S]*?)\\[/b\\]\\[/font_size\\]")
	var result: String = text
	var match_result: RegExMatch = regex.search(result)
	while match_result != null:
		var size_value: int = int(match_result.get_string(1))
		var inner_text: String = match_result.get_string(2)
		var prefix: String = _heading_prefix_for_size(size_value)
		var replacement: String = prefix + " " + inner_text
		result = result.substr(0, match_result.get_start()) + replacement + result.substr(match_result.get_end())
		match_result = regex.search(result)
	return result


static func _heading_prefix_for_size(size_value: int) -> String:
	if size_value >= 28:
		return "#"
	if size_value >= 23:
		return "##"
	if size_value >= 19:
		return "###"
	if size_value >= 17:
		return "####"
	if size_value >= 15:
		return "#####"
	return "######"


static func _replace_lists_to_markdown(text: String) -> String:
	var result: String = text
	var ul_regex: RegEx = RegEx.new()
	ul_regex.compile("\\[ul\\]([\\s\\S]*?)\\[/ul\\]")
	var ul_match: RegExMatch = ul_regex.search(result)
	while ul_match != null:
		var converted: String = _convert_list_block(ul_match.get_string(1), false)
		result = result.substr(0, ul_match.get_start()) + converted + result.substr(ul_match.get_end())
		ul_match = ul_regex.search(result)
	var ol_regex: RegEx = RegEx.new()
	ol_regex.compile("\\[ol\\]([\\s\\S]*?)\\[/ol\\]")
	var ol_match: RegExMatch = ol_regex.search(result)
	while ol_match != null:
		var converted_ol: String = _convert_list_block(ol_match.get_string(1), true)
		result = result.substr(0, ol_match.get_start()) + converted_ol + result.substr(ol_match.get_end())
		ol_match = ol_regex.search(result)
	return result


static func _convert_list_block(inner: String, ordered: bool) -> String:
	var lines: PackedStringArray = inner.split("\n")
	var out: PackedStringArray = PackedStringArray()
	var counter: int = 1
	for raw_line: String in lines:
		var trimmed: String = raw_line.strip_edges()
		if trimmed == "":
			continue
		if ordered:
			out.append("%d. %s" % [counter, trimmed])
			counter += 1
		else:
			out.append("- " + trimmed)
	return "\n".join(out)


static func _replace_pair_tag(text: String, tag: String, open_token: String, close_token: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("\\[" + tag + "\\]([\\s\\S]*?)\\[/" + tag + "\\]")
	return regex.sub(text, open_token + "$1" + close_token, true)


static func _replace_url_tag_to_markdown(text: String) -> String:
	var regex_with_target: RegEx = RegEx.new()
	regex_with_target.compile("\\[url=([^\\]]+)\\]([\\s\\S]*?)\\[/url\\]")
	var result: String = regex_with_target.sub(text, "[$2]($1)", true)
	var regex_bare: RegEx = RegEx.new()
	regex_bare.compile("\\[url\\]([\\s\\S]*?)\\[/url\\]")
	result = regex_bare.sub(result, "[$1]($1)", true)
	return result


static func _replace_img_tag_to_markdown(text: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("\\[img(?:=[^\\]]*)?\\]([\\s\\S]*?)\\[/img\\]")
	return regex.sub(text, "![]($1)", true)


static func _strip_attribute_tag(text: String, tag: String) -> String:
	var open_regex: RegEx = RegEx.new()
	open_regex.compile("\\[" + tag + "(=[^\\]]*)?\\]")
	var close_regex: RegEx = RegEx.new()
	close_regex.compile("\\[/" + tag + "\\]")
	var result: String = open_regex.sub(text, "", true)
	result = close_regex.sub(result, "", true)
	return result


static func contains_bbcode(text: String) -> bool:
	var regex: RegEx = RegEx.new()
	regex.compile("\\[/?(b|i|u|s|code|url|img|color|font_size|ul|ol|font|bgcolor|hr)(=[^\\]]*)?\\]")
	return regex.search(text) != null


static func normalize_to_markdown(text: String) -> String:
	if contains_bbcode(text):
		return bbcode_to_markdown(text)
	return text
