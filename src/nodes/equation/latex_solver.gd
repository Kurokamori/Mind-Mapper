class_name LatexSolver
extends RefCounted

const FUNCTION_MAP: Dictionary = {
	"sin": "sin", "cos": "cos", "tan": "tan",
	"asin": "asin", "acos": "acos", "atan": "atan",
	"arcsin": "asin", "arccos": "acos", "arctan": "atan",
	"sinh": "sinh", "cosh": "cosh", "tanh": "tanh",
	"log": "log", "ln": "log", "lg": "log",
	"exp": "exp", "abs": "abs", "floor": "floor", "ceil": "ceil",
	"sqrt": "sqrt", "max": "max", "min": "min",
}

const CONSTANT_MAP: Dictionary = {
	"pi": "PI", "tau": "TAU", "e": "2.718281828459045",
	"infty": "INF", "infin": "INF",
}


static func try_solve(src: String) -> Dictionary:
	if src.strip_edges() == "":
		return {"ok": false, "reason": "empty"}
	var clean: String = _strip_math_delims(src.strip_edges())
	var sides: Array = _split_equation(clean)
	if sides.size() == 2:
		var lhs: String = String(sides[0]).strip_edges()
		var rhs: String = String(sides[1]).strip_edges()
		var assign_var: String = _detect_simple_var(lhs)
		if assign_var != "":
			var rhs_val: Variant = _evaluate(rhs)
			if rhs_val == null:
				return {"ok": false, "reason": "cannot evaluate right-hand side"}
			return {"ok": true, "mode": "assign", "var": assign_var, "value": rhs_val, "formatted": assign_var + " = " + _format_number(rhs_val)}
		var lhs_val: Variant = _evaluate(lhs)
		var rhs_val2: Variant = _evaluate(rhs)
		if lhs_val != null and rhs_val2 != null:
			var truth: bool = abs(float(lhs_val) - float(rhs_val2)) < 1.0e-9
			return {"ok": true, "mode": "check", "lhs": lhs_val, "rhs": rhs_val2, "truth": truth, "formatted": _format_number(lhs_val) + " = " + _format_number(rhs_val2) + ("  ✓" if truth else "  ✗")}
		if lhs_val != null and rhs_val2 == null:
			return {"ok": true, "mode": "lhs_only", "value": lhs_val, "formatted": "LHS = " + _format_number(lhs_val)}
		if rhs_val2 != null and lhs_val == null:
			return {"ok": true, "mode": "rhs_only", "value": rhs_val2, "formatted": "RHS = " + _format_number(rhs_val2)}
		return {"ok": false, "reason": "symbolic equation"}
	var val: Variant = _evaluate(clean)
	if val == null:
		return {"ok": false, "reason": "cannot evaluate"}
	return {"ok": true, "mode": "value", "value": val, "formatted": _format_number(val)}


static func _strip_math_delims(s: String) -> String:
	var t: String = s.strip_edges()
	if t.begins_with("$$") and t.ends_with("$$"):
		return t.substr(2, t.length() - 4).strip_edges()
	if t.begins_with("\\[") and t.ends_with("\\]"):
		return t.substr(2, t.length() - 4).strip_edges()
	if t.begins_with("\\(") and t.ends_with("\\)"):
		return t.substr(2, t.length() - 4).strip_edges()
	if t.length() >= 2 and t.begins_with("$") and t.ends_with("$"):
		return t.substr(1, t.length() - 2).strip_edges()
	return t


static func _split_equation(s: String) -> Array:
	var depth: int = 0
	for i in range(s.length()):
		var c: String = s.substr(i, 1)
		if c == "{" or c == "(" or c == "[":
			depth += 1
		elif c == "}" or c == ")" or c == "]":
			depth -= 1
		elif c == "=" and depth == 0:
			if i > 0 and s.substr(i - 1, 1) in ["<", ">", "!", ":"]:
				continue
			if i + 1 < s.length() and s.substr(i + 1, 1) == "=":
				continue
			return [s.substr(0, i), s.substr(i + 1, s.length() - i - 1)]
	return [s]


static func _detect_simple_var(lhs: String) -> String:
	var t: String = lhs.strip_edges()
	if t.length() == 0:
		return ""
	for i in range(t.length()):
		var c: String = t.substr(i, 1)
		if not _is_identifier_char(c):
			return ""
	if _is_digit(t.substr(0, 1)):
		return ""
	return t


static func _is_identifier_char(c: String) -> bool:
	if c.length() == 0:
		return false
	var code: int = c.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or c == "_"


static func _is_digit(c: String) -> bool:
	if c.length() == 0:
		return false
	var code: int = c.unicode_at(0)
	return code >= 48 and code <= 57


static func _evaluate(latex_src: String) -> Variant:
	var expr_str: String = _to_expression(latex_src)
	if expr_str == "":
		return null
	var expr: Expression = Expression.new()
	var err: int = expr.parse(expr_str)
	if err != OK:
		return null
	var result: Variant = expr.execute([], null, false)
	if expr.has_execute_failed():
		return null
	if typeof(result) != TYPE_FLOAT and typeof(result) != TYPE_INT:
		return null
	if typeof(result) == TYPE_FLOAT:
		var f: float = float(result)
		if is_nan(f) or is_inf(f):
			return null
	return result


static func _is_known_identifier(word: String) -> bool:
	if word == "PI" or word == "TAU" or word == "INF" or word == "NAN":
		return true
	if FUNCTION_MAP.values().has(word):
		return true
	if word == "pow" or word == "round" or word == "sign" or word == "fmod":
		return true
	return false


static func _to_expression(src: String) -> String:
	var s: String = src
	s = _replace_constants_and_functions(s)
	s = _expand_fracs(s)
	s = _expand_sqrts(s)
	s = _strip_decorations(s)
	s = _strip_left_right(s)
	s = _strip_text_styles(s)
	s = _replace_operators(s)
	s = _drop_subscripts(s)
	s = _expand_powers(s)
	s = _replace_braces_with_parens(s)
	s = _strip_remaining_backslashes(s)
	s = _insert_implicit_multiplication(s)
	s = _collapse_whitespace(s)
	return s


static func _replace_constants_and_functions(s: String) -> String:
	var out: String = ""
	var i: int = 0
	while i < s.length():
		var c: String = s.substr(i, 1)
		if c == "\\":
			var name_end: int = i + 1
			while name_end < s.length():
				var ch: String = s.substr(name_end, 1)
				var code: int = ch.unicode_at(0)
				var is_a: bool = (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
				if not is_a:
					break
				name_end += 1
			var name: String = s.substr(i + 1, name_end - i - 1)
			if name == "":
				out += s.substr(i, 2)
				i += 2
				continue
			if CONSTANT_MAP.has(name):
				out += " " + String(CONSTANT_MAP[name]) + " "
				i = name_end
				continue
			if FUNCTION_MAP.has(name):
				out += " " + String(FUNCTION_MAP[name])
				i = name_end
				continue
			out += "\\" + name
			i = name_end
		else:
			out += c
			i += 1
	return out


static func _expand_fracs(s: String) -> String:
	var keys: Array = ["frac", "dfrac", "tfrac", "cfrac"]
	var changed: bool = true
	var current: String = s
	while changed:
		changed = false
		for key in keys:
			var token: String = "\\" + String(key)
			var pos: int = current.find(token)
			while pos >= 0:
				var after: int = pos + token.length()
				var a_pair: Array = _read_braced_group(current, after)
				if a_pair.size() != 2:
					pos = current.find(token, after)
					continue
				var b_pair: Array = _read_braced_group(current, int(a_pair[1]))
				if b_pair.size() != 2:
					pos = current.find(token, after)
					continue
				var num: String = String(a_pair[0])
				var den: String = String(b_pair[0])
				var replacement: String = "((" + num + ")/(" + den + "))"
				current = current.substr(0, pos) + replacement + current.substr(int(b_pair[1]), current.length() - int(b_pair[1]))
				changed = true
				pos = current.find(token, pos + replacement.length())
	return current


static func _expand_sqrts(s: String) -> String:
	var current: String = s
	var changed: bool = true
	while changed:
		changed = false
		var pos: int = current.find("\\sqrt")
		while pos >= 0:
			var after: int = pos + 5
			var index_str: String = ""
			var read_from: int = after
			if read_from < current.length() and current.substr(read_from, 1) == "[":
				var br_pair: Array = _read_bracket_group(current, read_from)
				if br_pair.size() == 2:
					index_str = String(br_pair[0])
					read_from = int(br_pair[1])
			var grp: Array = _read_braced_group(current, read_from)
			if grp.size() != 2:
				pos = current.find("\\sqrt", after)
				continue
			var rad: String = String(grp[0])
			var rep: String
			if index_str == "":
				rep = " sqrt(" + rad + ") "
			else:
				rep = " pow((" + rad + "),(1.0/(" + index_str + "))) "
			current = current.substr(0, pos) + rep + current.substr(int(grp[1]), current.length() - int(grp[1]))
			changed = true
			pos = current.find("\\sqrt", pos + rep.length())
	return current


static func _read_braced_group(s: String, start: int) -> Array:
	var i: int = start
	while i < s.length() and s.substr(i, 1) == " ":
		i += 1
	if i >= s.length():
		return []
	if s.substr(i, 1) != "{":
		if i < s.length():
			return [s.substr(i, 1), i + 1]
		return []
	var depth: int = 1
	var j: int = i + 1
	while j < s.length():
		var c: String = s.substr(j, 1)
		if c == "{":
			depth += 1
		elif c == "}":
			depth -= 1
			if depth == 0:
				return [s.substr(i + 1, j - i - 1), j + 1]
		j += 1
	return []


static func _read_bracket_group(s: String, start: int) -> Array:
	if start >= s.length() or s.substr(start, 1) != "[":
		return []
	var depth: int = 1
	var j: int = start + 1
	while j < s.length():
		var c: String = s.substr(j, 1)
		if c == "[":
			depth += 1
		elif c == "]":
			depth -= 1
			if depth == 0:
				return [s.substr(start + 1, j - start - 1), j + 1]
		j += 1
	return []


static func _strip_decorations(s: String) -> String:
	var keys: Array = ["hat", "widehat", "bar", "overline", "underline", "tilde", "widetilde", "vec", "dot", "ddot", "mathring", "boxed", "fbox"]
	var current: String = s
	for key in keys:
		var token: String = "\\" + String(key)
		var pos: int = current.find(token)
		while pos >= 0:
			var after: int = pos + token.length()
			var grp: Array = _read_braced_group(current, after)
			if grp.size() != 2:
				pos = current.find(token, after)
				continue
			current = current.substr(0, pos) + "(" + String(grp[0]) + ")" + current.substr(int(grp[1]), current.length() - int(grp[1]))
			pos = current.find(token, pos + 1)
	return current


static func _strip_text_styles(s: String) -> String:
	var keys: Array = ["mathrm", "mathbf", "mathit", "mathsf", "mathtt", "mathcal", "mathbb", "mathfrak", "operatorname", "text", "textbf", "textit", "textrm", "texttt", "boldsymbol", "bm"]
	var current: String = s
	for key in keys:
		var token: String = "\\" + String(key)
		var pos: int = current.find(token)
		while pos >= 0:
			var after: int = pos + token.length()
			var grp: Array = _read_braced_group(current, after)
			if grp.size() != 2:
				pos = current.find(token, after)
				continue
			current = current.substr(0, pos) + String(grp[0]) + current.substr(int(grp[1]), current.length() - int(grp[1]))
			pos = current.find(token, pos + 1)
	return current


static func _strip_left_right(s: String) -> String:
	var current: String = s
	var keys: Array = ["\\left", "\\right", "\\bigl", "\\Bigl", "\\biggl", "\\Biggl", "\\bigr", "\\Bigr", "\\biggr", "\\Biggr", "\\big", "\\Big", "\\bigg", "\\Bigg"]
	for k in keys:
		current = current.replace(String(k), "")
	current = current.replace("\\.", "")
	return current


static func _replace_operators(s: String) -> String:
	var pairs: Array = [
		["\\cdot", "*"], ["\\times", "*"], ["\\ast", "*"],
		["\\div", "/"], ["\\pm", "+"], ["\\mp", "-"],
		["\\le", "<="], ["\\leq", "<="], ["\\ge", ">="], ["\\geq", ">="],
		["\\neq", "!="], ["\\ne", "!="], ["\\approx", "="], ["\\equiv", "="],
		["\\,", " "], ["\\;", " "], ["\\:", " "], ["\\!", ""], ["\\quad", " "], ["\\qquad", " "],
		["\\%", "%"], ["\\$", "$"], ["\\#", "#"], ["\\&", "&"],
		["\\\\", " "],
	]
	var current: String = s
	for p in pairs:
		current = current.replace(String(p[0]), String(p[1]))
	return current


static func _drop_subscripts(s: String) -> String:
	var current: String = s
	var pos: int = current.find("_")
	while pos >= 0:
		var after: int = pos + 1
		if after < current.length() and current.substr(after, 1) == "{":
			var grp: Array = _read_braced_group(current, after)
			if grp.size() == 2:
				current = current.substr(0, pos) + current.substr(int(grp[1]), current.length() - int(grp[1]))
				pos = current.find("_", pos)
				continue
		if after < current.length():
			current = current.substr(0, pos) + current.substr(after + 1, current.length() - after - 1)
			pos = current.find("_", pos)
			continue
		current = current.substr(0, pos)
		break
	return current


static func _expand_powers(s: String) -> String:
	var current: String = s
	var pos: int = current.find("^")
	while pos >= 0:
		var after: int = pos + 1
		if after >= current.length():
			break
		var grp: Array = _read_braced_group(current, after)
		var op_str: String
		var end_idx: int
		if grp.size() == 2 and after < current.length() and current.substr(after, 1) == "{":
			op_str = "(" + String(grp[0]) + ")"
			end_idx = int(grp[1])
		else:
			op_str = "(" + current.substr(after, 1) + ")"
			end_idx = after + 1
		var rep: String = "**" + op_str
		current = current.substr(0, pos) + rep + current.substr(end_idx, current.length() - end_idx)
		pos = current.find("^", pos + rep.length())
	return current


static func _replace_braces_with_parens(s: String) -> String:
	return s.replace("{", "(").replace("}", ")")


static func _strip_remaining_backslashes(s: String) -> String:
	var out: String = ""
	var i: int = 0
	while i < s.length():
		var c: String = s.substr(i, 1)
		if c == "\\":
			i += 1
			while i < s.length():
				var ch: String = s.substr(i, 1)
				var code: int = ch.unicode_at(0)
				var is_a: bool = (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
				if not is_a:
					break
				i += 1
			continue
		out += c
		i += 1
	return out


static func _insert_implicit_multiplication(s: String) -> String:
	var tokens: Array = _tokenize_for_implicit(s)
	var filtered: Array = []
	for t: Dictionary in tokens:
		if String(t.k) != "ws":
			filtered.append(t)
	var out: String = ""
	for i in range(filtered.size()):
		var tok: Dictionary = filtered[i]
		out += String(tok.v)
		if i + 1 >= filtered.size():
			continue
		var nxt: Dictionary = filtered[i + 1]
		if _needs_mul(tok, nxt):
			out += "*"
		elif _needs_space(tok, nxt):
			out += " "
	return out


static func _needs_space(prev: Dictionary, nxt: Dictionary) -> bool:
	var pk: String = String(prev.k)
	var nk: String = String(nxt.k)
	if pk == "ident" and bool(prev.get("known", false)):
		var v: String = String(prev.v)
		if nk == "lp":
			return false
		if v == "PI" or v == "TAU" or v == "INF" or v == "NAN":
			return false
		return true
	return false


static func _tokenize_for_implicit(s: String) -> Array:
	var out: Array = []
	var i: int = 0
	while i < s.length():
		var c: String = s.substr(i, 1)
		if c == " " or c == "\t" or c == "\n":
			out.append({"k": "ws", "v": c})
			i += 1
			continue
		if _is_digit(c) or c == ".":
			var j: int = i
			while j < s.length() and (_is_digit(s.substr(j, 1)) or s.substr(j, 1) == "."):
				j += 1
			out.append({"k": "num", "v": s.substr(i, j - i)})
			i = j
			continue
		var code: int = c.unicode_at(0)
		var is_a: bool = (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or c == "_"
		if is_a:
			var k: int = i
			while k < s.length():
				var ck: String = s.substr(k, 1)
				var ck_code: int = ck.unicode_at(0)
				var ck_a: bool = (ck_code >= 65 and ck_code <= 90) or (ck_code >= 97 and ck_code <= 122) or ck == "_"
				if not ck_a:
					break
				k += 1
			var word: String = s.substr(i, k - i)
			if _is_known_identifier(word):
				out.append({"k": "ident", "v": word, "known": true})
			else:
				for ci in range(word.length()):
					out.append({"k": "ident", "v": word.substr(ci, 1), "known": false})
			i = k
			continue
		if c == "*" and i + 1 < s.length() and s.substr(i + 1, 1) == "*":
			out.append({"k": "op", "v": "**"})
			i += 2
			continue
		if c == "(":
			out.append({"k": "lp", "v": "("})
			i += 1
			continue
		if c == ")":
			out.append({"k": "rp", "v": ")"})
			i += 1
			continue
		out.append({"k": "op", "v": c})
		i += 1
	return out


static func _needs_mul(prev: Dictionary, nxt: Dictionary) -> bool:
	var pk: String = String(prev.k)
	var nk: String = String(nxt.k)
	if pk == "ws" or nk == "ws":
		return false
	if pk == "op" or nk == "op":
		return false
	if pk == "lp":
		return false
	if nk == "rp":
		return false
	if pk == "num" and (nk == "ident" or nk == "lp"):
		return true
	if pk == "ident":
		if nk == "num":
			return true
		if nk == "ident":
			return true
		if nk == "lp":
			return not bool(prev.get("known", false))
	if pk == "rp" and (nk == "ident" or nk == "num" or nk == "lp"):
		return true
	return false


static func _collapse_whitespace(s: String) -> String:
	var out: String = ""
	var prev_ws: bool = false
	for i in range(s.length()):
		var c: String = s.substr(i, 1)
		if c == " " or c == "\t" or c == "\n":
			if not prev_ws:
				out += " "
			prev_ws = true
		else:
			out += c
			prev_ws = false
	return out.strip_edges()


static func _format_number(v: Variant) -> String:
	if typeof(v) == TYPE_INT:
		return str(v)
	if typeof(v) == TYPE_FLOAT:
		var f: float = float(v)
		if is_equal_approx(f, round(f)) and abs(f) < 1.0e15:
			return str(int(round(f)))
		var formatted: String = "%.10g" % f
		return formatted
	return str(v)
