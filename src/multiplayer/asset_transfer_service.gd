class_name AssetTransferService
extends RefCounted

const CHUNK_BYTES: int = 64 * 1024
const MAX_CONCURRENT_REQUESTS: int = 8
const TRANSFER_STATE_PENDING: String = "pending"
const TRANSFER_STATE_RECEIVING: String = "receiving"
const TRANSFER_STATE_DONE: String = "done"
const TRANSFER_STATE_FAILED: String = "failed"

var _project: Project = null
var _adapter_proxy: Callable = Callable()
var _outgoing: Dictionary = {}
var _incoming: Dictionary = {}
var _local_inventory: Dictionary = {}


func _init(project: Project, adapter_proxy_value: Callable) -> void:
	_project = project
	_adapter_proxy = adapter_proxy_value
	_rebuild_local_inventory()


func project() -> Project:
	return _project


func rebind_project(project: Project) -> void:
	_project = project
	_local_inventory.clear()
	_rebuild_local_inventory()


func has_local_asset(asset_name: String) -> bool:
	if asset_name == "" or _project == null:
		return false
	if _local_inventory.has(asset_name):
		return true
	var path: String = _project.resolve_asset_path(asset_name)
	var exists: bool = FileAccess.file_exists(path)
	if exists:
		_local_inventory[asset_name] = true
	return exists


func register_local_asset(asset_name: String) -> void:
	if asset_name == "":
		return
	_local_inventory[asset_name] = true


func handle_query_request(from_network_id: int, asset_names: Array) -> void:
	if _adapter_proxy.is_null():
		return
	var have: Array = []
	for name_v: Variant in asset_names:
		var name: String = String(name_v)
		if has_local_asset(name):
			have.append(name)
	_adapter_proxy.call(from_network_id, NetworkMessage.KIND_ASSET_OFFER, {"asset_names": have})


func handle_offer(from_network_id: int, asset_names: Array) -> void:
	for name_v: Variant in asset_names:
		var name: String = String(name_v)
		if has_local_asset(name):
			continue
		if _incoming.has(name):
			continue
		_incoming[name] = {"state": TRANSFER_STATE_PENDING, "from_network_id": from_network_id, "received": [], "expected_chunks": -1}
		_adapter_proxy.call(from_network_id, NetworkMessage.KIND_ASSET_REQUEST, {"asset_name": name})


func handle_request(from_network_id: int, asset_name: String) -> void:
	if _adapter_proxy.is_null() or _project == null:
		return
	if not has_local_asset(asset_name):
		_adapter_proxy.call(from_network_id, NetworkMessage.KIND_ASSET_DENY, {"asset_name": asset_name, "reason": "not_found"})
		return
	var path: String = _project.resolve_asset_path(asset_name)
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		_adapter_proxy.call(from_network_id, NetworkMessage.KIND_ASSET_DENY, {"asset_name": asset_name, "reason": "open_failed"})
		return
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var total_chunks: int = int(ceil(float(bytes.size()) / float(CHUNK_BYTES))) if bytes.size() > 0 else 1
	var session_id: String = "%s::%d" % [asset_name, Time.get_ticks_msec()]
	for i: int in range(total_chunks):
		var start: int = i * CHUNK_BYTES
		var end: int = min(start + CHUNK_BYTES, bytes.size())
		var slice: PackedByteArray = bytes.slice(start, end) if end > start else PackedByteArray()
		var chunk_payload: Dictionary = {
			"asset_name": asset_name,
			"session_id": session_id,
			"chunk_index": i,
			"chunk_count": total_chunks,
			"chunk_b64": Marshalls.raw_to_base64(slice),
		}
		_adapter_proxy.call(from_network_id, NetworkMessage.KIND_ASSET_CHUNK, chunk_payload)


func handle_chunk(from_network_id: int, payload: Dictionary) -> Dictionary:
	var asset_name: String = String(payload.get("asset_name", ""))
	var chunk_count: int = int(payload.get("chunk_count", 0))
	var chunk_index: int = int(payload.get("chunk_index", 0))
	var chunk_b64: String = String(payload.get("chunk_b64", ""))
	if asset_name == "" or chunk_count <= 0:
		return {"completed": false, "asset_name": ""}
	var entry: Dictionary = _incoming.get(asset_name, {"state": TRANSFER_STATE_RECEIVING, "from_network_id": from_network_id, "received": [], "expected_chunks": chunk_count})
	entry["state"] = TRANSFER_STATE_RECEIVING
	entry["expected_chunks"] = chunk_count
	var received: Array = entry.get("received", []) as Array
	while received.size() < chunk_count:
		received.append(null)
	received[chunk_index] = chunk_b64
	entry["received"] = received
	_incoming[asset_name] = entry
	var any_missing: bool = false
	for v: Variant in received:
		if v == null:
			any_missing = true
			break
	if any_missing:
		return {"completed": false, "asset_name": asset_name}
	var assembled: PackedByteArray = PackedByteArray()
	for piece in received:
		var bytes: PackedByteArray = Marshalls.base64_to_raw(String(piece))
		assembled.append_array(bytes)
	if _project != null:
		var path: String = _project.resolve_asset_path(asset_name)
		var dir: String = path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(assembled)
			f.close()
			register_local_asset(asset_name)
	entry["state"] = TRANSFER_STATE_DONE
	_incoming.erase(asset_name)
	return {"completed": true, "asset_name": asset_name}


func handle_deny(asset_name: String, _reason: String) -> void:
	if _incoming.has(asset_name):
		_incoming.erase(asset_name)


func request_unknown_assets(asset_names: Array, from_network_id: int) -> void:
	if _adapter_proxy.is_null():
		return
	var unknown: Array = []
	for name_v: Variant in asset_names:
		var name: String = String(name_v)
		if name == "" or has_local_asset(name) or _incoming.has(name):
			continue
		unknown.append(name)
	if unknown.is_empty():
		return
	_adapter_proxy.call(from_network_id, NetworkMessage.KIND_ASSET_QUERY, {"asset_names": unknown})


func _rebuild_local_inventory() -> void:
	if _project == null:
		return
	var dir: String = _project.assets_path()
	if not DirAccess.dir_exists_absolute(dir):
		return
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var entry: String = d.get_next()
	while entry != "":
		if not d.current_is_dir():
			_local_inventory[entry] = true
		entry = d.get_next()
	d.list_dir_end()
