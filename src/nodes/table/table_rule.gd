class_name TableRule
extends RefCounted

const SCOPE_ALL: String = "all"
const SCOPE_COLUMN: String = "column"
const SCOPE_ROW: String = "row"
const SCOPE_CELL: String = "cell"

const OP_ALWAYS: String = "always"
const OP_CONTAINS: String = "contains"
const OP_EQUALS: String = "equals"
const OP_STARTS_WITH: String = "starts_with"
const OP_ENDS_WITH: String = "ends_with"
const OP_REGEX: String = "regex"
const OP_EMPTY: String = "empty"
const OP_NON_EMPTY: String = "non_empty"
const OP_NUM_GREATER: String = "number_greater"
const OP_NUM_LESS: String = "number_less"
const OP_NUM_EQUALS: String = "number_equals"
const OP_NUM_BETWEEN: String = "number_between"

const SCOPE_OPTIONS: Array = [
	{"id": SCOPE_ALL, "label": "All cells"},
	{"id": SCOPE_COLUMN, "label": "Column"},
	{"id": SCOPE_ROW, "label": "Row"},
	{"id": SCOPE_CELL, "label": "Single cell"},
]

const OP_OPTIONS: Array = [
	{"id": OP_ALWAYS, "label": "Always", "needs_value": false, "needs_value2": false},
	{"id": OP_CONTAINS, "label": "Contains", "needs_value": true, "needs_value2": false},
	{"id": OP_EQUALS, "label": "Equals", "needs_value": true, "needs_value2": false},
	{"id": OP_STARTS_WITH, "label": "Starts with", "needs_value": true, "needs_value2": false},
	{"id": OP_ENDS_WITH, "label": "Ends with", "needs_value": true, "needs_value2": false},
	{"id": OP_REGEX, "label": "Regex match", "needs_value": true, "needs_value2": false},
	{"id": OP_EMPTY, "label": "Is empty", "needs_value": false, "needs_value2": false},
	{"id": OP_NON_EMPTY, "label": "Is non-empty", "needs_value": false, "needs_value2": false},
	{"id": OP_NUM_GREATER, "label": "Number >", "needs_value": true, "needs_value2": false},
	{"id": OP_NUM_LESS, "label": "Number <", "needs_value": true, "needs_value2": false},
	{"id": OP_NUM_EQUALS, "label": "Number =", "needs_value": true, "needs_value2": false},
	{"id": OP_NUM_BETWEEN, "label": "Number in [a, b]", "needs_value": true, "needs_value2": true},
]


static func make_default() -> Dictionary:
	return {
		"scope": SCOPE_ALL,
		"column": 0,
		"row": 0,
		"op": OP_CONTAINS,
		"value": "",
		"value2": "",
		"case_sensitive": false,
		"use_bg": true,
		"use_fg": false,
		"bg": [0.95, 0.83, 0.30, 1.0],
		"fg": [0.10, 0.10, 0.12, 1.0],
		"bold": false,
		"italic": false,
		"apply_to_header_row": false,
	}


static func normalize(raw: Variant) -> Dictionary:
	var src: Dictionary = raw as Dictionary if typeof(raw) == TYPE_DICTIONARY else {}
	var def: Dictionary = make_default()
	var out: Dictionary = {}
	for key: String in def.keys():
		out[key] = src.get(key, def[key])
	out["scope"] = String(out["scope"])
	out["op"] = String(out["op"])
	out["value"] = String(out["value"])
	out["value2"] = String(out["value2"])
	out["column"] = int(out["column"])
	out["row"] = int(out["row"])
	out["case_sensitive"] = bool(out["case_sensitive"])
	out["use_bg"] = bool(out["use_bg"])
	out["use_fg"] = bool(out["use_fg"])
	out["bold"] = bool(out["bold"])
	out["italic"] = bool(out["italic"])
	out["apply_to_header_row"] = bool(out["apply_to_header_row"])
	return out


static func normalize_array(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for entry: Variant in (raw as Array):
		out.append(normalize(entry))
	return out


static func scope_in_range(rule: Dictionary, r: int, c: int) -> bool:
	var scope: String = String(rule.get("scope", SCOPE_ALL))
	match scope:
		SCOPE_ALL:
			return true
		SCOPE_COLUMN:
			return c == int(rule.get("column", 0))
		SCOPE_ROW:
			return r == int(rule.get("row", 0))
		SCOPE_CELL:
			return r == int(rule.get("row", 0)) and c == int(rule.get("column", 0))
	return false


static func matches_value(rule: Dictionary, cell_text: String) -> bool:
	var op: String = String(rule.get("op", OP_CONTAINS))
	var value: String = String(rule.get("value", ""))
	var value2: String = String(rule.get("value2", ""))
	var case_sensitive: bool = bool(rule.get("case_sensitive", false))
	var lhs: String = cell_text if case_sensitive else cell_text.to_lower()
	var rhs: String = value if case_sensitive else value.to_lower()
	match op:
		OP_ALWAYS:
			return true
		OP_CONTAINS:
			return value != "" and lhs.contains(rhs)
		OP_EQUALS:
			return lhs == rhs
		OP_STARTS_WITH:
			return value != "" and lhs.begins_with(rhs)
		OP_ENDS_WITH:
			return value != "" and lhs.ends_with(rhs)
		OP_REGEX:
			if value == "":
				return false
			var re: RegEx = RegEx.new()
			var pattern: String = value
			if not case_sensitive:
				pattern = "(?i)" + pattern
			var err: int = re.compile(pattern)
			if err != OK:
				return false
			return re.search(cell_text) != null
		OP_EMPTY:
			return cell_text.strip_edges() == ""
		OP_NON_EMPTY:
			return cell_text.strip_edges() != ""
		OP_NUM_GREATER:
			return _parse_number(cell_text) > _parse_number(value)
		OP_NUM_LESS:
			return _parse_number(cell_text) < _parse_number(value)
		OP_NUM_EQUALS:
			return is_equal_approx(_parse_number(cell_text), _parse_number(value))
		OP_NUM_BETWEEN:
			var n: float = _parse_number(cell_text)
			var lo: float = _parse_number(value)
			var hi: float = _parse_number(value2)
			if lo > hi:
				var tmp: float = lo
				lo = hi
				hi = tmp
			return n >= lo and n <= hi
	return false


static func _parse_number(s: String) -> float:
	var trimmed: String = s.strip_edges()
	if trimmed == "":
		return NAN
	if not trimmed.is_valid_float():
		var cleaned: String = ""
		for ch: String in trimmed:
			if "0123456789.-+eE".contains(ch):
				cleaned += ch
		if cleaned.is_valid_float():
			return cleaned.to_float()
		return NAN
	return trimmed.to_float()


static func op_needs_value(op: String) -> bool:
	for info: Dictionary in OP_OPTIONS:
		if String(info["id"]) == op:
			return bool(info.get("needs_value", false))
	return false


static func op_needs_value2(op: String) -> bool:
	for info: Dictionary in OP_OPTIONS:
		if String(info["id"]) == op:
			return bool(info.get("needs_value2", false))
	return false


static func evaluate_cell(rules: Array, r: int, c: int, cell_text: String, header_row: bool) -> Dictionary:
	var formatting: Dictionary = {"bg": null, "fg": null, "bold": false, "italic": false, "matched": false}
	for rule_v: Variant in rules:
		if typeof(rule_v) != TYPE_DICTIONARY:
			continue
		var rule: Dictionary = rule_v
		if header_row and not bool(rule.get("apply_to_header_row", false)):
			continue
		if not scope_in_range(rule, r, c):
			continue
		if not matches_value(rule, cell_text):
			continue
		formatting["matched"] = true
		if bool(rule.get("use_bg", false)):
			formatting["bg"] = ColorUtil.from_array(rule.get("bg", null), Color(1, 1, 1, 1))
		if bool(rule.get("use_fg", false)):
			formatting["fg"] = ColorUtil.from_array(rule.get("fg", null), Color(0, 0, 0, 1))
		if bool(rule.get("bold", false)):
			formatting["bold"] = true
		if bool(rule.get("italic", false)):
			formatting["italic"] = true
	return formatting
