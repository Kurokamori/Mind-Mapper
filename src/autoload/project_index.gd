extends Node

signal index_changed()

const SEARCH_RESULT_KIND_BOARD: String = "board"
const SEARCH_RESULT_KIND_ITEM: String = "item"
const SEARCH_RESULT_KIND_TODO_CARD: String = "todo_card"
const SEARCH_RESULT_KIND_BLOCK_ROW: String = "block_row"
const SEARCH_RESULT_KIND_CONNECTION: String = "connection"

const BACKLINK_KIND_LINK_TO_ITEM: String = "link_to_item"
const BACKLINK_KIND_LINK_TO_BOARD: String = "link_to_board"
const BACKLINK_KIND_PINBOARD: String = "pinboard"
const BACKLINK_KIND_SUBPAGE: String = "subpage"

class SearchResult:
	extends RefCounted
	var kind: String = ""
	var board_id: String = ""
	var board_name: String = ""
	var item_id: String = ""
	var title: String = ""
	var subtitle: String = ""
	var score: float = 0.0
	var card_text: String = ""
	var connection_id: String = ""

class BacklinkRef:
	extends RefCounted
	var kind: String = ""
	var board_id: String = ""
	var board_name: String = ""
	var item_id: String = ""
	var item_title: String = ""

var _board_summaries: Dictionary = {}
var _board_order: Array[String] = []


func _ready() -> void:
	AppState.project_opened.connect(_on_project_opened)
	AppState.project_closed.connect(_on_project_closed)
	AppState.board_modified.connect(_on_board_modified)
	if AppState.current_project != null:
		_full_reindex()


func _exit_tree() -> void:
	_board_summaries.clear()
	_board_order.clear()


func _on_project_opened(_project: Project) -> void:
	_full_reindex()


func _on_project_closed() -> void:
	_board_summaries.clear()
	_board_order.clear()
	emit_signal("index_changed")


func _on_board_modified(board_id: String) -> void:
	if AppState.current_project == null or board_id == "":
		return
	var board: Board = AppState.current_project.read_board(board_id)
	if board == null:
		_board_summaries.erase(board_id)
		_board_order.erase(board_id)
	else:
		_board_summaries[board_id] = _summarize_board(board)
		if not _board_order.has(board_id):
			_board_order.append(board_id)
	emit_signal("index_changed")


func _full_reindex() -> void:
	_board_summaries.clear()
	_board_order.clear()
	if AppState.current_project == null:
		emit_signal("index_changed")
		return
	var entries: Array = AppState.current_project.list_boards()
	for entry in entries:
		var board_id: String = String(entry.get("id", ""))
		if board_id == "":
			continue
		var board: Board = AppState.current_project.read_board(board_id)
		if board == null:
			continue
		_board_summaries[board_id] = _summarize_board(board)
		_board_order.append(board_id)
	emit_signal("index_changed")


func _summarize_board(board: Board) -> Dictionary:
	var items_out: Array = []
	var todo_cards_out: Array = []
	var block_titles_out: Array = []
	for raw: Variant in board.items:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = raw
		var item_summary: Dictionary = _summarize_item(d)
		items_out.append(item_summary)
		var type_id: String = String(d.get("type", ""))
		var item_id: String = String(d.get("id", ""))
		if type_id == ItemRegistry.TYPE_TODO_LIST:
			var cards_raw: Variant = d.get("cards", [])
			if typeof(cards_raw) == TYPE_ARRAY:
				for card_v: Variant in cards_raw:
					if typeof(card_v) == TYPE_DICTIONARY:
						var card_text: String = String((card_v as Dictionary).get("text", ""))
						if card_text.strip_edges() != "":
							todo_cards_out.append({
								"item_id": item_id,
								"text": card_text,
							})
		elif type_id == ItemRegistry.TYPE_BLOCK_STACK:
			var blocks_raw: Variant = d.get("blocks", [])
			if typeof(blocks_raw) == TYPE_ARRAY:
				for block_v: Variant in blocks_raw:
					if typeof(block_v) == TYPE_DICTIONARY:
						var block_text: String = String((block_v as Dictionary).get("text", ""))
						if block_text.strip_edges() != "":
							block_titles_out.append({
								"item_id": item_id,
								"text": block_text,
							})
	var connections_out: Array = []
	for raw_conn: Variant in board.connections:
		if typeof(raw_conn) != TYPE_DICTIONARY:
			continue
		var cd: Dictionary = raw_conn
		connections_out.append({
			"id": String(cd.get("id", "")),
			"label": String(cd.get("label", "")),
			"from_item_id": String(cd.get("from_item_id", "")),
			"to_item_id": String(cd.get("to_item_id", "")),
		})
	return {
		"id": board.id,
		"name": board.name,
		"parent_board_id": board.parent_board_id,
		"items": items_out,
		"todo_cards": todo_cards_out,
		"block_titles": block_titles_out,
		"connections": connections_out,
	}


func _summarize_item(d: Dictionary) -> Dictionary:
	var type_id: String = String(d.get("type", ""))
	var item_id: String = String(d.get("id", ""))
	var title: String = _extract_item_title(type_id, d)
	var haystack_pieces: Array[String] = []
	if title != "":
		haystack_pieces.append(title)
	match type_id:
		ItemRegistry.TYPE_RICH_TEXT:
			var stripped: String = _strip_bbcode(String(d.get("bbcode_text", "")))
			if stripped != "":
				haystack_pieces.append(stripped)
		ItemRegistry.TYPE_TODO_LIST:
			var cards_raw: Variant = d.get("cards", [])
			if typeof(cards_raw) == TYPE_ARRAY:
				for card_v: Variant in cards_raw:
					if typeof(card_v) == TYPE_DICTIONARY:
						haystack_pieces.append(String((card_v as Dictionary).get("text", "")))
		ItemRegistry.TYPE_BLOCK_STACK:
			var blocks_raw: Variant = d.get("blocks", [])
			if typeof(blocks_raw) == TYPE_ARRAY:
				for block_v: Variant in blocks_raw:
					if typeof(block_v) == TYPE_DICTIONARY:
						haystack_pieces.append(String((block_v as Dictionary).get("text", "")))
	var haystack: String = " ".join(haystack_pieces).to_lower()
	var link_target: Dictionary = {}
	var lt_raw: Variant = d.get("link_target", null)
	if typeof(lt_raw) == TYPE_DICTIONARY:
		link_target = (lt_raw as Dictionary).duplicate(true)
	var entry: Dictionary = {
		"id": item_id,
		"type": type_id,
		"title": title,
		"haystack": haystack,
		"link_target": link_target,
	}
	if type_id == ItemRegistry.TYPE_PINBOARD or type_id == ItemRegistry.TYPE_SUBPAGE:
		entry["target_board_id"] = String(d.get("target_board_id", ""))
	return entry


func _extract_item_title(type_id: String, d: Dictionary) -> String:
	match type_id:
		ItemRegistry.TYPE_TEXT:
			return String(d.get("text", ""))
		ItemRegistry.TYPE_LABEL:
			return String(d.get("text", ""))
		ItemRegistry.TYPE_RICH_TEXT:
			return _strip_bbcode(String(d.get("bbcode_text", "")))
		ItemRegistry.TYPE_GROUP:
			return String(d.get("title", ""))
		ItemRegistry.TYPE_PINBOARD:
			return String(d.get("title", ""))
		ItemRegistry.TYPE_SUBPAGE:
			return String(d.get("title", ""))
		ItemRegistry.TYPE_TODO_LIST:
			return String(d.get("title", ""))
		ItemRegistry.TYPE_BLOCK_STACK:
			return String(d.get("title", ""))
		ItemRegistry.TYPE_TIMER:
			return String(d.get("label_text", ""))
		ItemRegistry.TYPE_SOUND:
			return String(d.get("display_label", ""))
		ItemRegistry.TYPE_PRIMITIVE:
			return ""
		ItemRegistry.TYPE_IMAGE:
			return String(d.get("asset_name", d.get("source_path", "")))
	return ""


func _strip_bbcode(input: String) -> String:
	if input == "":
		return ""
	var rx: RegEx = RegEx.new()
	if rx.compile("\\[/?[^\\[\\]]*\\]") != OK:
		return input
	var stripped: String = rx.sub(input, "", true)
	return stripped.strip_edges()


func get_board_summary(board_id: String) -> Dictionary:
	var entry: Variant = _board_summaries.get(board_id, null)
	if typeof(entry) == TYPE_DICTIONARY:
		return entry
	return {}


func list_boards_with_parents() -> Array:
	var out: Array = []
	for board_id: String in _board_order:
		var summary: Dictionary = _board_summaries.get(board_id, {})
		out.append({
			"id": board_id,
			"name": String(summary.get("name", "")),
			"parent_board_id": String(summary.get("parent_board_id", "")),
		})
	return out


func resolve_item(board_id: String, item_id: String) -> Dictionary:
	var summary: Dictionary = _board_summaries.get(board_id, {})
	var items_raw: Variant = summary.get("items", [])
	if typeof(items_raw) != TYPE_ARRAY:
		return {}
	for entry_v: Variant in items_raw:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		if String(entry.get("id", "")) == item_id:
			return entry
	return {}


func find_item(item_id: String) -> Dictionary:
	for board_id: String in _board_order:
		var summary: Dictionary = _board_summaries[board_id]
		var items_raw: Variant = summary.get("items", [])
		if typeof(items_raw) != TYPE_ARRAY:
			continue
		for entry_v: Variant in items_raw:
			if typeof(entry_v) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_v
			if String(entry.get("id", "")) == item_id:
				var with_board: Dictionary = entry.duplicate()
				with_board["board_id"] = board_id
				with_board["board_name"] = String(summary.get("name", ""))
				return with_board
	return {}


func backlinks_to_item(item_id: String) -> Array:
	var out: Array = []
	if item_id == "":
		return out
	for board_id: String in _board_order:
		var summary: Dictionary = _board_summaries[board_id]
		var board_name: String = String(summary.get("name", ""))
		var items_raw: Variant = summary.get("items", [])
		if typeof(items_raw) != TYPE_ARRAY:
			continue
		for entry_v: Variant in items_raw:
			if typeof(entry_v) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_v
			var src_item_id: String = String(entry.get("id", ""))
			if src_item_id == item_id:
				continue
			var lt_raw: Variant = entry.get("link_target", {})
			if typeof(lt_raw) != TYPE_DICTIONARY:
				continue
			var lt: Dictionary = lt_raw
			if String(lt.get("kind", "")) == BoardItem.LINK_KIND_ITEM \
					and String(lt.get("id", "")) == item_id:
				var ref: BacklinkRef = BacklinkRef.new()
				ref.kind = BACKLINK_KIND_LINK_TO_ITEM
				ref.board_id = board_id
				ref.board_name = board_name
				ref.item_id = src_item_id
				ref.item_title = _display_title_for_entry(entry)
				out.append(ref)
	return out


func backlinks_to_board(board_id: String) -> Array:
	var out: Array = []
	if board_id == "":
		return out
	for src_board_id: String in _board_order:
		var summary: Dictionary = _board_summaries[src_board_id]
		var board_name: String = String(summary.get("name", ""))
		var items_raw: Variant = summary.get("items", [])
		if typeof(items_raw) != TYPE_ARRAY:
			continue
		for entry_v: Variant in items_raw:
			if typeof(entry_v) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_v
			var entry_type: String = String(entry.get("type", ""))
			var matched_kind: String = ""
			if entry_type == ItemRegistry.TYPE_PINBOARD \
					and String(entry.get("target_board_id", "")) == board_id:
				matched_kind = BACKLINK_KIND_PINBOARD
			elif entry_type == ItemRegistry.TYPE_SUBPAGE \
					and String(entry.get("target_board_id", "")) == board_id:
				matched_kind = BACKLINK_KIND_SUBPAGE
			else:
				var lt_raw: Variant = entry.get("link_target", {})
				if typeof(lt_raw) == TYPE_DICTIONARY:
					var lt: Dictionary = lt_raw
					if String(lt.get("kind", "")) == BoardItem.LINK_KIND_BOARD \
							and String(lt.get("id", "")) == board_id:
						matched_kind = BACKLINK_KIND_LINK_TO_BOARD
			if matched_kind == "":
				continue
			var ref: BacklinkRef = BacklinkRef.new()
			ref.kind = matched_kind
			ref.board_id = src_board_id
			ref.board_name = board_name
			ref.item_id = String(entry.get("id", ""))
			ref.item_title = _display_title_for_entry(entry)
			out.append(ref)
	return out


func _display_title_for_entry(entry: Dictionary) -> String:
	var title: String = String(entry.get("title", ""))
	if title.strip_edges() != "":
		return _truncate(title, 80)
	return _human_type_name(String(entry.get("type", "")))


func _truncate(s: String, max_chars: int) -> String:
	var collapsed: String = s.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges()
	if collapsed.length() <= max_chars:
		return collapsed
	return collapsed.substr(0, max_chars - 1) + "…"


func _human_type_name(type_id: String) -> String:
	match type_id:
		ItemRegistry.TYPE_TEXT: return "Text"
		ItemRegistry.TYPE_LABEL: return "Label"
		ItemRegistry.TYPE_RICH_TEXT: return "Rich Text"
		ItemRegistry.TYPE_IMAGE: return "Image"
		ItemRegistry.TYPE_SOUND: return "Sound"
		ItemRegistry.TYPE_PRIMITIVE: return "Primitive"
		ItemRegistry.TYPE_GROUP: return "Group"
		ItemRegistry.TYPE_TIMER: return "Timer"
		ItemRegistry.TYPE_PINBOARD: return "Pinboard"
		ItemRegistry.TYPE_SUBPAGE: return "Subpage"
		ItemRegistry.TYPE_TODO_LIST: return "Todo List"
		ItemRegistry.TYPE_BLOCK_STACK: return "Block Stack"
	return type_id.capitalize() if type_id != "" else "Item"


func search(query: String, limit: int = 50) -> Array:
	var trimmed: String = query.strip_edges().to_lower()
	var out: Array = []
	if trimmed == "" or _board_order.is_empty():
		return out
	for board_id: String in _board_order:
		var summary: Dictionary = _board_summaries[board_id]
		var board_name: String = String(summary.get("name", ""))
		var board_score: float = _score(board_name.to_lower(), trimmed)
		if board_score > 0.0:
			var br: SearchResult = SearchResult.new()
			br.kind = SEARCH_RESULT_KIND_BOARD
			br.board_id = board_id
			br.board_name = board_name
			br.title = board_name
			br.subtitle = "Board"
			br.score = board_score + 0.5
			out.append(br)
		var items_raw: Variant = summary.get("items", [])
		if typeof(items_raw) == TYPE_ARRAY:
			for entry_v: Variant in items_raw:
				if typeof(entry_v) != TYPE_DICTIONARY:
					continue
				var entry: Dictionary = entry_v
				var haystack: String = String(entry.get("haystack", ""))
				var item_score: float = _score(haystack, trimmed)
				if item_score > 0.0:
					var ir: SearchResult = SearchResult.new()
					ir.kind = SEARCH_RESULT_KIND_ITEM
					ir.board_id = board_id
					ir.board_name = board_name
					ir.item_id = String(entry.get("id", ""))
					ir.title = _display_title_for_entry(entry)
					ir.subtitle = "%s · %s" % [_human_type_name(String(entry.get("type", ""))), board_name]
					ir.score = item_score
					out.append(ir)
		var todo_raw: Variant = summary.get("todo_cards", [])
		if typeof(todo_raw) == TYPE_ARRAY:
			for card_v: Variant in todo_raw:
				if typeof(card_v) != TYPE_DICTIONARY:
					continue
				var card: Dictionary = card_v
				var card_text: String = String(card.get("text", ""))
				var card_score: float = _score(card_text.to_lower(), trimmed)
				if card_score > 0.0:
					var cr: SearchResult = SearchResult.new()
					cr.kind = SEARCH_RESULT_KIND_TODO_CARD
					cr.board_id = board_id
					cr.board_name = board_name
					cr.item_id = String(card.get("item_id", ""))
					cr.title = _truncate(card_text, 80)
					cr.subtitle = "Todo card · %s" % board_name
					cr.score = card_score - 0.05
					cr.card_text = card_text
					out.append(cr)
		var blocks_raw: Variant = summary.get("block_titles", [])
		if typeof(blocks_raw) == TYPE_ARRAY:
			for block_v: Variant in blocks_raw:
				if typeof(block_v) != TYPE_DICTIONARY:
					continue
				var block: Dictionary = block_v
				var block_text: String = String(block.get("text", ""))
				var block_score: float = _score(block_text.to_lower(), trimmed)
				if block_score > 0.0:
					var br2: SearchResult = SearchResult.new()
					br2.kind = SEARCH_RESULT_KIND_BLOCK_ROW
					br2.board_id = board_id
					br2.board_name = board_name
					br2.item_id = String(block.get("item_id", ""))
					br2.title = _truncate(block_text, 80)
					br2.subtitle = "Block · %s" % board_name
					br2.score = block_score - 0.05
					br2.card_text = block_text
					out.append(br2)
		var conns_raw: Variant = summary.get("connections", [])
		if typeof(conns_raw) == TYPE_ARRAY:
			for conn_v: Variant in conns_raw:
				if typeof(conn_v) != TYPE_DICTIONARY:
					continue
				var conn: Dictionary = conn_v
				var conn_label: String = String(conn.get("label", ""))
				if conn_label.strip_edges() == "":
					continue
				var conn_score: float = _score(conn_label.to_lower(), trimmed)
				if conn_score <= 0.0:
					continue
				var cn: SearchResult = SearchResult.new()
				cn.kind = SEARCH_RESULT_KIND_CONNECTION
				cn.board_id = board_id
				cn.board_name = board_name
				cn.item_id = String(conn.get("from_item_id", ""))
				cn.connection_id = String(conn.get("id", ""))
				cn.title = _truncate(conn_label, 80)
				cn.subtitle = "Connection · %s" % board_name
				cn.score = conn_score - 0.1
				out.append(cn)
	out.sort_custom(_compare_results_descending)
	if out.size() > limit:
		out.resize(limit)
	return out


static func _compare_results_descending(a: SearchResult, b: SearchResult) -> bool:
	if a.score == b.score:
		return a.title.naturalnocasecmp_to(b.title) < 0
	return a.score > b.score


static func _score(haystack: String, query: String) -> float:
	if haystack == "" or query == "":
		return 0.0
	if haystack == query:
		return 1000.0
	if haystack.begins_with(query):
		return 500.0 + float(query.length()) / float(max(1, haystack.length()))
	var contains_index: int = haystack.find(query)
	if contains_index >= 0:
		return 200.0 - float(contains_index) * 0.5 + float(query.length()) / float(max(1, haystack.length()))
	var hi: int = 0
	var qi: int = 0
	var matched: int = 0
	var first_match_index: int = -1
	var contiguous: int = 0
	var best_contiguous: int = 0
	while hi < haystack.length() and qi < query.length():
		if haystack[hi] == query[qi]:
			if first_match_index < 0:
				first_match_index = hi
			matched += 1
			qi += 1
			contiguous += 1
			if contiguous > best_contiguous:
				best_contiguous = contiguous
		else:
			contiguous = 0
		hi += 1
	if qi < query.length():
		return 0.0
	var score: float = 50.0
	score += float(best_contiguous) * 6.0
	score += float(matched) / float(max(1, haystack.length())) * 20.0
	score -= float(first_match_index) * 0.25
	return max(score, 1.0)
