class_name OpApplier
extends RefCounted

const TOMBSTONE_KEY: String = "__tombstones__"

var _project: Project = null


func _init(project: Project) -> void:
	_project = project


func apply_to_project(op: Op) -> Dictionary:
	if op == null or _project == null:
		return {"applied": false, "reason": "no_project"}
	match op.scope:
		OpKinds.SCOPE_BOARD:
			return _apply_to_board(op)
		OpKinds.SCOPE_PROJECT:
			return _apply_to_project_scope(op)
		OpKinds.SCOPE_MANIFEST:
			return _apply_to_manifest(op)
		_:
			return {"applied": false, "reason": "unknown_scope"}


func _apply_to_board(op: Op) -> Dictionary:
	if op.board_id == "":
		return {"applied": false, "reason": "missing_board_id"}
	var board: Board = _project.read_board(op.board_id)
	if board == null:
		return {"applied": false, "reason": "missing_board"}
	var changed: bool = false
	match op.kind:
		OpKinds.CREATE_ITEM:
			changed = _op_create_item(board, op)
		OpKinds.DELETE_ITEM:
			changed = _op_delete_item(board, op)
		OpKinds.MOVE_ITEMS:
			changed = _op_move_items(board, op)
		OpKinds.SET_ITEM_PROPERTY:
			changed = _op_set_item_property(board, op)
		OpKinds.REORDER_ITEMS:
			changed = _op_reorder_items(board, op)
		OpKinds.REPARENT_ITEMS:
			changed = _op_reparent_items(board, op)
		OpKinds.SET_BLOCK_STACK_ROW:
			changed = _op_set_block_stack_row(board, op)
		OpKinds.SET_TODO_CARD:
			changed = _op_set_todo_card(board, op)
		OpKinds.MOVE_TODO_CARD:
			changed = _op_move_todo_card(board, op)
		OpKinds.CREATE_CONNECTION:
			changed = _op_create_connection(board, op)
		OpKinds.DELETE_CONNECTION:
			changed = _op_delete_connection(board, op)
		OpKinds.SET_CONNECTION_PROPERTY:
			changed = _op_set_connection_property(board, op)
		OpKinds.SET_BOARD_PROPERTY:
			changed = _op_set_board_property(board, op)
		OpKinds.CREATE_COMMENT:
			changed = _op_create_comment(board, op)
		OpKinds.DELETE_COMMENT:
			changed = _op_delete_comment(board, op)
		OpKinds.SET_COMMENT_PROPERTY:
			changed = _op_set_comment_property(board, op)
		_:
			return {"applied": false, "reason": "unknown_kind"}
	if changed:
		_project.write_board(board)
	return {"applied": changed, "board_id": op.board_id}


func _apply_to_project_scope(op: Op) -> Dictionary:
	var changed: bool = false
	match op.kind:
		OpKinds.CREATE_BOARD:
			changed = _op_create_board(op)
		OpKinds.RENAME_BOARD:
			changed = _op_rename_board(op)
		OpKinds.REPARENT_BOARD:
			changed = _op_reparent_board(op)
		OpKinds.DELETE_BOARD:
			changed = _op_delete_board(op)
		_:
			return {"applied": false, "reason": "unknown_kind"}
	if changed:
		_project.write_manifest()
	return {"applied": changed}


func _apply_to_manifest(op: Op) -> Dictionary:
	return {"applied": false, "reason": "manifest_apply_handled_externally"}


func _op_create_item(board: Board, op: Op) -> bool:
	var item_dict_raw: Variant = op.payload.get("item_dict", null)
	if typeof(item_dict_raw) != TYPE_DICTIONARY:
		return false
	var item_dict: Dictionary = (item_dict_raw as Dictionary).duplicate(true)
	var item_id: String = String(item_dict.get("id", ""))
	if item_id == "":
		return false
	if _is_tombstoned(board, "item:%s" % item_id):
		return false
	for existing in board.items:
		if typeof(existing) == TYPE_DICTIONARY and String((existing as Dictionary).get("id", "")) == item_id:
			return false
	board.items.append(item_dict)
	return true


func _op_delete_item(board: Board, op: Op) -> bool:
	var item_id: String = String(op.payload.get("item_id", ""))
	if item_id == "":
		return false
	for i in range(board.items.size() - 1, -1, -1):
		var d: Variant = board.items[i]
		if typeof(d) == TYPE_DICTIONARY and String((d as Dictionary).get("id", "")) == item_id:
			board.items.remove_at(i)
			_add_tombstone(board, "item:%s" % item_id)
			_remove_connections_referencing_item(board, item_id)
			_remove_comments_referencing_item(board, item_id)
			return true
	_add_tombstone(board, "item:%s" % item_id)
	_remove_comments_referencing_item(board, item_id)
	return false


func _op_move_items(board: Board, op: Op) -> bool:
	var entries_raw: Variant = op.payload.get("entries", [])
	if typeof(entries_raw) != TYPE_ARRAY:
		return false
	var changed: bool = false
	for e_v: Variant in (entries_raw as Array):
		if typeof(e_v) != TYPE_DICTIONARY:
			continue
		var item_id: String = String((e_v as Dictionary).get("id", ""))
		var to_arr: Array = (e_v as Dictionary).get("to", []) as Array
		if item_id == "" or to_arr.size() < 2:
			continue
		for i in range(board.items.size()):
			var d: Variant = board.items[i]
			if typeof(d) != TYPE_DICTIONARY:
				continue
			if String((d as Dictionary).get("id", "")) != item_id:
				continue
			(d as Dictionary)["position"] = [float(to_arr[0]), float(to_arr[1])]
			board.items[i] = d
			changed = true
			break
	return changed


func _op_set_item_property(board: Board, op: Op) -> bool:
	var item_id: String = String(op.payload.get("item_id", ""))
	var key: String = String(op.payload.get("key", ""))
	if item_id == "" or key == "":
		return false
	var has_value: bool = (op.payload as Dictionary).has("value")
	if not has_value:
		return false
	for i in range(board.items.size()):
		var d: Variant = board.items[i]
		if typeof(d) != TYPE_DICTIONARY:
			continue
		if String((d as Dictionary).get("id", "")) != item_id:
			continue
		var raw_value: Variant = op.payload["value"]
		if typeof(raw_value) == TYPE_VECTOR2:
			(d as Dictionary)[key] = [(raw_value as Vector2).x, (raw_value as Vector2).y]
		else:
			(d as Dictionary)[key] = raw_value
		board.items[i] = d
		return true
	return false


func _op_reorder_items(board: Board, op: Op) -> bool:
	var order_raw: Variant = op.payload.get("order", [])
	if typeof(order_raw) != TYPE_ARRAY:
		return false
	var lookup: Dictionary = {}
	for d_v: Variant in board.items:
		if typeof(d_v) == TYPE_DICTIONARY:
			lookup[String((d_v as Dictionary).get("id", ""))] = d_v
	var rebuilt: Array = []
	for id_v: Variant in (order_raw as Array):
		var id_str: String = String(id_v)
		if lookup.has(id_str):
			rebuilt.append(lookup[id_str])
			lookup.erase(id_str)
	for leftover in lookup.values():
		rebuilt.append(leftover)
	board.items = rebuilt
	return true


func _op_reparent_items(board: Board, op: Op) -> bool:
	var entries_raw: Variant = op.payload.get("entries", [])
	if typeof(entries_raw) != TYPE_ARRAY:
		return false
	var changed: bool = false
	for e_v: Variant in (entries_raw as Array):
		if typeof(e_v) != TYPE_DICTIONARY:
			continue
		var item_id: String = String((e_v as Dictionary).get("id", ""))
		var to_parent: String = String((e_v as Dictionary).get("to_parent", ""))
		for i in range(board.items.size()):
			var d: Variant = board.items[i]
			if typeof(d) != TYPE_DICTIONARY:
				continue
			if String((d as Dictionary).get("id", "")) != item_id:
				continue
			if to_parent == "":
				(d as Dictionary).erase("parent_id")
			else:
				(d as Dictionary)["parent_id"] = to_parent
			board.items[i] = d
			changed = true
			break
	return changed


func _op_set_block_stack_row(board: Board, op: Op) -> bool:
	var item_id: String = String(op.payload.get("item_id", ""))
	var row_data_raw: Variant = op.payload.get("row_data", null)
	if item_id == "" or typeof(row_data_raw) != TYPE_DICTIONARY:
		return false
	var row_data: Dictionary = row_data_raw
	for i in range(board.items.size()):
		var d: Variant = board.items[i]
		if typeof(d) != TYPE_DICTIONARY:
			continue
		if String((d as Dictionary).get("id", "")) != item_id:
			continue
		var rows_raw: Variant = (d as Dictionary).get("rows", [])
		var rows: Array = (rows_raw as Array).duplicate(true) if typeof(rows_raw) == TYPE_ARRAY else []
		var row_id: String = String(row_data.get("id", ""))
		var found: bool = false
		for ri in range(rows.size()):
			if typeof(rows[ri]) == TYPE_DICTIONARY and String((rows[ri] as Dictionary).get("id", "")) == row_id:
				rows[ri] = row_data
				found = true
				break
		if not found:
			rows.append(row_data)
		(d as Dictionary)["rows"] = rows
		board.items[i] = d
		return true
	return false


func _op_set_todo_card(board: Board, op: Op) -> bool:
	var item_id: String = String(op.payload.get("item_id", ""))
	var card_data_raw: Variant = op.payload.get("card_data", null)
	if item_id == "":
		return false
	for i in range(board.items.size()):
		var d: Variant = board.items[i]
		if typeof(d) != TYPE_DICTIONARY:
			continue
		if String((d as Dictionary).get("id", "")) != item_id:
			continue
		if typeof(card_data_raw) == TYPE_DICTIONARY:
			var cards_raw: Variant = (d as Dictionary).get("cards", [])
			var cards: Array = (cards_raw as Array).duplicate(true) if typeof(cards_raw) == TYPE_ARRAY else []
			var card_id: String = String((card_data_raw as Dictionary).get("id", ""))
			var found: bool = false
			for ci in range(cards.size()):
				if typeof(cards[ci]) == TYPE_DICTIONARY and String((cards[ci] as Dictionary).get("id", "")) == card_id:
					cards[ci] = card_data_raw
					found = true
					break
			if not found:
				cards.append(card_data_raw)
			(d as Dictionary)["cards"] = cards
			board.items[i] = d
			return true
	return false


func _op_move_todo_card(board: Board, op: Op) -> bool:
	var src_item_id: String = String(op.payload.get("src_item_id", ""))
	var dst_item_id: String = String(op.payload.get("dst_item_id", ""))
	var card_id: String = String(op.payload.get("card_id", ""))
	var dst_index: int = int(op.payload.get("dst_index", -1))
	if card_id == "" or src_item_id == "" or dst_item_id == "":
		return false
	var src_idx: int = -1
	var dst_idx: int = -1
	for i in range(board.items.size()):
		var d: Variant = board.items[i]
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var did: String = String((d as Dictionary).get("id", ""))
		if did == src_item_id:
			src_idx = i
		if did == dst_item_id:
			dst_idx = i
	if src_idx < 0 or dst_idx < 0:
		return false
	var src_dict: Dictionary = board.items[src_idx]
	var dst_dict: Dictionary = board.items[dst_idx]
	var src_cards_raw: Variant = src_dict.get("cards", [])
	var src_cards: Array = (src_cards_raw as Array).duplicate(true) if typeof(src_cards_raw) == TYPE_ARRAY else []
	var moving: Dictionary = {}
	for ci in range(src_cards.size()):
		if typeof(src_cards[ci]) == TYPE_DICTIONARY and String((src_cards[ci] as Dictionary).get("id", "")) == card_id:
			moving = src_cards[ci]
			src_cards.remove_at(ci)
			break
	if moving.is_empty():
		return false
	src_dict["cards"] = src_cards
	board.items[src_idx] = src_dict
	var dst_cards_raw: Variant = dst_dict.get("cards", [])
	var dst_cards: Array = (dst_cards_raw as Array).duplicate(true) if typeof(dst_cards_raw) == TYPE_ARRAY else []
	if dst_index < 0 or dst_index > dst_cards.size():
		dst_cards.append(moving)
	else:
		dst_cards.insert(dst_index, moving)
	dst_dict["cards"] = dst_cards
	board.items[dst_idx] = dst_dict
	return true


func _op_create_connection(board: Board, op: Op) -> bool:
	var conn_dict_raw: Variant = op.payload.get("connection_dict", null)
	if typeof(conn_dict_raw) != TYPE_DICTIONARY:
		return false
	var conn_dict: Dictionary = (conn_dict_raw as Dictionary).duplicate(true)
	var conn_id: String = String(conn_dict.get("id", ""))
	if conn_id == "":
		return false
	if _is_tombstoned(board, "conn:%s" % conn_id):
		return false
	for c in board.connections:
		if typeof(c) == TYPE_DICTIONARY and String((c as Dictionary).get("id", "")) == conn_id:
			return false
	board.connections.append(conn_dict)
	return true


func _op_delete_connection(board: Board, op: Op) -> bool:
	var conn_id: String = String(op.payload.get("connection_id", ""))
	if conn_id == "":
		return false
	for i in range(board.connections.size() - 1, -1, -1):
		var c: Variant = board.connections[i]
		if typeof(c) == TYPE_DICTIONARY and String((c as Dictionary).get("id", "")) == conn_id:
			board.connections.remove_at(i)
			_add_tombstone(board, "conn:%s" % conn_id)
			return true
	_add_tombstone(board, "conn:%s" % conn_id)
	return false


func _op_set_connection_property(board: Board, op: Op) -> bool:
	var conn_id: String = String(op.payload.get("connection_id", ""))
	var key: String = String(op.payload.get("key", ""))
	var has_value: bool = (op.payload as Dictionary).has("value")
	if conn_id == "" or key == "" or not has_value:
		return false
	for i in range(board.connections.size()):
		var c: Variant = board.connections[i]
		if typeof(c) != TYPE_DICTIONARY:
			continue
		if String((c as Dictionary).get("id", "")) != conn_id:
			continue
		(c as Dictionary)[key] = op.payload["value"]
		board.connections[i] = c
		return true
	return false


func _op_set_board_property(board: Board, op: Op) -> bool:
	var key: String = String(op.payload.get("key", ""))
	if key == "":
		return false
	var has_value: bool = (op.payload as Dictionary).has("value")
	if not has_value:
		return false
	var value: Variant = op.payload["value"]
	match key:
		"name":
			board.name = String(value)
		"background_image_asset":
			board.background_image_asset = String(value)
		"background_image_mode":
			board.background_image_mode = int(value)
		"background_color_override":
			if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 3:
				var arr: Array = value
				var a: float = 1.0 if arr.size() < 4 else float(arr[3])
				board.background_color_override = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
		"parent_board_id":
			board.parent_board_id = String(value)
		_:
			return false
	return true


func _op_create_board(op: Op) -> bool:
	var board_id: String = String(op.payload.get("board_id", ""))
	var board_name: String = String(op.payload.get("name", "Sub-board"))
	var parent_id: String = String(op.payload.get("parent_board_id", ""))
	if board_id == "":
		return false
	if FileAccess.file_exists(_project.board_path(board_id)):
		return false
	var b: Board = Board.new()
	b.id = board_id
	b.name = board_name
	b.parent_board_id = parent_id
	if _project.write_board(b) != OK:
		return false
	return true


func _op_rename_board(op: Op) -> bool:
	var board_id: String = String(op.payload.get("board_id", ""))
	var new_name: String = String(op.payload.get("name", ""))
	if board_id == "" or new_name == "":
		return false
	return _project.rename_board(board_id, new_name)


func _op_reparent_board(op: Op) -> bool:
	var board_id: String = String(op.payload.get("board_id", ""))
	var parent_id: String = String(op.payload.get("parent_board_id", ""))
	if board_id == "":
		return false
	return _project.reparent_board(board_id, parent_id)


func _op_delete_board(op: Op) -> bool:
	var board_id: String = String(op.payload.get("board_id", ""))
	if board_id == "":
		return false
	return _project.delete_board(board_id)


func _is_tombstoned(board: Board, key: String) -> bool:
	var tomb_raw: Variant = (board.to_dict() as Dictionary).get(TOMBSTONE_KEY, [])
	if typeof(tomb_raw) != TYPE_ARRAY:
		return false
	for entry in (tomb_raw as Array):
		if String(entry) == key:
			return true
	return false


func _add_tombstone(board: Board, key: String) -> void:
	pass


func _op_create_comment(board: Board, op: Op) -> bool:
	var comment_raw: Variant = op.payload.get("comment_dict", null)
	if typeof(comment_raw) != TYPE_DICTIONARY:
		return false
	var comment_dict: Dictionary = CommentData.normalize((comment_raw as Dictionary).duplicate(true))
	var comment_id: String = String(comment_dict.get(CommentData.FIELD_ID, ""))
	if comment_id == "":
		return false
	if _is_tombstoned(board, "comment:%s" % comment_id):
		return false
	if CommentData.find_index(board.comments, comment_id) >= 0:
		return false
	board.comments.append(comment_dict)
	return true


func _op_delete_comment(board: Board, op: Op) -> bool:
	var comment_id: String = String(op.payload.get("comment_id", ""))
	if comment_id == "":
		return false
	var idx: int = CommentData.find_index(board.comments, comment_id)
	if idx < 0:
		_add_tombstone(board, "comment:%s" % comment_id)
		return false
	board.comments.remove_at(idx)
	_add_tombstone(board, "comment:%s" % comment_id)
	return true


func _op_set_comment_property(board: Board, op: Op) -> bool:
	var comment_id: String = String(op.payload.get("comment_id", ""))
	var key: String = String(op.payload.get("key", ""))
	if comment_id == "" or key == "":
		return false
	if not (op.payload as Dictionary).has("value"):
		return false
	if not CommentData.is_settable_key(key):
		return false
	var idx: int = CommentData.find_index(board.comments, comment_id)
	if idx < 0:
		return false
	var entry: Dictionary = (board.comments[idx] as Dictionary).duplicate(true)
	var raw_value: Variant = op.payload["value"]
	if key == CommentData.FIELD_COLOR:
		if typeof(raw_value) == TYPE_COLOR:
			entry[key] = CommentData.serialize_color_value(raw_value)
		elif typeof(raw_value) == TYPE_ARRAY:
			entry[key] = (raw_value as Array).duplicate()
		else:
			return false
	else:
		entry[key] = raw_value
	entry[CommentData.FIELD_LAST_EDITED_UNIX] = int(Time.get_unix_time_from_system())
	board.comments[idx] = entry
	return true


func _remove_comments_referencing_item(board: Board, item_id: String) -> void:
	if item_id == "":
		return
	for i in range(board.comments.size() - 1, -1, -1):
		var entry: Variant = board.comments[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if String((entry as Dictionary).get(CommentData.FIELD_TARGET_ITEM_ID, "")) == item_id:
			var cid: String = String((entry as Dictionary).get(CommentData.FIELD_ID, ""))
			board.comments.remove_at(i)
			if cid != "":
				_add_tombstone(board, "comment:%s" % cid)


func _remove_connections_referencing_item(board: Board, item_id: String) -> void:
	for i in range(board.connections.size() - 1, -1, -1):
		var c: Variant = board.connections[i]
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var f: String = String((c as Dictionary).get("from_item_id", ""))
		var t: String = String((c as Dictionary).get("to_item_id", ""))
		if f == item_id or t == item_id:
			board.connections.remove_at(i)
