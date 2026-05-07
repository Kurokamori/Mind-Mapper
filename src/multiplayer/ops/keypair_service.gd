extends Node

const KEYPAIR_PRIVATE_BASENAME: String = "multiplayer_identity.private.pem"
const KEYPAIR_PUBLIC_BASENAME: String = "multiplayer_identity.public.pem"
const IDENTITY_BASENAME: String = "multiplayer_identity.json"
const IDENTITY_SUFFIX_FLAG: String = "--identity-suffix"
const IDENTITY_SUFFIX_ENV: String = "MM_IDENTITY_SUFFIX"
const RSA_BITS: int = 2048
const SIG_HASH_TYPE: int = HashingContext.HASH_SHA256

var _crypto: Crypto = null
var _private_key: CryptoKey = null
var _public_key: CryptoKey = null
var _public_key_pem: String = ""
var _public_key_fingerprint: String = ""
var _stable_id: String = ""
var _display_name: String = ""
var _identity_suffix: String = ""
var _keypair_private_path: String = ""
var _keypair_public_path: String = ""
var _identity_path: String = ""
var _ready_done: bool = false


func _ready() -> void:
	_crypto = Crypto.new()
	_identity_suffix = _resolve_identity_suffix()
	_keypair_private_path = _build_user_path(KEYPAIR_PRIVATE_BASENAME, _identity_suffix)
	_keypair_public_path = _build_user_path(KEYPAIR_PUBLIC_BASENAME, _identity_suffix)
	_identity_path = _build_user_path(IDENTITY_BASENAME, _identity_suffix)
	_load_or_generate()
	_ready_done = true


func identity_suffix() -> String:
	return _identity_suffix


func _resolve_identity_suffix() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var from_args: String = _extract_flag_value(args, IDENTITY_SUFFIX_FLAG)
	if from_args == "":
		var all_args: PackedStringArray = OS.get_cmdline_args()
		from_args = _extract_flag_value(all_args, IDENTITY_SUFFIX_FLAG)
	if from_args != "":
		return _sanitize_suffix(from_args)
	var from_env: String = OS.get_environment(IDENTITY_SUFFIX_ENV)
	if from_env != "":
		return _sanitize_suffix(from_env)
	return ""


func _extract_flag_value(args: PackedStringArray, flag: String) -> String:
	var prefix: String = "%s=" % flag
	var count: int = args.size()
	for i: int in range(count):
		var token: String = args[i]
		if token == flag:
			if i + 1 < count:
				return args[i + 1]
			return ""
		if token.begins_with(prefix):
			return token.substr(prefix.length())
	return ""


func _sanitize_suffix(raw: String) -> String:
	var trimmed: String = raw.strip_edges()
	if trimmed == "":
		return ""
	var allowed: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
	var out: String = ""
	for i: int in range(trimmed.length()):
		var ch: String = trimmed.substr(i, 1)
		if allowed.find(ch) != -1:
			out += ch
	return out


func _build_user_path(basename: String, suffix: String) -> String:
	if suffix == "":
		return "user://%s" % basename
	var dot_index: int = basename.rfind(".")
	if dot_index <= 0:
		return "user://%s.%s" % [basename, suffix]
	var stem: String = basename.substr(0, dot_index)
	var ext: String = basename.substr(dot_index)
	return "user://%s.%s%s" % [stem, suffix, ext]


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
	if FileAccess.file_exists(_keypair_private_path) and FileAccess.file_exists(_keypair_public_path):
		var ok: bool = _load_existing()
		if ok:
			_load_identity()
			return
	_generate_new()
	_save_identity()


func _load_existing() -> bool:
	var private_text: String = _read_text(_keypair_private_path)
	var public_text: String = _read_text(_keypair_public_path)
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
	_write_text(_keypair_private_path, private_pem)
	_write_text(_keypair_public_path, _public_key_pem)
	_public_key = CryptoKey.new()
	_public_key.load_from_string(_public_key_pem, true)
	_public_key_fingerprint = fingerprint_for_pem(_public_key_pem)


func _load_identity() -> void:
	if not FileAccess.file_exists(_identity_path):
		_initialize_identity_from_fingerprint()
		_save_identity()
		return
	var f: FileAccess = FileAccess.open(_identity_path, FileAccess.READ)
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
	var f: FileAccess = FileAccess.open(_identity_path, FileAccess.WRITE)
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
