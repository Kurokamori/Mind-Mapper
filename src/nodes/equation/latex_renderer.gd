class_name LatexRenderer
extends RefCounted

const TOK_CHAR: int = 0
const TOK_CMD: int = 1
const TOK_LB: int = 2
const TOK_RB: int = 3
const TOK_LBR: int = 4
const TOK_RBR: int = 5
const TOK_CARET: int = 6
const TOK_UNDER: int = 7
const TOK_AMP: int = 8
const TOK_DBKS: int = 9
const TOK_SPACE: int = 10
const TOK_EOF: int = 11

const SYMBOLS: Dictionary = {
	"alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ",
	"epsilon": "ε", "varepsilon": "ε", "zeta": "ζ", "eta": "η",
	"theta": "θ", "vartheta": "ϑ", "iota": "ι", "kappa": "κ",
	"varkappa": "ϰ", "lambda": "λ", "mu": "μ", "nu": "ν",
	"xi": "ξ", "omicron": "ο", "pi": "π", "varpi": "ϖ",
	"rho": "ρ", "varrho": "ϱ", "sigma": "σ", "varsigma": "ς",
	"tau": "τ", "upsilon": "υ", "phi": "φ", "varphi": "ϕ",
	"chi": "χ", "psi": "ψ", "omega": "ω",
	"Alpha": "Α", "Beta": "Β", "Gamma": "Γ", "Delta": "Δ",
	"Epsilon": "Ε", "Zeta": "Ζ", "Eta": "Η", "Theta": "Θ",
	"Iota": "Ι", "Kappa": "Κ", "Lambda": "Λ", "Mu": "Μ",
	"Nu": "Ν", "Xi": "Ξ", "Omicron": "Ο", "Pi": "Π",
	"Rho": "Ρ", "Sigma": "Σ", "Tau": "Τ", "Upsilon": "Υ",
	"Phi": "Φ", "Chi": "Χ", "Psi": "Ψ", "Omega": "Ω",
	"infty": "∞", "infin": "∞", "aleph": "ℵ", "beth": "ℶ",
	"hbar": "ℏ", "ell": "ℓ", "wp": "℘", "Re": "ℜ", "Im": "ℑ",
	"emptyset": "∅", "varnothing": "∅", "nabla": "∇", "partial": "∂",
	"forall": "∀", "exists": "∃", "nexists": "∄",
	"in": "∈", "notin": "∉", "ni": "∋", "subset": "⊂", "supset": "⊃",
	"subseteq": "⊆", "supseteq": "⊇", "subsetneq": "⊊", "supsetneq": "⊋",
	"cup": "∪", "cap": "∩", "setminus": "∖",
	"land": "∧", "lor": "∨", "lnot": "¬", "neg": "¬",
	"to": "→", "rightarrow": "→", "leftarrow": "←", "leftrightarrow": "↔",
	"Rightarrow": "⇒", "Leftarrow": "⇐", "Leftrightarrow": "⇔",
	"implies": "⟹", "iff": "⟺", "mapsto": "↦", "longmapsto": "⟼",
	"longrightarrow": "⟶", "longleftarrow": "⟵", "longleftrightarrow": "⟷",
	"uparrow": "↑", "downarrow": "↓", "updownarrow": "↕",
	"Uparrow": "⇑", "Downarrow": "⇓", "Updownarrow": "⇕",
	"hookrightarrow": "↪", "hookleftarrow": "↩",
	"sum": "∑", "prod": "∏", "coprod": "∐", "int": "∫", "iint": "∬",
	"iiint": "∭", "oint": "∮", "oiint": "∯", "oiiint": "∰",
	"bigcup": "⋃", "bigcap": "⋂", "bigvee": "⋁", "bigwedge": "⋀",
	"bigoplus": "⨁", "bigotimes": "⨂", "bigodot": "⨀", "biguplus": "⨄",
	"pm": "±", "mp": "∓", "times": "×", "div": "÷", "cdot": "·",
	"ast": "∗", "star": "⋆", "circ": "∘", "bullet": "•",
	"oplus": "⊕", "ominus": "⊖", "otimes": "⊗", "oslash": "⊘", "odot": "⊙",
	"leq": "≤", "le": "≤", "geq": "≥", "ge": "≥", "neq": "≠", "ne": "≠",
	"approx": "≈", "equiv": "≡", "cong": "≅", "sim": "∼", "simeq": "≃",
	"propto": "∝", "doteq": "≐", "ll": "≪", "gg": "≫",
	"prec": "≺", "succ": "≻", "preceq": "⪯", "succeq": "⪰",
	"perp": "⊥", "parallel": "∥", "nparallel": "∦", "angle": "∠",
	"sphericalangle": "∢", "measuredangle": "∡",
	"surd": "√", "checkmark": "✓",
	"Box": "□", "square": "□", "blacksquare": "■", "triangle": "△",
	"triangleleft": "◁", "triangleright": "▷", "blacktriangle": "▲",
	"diamondsuit": "♢", "heartsuit": "♡", "clubsuit": "♣", "spadesuit": "♠",
	"flat": "♭", "natural": "♮", "sharp": "♯",
	"dagger": "†", "ddagger": "‡", "S": "§", "P": "¶",
	"copyright": "©", "pounds": "£",
	"vdots": "⋮", "cdots": "⋯", "ldots": "…", "dots": "…", "ddots": "⋱",
	"backslash": "\\", "lbrace": "{", "rbrace": "}", "vert": "|", "Vert": "‖",
	"langle": "⟨", "rangle": "⟩", "lceil": "⌈", "rceil": "⌉",
	"lfloor": "⌊", "rfloor": "⌋", "lvert": "|", "rvert": "|",
	"lVert": "‖", "rVert": "‖",
	"prime": "′", "dprime": "″", "tprime": "‴",
	"degree": "°", "circledR": "®",
	"therefore": "∴", "because": "∵", "QED": "∎",
	"mathbb{R}": "ℝ", "mathbb{N}": "ℕ", "mathbb{Z}": "ℤ", "mathbb{Q}": "ℚ",
	"mathbb{C}": "ℂ", "mathbb{P}": "ℙ", "mathbb{H}": "ℍ",
	"%": "%", "$": "$", "#": "#", "&": "&", "_": "_",
	"{": "{", "}": "}",
	",": " ", ";": " ", ":": " ", "!": "", " ": " ", "quad": "  ", "qquad": "    ",
}

const FUNCTIONS: Array = [
	"sin", "cos", "tan", "sec", "csc", "cot",
	"arcsin", "arccos", "arctan", "arcsec", "arccsc", "arccot",
	"sinh", "cosh", "tanh", "coth", "sech", "csch",
	"log", "ln", "lg", "exp", "lim", "limsup", "liminf",
	"sup", "inf", "max", "min", "arg", "ker", "det", "dim",
	"gcd", "lcm", "Pr", "deg", "hom",
]

const BIG_OPS: Dictionary = {
	"sum": "∑", "prod": "∏", "coprod": "∐",
	"int": "∫", "iint": "∬", "iiint": "∭",
	"oint": "∮", "oiint": "∯", "oiiint": "∰",
	"bigcup": "⋃", "bigcap": "⋂", "bigvee": "⋁", "bigwedge": "⋀",
	"bigoplus": "⨁", "bigotimes": "⨂", "bigodot": "⨀", "biguplus": "⨄",
	"lim": "lim", "limsup": "lim sup", "liminf": "lim inf",
	"max": "max", "min": "min", "sup": "sup", "inf": "inf",
}

const SUPER_DIGITS: Dictionary = {
	"0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵",
	"6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
	"+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾", "n": "ⁿ", "i": "ⁱ",
}

const SUB_DIGITS: Dictionary = {
	"0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅",
	"6": "₆", "7": "₇", "8": "₈", "9": "₉",
	"+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
	"a": "ₐ", "e": "ₑ", "o": "ₒ", "x": "ₓ", "i": "ᵢ", "j": "ⱼ",
	"r": "ᵣ", "u": "ᵤ", "v": "ᵥ", "n": "ₙ", "m": "ₘ", "k": "ₖ",
	"l": "ₗ", "h": "ₕ", "p": "ₚ", "s": "ₛ", "t": "ₜ",
}

const DELIM_MAP: Dictionary = {
	"(": "(", ")": ")", "[": "[", "]": "]",
	"\\{": "{", "\\}": "}", "{": "{", "}": "}",
	"|": "|", "\\|": "‖", "/": "/", "\\backslash": "\\",
	"\\langle": "⟨", "\\rangle": "⟩",
	"\\lceil": "⌈", "\\rceil": "⌉",
	"\\lfloor": "⌊", "\\rfloor": "⌋",
	"\\uparrow": "↑", "\\downarrow": "↓",
	"\\Uparrow": "⇑", "\\Downarrow": "⇓",
	"\\lvert": "|", "\\rvert": "|", "\\lVert": "‖", "\\rVert": "‖",
	".": "",
}


static func to_bbcode(src: String, base_font_size: int = 22) -> String:
	if src.strip_edges() == "":
		return ""
	var stripped: String = _strip_math_delims(src)
	var tokens: Array = _tokenize(stripped)
	var idx: Array = [0]
	var nodes: Array = _parse_sequence(tokens, idx, [TOK_EOF])
	var ctx: Dictionary = {"font": base_font_size}
	var bb: String = _render_seq(nodes, ctx)
	return "[center]" + bb + "[/center]"


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


static func _tokenize(s: String) -> Array:
	var out: Array = []
	var i: int = 0
	var n: int = s.length()
	while i < n:
		var c: String = s.substr(i, 1)
		if c == "\\":
			if i + 1 < n and s.substr(i + 1, 1) == "\\":
				out.append({"k": TOK_DBKS, "v": "\\\\"})
				i += 2
				continue
			var j: int = i + 1
			if j < n:
				var nc: String = s.substr(j, 1)
				if _is_alpha(nc):
					var start: int = j
					while j < n and _is_alpha(s.substr(j, 1)):
						j += 1
					out.append({"k": TOK_CMD, "v": s.substr(start, j - start)})
					i = j
					continue
				else:
					out.append({"k": TOK_CMD, "v": nc})
					i = j + 1
					continue
			i += 1
			continue
		if c == "{":
			out.append({"k": TOK_LB, "v": c}); i += 1; continue
		if c == "}":
			out.append({"k": TOK_RB, "v": c}); i += 1; continue
		if c == "[":
			out.append({"k": TOK_LBR, "v": c}); i += 1; continue
		if c == "]":
			out.append({"k": TOK_RBR, "v": c}); i += 1; continue
		if c == "^":
			out.append({"k": TOK_CARET, "v": c}); i += 1; continue
		if c == "_":
			out.append({"k": TOK_UNDER, "v": c}); i += 1; continue
		if c == "&":
			out.append({"k": TOK_AMP, "v": c}); i += 1; continue
		if c == " " or c == "\t" or c == "\n" or c == "\r":
			out.append({"k": TOK_SPACE, "v": " "}); i += 1; continue
		if c == "%":
			while i < n and s.substr(i, 1) != "\n":
				i += 1
			continue
		out.append({"k": TOK_CHAR, "v": c})
		i += 1
	out.append({"k": TOK_EOF, "v": ""})
	return out


static func _is_alpha(c: String) -> bool:
	if c.length() == 0:
		return false
	var code: int = c.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


static func _peek(tokens: Array, idx: Array) -> Dictionary:
	return tokens[idx[0]]


static func _advance(tokens: Array, idx: Array) -> Dictionary:
	var t: Dictionary = tokens[idx[0]]
	idx[0] += 1
	return t


static func _skip_spaces(tokens: Array, idx: Array) -> void:
	while tokens[idx[0]].k == TOK_SPACE:
		idx[0] += 1


static func _parse_sequence(tokens: Array, idx: Array, end_kinds: Array) -> Array:
	var nodes: Array = []
	while true:
		var t: Dictionary = tokens[idx[0]]
		if end_kinds.has(t.k):
			break
		if t.k == TOK_SPACE:
			idx[0] += 1
			continue
		var atom: Variant = _parse_atom(tokens, idx)
		if atom == null:
			continue
		_attach_scripts(atom, nodes, tokens, idx)
	return nodes


static func _attach_scripts(atom: Dictionary, nodes: Array, tokens: Array, idx: Array) -> void:
	var has_sup: bool = false
	var has_sub: bool = false
	var sup_nodes: Array = []
	var sub_nodes: Array = []
	while true:
		_skip_spaces(tokens, idx)
		var t: Dictionary = tokens[idx[0]]
		if t.k == TOK_CARET and not has_sup:
			idx[0] += 1
			sup_nodes = _parse_script_argument(tokens, idx)
			has_sup = true
		elif t.k == TOK_UNDER and not has_sub:
			idx[0] += 1
			sub_nodes = _parse_script_argument(tokens, idx)
			has_sub = true
		else:
			break
	if has_sup or has_sub:
		if atom.get("t", "") == "bigop":
			atom["lower"] = sub_nodes if has_sub else []
			atom["upper"] = sup_nodes if has_sup else []
			atom["has_lower"] = has_sub
			atom["has_upper"] = has_sup
			nodes.append(atom)
			return
		var script_node: Dictionary = {
			"t": "scripts", "base": atom,
			"sup": sup_nodes, "sub": sub_nodes,
			"has_sup": has_sup, "has_sub": has_sub,
		}
		nodes.append(script_node)
	else:
		nodes.append(atom)


static func _parse_script_argument(tokens: Array, idx: Array) -> Array:
	_skip_spaces(tokens, idx)
	var t: Dictionary = tokens[idx[0]]
	if t.k == TOK_LB:
		idx[0] += 1
		var inner: Array = _parse_sequence(tokens, idx, [TOK_RB, TOK_EOF])
		if tokens[idx[0]].k == TOK_RB:
			idx[0] += 1
		return inner
	if t.k == TOK_CMD:
		idx[0] += 1
		var node: Variant = _resolve_command(t.v, tokens, idx)
		if node == null:
			return []
		return [node]
	if t.k == TOK_CHAR:
		idx[0] += 1
		return [{"t": "char", "v": t.v}]
	return []


static func _parse_atom(tokens: Array, idx: Array) -> Variant:
	var t: Dictionary = tokens[idx[0]]
	if t.k == TOK_CHAR:
		idx[0] += 1
		return {"t": "char", "v": t.v}
	if t.k == TOK_LB:
		idx[0] += 1
		var inner: Array = _parse_sequence(tokens, idx, [TOK_RB, TOK_EOF])
		if tokens[idx[0]].k == TOK_RB:
			idx[0] += 1
		return {"t": "group", "children": inner}
	if t.k == TOK_CMD:
		idx[0] += 1
		return _resolve_command(t.v, tokens, idx)
	if t.k == TOK_LBR:
		idx[0] += 1
		return {"t": "char", "v": "["}
	if t.k == TOK_RBR:
		idx[0] += 1
		return {"t": "char", "v": "]"}
	if t.k == TOK_AMP:
		idx[0] += 1
		return {"t": "amp"}
	if t.k == TOK_DBKS:
		idx[0] += 1
		return {"t": "row_break"}
	idx[0] += 1
	return null


static func _read_required_group(tokens: Array, idx: Array) -> Array:
	_skip_spaces(tokens, idx)
	var t: Dictionary = tokens[idx[0]]
	if t.k == TOK_LB:
		idx[0] += 1
		var inner: Array = _parse_sequence(tokens, idx, [TOK_RB, TOK_EOF])
		if tokens[idx[0]].k == TOK_RB:
			idx[0] += 1
		return inner
	if t.k == TOK_CMD:
		idx[0] += 1
		var node: Variant = _resolve_command(t.v, tokens, idx)
		if node == null:
			return []
		return [node]
	if t.k == TOK_CHAR:
		idx[0] += 1
		return [{"t": "char", "v": t.v}]
	return []


static func _read_optional_bracket(tokens: Array, idx: Array) -> Array:
	_skip_spaces(tokens, idx)
	if tokens[idx[0]].k != TOK_LBR:
		return []
	idx[0] += 1
	var inner: Array = _parse_sequence(tokens, idx, [TOK_RBR, TOK_EOF])
	if tokens[idx[0]].k == TOK_RBR:
		idx[0] += 1
	return inner


static func _read_literal_until(tokens: Array, idx: Array) -> String:
	_skip_spaces(tokens, idx)
	var t: Dictionary = tokens[idx[0]]
	if t.k != TOK_LB:
		if t.k == TOK_CHAR:
			idx[0] += 1
			return t.v
		return ""
	idx[0] += 1
	var depth: int = 1
	var out: String = ""
	while idx[0] < tokens.size():
		var tt: Dictionary = tokens[idx[0]]
		if tt.k == TOK_LB:
			depth += 1
			out += "{"
		elif tt.k == TOK_RB:
			depth -= 1
			if depth == 0:
				idx[0] += 1
				return out
			out += "}"
		elif tt.k == TOK_CMD:
			out += "\\" + String(tt.v)
		else:
			out += String(tt.v)
		idx[0] += 1
	return out


static func _read_delim(tokens: Array, idx: Array) -> String:
	_skip_spaces(tokens, idx)
	var t: Dictionary = tokens[idx[0]]
	if t.k == TOK_CMD:
		idx[0] += 1
		var key: String = "\\" + String(t.v)
		if DELIM_MAP.has(key):
			return String(DELIM_MAP[key])
		if SYMBOLS.has(String(t.v)):
			return String(SYMBOLS[String(t.v)])
		return ""
	if t.k == TOK_CHAR or t.k == TOK_LB or t.k == TOK_RB or t.k == TOK_LBR or t.k == TOK_RBR:
		idx[0] += 1
		var ch: String = String(t.v)
		if DELIM_MAP.has(ch):
			return String(DELIM_MAP[ch])
		return ch
	return ""


static func _resolve_command(name: String, tokens: Array, idx: Array) -> Variant:
	if name == "frac" or name == "dfrac" or name == "tfrac" or name == "cfrac":
		var num: Array = _read_required_group(tokens, idx)
		var den: Array = _read_required_group(tokens, idx)
		return {"t": "frac", "num": num, "den": den, "display": name != "tfrac"}
	if name == "binom" or name == "dbinom" or name == "tbinom":
		var top: Array = _read_required_group(tokens, idx)
		var bot: Array = _read_required_group(tokens, idx)
		return {"t": "binom", "top": top, "bot": bot}
	if name == "sqrt":
		var index_arg: Array = _read_optional_bracket(tokens, idx)
		var radicand: Array = _read_required_group(tokens, idx)
		return {"t": "sqrt", "index": index_arg, "rad": radicand}
	if name == "root":
		var idx_arg: Array = _read_required_group(tokens, idx)
		var rad2: Array = _read_required_group(tokens, idx)
		return {"t": "sqrt", "index": idx_arg, "rad": rad2}
	if name in ["hat", "widehat"]:
		return {"t": "deco", "kind": "hat", "inner": _read_required_group(tokens, idx)}
	if name in ["bar", "overline"]:
		return {"t": "deco", "kind": "bar", "inner": _read_required_group(tokens, idx)}
	if name == "underline":
		return {"t": "deco", "kind": "under", "inner": _read_required_group(tokens, idx)}
	if name in ["tilde", "widetilde"]:
		return {"t": "deco", "kind": "tilde", "inner": _read_required_group(tokens, idx)}
	if name == "vec" or name == "overrightarrow":
		return {"t": "deco", "kind": "vec", "inner": _read_required_group(tokens, idx)}
	if name == "overleftarrow":
		return {"t": "deco", "kind": "leftvec", "inner": _read_required_group(tokens, idx)}
	if name == "dot":
		return {"t": "deco", "kind": "dot", "inner": _read_required_group(tokens, idx)}
	if name == "ddot":
		return {"t": "deco", "kind": "ddot", "inner": _read_required_group(tokens, idx)}
	if name == "overset":
		var over: Array = _read_required_group(tokens, idx)
		var base_over: Array = _read_required_group(tokens, idx)
		return {"t": "overset", "over": over, "base": base_over}
	if name == "underset":
		var under: Array = _read_required_group(tokens, idx)
		var base_under: Array = _read_required_group(tokens, idx)
		return {"t": "underset", "under": under, "base": base_under}
	if name == "stackrel":
		var top_s: Array = _read_required_group(tokens, idx)
		var bot_s: Array = _read_required_group(tokens, idx)
		return {"t": "overset", "over": top_s, "base": bot_s}
	if name == "boxed" or name == "fbox":
		return {"t": "boxed", "inner": _read_required_group(tokens, idx)}
	if name == "text" or name == "textrm" or name == "textsf" or name == "textnormal":
		var s: String = _read_literal_until(tokens, idx)
		return {"t": "text_literal", "v": s, "style": "rm"}
	if name == "textbf":
		var sb: String = _read_literal_until(tokens, idx)
		return {"t": "text_literal", "v": sb, "style": "bf"}
	if name == "textit" or name == "emph":
		var si: String = _read_literal_until(tokens, idx)
		return {"t": "text_literal", "v": si, "style": "it"}
	if name == "texttt":
		var stt: String = _read_literal_until(tokens, idx)
		return {"t": "text_literal", "v": stt, "style": "tt"}
	if name == "mathrm" or name == "operatorname":
		return {"t": "styled", "style": "rm", "inner": _read_required_group(tokens, idx)}
	if name == "mathbf" or name == "bm" or name == "boldsymbol":
		return {"t": "styled", "style": "bf", "inner": _read_required_group(tokens, idx)}
	if name == "mathit":
		return {"t": "styled", "style": "it", "inner": _read_required_group(tokens, idx)}
	if name == "mathsf":
		return {"t": "styled", "style": "sf", "inner": _read_required_group(tokens, idx)}
	if name == "mathtt":
		return {"t": "styled", "style": "tt", "inner": _read_required_group(tokens, idx)}
	if name == "mathcal":
		return {"t": "styled", "style": "cal", "inner": _read_required_group(tokens, idx)}
	if name == "mathbb":
		return {"t": "styled", "style": "bb", "inner": _read_required_group(tokens, idx)}
	if name == "mathfrak":
		return {"t": "styled", "style": "frak", "inner": _read_required_group(tokens, idx)}
	if name == "color":
		var col_name: String = _read_literal_until(tokens, idx)
		var col_body: Array = _read_required_group(tokens, idx)
		return {"t": "color", "color": col_name, "inner": col_body}
	if name == "textcolor":
		var tc_name: String = _read_literal_until(tokens, idx)
		var tc_body: Array = _read_required_group(tokens, idx)
		return {"t": "color", "color": tc_name, "inner": tc_body}
	if name == "left":
		var ld: String = _read_delim(tokens, idx)
		var body: Array = _parse_sequence(tokens, idx, [TOK_EOF])
		return {"t": "lr", "ld": ld, "rd": "", "inner": body}
	if name == "right":
		return {"t": "right_marker", "delim": _read_delim(tokens, idx)}
	if name == "middle":
		return {"t": "middle", "delim": _read_delim(tokens, idx)}
	if name == "begin":
		var env: String = _read_literal_until(tokens, idx)
		return _parse_environment(env, tokens, idx)
	if name == "end":
		_read_literal_until(tokens, idx)
		return {"t": "end_marker"}
	if name == "limits" or name == "nolimits" or name == "displaystyle" or name == "textstyle":
		return {"t": "ignore"}
	if name in ["bigl", "Bigl", "biggl", "Biggl", "bigr", "Bigr", "biggr", "Biggr", "big", "Big", "bigg", "Bigg"]:
		return {"t": "ignore"}
	if name == "phantom" or name == "hphantom" or name == "vphantom":
		_read_required_group(tokens, idx)
		return {"t": "ignore"}
	if name == "label" or name == "tag" or name == "ref":
		_read_required_group(tokens, idx)
		return {"t": "ignore"}
	if name == "not":
		var inner_not: Array = _read_required_group(tokens, idx)
		return {"t": "negated", "inner": inner_not}
	if BIG_OPS.has(name):
		return {"t": "bigop", "sym": String(BIG_OPS[name]), "name": name, "lower": [], "upper": [], "has_lower": false, "has_upper": false}
	if FUNCTIONS.has(name):
		return {"t": "func", "name": name}
	if SYMBOLS.has(name):
		return {"t": "sym", "v": String(SYMBOLS[name])}
	if name == "&" or name == "%" or name == "#" or name == "$" or name == "{" or name == "}" or name == "_":
		return {"t": "char", "v": name}
	if name.length() == 1:
		return {"t": "char", "v": name}
	return {"t": "text_literal", "v": name, "style": "rm"}


static func _parse_environment(env: String, tokens: Array, idx: Array) -> Dictionary:
	var rows: Array = [[]]
	var cur_cell: Array = []
	var delim_l: String = ""
	var delim_r: String = ""
	var col_align: String = ""
	match env:
		"pmatrix":
			delim_l = "("; delim_r = ")"
		"bmatrix":
			delim_l = "["; delim_r = "]"
		"Bmatrix":
			delim_l = "{"; delim_r = "}"
		"vmatrix":
			delim_l = "|"; delim_r = "|"
		"Vmatrix":
			delim_l = "‖"; delim_r = "‖"
		"cases":
			delim_l = "{"; delim_r = ""
		"matrix", "smallmatrix":
			delim_l = ""; delim_r = ""
		"array":
			col_align = _read_literal_until(tokens, idx)
		"aligned", "align", "align*", "split", "gathered", "gather", "gather*", "eqnarray", "eqnarray*":
			delim_l = ""; delim_r = ""
		_:
			pass
	while idx[0] < tokens.size():
		var t: Dictionary = tokens[idx[0]]
		if t.k == TOK_EOF:
			break
		if t.k == TOK_CMD and t.v == "end":
			idx[0] += 1
			_read_literal_until(tokens, idx)
			break
		if t.k == TOK_AMP:
			idx[0] += 1
			rows[rows.size() - 1].append(cur_cell)
			cur_cell = []
			continue
		if t.k == TOK_DBKS:
			idx[0] += 1
			rows[rows.size() - 1].append(cur_cell)
			cur_cell = []
			rows.append([])
			continue
		if t.k == TOK_SPACE:
			idx[0] += 1
			continue
		var atom: Variant = _parse_atom(tokens, idx)
		if atom == null:
			continue
		_attach_scripts(atom, cur_cell, tokens, idx)
	if cur_cell.size() > 0:
		rows[rows.size() - 1].append(cur_cell)
	while rows.size() > 0 and (rows[rows.size() - 1] as Array).is_empty():
		rows.pop_back()
	return {
		"t": "matrix", "rows": rows,
		"ld": delim_l, "rd": delim_r, "env": env, "col_align": col_align,
	}


static func _render_seq(nodes: Array, ctx: Dictionary) -> String:
	_finalize_left_right(nodes)
	var out: String = ""
	var prev_was_func: bool = false
	for i in range(nodes.size()):
		var node: Dictionary = nodes[i]
		var s: String = _render_node(node, ctx)
		if prev_was_func and s != "" and not s.begins_with("(") and not s.begins_with("["):
			out += " "
		out += s
		prev_was_func = node.get("t", "") == "func" or node.get("t", "") == "func_named"
	return out


static func _finalize_left_right(nodes: Array) -> void:
	var i: int = 0
	while i < nodes.size():
		var n: Dictionary = nodes[i]
		if n.get("t", "") == "lr" and String(n.get("rd", "")) == "":
			var inner: Array = n.get("inner", []) as Array
			var found_right: int = -1
			for j in range(inner.size()):
				var c: Dictionary = inner[j]
				if c.get("t", "") == "right_marker":
					found_right = j
					n["rd"] = String(c.get("delim", ""))
					break
			if found_right >= 0:
				var moved: Array = inner.slice(found_right + 1, inner.size())
				n["inner"] = inner.slice(0, found_right)
				_finalize_left_right(n["inner"])
				for k in range(moved.size()):
					nodes.insert(i + 1 + k, moved[k])
			else:
				_finalize_left_right(inner)
		else:
			_recurse_finalize(n)
		i += 1


static func _recurse_finalize(node: Dictionary) -> void:
	for key in ["children", "num", "den", "top", "bot", "rad", "index", "inner", "sup", "sub", "over", "under", "lower", "upper", "base"]:
		if node.has(key) and typeof(node[key]) == TYPE_ARRAY:
			_finalize_left_right(node[key])
	if node.get("t", "") == "scripts" and node.has("base") and typeof(node["base"]) == TYPE_DICTIONARY:
		_recurse_finalize(node["base"])
	if node.get("t", "") == "matrix" and node.has("rows"):
		for row in node["rows"]:
			for cell in row:
				if typeof(cell) == TYPE_ARRAY:
					_finalize_left_right(cell)


static func _render_node(node: Dictionary, ctx: Dictionary) -> String:
	var t: String = String(node.get("t", ""))
	match t:
		"char":
			return _escape_bb(String(node.get("v", "")))
		"sym":
			return _escape_bb(String(node.get("v", "")))
		"group":
			return _render_seq(node.get("children", []) as Array, ctx)
		"text_literal":
			var style: String = String(node.get("style", "rm"))
			return _wrap_style(_escape_bb(String(node.get("v", ""))), style)
		"styled":
			var st: String = String(node.get("style", "rm"))
			return _wrap_style(_render_seq(node.get("inner", []) as Array, ctx), st)
		"color":
			var col: String = _color_name_to_hex(String(node.get("color", "")))
			return "[color=" + col + "]" + _render_seq(node.get("inner", []) as Array, ctx) + "[/color]"
		"func":
			return "[i]" + String(node.get("name", "")) + "[/i]"
		"func_named":
			return "[i]" + _escape_bb(String(node.get("name", ""))) + "[/i]"
		"frac":
			return _render_frac(node, ctx)
		"binom":
			var bt: String = _render_seq(node.get("top", []) as Array, ctx)
			var bb: String = _render_seq(node.get("bot", []) as Array, ctx)
			return "([sup]" + bt + "[/sup]⁄[sub]" + bb + "[/sub])"
		"sqrt":
			return _render_sqrt(node, ctx)
		"deco":
			return _render_deco(node, ctx)
		"overset":
			var ov: String = _render_seq(node.get("over", []) as Array, ctx)
			var ob: String = _render_seq(node.get("base", []) as Array, ctx)
			return "[sup]" + ov + "[/sup]" + ob
		"underset":
			var un: String = _render_seq(node.get("under", []) as Array, ctx)
			var ub: String = _render_seq(node.get("base", []) as Array, ctx)
			return ub + "[sub]" + un + "[/sub]"
		"boxed":
			return "⟦" + _render_seq(node.get("inner", []) as Array, ctx) + "⟧"
		"scripts":
			return _render_scripts(node, ctx)
		"bigop":
			return _render_bigop(node, ctx)
		"lr":
			var ld: String = String(node.get("ld", ""))
			var rd: String = String(node.get("rd", ""))
			var body: String = _render_seq(node.get("inner", []) as Array, ctx)
			return _escape_bb(ld) + body + _escape_bb(rd)
		"matrix":
			return _render_matrix(node, ctx)
		"negated":
			var inn: String = _render_seq(node.get("inner", []) as Array, ctx)
			return inn + "̸"
		"amp":
			return " "
		"row_break":
			return "\n"
		"right_marker", "middle", "end_marker", "ignore":
			return ""
		_:
			return ""


static func _render_frac(node: Dictionary, ctx: Dictionary) -> String:
	var n: String = _render_seq(node.get("num", []) as Array, ctx)
	var d: String = _render_seq(node.get("den", []) as Array, ctx)
	var n_clean: String = _strip_bb(n)
	var d_clean: String = _strip_bb(d)
	var num_paren: String = n if _is_simple(n_clean) else "(" + n + ")"
	var den_paren: String = d if _is_simple(d_clean) else "(" + d + ")"
	return "[sup]" + num_paren + "[/sup]⁄[sub]" + den_paren + "[/sub]"


static func _render_sqrt(node: Dictionary, ctx: Dictionary) -> String:
	var rad: String = _render_seq(node.get("rad", []) as Array, ctx)
	var rad_clean: String = _strip_bb(rad)
	var idx_arr: Array = node.get("index", []) as Array
	var idx_prefix: String = ""
	if idx_arr.size() > 0:
		idx_prefix = "[sup]" + _render_seq(idx_arr, ctx) + "[/sup]"
	if _is_simple(rad_clean):
		return idx_prefix + "√" + rad
	return idx_prefix + "√(" + rad + ")"


static func _render_deco(node: Dictionary, ctx: Dictionary) -> String:
	var kind: String = String(node.get("kind", ""))
	var inner: String = _render_seq(node.get("inner", []) as Array, ctx)
	match kind:
		"hat":
			return inner + "̂"
		"bar":
			return _apply_combining(inner, "̅")
		"under":
			return "[u]" + inner + "[/u]"
		"tilde":
			return inner + "̃"
		"vec":
			return inner + "⃗"
		"leftvec":
			return inner + "⃖"
		"dot":
			return inner + "̇"
		"ddot":
			return inner + "̈"
	return inner


static func _apply_combining(s: String, mark: String) -> String:
	if _has_bb(s):
		return s + mark
	var out: String = ""
	for i in range(s.length()):
		out += s.substr(i, 1) + mark
	return out


static func _render_scripts(node: Dictionary, ctx: Dictionary) -> String:
	var base_node: Dictionary = node.get("base", {}) as Dictionary
	var base_str: String = _render_node(base_node, ctx)
	var has_sup: bool = bool(node.get("has_sup", false))
	var has_sub: bool = bool(node.get("has_sub", false))
	var sup_arr: Array = node.get("sup", []) as Array
	var sub_arr: Array = node.get("sub", []) as Array
	var sup_str: String = _render_seq(sup_arr, ctx) if has_sup else ""
	var sub_str: String = _render_seq(sub_arr, ctx) if has_sub else ""
	var sup_clean: String = _strip_bb(sup_str)
	var sub_clean: String = _strip_bb(sub_str)
	var unicode_sup: String = _try_unicode_super(sup_clean) if has_sup else ""
	var unicode_sub: String = _try_unicode_sub(sub_clean) if has_sub else ""
	var sup_part: String = ""
	var sub_part: String = ""
	if has_sup:
		sup_part = unicode_sup if unicode_sup != "" else "[sup]" + sup_str + "[/sup]"
	if has_sub:
		sub_part = unicode_sub if unicode_sub != "" else "[sub]" + sub_str + "[/sub]"
	return base_str + sup_part + sub_part


static func _try_unicode_super(s: String) -> String:
	if s.length() == 0 or s.length() > 4:
		return ""
	var out: String = ""
	for i in range(s.length()):
		var c: String = s.substr(i, 1)
		if not SUPER_DIGITS.has(c):
			return ""
		out += String(SUPER_DIGITS[c])
	return out


static func _try_unicode_sub(s: String) -> String:
	if s.length() == 0 or s.length() > 4:
		return ""
	var out: String = ""
	for i in range(s.length()):
		var c: String = s.substr(i, 1)
		if not SUB_DIGITS.has(c):
			return ""
		out += String(SUB_DIGITS[c])
	return out


static func _render_bigop(node: Dictionary, ctx: Dictionary) -> String:
	var sym: String = String(node.get("sym", ""))
	var has_lower: bool = bool(node.get("has_lower", false))
	var has_upper: bool = bool(node.get("has_upper", false))
	var lo_str: String = ""
	var hi_str: String = ""
	if has_lower:
		lo_str = "[sub]" + _render_seq(node.get("lower", []) as Array, ctx) + "[/sub]"
	if has_upper:
		hi_str = "[sup]" + _render_seq(node.get("upper", []) as Array, ctx) + "[/sup]"
	var big_size: int = int(ctx.get("font", 22)) + 6
	return "[font_size=" + str(big_size) + "]" + sym + "[/font_size]" + lo_str + hi_str


static func _render_matrix(node: Dictionary, ctx: Dictionary) -> String:
	var rows: Array = node.get("rows", []) as Array
	var ld: String = String(node.get("ld", ""))
	var rd: String = String(node.get("rd", ""))
	var col_count: int = 0
	for row in rows:
		col_count = max(col_count, (row as Array).size())
	if col_count == 0:
		return _escape_bb(ld) + _escape_bb(rd)
	var inner: String = "[table=" + str(col_count) + "]"
	for row in rows:
		var arr: Array = row as Array
		for i in range(col_count):
			var cell_arr: Array = arr[i] as Array if i < arr.size() else []
			var cell_text: String = _render_seq(cell_arr, ctx)
			inner += "[cell]" + cell_text + "  [/cell]"
	inner += "[/table]"
	return _escape_bb(ld) + inner + _escape_bb(rd)


static func _wrap_style(s: String, style: String) -> String:
	match style:
		"bf":
			return "[b]" + s + "[/b]"
		"it":
			return "[i]" + s + "[/i]"
		"tt":
			return "[code]" + s + "[/code]"
		"sf":
			return s
		"cal", "bb", "frak":
			return s
		"rm":
			return s
	return s


static func _escape_bb(s: String) -> String:
	return s.replace("[", "[lb]")


static func _strip_bb(s: String) -> String:
	var out: String = ""
	var i: int = 0
	var in_tag: bool = false
	while i < s.length():
		var c: String = s.substr(i, 1)
		if c == "[":
			in_tag = true
		elif c == "]":
			in_tag = false
		elif not in_tag:
			out += c
		i += 1
	return out


static func _has_bb(s: String) -> bool:
	return s.find("[") >= 0


static func _is_simple(s: String) -> bool:
	if s.length() <= 1:
		return true
	for i in range(s.length()):
		var c: String = s.substr(i, 1)
		if c == " " or c == "+" or c == "-" or c == "*" or c == "/" or c == "=" or c == "(" or c == ")":
			return false
	return s.length() <= 3


static func _color_name_to_hex(name: String) -> String:
	var n: String = name.strip_edges().to_lower()
	if n.begins_with("#"):
		return n
	match n:
		"red": return "#ff4040"
		"green": return "#40c060"
		"blue": return "#5080ff"
		"yellow": return "#ffd040"
		"orange": return "#ff9040"
		"purple": return "#b060d0"
		"pink": return "#ff80c0"
		"cyan": return "#40d0d0"
		"magenta": return "#d040d0"
		"black": return "#101010"
		"white": return "#f0f0f0"
		"gray", "grey": return "#909090"
	return "#c0c0c0"


static func render_plain(src: String) -> String:
	var bb: String = to_bbcode(src, 22)
	var stripped: String = _strip_bb(bb)
	return stripped
