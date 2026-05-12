class_name DocumentImporter
extends RefCounted


class ImportResult:
	var ok: bool = false
	var markdown: String = ""
	var error_message: String = ""
	var notice: String = ""
	var source_extension: String = ""


static func import_to_markdown(path: String) -> ImportResult:
	var result: ImportResult = ImportResult.new()
	if not FileAccess.file_exists(path):
		result.error_message = "File not found: %s" % path
		return result
	var ext: String = path.get_extension().to_lower()
	result.source_extension = ext
	match ext:
		"md", "markdown":
			return _import_plain_text(path, result, "Imported Markdown.")
		"txt":
			return _import_plain_text(path, result, "Imported plain text.")
		"rtf":
			return _import_rtf(path, result)
		"docx":
			return _import_docx(path, result)
		"pdf":
			return _import_pdf(path, result)
		_:
			result.error_message = "Unsupported file type: .%s" % ext
			return result


static func _import_plain_text(path: String, result: ImportResult, notice: String) -> ImportResult:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() == 0 and FileAccess.get_open_error() != OK:
		result.error_message = "Could not open file."
		return result
	var text: String = bytes.get_string_from_utf8()
	if text == "" and bytes.size() > 0:
		text = bytes.get_string_from_ascii()
	result.ok = true
	result.markdown = text
	result.notice = notice
	return result


static func _import_rtf(path: String, result: ImportResult) -> ImportResult:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() == 0:
		result.error_message = "Could not open RTF file."
		return result
	var raw: String = bytes.get_string_from_ascii()
	result.markdown = _rtf_to_markdown(raw)
	result.ok = true
	result.notice = "Imported RTF. Formatting was reduced to Markdown approximations."
	return result


static func _rtf_to_markdown(raw: String) -> String:
	var output: String = ""
	var i: int = 0
	var length: int = raw.length()
	var bold: bool = false
	var italic: bool = false
	var skip_group_depth: int = 0
	var brace_depth: int = 0
	while i < length:
		var ch: String = raw[i]
		if ch == "\\":
			var word: String = ""
			var j: int = i + 1
			if j < length and raw[j] == "*":
				skip_group_depth = max(skip_group_depth, brace_depth + 1)
				i = j + 1
				continue
			while j < length and ((raw[j] >= "a" and raw[j] <= "z") or (raw[j] >= "A" and raw[j] <= "Z")):
				word += raw[j]
				j += 1
			var numeric_part: String = ""
			var negative: bool = false
			if j < length and raw[j] == "-":
				negative = true
				j += 1
			while j < length and raw[j] >= "0" and raw[j] <= "9":
				numeric_part += raw[j]
				j += 1
			if j < length and raw[j] == " ":
				j += 1
			if word == "":
				if i + 1 < length:
					var escaped: String = raw[i + 1]
					if escaped == "\\" or escaped == "{" or escaped == "}":
						if skip_group_depth == 0:
							output += escaped
						i += 2
						continue
					if escaped == "'":
						if i + 3 < length:
							var hex: String = raw.substr(i + 2, 2)
							var code: int = ("0x" + hex).hex_to_int()
							if skip_group_depth == 0 and code != 0:
								output += char(code)
							i += 4
							continue
				i += 1
				continue
			match word:
				"par", "line":
					if skip_group_depth == 0:
						output += "\n"
				"tab":
					if skip_group_depth == 0:
						output += "\t"
				"b":
					if numeric_part == "0":
						if bold and skip_group_depth == 0:
							output += "**"
						bold = false
					else:
						if not bold and skip_group_depth == 0:
							output += "**"
						bold = true
				"i":
					if numeric_part == "0":
						if italic and skip_group_depth == 0:
							output += "*"
						italic = false
					else:
						if not italic and skip_group_depth == 0:
							output += "*"
						italic = true
				"fonttbl", "colortbl", "stylesheet", "info", "pict", "header", "footer", "object":
					skip_group_depth = max(skip_group_depth, brace_depth + 1)
				_:
					pass
			i = j
			continue
		if ch == "{":
			brace_depth += 1
			i += 1
			continue
		if ch == "}":
			if skip_group_depth > 0 and brace_depth == skip_group_depth:
				skip_group_depth = 0
			brace_depth -= 1
			i += 1
			continue
		if ch == "\r" or ch == "\n":
			i += 1
			continue
		if skip_group_depth == 0:
			output += ch
		i += 1
	if bold:
		output += "**"
	if italic:
		output += "*"
	return _collapse_blank_lines(output)


static func _collapse_blank_lines(text: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	var out: PackedStringArray = PackedStringArray()
	var blank_run: int = 0
	for line: String in lines:
		if line.strip_edges() == "":
			blank_run += 1
			if blank_run <= 2:
				out.append("")
		else:
			blank_run = 0
			out.append(line)
	return "\n".join(out).strip_edges()


static func _import_docx(path: String, result: ImportResult) -> ImportResult:
	var reader: ZIPReader = ZIPReader.new()
	if reader.open(path) != OK:
		result.error_message = "Could not open .docx (not a valid ZIP archive)."
		return result
	if not reader.file_exists("word/document.xml"):
		reader.close()
		result.error_message = "Invalid .docx (missing word/document.xml)."
		return result
	var xml_bytes: PackedByteArray = reader.read_file("word/document.xml")
	reader.close()
	var xml_text: String = xml_bytes.get_string_from_utf8()
	result.markdown = _docx_xml_to_markdown(xml_text)
	result.ok = true
	result.notice = "Imported DOCX. Bold/italic and basic headings preserved; advanced formatting was flattened."
	return result


static func _docx_xml_to_markdown(xml_text: String) -> String:
	var parser: XMLParser = XMLParser.new()
	if parser.open_buffer(xml_text.to_utf8_buffer()) != OK:
		return ""
	var out_lines: PackedStringArray = PackedStringArray()
	var current_line: String = ""
	var current_style: String = ""
	var current_list_format: String = ""
	var run_bold: bool = false
	var run_italic: bool = false
	var in_text_element: bool = false
	while parser.read() == OK:
		var node_type: int = parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var name: String = parser.get_node_name()
			match name:
				"w:p":
					current_style = ""
					current_list_format = ""
				"w:pStyle":
					current_style = parser.get_named_attribute_value_safe("w:val")
				"w:numPr":
					current_list_format = "ul"
				"w:b":
					run_bold = parser.get_named_attribute_value_safe("w:val") != "false"
				"w:i":
					run_italic = parser.get_named_attribute_value_safe("w:val") != "false"
				"w:t":
					in_text_element = true
				"w:br", "w:cr":
					current_line += "\n"
				"w:tab":
					current_line += "\t"
		elif node_type == XMLParser.NODE_TEXT:
			if in_text_element:
				var text_value: String = parser.get_node_data()
				if run_bold and run_italic:
					text_value = "***" + text_value + "***"
				elif run_bold:
					text_value = "**" + text_value + "**"
				elif run_italic:
					text_value = "*" + text_value + "*"
				current_line += text_value
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var end_name: String = parser.get_node_name()
			match end_name:
				"w:r":
					run_bold = false
					run_italic = false
				"w:t":
					in_text_element = false
				"w:p":
					var prefix: String = _docx_prefix_for_style(current_style, current_list_format)
					var line_text: String = current_line.strip_edges()
					if line_text == "":
						out_lines.append("")
					else:
						out_lines.append(prefix + line_text)
					current_line = ""
					current_style = ""
					current_list_format = ""
	return _collapse_blank_lines("\n".join(out_lines))


static func _docx_prefix_for_style(style: String, list_format: String) -> String:
	if list_format == "ul":
		return "- "
	match style:
		"Title", "Heading1":
			return "# "
		"Heading2":
			return "## "
		"Heading3":
			return "### "
		"Heading4":
			return "#### "
		"Heading5":
			return "##### "
		"Heading6":
			return "###### "
		"Quote", "IntenseQuote":
			return "> "
	return ""


static func _import_pdf(path: String, result: ImportResult) -> ImportResult:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() == 0:
		result.error_message = "Could not open PDF file."
		return result
	var extracted: String = _pdf_extract_text(bytes)
	if extracted.strip_edges() == "":
		result.markdown = "# %s\n\n*(PDF text could not be extracted in-engine. Open in an external reader and paste the contents.)*\n" % path.get_file().get_basename()
		result.ok = true
		result.notice = "PDF imported as placeholder — extraction unavailable for this file's encoding."
		return result
	result.markdown = extracted
	result.ok = true
	result.notice = "Imported PDF text. Layout and formatting were discarded."
	return result


static func _pdf_extract_text(bytes: PackedByteArray) -> String:
	var pieces: PackedStringArray = PackedStringArray()
	var data_string: String = bytes.get_string_from_ascii()
	if data_string == "":
		return ""
	var regex: RegEx = RegEx.new()
	if regex.compile("\\(((?:\\\\.|[^\\\\()])*)\\)\\s*Tj") != OK:
		return ""
	for match_result in regex.search_all(data_string):
		var inner: String = match_result.get_string(1)
		pieces.append(_pdf_unescape(inner))
	var array_regex: RegEx = RegEx.new()
	if array_regex.compile("\\[((?:[^\\[\\]]|\\\\.)*?)\\]\\s*TJ") == OK:
		for match_result_tj in array_regex.search_all(data_string):
			var inner_array: String = match_result_tj.get_string(1)
			var token_regex: RegEx = RegEx.new()
			if token_regex.compile("\\(((?:\\\\.|[^\\\\()])*)\\)") == OK:
				var assembled: String = ""
				for tok in token_regex.search_all(inner_array):
					assembled += _pdf_unescape(tok.get_string(1))
				if assembled != "":
					pieces.append(assembled)
	if pieces.size() == 0:
		return ""
	return "\n".join(pieces)


static func _pdf_unescape(raw: String) -> String:
	var out: String = ""
	var i: int = 0
	var length: int = raw.length()
	while i < length:
		var ch: String = raw[i]
		if ch == "\\" and i + 1 < length:
			var next: String = raw[i + 1]
			match next:
				"n":
					out += "\n"
					i += 2
					continue
				"r":
					out += "\r"
					i += 2
					continue
				"t":
					out += "\t"
					i += 2
					continue
				"b":
					out += "\b"
					i += 2
					continue
				"f":
					i += 2
					continue
				"(", ")", "\\":
					out += next
					i += 2
					continue
				_:
					if next >= "0" and next <= "7":
						var oct: String = ""
						var k: int = 0
						while k < 3 and i + 1 + k < length and raw[i + 1 + k] >= "0" and raw[i + 1 + k] <= "7":
							oct += raw[i + 1 + k]
							k += 1
						out += char(_octal_to_int(oct))
						i += 1 + k
						continue
					out += next
					i += 2
					continue
		out += ch
		i += 1
	return out


static func _octal_to_int(oct: String) -> int:
	var value: int = 0
	for c: String in oct:
		value = value * 8 + (c.unicode_at(0) - 48)
	return value
