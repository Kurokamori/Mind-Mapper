class_name Op
extends RefCounted

const FORMAT_VERSION: int = 1
const FLAG_NONE: int = 0
const FLAG_EPHEMERAL_GUEST: int = 1 << 0
const FLAG_LOCAL_INVERSE: int = 1 << 1
const FLAG_REPLAY: int = 1 << 2

var op_id: String = ""
var kind: String = ""
var scope: String = ""
var board_id: String = ""
var author_stable_id: String = ""
var author_display_name: String = ""
var author_network_id: int = 0
var lamport_ts: int = 0
var origin_unix: int = 0
var payload: Dictionary = {}
var flags: int = FLAG_NONE
var signature_hex: String = ""
var public_key_hex: String = ""
var inverse_payload: Dictionary = {}


static func make(kind_value: String, payload_value: Dictionary, board_id_value: String) -> Op:
	var o: Op = Op.new()
	o.op_id = Uuid.v4()
	o.kind = kind_value
	o.scope = OpKinds.scope_for_kind(kind_value)
	o.board_id = board_id_value
	o.payload = payload_value.duplicate(true)
	o.origin_unix = int(Time.get_unix_time_from_system())
	return o


func to_dict() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"op_id": op_id,
		"kind": kind,
		"scope": scope,
		"board_id": board_id,
		"author_stable_id": author_stable_id,
		"author_display_name": author_display_name,
		"author_network_id": author_network_id,
		"lamport_ts": lamport_ts,
		"origin_unix": origin_unix,
		"payload": payload.duplicate(true),
		"flags": flags,
		"signature_hex": signature_hex,
		"public_key_hex": public_key_hex,
		"inverse_payload": inverse_payload.duplicate(true),
	}


static func from_dict(d: Dictionary) -> Op:
	var o: Op = Op.new()
	o.op_id = String(d.get("op_id", ""))
	o.kind = String(d.get("kind", ""))
	o.scope = String(d.get("scope", OpKinds.scope_for_kind(o.kind)))
	o.board_id = String(d.get("board_id", ""))
	o.author_stable_id = String(d.get("author_stable_id", ""))
	o.author_display_name = String(d.get("author_display_name", ""))
	o.author_network_id = int(d.get("author_network_id", 0))
	o.lamport_ts = int(d.get("lamport_ts", 0))
	o.origin_unix = int(d.get("origin_unix", 0))
	var payload_raw: Variant = d.get("payload", {})
	o.payload = (payload_raw as Dictionary).duplicate(true) if typeof(payload_raw) == TYPE_DICTIONARY else {}
	o.flags = int(d.get("flags", 0))
	o.signature_hex = String(d.get("signature_hex", ""))
	o.public_key_hex = String(d.get("public_key_hex", ""))
	var inv_raw: Variant = d.get("inverse_payload", {})
	o.inverse_payload = (inv_raw as Dictionary).duplicate(true) if typeof(inv_raw) == TYPE_DICTIONARY else {}
	return o


func canonical_signing_bytes() -> PackedByteArray:
	var data: Dictionary = {
		"format_version": FORMAT_VERSION,
		"op_id": op_id,
		"kind": kind,
		"scope": scope,
		"board_id": board_id,
		"author_stable_id": author_stable_id,
		"author_network_id": author_network_id,
		"lamport_ts": lamport_ts,
		"origin_unix": origin_unix,
		"payload": payload,
		"flags": flags,
	}
	return JSON.stringify(data, "", true, true).to_utf8_buffer()


func has_flag(flag: int) -> bool:
	return (flags & flag) != 0


func set_flag(flag: int, enabled: bool) -> void:
	if enabled:
		flags |= flag
	else:
		flags &= ~flag


func compare_total_order(other: Op) -> int:
	if lamport_ts < other.lamport_ts:
		return -1
	if lamport_ts > other.lamport_ts:
		return 1
	if author_stable_id < other.author_stable_id:
		return -1
	if author_stable_id > other.author_stable_id:
		return 1
	if op_id < other.op_id:
		return -1
	if op_id > other.op_id:
		return 1
	return 0
