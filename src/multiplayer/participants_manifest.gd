class_name ParticipantsManifest
extends RefCounted

const ROLE_OWNER: String = "owner"
const ROLE_CO_AUTHOR: String = "co_author"
const ROLE_GUEST: String = "guest"

const GUEST_POLICY_VIEW: String = "view"
const GUEST_POLICY_COMMENT: String = "comment"
const GUEST_POLICY_EDIT: String = "edit"

const MANIFEST_FILENAME: String = "participants.json"
const MANIFEST_FORMAT_VERSION: int = 1

var owner_stable_id: String = ""
var owner_public_key: String = ""
var participants: Dictionary = {}
var guest_policy: String = GUEST_POLICY_EDIT
var manifest_signature: String = ""
var manifest_origin_unix: int = 0
var ops_log: Array = []


static func make_for_owner(stable_id: String, public_key_pem: String, display_name: String) -> ParticipantsManifest:
	var m: ParticipantsManifest = ParticipantsManifest.new()
	m.owner_stable_id = stable_id
	m.owner_public_key = public_key_pem
	m.participants[stable_id] = {
		"role": ROLE_OWNER,
		"display_name": display_name,
		"public_key": public_key_pem,
		"added_unix": int(Time.get_unix_time_from_system()),
	}
	m.manifest_origin_unix = int(Time.get_unix_time_from_system())
	return m


func has_participant(stable_id: String) -> bool:
	return participants.has(stable_id)


func role_of(stable_id: String) -> String:
	if not participants.has(stable_id):
		return ROLE_GUEST
	return String((participants[stable_id] as Dictionary).get("role", ROLE_CO_AUTHOR))


func display_name_of(stable_id: String) -> String:
	if not participants.has(stable_id):
		return "Guest"
	return String((participants[stable_id] as Dictionary).get("display_name", "Player"))


func public_key_of(stable_id: String) -> String:
	if stable_id == owner_stable_id:
		return owner_public_key
	if not participants.has(stable_id):
		return ""
	return String((participants[stable_id] as Dictionary).get("public_key", ""))


func is_owner(stable_id: String) -> bool:
	return stable_id == owner_stable_id


func add_co_author(stable_id: String, public_key_pem: String, display_name: String) -> void:
	participants[stable_id] = {
		"role": ROLE_CO_AUTHOR,
		"display_name": display_name,
		"public_key": public_key_pem,
		"added_unix": int(Time.get_unix_time_from_system()),
	}


func remove_participant(stable_id: String) -> void:
	if stable_id == owner_stable_id:
		return
	participants.erase(stable_id)


func transfer_ownership(new_owner_stable_id: String) -> bool:
	if not participants.has(new_owner_stable_id):
		return false
	if owner_stable_id != "" and participants.has(owner_stable_id):
		(participants[owner_stable_id] as Dictionary)["role"] = ROLE_CO_AUTHOR
	(participants[new_owner_stable_id] as Dictionary)["role"] = ROLE_OWNER
	owner_stable_id = new_owner_stable_id
	owner_public_key = String((participants[new_owner_stable_id] as Dictionary).get("public_key", ""))
	return true


func append_op(op: Op) -> void:
	for entry in ops_log:
		if typeof(entry) == TYPE_DICTIONARY and String((entry as Dictionary).get("op_id", "")) == op.op_id:
			return
	ops_log.append(op.to_dict())


func to_dict() -> Dictionary:
	return {
		"format_version": MANIFEST_FORMAT_VERSION,
		"owner_stable_id": owner_stable_id,
		"owner_public_key": owner_public_key,
		"participants": _participants_to_dict(),
		"guest_policy": guest_policy,
		"manifest_origin_unix": manifest_origin_unix,
		"ops_log": ops_log,
	}


func _participants_to_dict() -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in participants.keys():
		out[String(k)] = (participants[k] as Dictionary).duplicate(true)
	return out


static func from_dict(d: Dictionary) -> ParticipantsManifest:
	var m: ParticipantsManifest = ParticipantsManifest.new()
	m.owner_stable_id = String(d.get("owner_stable_id", ""))
	m.owner_public_key = String(d.get("owner_public_key", ""))
	m.guest_policy = String(d.get("guest_policy", GUEST_POLICY_EDIT))
	m.manifest_origin_unix = int(d.get("manifest_origin_unix", 0))
	var p_raw: Variant = d.get("participants", {})
	if typeof(p_raw) == TYPE_DICTIONARY:
		for k: Variant in (p_raw as Dictionary).keys():
			var entry_raw: Variant = (p_raw as Dictionary)[k]
			if typeof(entry_raw) == TYPE_DICTIONARY:
				m.participants[String(k)] = (entry_raw as Dictionary).duplicate(true)
	var ops_raw: Variant = d.get("ops_log", [])
	if typeof(ops_raw) == TYPE_ARRAY:
		m.ops_log = (ops_raw as Array).duplicate(true)
	return m


static func load_or_create(project: Project, owner_stable_id_value: String, owner_public_key_value: String, owner_display_name: String) -> ParticipantsManifest:
	if project == null:
		return null
	var path: String = project.folder_path.path_join(MANIFEST_FILENAME)
	if FileAccess.file_exists(path):
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f != null:
			var raw: String = f.get_as_text()
			f.close()
			var parsed: Variant = JSON.parse_string(raw)
			if typeof(parsed) == TYPE_DICTIONARY:
				return ParticipantsManifest.from_dict(parsed)
	var m: ParticipantsManifest = ParticipantsManifest.make_for_owner(owner_stable_id_value, owner_public_key_value, owner_display_name)
	m.save(project)
	return m


func save(project: Project) -> Error:
	if project == null:
		return ERR_UNCONFIGURED
	var path: String = project.folder_path.path_join(MANIFEST_FILENAME)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	return OK


func known_co_author_stable_ids() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in participants.keys():
		var role: String = String((participants[k] as Dictionary).get("role", ""))
		if role == ROLE_CO_AUTHOR or role == ROLE_OWNER:
			out.append(String(k))
	return out
