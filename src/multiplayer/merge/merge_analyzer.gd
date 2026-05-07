class_name MergeAnalyzer
extends RefCounted

const SIDE_LOCAL: String = "local"
const SIDE_REMOTE: String = "remote"

const RESOLUTION_PENDING: String = "pending"
const RESOLUTION_KEEP_LOCAL: String = "keep_local"
const RESOLUTION_KEEP_REMOTE: String = "keep_remote"

const TARGET_KIND_ITEM: String = "item"
const TARGET_KIND_CONNECTION: String = "connection"
const TARGET_KIND_COMMENT: String = "comment"
const TARGET_KIND_BOARD: String = "board"


static func analyze(local_ops: Array, remote_ops: Array) -> Dictionary:
	var local_buckets: Dictionary = _bucket_by_target(local_ops)
	var remote_buckets: Dictionary = _bucket_by_target(remote_ops)
	var conflicts: Array = []
	var conflicting_local_ids: Dictionary = {}
	var conflicting_remote_ids: Dictionary = {}
	for target_key: String in local_buckets.keys():
		if not remote_buckets.has(target_key):
			continue
		var local_entries: Array = local_buckets[target_key] as Array
		var remote_entries: Array = remote_buckets[target_key] as Array
		var pairs: Array = _pair_conflicts(local_entries, remote_entries)
		for pair: Dictionary in pairs:
			var lops: Array = pair["local_ops"] as Array
			var rops: Array = pair["remote_ops"] as Array
			if lops.is_empty() or rops.is_empty():
				continue
			conflicts.append(_make_conflict_record(target_key, pair["touch_key"] as String, lops, rops))
			for op_v: Variant in lops:
				if op_v is Op:
					conflicting_local_ids[(op_v as Op).op_id] = true
			for op_v: Variant in rops:
				if op_v is Op:
					conflicting_remote_ids[(op_v as Op).op_id] = true
	var non_conflicting_local: Array = []
	for op_v: Variant in local_ops:
		if op_v is Op and not conflicting_local_ids.has((op_v as Op).op_id):
			non_conflicting_local.append(op_v)
	var non_conflicting_remote: Array = []
	for op_v: Variant in remote_ops:
		if op_v is Op and not conflicting_remote_ids.has((op_v as Op).op_id):
			non_conflicting_remote.append(op_v)
	return {
		"conflicts": conflicts,
		"non_conflicting_local": non_conflicting_local,
		"non_conflicting_remote": non_conflicting_remote,
	}


static func touch_keys(op: Op) -> Array:
	var out: Array = []
	if op == null:
		return out
	match op.kind:
		OpKinds.SET_ITEM_PROPERTY:
			var iid: String = String(op.payload.get("item_id", ""))
			var pkey: String = String(op.payload.get("key", ""))
			if iid != "" and pkey != "":
				out.append("item:%s/%s" % [iid, pkey])
		OpKinds.MOVE_ITEMS:
			var entries_raw: Variant = op.payload.get("entries", [])
			if typeof(entries_raw) == TYPE_ARRAY:
				for e_v: Variant in (entries_raw as Array):
					if typeof(e_v) != TYPE_DICTIONARY:
						continue
					var eid: String = String((e_v as Dictionary).get("id", ""))
					if eid != "":
						out.append("item:%s/position" % eid)
		OpKinds.REPARENT_ITEMS:
			var entries_raw_p: Variant = op.payload.get("entries", [])
			if typeof(entries_raw_p) == TYPE_ARRAY:
				for e_v: Variant in (entries_raw_p as Array):
					if typeof(e_v) != TYPE_DICTIONARY:
						continue
					var eid_p: String = String((e_v as Dictionary).get("id", ""))
					if eid_p != "":
						out.append("item:%s/parent_id" % eid_p)
		OpKinds.DELETE_ITEM:
			var did: String = String(op.payload.get("item_id", ""))
			if did != "":
				out.append("item:%s/*" % did)
		OpKinds.CREATE_ITEM:
			var item_dict_raw: Variant = op.payload.get("item_dict", null)
			if typeof(item_dict_raw) == TYPE_DICTIONARY:
				var cid: String = String((item_dict_raw as Dictionary).get("id", ""))
				if cid != "":
					out.append("item:%s/*" % cid)
		OpKinds.REORDER_ITEMS:
			out.append("board:_order")
		OpKinds.SET_BLOCK_STACK_ROW:
			var biid: String = String(op.payload.get("item_id", ""))
			var row_data_raw: Variant = op.payload.get("row_data", null)
			var rid: String = ""
			if typeof(row_data_raw) == TYPE_DICTIONARY:
				rid = String((row_data_raw as Dictionary).get("id", ""))
			if biid != "" and rid != "":
				out.append("item:%s/rows/%s" % [biid, rid])
		OpKinds.SET_TODO_CARD:
			var tiid: String = String(op.payload.get("item_id", ""))
			var card_data_raw: Variant = op.payload.get("card_data", null)
			var cardid: String = ""
			if typeof(card_data_raw) == TYPE_DICTIONARY:
				cardid = String((card_data_raw as Dictionary).get("id", ""))
			if tiid != "" and cardid != "":
				out.append("item:%s/cards/%s" % [tiid, cardid])
		OpKinds.MOVE_TODO_CARD:
			var src_iid: String = String(op.payload.get("src_item_id", ""))
			var dst_iid: String = String(op.payload.get("dst_item_id", ""))
			var mc_id: String = String(op.payload.get("card_id", ""))
			if mc_id != "":
				if src_iid != "":
					out.append("item:%s/cards/%s" % [src_iid, mc_id])
				if dst_iid != "" and dst_iid != src_iid:
					out.append("item:%s/cards/%s" % [dst_iid, mc_id])
		OpKinds.CREATE_CONNECTION:
			var conn_dict_raw: Variant = op.payload.get("connection_dict", null)
			if typeof(conn_dict_raw) == TYPE_DICTIONARY:
				var conn_id_c: String = String((conn_dict_raw as Dictionary).get("id", ""))
				if conn_id_c != "":
					out.append("conn:%s/*" % conn_id_c)
		OpKinds.DELETE_CONNECTION:
			var conn_id_d: String = String(op.payload.get("connection_id", ""))
			if conn_id_d != "":
				out.append("conn:%s/*" % conn_id_d)
		OpKinds.SET_CONNECTION_PROPERTY:
			var conn_id_s: String = String(op.payload.get("connection_id", ""))
			var conn_key: String = String(op.payload.get("key", ""))
			if conn_id_s != "" and conn_key != "":
				out.append("conn:%s/%s" % [conn_id_s, conn_key])
		OpKinds.SET_BOARD_PROPERTY:
			var bkey: String = String(op.payload.get("key", ""))
			if bkey != "":
				out.append("board:%s" % bkey)
		OpKinds.CREATE_COMMENT:
			var comment_raw_c: Variant = op.payload.get("comment_dict", null)
			if typeof(comment_raw_c) == TYPE_DICTIONARY:
				var cmid_c: String = String((comment_raw_c as Dictionary).get("id", ""))
				if cmid_c != "":
					out.append("comment:%s/*" % cmid_c)
		OpKinds.DELETE_COMMENT:
			var cmid_d: String = String(op.payload.get("comment_id", ""))
			if cmid_d != "":
				out.append("comment:%s/*" % cmid_d)
		OpKinds.SET_COMMENT_PROPERTY:
			var cmid_s: String = String(op.payload.get("comment_id", ""))
			var cm_key: String = String(op.payload.get("key", ""))
			if cmid_s != "" and cm_key != "":
				out.append("comment:%s/%s" % [cmid_s, cm_key])
	return out


static func keys_conflict(a: String, b: String) -> bool:
	if a == b:
		return true
	var a_target: String = _entity_prefix(a)
	var b_target: String = _entity_prefix(b)
	if a_target != b_target or a_target == "":
		return false
	if a.ends_with("/*") or b.ends_with("/*"):
		return true
	return false


static func target_kind_for_key(key: String) -> String:
	if key.begins_with("item:"):
		return TARGET_KIND_ITEM
	if key.begins_with("conn:"):
		return TARGET_KIND_CONNECTION
	if key.begins_with("comment:"):
		return TARGET_KIND_COMMENT
	if key.begins_with("board:"):
		return TARGET_KIND_BOARD
	return ""


static func _entity_prefix(key: String) -> String:
	var slash_idx: int = key.find("/")
	if slash_idx < 0:
		return key
	return key.substr(0, slash_idx)


static func _bucket_by_target(ops: Array) -> Dictionary:
	var out: Dictionary = {}
	for op_v: Variant in ops:
		if not (op_v is Op):
			continue
		var op: Op = op_v
		for key_v: Variant in touch_keys(op):
			var key: String = String(key_v)
			var entity: String = _entity_prefix(key)
			if entity == "":
				continue
			if not out.has(entity):
				out[entity] = []
			(out[entity] as Array).append({"key": key, "op": op})
	return out


static func _pair_conflicts(local_entries: Array, remote_entries: Array) -> Array:
	var pairs: Array = []
	var consumed_local: Dictionary = {}
	var consumed_remote: Dictionary = {}
	for li: int in range(local_entries.size()):
		if consumed_local.has(li):
			continue
		var l_entry: Dictionary = local_entries[li] as Dictionary
		var l_key: String = String(l_entry.get("key", ""))
		var l_op: Op = l_entry.get("op", null) as Op
		if l_op == null:
			continue
		var matched_remotes: Array = []
		var matched_locals: Array = [l_op]
		consumed_local[li] = true
		for ri: int in range(remote_entries.size()):
			if consumed_remote.has(ri):
				continue
			var r_entry: Dictionary = remote_entries[ri] as Dictionary
			var r_key: String = String(r_entry.get("key", ""))
			var r_op: Op = r_entry.get("op", null) as Op
			if r_op == null:
				continue
			if not keys_conflict(l_key, r_key):
				continue
			matched_remotes.append(r_op)
			consumed_remote[ri] = true
		if matched_remotes.is_empty():
			consumed_local.erase(li)
			continue
		for li2: int in range(local_entries.size()):
			if consumed_local.has(li2):
				continue
			var l2_entry: Dictionary = local_entries[li2] as Dictionary
			var l2_key: String = String(l2_entry.get("key", ""))
			var l2_op: Op = l2_entry.get("op", null) as Op
			if l2_op == null:
				continue
			var collides_any: bool = false
			for rop_v: Variant in matched_remotes:
				if rop_v is Op and keys_conflict(l2_key, _key_of_op_for_target(l_key, rop_v)):
					collides_any = true
					break
			if not collides_any:
				continue
			matched_locals.append(l2_op)
			consumed_local[li2] = true
		pairs.append({
			"touch_key": l_key,
			"local_ops": matched_locals,
			"remote_ops": matched_remotes,
		})
	return pairs


static func _key_of_op_for_target(reference_key: String, op: Op) -> String:
	var ref_entity: String = _entity_prefix(reference_key)
	for k_v: Variant in touch_keys(op):
		if _entity_prefix(String(k_v)) == ref_entity:
			return String(k_v)
	return reference_key


static func _make_conflict_record(target_entity: String, touch_key: String, local_ops: Array, remote_ops: Array) -> Dictionary:
	local_ops.sort_custom(func(a: Op, b: Op) -> bool: return a.lamport_ts < b.lamport_ts)
	remote_ops.sort_custom(func(a: Op, b: Op) -> bool: return a.lamport_ts < b.lamport_ts)
	var representative_local: Op = local_ops[local_ops.size() - 1] as Op
	var representative_remote: Op = remote_ops[remote_ops.size() - 1] as Op
	return {
		"target_entity": target_entity,
		"touch_key": touch_key,
		"target_kind": target_kind_for_key(touch_key),
		"target_id": _id_from_target(target_entity),
		"property_label": _property_label_from_key(touch_key),
		"local_ops": local_ops,
		"remote_ops": remote_ops,
		"local_representative": representative_local,
		"remote_representative": representative_remote,
		"local_summary": op_summary(representative_local),
		"remote_summary": op_summary(representative_remote),
		"resolution": RESOLUTION_PENDING,
	}


static func _id_from_target(target_entity: String) -> String:
	var colon_idx: int = target_entity.find(":")
	if colon_idx < 0:
		return target_entity
	return target_entity.substr(colon_idx + 1)


static func _property_label_from_key(touch_key: String) -> String:
	var slash_idx: int = touch_key.find("/")
	if slash_idx < 0:
		return "(entity)"
	var tail: String = touch_key.substr(slash_idx + 1)
	if tail == "*":
		return "(create/delete)"
	return tail


static func op_summary(op: Op) -> Dictionary:
	if op == null:
		return {}
	var label: String = ""
	var value_text: String = ""
	match op.kind:
		OpKinds.SET_ITEM_PROPERTY:
			label = "Set %s" % String(op.payload.get("key", ""))
			value_text = _stringify_value(op.payload.get("value", null))
		OpKinds.MOVE_ITEMS:
			label = "Move"
			value_text = _stringify_value(op.payload.get("entries", []))
		OpKinds.REPARENT_ITEMS:
			label = "Reparent"
			value_text = _stringify_value(op.payload.get("entries", []))
		OpKinds.DELETE_ITEM:
			label = "Delete item"
			value_text = String(op.payload.get("item_id", ""))
		OpKinds.CREATE_ITEM:
			label = "Create item"
			var item_dict_raw: Variant = op.payload.get("item_dict", null)
			if typeof(item_dict_raw) == TYPE_DICTIONARY:
				value_text = String((item_dict_raw as Dictionary).get("id", ""))
		OpKinds.REORDER_ITEMS:
			label = "Reorder"
			value_text = "%d items" % ((op.payload.get("order", []) as Array).size())
		OpKinds.SET_BLOCK_STACK_ROW:
			label = "Edit block-stack row"
			value_text = _stringify_value(op.payload.get("row_data", {}))
		OpKinds.SET_TODO_CARD:
			label = "Edit todo card"
			value_text = _stringify_value(op.payload.get("card_data", {}))
		OpKinds.MOVE_TODO_CARD:
			label = "Move todo card"
			value_text = "card %s" % String(op.payload.get("card_id", ""))
		OpKinds.CREATE_CONNECTION:
			label = "Create connection"
			var c_raw: Variant = op.payload.get("connection_dict", null)
			if typeof(c_raw) == TYPE_DICTIONARY:
				value_text = String((c_raw as Dictionary).get("id", ""))
		OpKinds.DELETE_CONNECTION:
			label = "Delete connection"
			value_text = String(op.payload.get("connection_id", ""))
		OpKinds.SET_CONNECTION_PROPERTY:
			label = "Set connection.%s" % String(op.payload.get("key", ""))
			value_text = _stringify_value(op.payload.get("value", null))
		OpKinds.SET_BOARD_PROPERTY:
			label = "Set board.%s" % String(op.payload.get("key", ""))
			value_text = _stringify_value(op.payload.get("value", null))
		OpKinds.CREATE_COMMENT:
			label = "Create comment"
			var cm_raw: Variant = op.payload.get("comment_dict", null)
			if typeof(cm_raw) == TYPE_DICTIONARY:
				value_text = String((cm_raw as Dictionary).get("id", ""))
		OpKinds.DELETE_COMMENT:
			label = "Delete comment"
			value_text = String(op.payload.get("comment_id", ""))
		OpKinds.SET_COMMENT_PROPERTY:
			label = "Set comment.%s" % String(op.payload.get("key", ""))
			value_text = _stringify_value(op.payload.get("value", null))
		_:
			label = op.kind
			value_text = _stringify_value(op.payload)
	return {
		"label": label,
		"value_text": value_text,
		"author_display_name": op.author_display_name,
		"author_stable_id": op.author_stable_id,
		"origin_unix": op.origin_unix,
		"lamport_ts": op.lamport_ts,
		"op_id": op.op_id,
		"kind": op.kind,
	}


static func _stringify_value(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "(null)"
		TYPE_STRING:
			var s: String = v
			if s.length() > 240:
				return s.substr(0, 240) + "…"
			return s
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			return str(v)
		TYPE_VECTOR2:
			var v2: Vector2 = v
			return "(%.1f, %.1f)" % [v2.x, v2.y]
		TYPE_COLOR:
			var c: Color = v
			return "Color(%.2f, %.2f, %.2f, %.2f)" % [c.r, c.g, c.b, c.a]
		TYPE_ARRAY:
			var arr: Array = v
			if arr.size() <= 6:
				return JSON.stringify(arr)
			return "[%d items]" % arr.size()
		TYPE_DICTIONARY:
			var dump: String = JSON.stringify(v)
			if dump.length() > 240:
				return dump.substr(0, 240) + "…"
			return dump
		_:
			return str(v)
