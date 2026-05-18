class_name LanSyncProtocol
extends RefCounted

const PROTOCOL_VERSION: int = 1
const PROTOCOL_MAGIC: String = "MM-SYNC-V1"

const UDP_PORT: int = 27830
const TCP_PORT: int = 27831
const ANNOUNCE_INTERVAL_SEC: float = 1.5
const ANNOUNCE_TIMEOUT_SEC: float = 6.0

const MAX_MESSAGE_BYTES: int = 16 * 1024 * 1024
const MAX_BODY_BYTES: int = 64 * 1024 * 1024
const HEADER_PREFIX_SIZE: int = 4
const STREAM_CHUNK_SIZE: int = 64 * 1024

const MSG_HELLO: String = "hello"
const MSG_HELLO_OK: String = "hello_ok"
const MSG_LIST: String = "list"
const MSG_LIST_OK: String = "list_ok"
const MSG_GET: String = "get"
const MSG_GET_OK: String = "get_ok"
const MSG_GET_ERR: String = "get_err"
const MSG_PUT: String = "put"
const MSG_PUT_OK: String = "put_ok"
const MSG_PUT_ERR: String = "put_err"
const MSG_PING: String = "ping"
const MSG_PONG: String = "pong"
const MSG_BYE: String = "bye"
const MSG_OFFER: String = "offer"
const MSG_OFFER_DECISION: String = "offer_decision"
const MSG_PUSH_COMPLETE: String = "push_complete"
const MSG_REVIEW_RESULT: String = "review_result"
const MSG_OFFER_RESOLUTION: String = "offer_resolution"

const OFFER_OP_PUSH: String = "push"
const OFFER_OP_SYNC: String = "sync"

const DECISION_REJECT: String = "reject"
const DECISION_REJECT_AND_BLOCK: String = "reject_and_block"
const DECISION_ACCEPT_ALL: String = "accept_all"
const DECISION_ACCEPT_REVIEW: String = "accept_review"
const DECISION_DEFER_TO_REQUESTER: String = "defer_to_requester"

const OFFER_FIELD_OP_KIND: String = "op_kind"
const OFFER_FIELD_CLIENT_NAME: String = "client_name"
const OFFER_FIELD_FILES: String = "files"
const OFFER_FIELD_DECISION: String = "decision"
const OFFER_FIELD_NOTE: String = "note"
const OFFER_FIELD_RESOLUTIONS: String = "resolutions"
const OFFER_FIELD_KEPT_MINE: String = "kept_mine"
const OFFER_FIELD_CONFLICTS: String = "conflicts"
const OFFER_FIELD_INCOMING_ONLY: String = "incoming_only"
const OFFER_FIELD_OUTGOING_ONLY: String = "outgoing_only"
const OFFER_FIELD_PROJECT_NAME: String = "project_name"
const OFFER_FIELD_HOST_NAME: String = "host_name"

const ANNOUNCE_FIELD_MAGIC: String = "magic"
const ANNOUNCE_FIELD_PROTOCOL: String = "protocol"
const ANNOUNCE_FIELD_PROJECT_ID: String = "project_id"
const ANNOUNCE_FIELD_PROJECT_NAME: String = "project_name"
const ANNOUNCE_FIELD_HOST_NAME: String = "host_name"
const ANNOUNCE_FIELD_TCP_PORT: String = "tcp_port"

const KIND_FIELD: String = "kind"
const PROTOCOL_FIELD: String = "protocol"


static func make_announce_packet(project_id: String, project_name: String, host_name: String) -> PackedByteArray:
	var payload: Dictionary = {
		ANNOUNCE_FIELD_MAGIC: PROTOCOL_MAGIC,
		ANNOUNCE_FIELD_PROTOCOL: PROTOCOL_VERSION,
		ANNOUNCE_FIELD_PROJECT_ID: project_id,
		ANNOUNCE_FIELD_PROJECT_NAME: project_name,
		ANNOUNCE_FIELD_HOST_NAME: host_name,
		ANNOUNCE_FIELD_TCP_PORT: TCP_PORT,
	}
	return JSON.stringify(payload).to_utf8_buffer()


static func parse_announce_packet(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {}
	var text: String = bytes.get_string_from_utf8()
	if text == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	if String(d.get(ANNOUNCE_FIELD_MAGIC, "")) != PROTOCOL_MAGIC:
		return {}
	if int(d.get(ANNOUNCE_FIELD_PROTOCOL, -1)) != PROTOCOL_VERSION:
		return {}
	return d


static func make_message(kind: String, payload: Dictionary) -> Dictionary:
	var body: Dictionary = payload.duplicate(true)
	body[KIND_FIELD] = kind
	body[PROTOCOL_FIELD] = PROTOCOL_VERSION
	return body


static func encode_envelope(message_dict: Dictionary, body_bytes: PackedByteArray) -> PackedByteArray:
	var json_bytes: PackedByteArray = JSON.stringify(message_dict).to_utf8_buffer()
	var total: PackedByteArray = PackedByteArray()
	_append_u32_be(total, json_bytes.size())
	total.append_array(json_bytes)
	_append_u32_be(total, body_bytes.size())
	if body_bytes.size() > 0:
		total.append_array(body_bytes)
	return total


static func sha256_hex(bytes: PackedByteArray) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


static func _append_u32_be(buf: PackedByteArray, value: int) -> void:
	buf.append((value >> 24) & 0xFF)
	buf.append((value >> 16) & 0xFF)
	buf.append((value >> 8) & 0xFF)
	buf.append(value & 0xFF)
