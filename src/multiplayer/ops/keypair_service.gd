extends Node

const KEYPAIR_PRIVATE_PATH: String = "user://multiplayer_identity.private.pem"
const KEYPAIR_PUBLIC_PATH: String = "user://multiplayer_identity.public.pem"
const IDENTITY_PATH: String = "user://multiplayer_identity.json"
const RSA_BITS: int = 2048
const SIG_HASH_TYPE: int = HashingContext.HASH_SHA256

var _crypto: Crypto = null
var _private_key: CryptoKey = null
var _public_key: CryptoKey = null
var _public_key_pem: String = ""
var _public_key_fingerprint: String = ""
var _stable_id: String = ""
var _display_name: String = ""
var _ready_done: bool = false


func _ready() -> void:
	_crypto = Crypto.new()
	_load_or_generate()
	_ready_done = true


func is_ready() -> bool:
	return _ready_done


func ensure_ready() -> void:
	if not _ready_done:
		_ready()


func stable_id() -> String:
	return _stable_id


func display_name() -> String:
	return _display_name


func set_display_name(value: String) -> void:
	var trimmed: String = value.strip_edges()
	if trimmed == "" or trimmed == _display_name:
		return
	_display_name = trimmed
	_save_identity()


func public_key_pem() -> String:
	return _public_key_pem


func public_key_fingerprint() -> String:
	return _public_key_fingerprint


func sign_bytes(bytes: PackedByteArray) -> PackedByteArray:
	if _private_key == null:
		return PackedByteArray()
	return _crypto.sign(SIG_HASH_TYPE, _hash(bytes), _private_key)


func verify_bytes(bytes: PackedByteArray, signature: PackedByteArray, public_key_pem_value: String) -> bool:
	if signature.is_empty() or public_key_pem_value == "":
		return false
	var key: CryptoKey = CryptoKey.new()
	var err: Error = key.load_from_string(public_key_pem_value, true)
	if err != OK:
		return false
	return _crypto.verify(SIG_HASH_TYPE, _hash(bytes), signature, key)


func sign_op(op: Op) -> void:
	if op == null or _private_key == null:
		return
	op.author_stable_id = _stable_id
	op.author_display_name = _display_name
	op.public_key_hex = _public_key_pem
	var sig: PackedByteArray = sign_bytes(op.canonical_signing_bytes())
	op.signature_hex = _bytes_to_hex(sig)


func verify_op(op: Op, public_key_pem_value: String) -> bool:
	if op == null or op.signature_hex == "":
		return false
	var sig_bytes: PackedByteArray = _hex_to_bytes(op.signature_hex)
	return verify_bytes(op.canonical_signing_bytes(), sig_bytes, public_key_pem_value)


func fingerprint_for_pem(pem: String) -> String:
	if pem == "":
		return ""
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(pem.to_utf8_buffer())
	return _bytes_to_hex(ctx.finish()).substr(0, 32)


func _hash(bytes: PackedByteArray) -> PackedByteArray:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish()


func _load_or_generate() -> void:
	if FileAccess.file_exists(KEYPAIR_PRIVATE_PATH) and FileAccess.file_exists(KEYPAIR_PUBLIC_PATH):
		var ok: bool = _load_existing()
		if ok:
			_load_identity()
			return
	_generate_new()
	_save_identity()


func _load_existing() -> bool:
	var private_text: String = _read_text(KEYPAIR_PRIVATE_PATH)
	var public_text: String = _read_text(KEYPAIR_PUBLIC_PATH)
	if private_text == "" or public_text == "":
		return false
	_private_key = CryptoKey.new()
	if _private_key.load_from_string(private_text, false) != OK:
		_private_key = null
		return false
	_public_key = CryptoKey.new()
	if _public_key.load_from_string(public_text, true) != OK:
		_public_key = null
		return false
	_public_key_pem = public_text
	_public_key_fingerprint = fingerprint_for_pem(public_text)
	return true


func _generate_new() -> void:
	_private_key = _crypto.generate_rsa(RSA_BITS)
	_public_key_pem = _private_key.save_to_string(true)
	var private_pem: String = _private_key.save_to_string(false)
	_write_text(KEYPAIR_PRIVATE_PATH, private_pem)
	_write_text(KEYPAIR_PUBLIC_PATH, _public_key_pem)
	_public_key = CryptoKey.new()
	_public_key.load_from_string(_public_key_pem, true)
	_public_key_fingerprint = fingerprint_for_pem(_public_key_pem)


func _load_identity() -> void:
	if not FileAccess.file_exists(IDENTITY_PATH):
		_initialize_identity_from_fingerprint()
		_save_identity()
		return
	var f: FileAccess = FileAccess.open(IDENTITY_PATH, FileAccess.READ)
	if f == null:
		_initialize_identity_from_fingerprint()
		return
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		_initialize_identity_from_fingerprint()
		_save_identity()
		return
	var d: Dictionary = parsed
	_stable_id = String(d.get("stable_id", ""))
	_display_name = String(d.get("display_name", ""))
	if _stable_id == "":
		_stable_id = "kp:%s" % _public_key_fingerprint
	if _display_name == "":
		_display_name = "Player %s" % _public_key_fingerprint.substr(0, 6)


func _initialize_identity_from_fingerprint() -> void:
	_stable_id = "kp:%s" % _public_key_fingerprint
	_display_name = "Player %s" % _public_key_fingerprint.substr(0, 6)


func _save_identity() -> void:
	var data: Dictionary = {
		"stable_id": _stable_id,
		"display_name": _display_name,
		"public_key_fingerprint": _public_key_fingerprint,
	}
	var f: FileAccess = FileAccess.open(IDENTITY_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func _read_text(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var raw: String = f.get_as_text()
	f.close()
	return raw


func _write_text(path: String, contents: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(contents)
	f.close()


func _bytes_to_hex(bytes: PackedByteArray) -> String:
	var out: String = ""
	for b: int in bytes:
		out += "%02x" % int(b)
	return out


func _hex_to_bytes(hex: String) -> PackedByteArray:
	var clean: String = hex.replace(" ", "")
	if clean.length() % 2 != 0:
		return PackedByteArray()
	var out: PackedByteArray = PackedByteArray()
	out.resize(clean.length() / 2)
	for i: int in range(out.size()):
		out[i] = clean.substr(i * 2, 2).hex_to_int()
	return out
