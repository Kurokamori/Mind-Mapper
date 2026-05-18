class_name LanSyncEnvelopeReader
extends RefCounted

const STATE_READ_JSON_SIZE: int = 0
const STATE_READ_JSON_BODY: int = 1
const STATE_READ_BODY_SIZE: int = 2
const STATE_READ_BODY: int = 3
const STATE_ERROR: int = 4

var _buffer: PackedByteArray = PackedByteArray()
var _state: int = STATE_READ_JSON_SIZE
var _expected_json_size: int = 0
var _expected_body_size: int = 0
var _pending_json: PackedByteArray = PackedByteArray()
var _pending_body: PackedByteArray = PackedByteArray()
var _pending_ready: bool = false
var _error_message: String = ""


func feed(bytes: PackedByteArray) -> void:
	if bytes.is_empty():
		return
	_buffer.append_array(bytes)


func is_in_error() -> bool:
	return _state == STATE_ERROR


func error_message() -> String:
	return _error_message


func has_envelope() -> bool:
	if _pending_ready:
		return true
	return _try_advance()


func consume_envelope() -> Dictionary:
	if not _pending_ready and not _try_advance():
		return {}
	var json_text: String = _pending_json.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_state = STATE_ERROR
		_error_message = "envelope_json_not_dict"
		return {}
	var out: Dictionary = {
		"message": parsed as Dictionary,
		"body": _pending_body.duplicate(),
	}
	_reset_pending()
	return out


func _try_advance() -> bool:
	while _state != STATE_ERROR:
		match _state:
			STATE_READ_JSON_SIZE:
				if _buffer.size() < 4:
					return false
				_expected_json_size = _read_u32_be(0)
				if _expected_json_size < 0 or _expected_json_size > LanSyncProtocol.MAX_MESSAGE_BYTES:
					_state = STATE_ERROR
					_error_message = "json_size_out_of_range"
					return false
				_buffer = _buffer.slice(4)
				_state = STATE_READ_JSON_BODY
			STATE_READ_JSON_BODY:
				if _buffer.size() < _expected_json_size:
					return false
				_pending_json = _buffer.slice(0, _expected_json_size)
				_buffer = _buffer.slice(_expected_json_size)
				_state = STATE_READ_BODY_SIZE
			STATE_READ_BODY_SIZE:
				if _buffer.size() < 4:
					return false
				_expected_body_size = _read_u32_be(0)
				if _expected_body_size < 0 or _expected_body_size > LanSyncProtocol.MAX_BODY_BYTES:
					_state = STATE_ERROR
					_error_message = "body_size_out_of_range"
					return false
				_buffer = _buffer.slice(4)
				_state = STATE_READ_BODY
			STATE_READ_BODY:
				if _buffer.size() < _expected_body_size:
					return false
				_pending_body = _buffer.slice(0, _expected_body_size)
				_buffer = _buffer.slice(_expected_body_size)
				_state = STATE_READ_JSON_SIZE
				_pending_ready = true
				return true
	return false


func _read_u32_be(offset: int) -> int:
	if _buffer.size() < offset + 4:
		return -1
	return (int(_buffer[offset]) << 24) \
		| (int(_buffer[offset + 1]) << 16) \
		| (int(_buffer[offset + 2]) << 8) \
		| int(_buffer[offset + 3])


func _reset_pending() -> void:
	_expected_json_size = 0
	_expected_body_size = 0
	_pending_json = PackedByteArray()
	_pending_body = PackedByteArray()
	_pending_ready = false
