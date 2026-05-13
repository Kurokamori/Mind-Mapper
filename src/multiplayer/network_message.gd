class_name NetworkMessage
extends RefCounted

const CHANNEL_CONTROL: int = 0
const CHANNEL_OPS: int = 1
const CHANNEL_PRESENCE: int = 2
const CHANNEL_ASSETS: int = 3

const KIND_HELLO: String = "hello"
const KIND_HELLO_ACK: String = "hello_ack"
const KIND_ROSTER: String = "roster"
const KIND_OP: String = "op"
const KIND_OP_BATCH: String = "op_batch"
const KIND_VECTOR_CLOCK_REQUEST: String = "vector_clock_request"
const KIND_VECTOR_CLOCK_OFFER: String = "vector_clock_offer"
const KIND_OPLOG_REQUEST: String = "oplog_request"
const KIND_OPLOG_RESPONSE: String = "oplog_response"
const KIND_BOARD_REQUEST: String = "board_request"
const KIND_BOARD_RESPONSE: String = "board_response"
const KIND_MAP_REQUEST: String = "map_request"
const KIND_MAP_RESPONSE: String = "map_response"
const KIND_TILESET_REQUEST: String = "tileset_request"
const KIND_TILESET_RESPONSE: String = "tileset_response"
const KIND_PRESENCE: String = "presence"
const KIND_HEARTBEAT: String = "heartbeat"
const KIND_PING_MARKER: String = "ping_marker"
const KIND_EDITING_LOCK: String = "editing_lock"
const KIND_EDITING_UNLOCK: String = "editing_unlock"
const KIND_ASSET_QUERY: String = "asset_query"
const KIND_ASSET_OFFER: String = "asset_offer"
const KIND_ASSET_REQUEST: String = "asset_request"
const KIND_ASSET_CHUNK: String = "asset_chunk"
const KIND_ASSET_DENY: String = "asset_deny"
const KIND_BOARD_HASH: String = "board_hash"
const KIND_DESYNC_RESYNC: String = "desync_resync"
const KIND_KICK: String = "kick"
const KIND_GUEST_POLICY: String = "guest_policy"
const KIND_MERGE_PREFLIGHT: String = "merge_preflight"
const KIND_MERGE_PREFLIGHT_RESPONSE: String = "merge_preflight_response"
const KIND_MERGE_FINALIZE: String = "merge_finalize"
const KIND_CHAT_MESSAGE: String = "chat_message"
const KIND_LIVE_STROKE: String = "live_stroke"


static func envelope(kind: String, payload: Variant) -> Dictionary:
	return {
		"kind": kind,
		"payload": payload,
	}


static func channel_for(kind: String) -> int:
	match kind:
		KIND_OP, KIND_OP_BATCH, KIND_OPLOG_REQUEST, KIND_OPLOG_RESPONSE, KIND_BOARD_REQUEST, KIND_BOARD_RESPONSE, \
		KIND_MAP_REQUEST, KIND_MAP_RESPONSE, KIND_TILESET_REQUEST, KIND_TILESET_RESPONSE, \
		KIND_MERGE_PREFLIGHT, KIND_MERGE_PREFLIGHT_RESPONSE, KIND_MERGE_FINALIZE:
			return CHANNEL_OPS
		KIND_PRESENCE, KIND_HEARTBEAT, KIND_PING_MARKER, KIND_LIVE_STROKE:
			return CHANNEL_PRESENCE
		KIND_ASSET_QUERY, KIND_ASSET_OFFER, KIND_ASSET_REQUEST, KIND_ASSET_CHUNK, KIND_ASSET_DENY:
			return CHANNEL_ASSETS
		_:
			return CHANNEL_CONTROL


static func is_unreliable(kind: String) -> bool:
	return kind == KIND_PRESENCE or kind == KIND_HEARTBEAT or kind == KIND_LIVE_STROKE
