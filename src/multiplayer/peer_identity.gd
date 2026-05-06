class_name PeerIdentity
extends RefCounted

const KIND_STEAM: String = "steam"
const KIND_LAN: String = "lan"
const KIND_ENET: String = "enet"
const KIND_LOCAL: String = "local"

var kind: String = KIND_LOCAL
var network_id: int = 1
var stable_id: String = ""
var display_name: String = "Player"
var public_key_hex: String = ""
var avatar_color: Color = Color(0.55, 0.78, 1.0, 1.0)


static func make(kind_value: String, network_id_value: int, stable_id_value: String, display_name_value: String) -> PeerIdentity:
	var p: PeerIdentity = PeerIdentity.new()
	p.kind = kind_value
	p.network_id = network_id_value
	p.stable_id = stable_id_value
	p.display_name = display_name_value
	p.avatar_color = PeerIdentity.color_for_stable_id(stable_id_value)
	return p


static func color_for_stable_id(stable_id_value: String) -> Color:
	if stable_id_value == "":
		return Color(0.55, 0.78, 1.0, 1.0)
	var hash_value: int = stable_id_value.hash()
	var hue: float = float(hash_value & 0xFFFF) / 65535.0
	var saturation: float = 0.55
	var value: float = 0.92
	return Color.from_hsv(hue, saturation, value)


func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"network_id": network_id,
		"stable_id": stable_id,
		"display_name": display_name,
		"public_key_hex": public_key_hex,
		"avatar_color": [avatar_color.r, avatar_color.g, avatar_color.b, avatar_color.a],
	}


static func from_dict(d: Dictionary) -> PeerIdentity:
	var p: PeerIdentity = PeerIdentity.new()
	p.kind = String(d.get("kind", KIND_LOCAL))
	p.network_id = int(d.get("network_id", 1))
	p.stable_id = String(d.get("stable_id", ""))
	p.display_name = String(d.get("display_name", "Player"))
	p.public_key_hex = String(d.get("public_key_hex", ""))
	var color_raw: Variant = d.get("avatar_color", null)
	if typeof(color_raw) == TYPE_ARRAY and (color_raw as Array).size() >= 3:
		var arr: Array = color_raw
		var a: float = 1.0 if arr.size() < 4 else float(arr[3])
		p.avatar_color = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
	else:
		p.avatar_color = PeerIdentity.color_for_stable_id(p.stable_id)
	return p
