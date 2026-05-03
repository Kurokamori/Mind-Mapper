class_name Connection
extends RefCounted

const STYLE_STRAIGHT: String = "straight"
const STYLE_BEZIER: String = "bezier"
const STYLE_ORTHOGONAL: String = "orthogonal"

const DEFAULT_COLOR: Color = Color(0.78, 0.84, 0.95, 1.0)
const DEFAULT_THICKNESS: float = 2.5
const DEFAULT_STYLE: String = STYLE_BEZIER
const DEFAULT_ARROW_END: bool = true
const DEFAULT_ARROW_START: bool = false
const DEFAULT_LABEL: String = ""
const DEFAULT_LABEL_FONT_SIZE: int = 12
const ANCHOR_AUTO: String = "auto"
const ANCHOR_N: String = "N"
const ANCHOR_NE: String = "NE"
const ANCHOR_E: String = "E"
const ANCHOR_SE: String = "SE"
const ANCHOR_S: String = "S"
const ANCHOR_SW: String = "SW"
const ANCHOR_W: String = "W"
const ANCHOR_NW: String = "NW"
const ANCHORS: Array[String] = [
	ANCHOR_N, ANCHOR_NE, ANCHOR_E, ANCHOR_SE,
	ANCHOR_S, ANCHOR_SW, ANCHOR_W, ANCHOR_NW,
]

var id: String = ""
var from_item_id: String = ""
var to_item_id: String = ""
var from_anchor: String = ANCHOR_AUTO
var to_anchor: String = ANCHOR_AUTO
var color: Color = DEFAULT_COLOR
var thickness: float = DEFAULT_THICKNESS
var style: String = DEFAULT_STYLE
var arrow_end: bool = DEFAULT_ARROW_END
var arrow_start: bool = DEFAULT_ARROW_START
var label: String = DEFAULT_LABEL
var label_font_size: int = DEFAULT_LABEL_FONT_SIZE
var waypoints: Array = []  # Array[Vector2]


static func make_new(from_id: String, to_id: String, from_anchor_value: String = ANCHOR_AUTO, to_anchor_value: String = ANCHOR_AUTO) -> Connection:
	var c: Connection = Connection.new()
	c.id = Uuid.v4()
	c.from_item_id = from_id
	c.to_item_id = to_id
	c.from_anchor = from_anchor_value
	c.to_anchor = to_anchor_value
	return c


static func from_dict(d: Dictionary) -> Connection:
	var c: Connection = Connection.new()
	c.id = String(d.get("id", ""))
	c.from_item_id = String(d.get("from_item_id", ""))
	c.to_item_id = String(d.get("to_item_id", ""))
	c.from_anchor = String(d.get("from_anchor", ANCHOR_AUTO))
	c.to_anchor = String(d.get("to_anchor", ANCHOR_AUTO))
	c.color = ColorUtil.from_array(d.get("color", null), DEFAULT_COLOR)
	c.thickness = float(d.get("thickness", DEFAULT_THICKNESS))
	c.style = String(d.get("style", DEFAULT_STYLE))
	c.arrow_end = bool(d.get("arrow_end", DEFAULT_ARROW_END))
	c.arrow_start = bool(d.get("arrow_start", DEFAULT_ARROW_START))
	c.label = String(d.get("label", DEFAULT_LABEL))
	c.label_font_size = int(d.get("label_font_size", DEFAULT_LABEL_FONT_SIZE))
	var wp_raw: Variant = d.get("waypoints", [])
	c.waypoints = []
	if typeof(wp_raw) == TYPE_ARRAY:
		for entry in (wp_raw as Array):
			if typeof(entry) == TYPE_ARRAY and (entry as Array).size() >= 2:
				c.waypoints.append(Vector2(float(entry[0]), float(entry[1])))
	return c


func to_dict() -> Dictionary:
	return {
		"id": id,
		"from_item_id": from_item_id,
		"to_item_id": to_item_id,
		"from_anchor": from_anchor,
		"to_anchor": to_anchor,
		"color": ColorUtil.to_array(color),
		"thickness": thickness,
		"style": style,
		"arrow_end": arrow_end,
		"arrow_start": arrow_start,
		"label": label,
		"label_font_size": label_font_size,
		"waypoints": _waypoints_to_array(),
	}


func _waypoints_to_array() -> Array:
	var out: Array = []
	for w in waypoints:
		out.append([float((w as Vector2).x), float((w as Vector2).y)])
	return out


func clone_dict_with_new_id() -> Dictionary:
	var d: Dictionary = to_dict()
	d["id"] = Uuid.v4()
	return d


func apply_property(key: String, value: Variant) -> void:
	match key:
		"color":
			color = ColorUtil.from_array(value, color)
		"thickness":
			thickness = float(value)
		"style":
			style = String(value)
		"arrow_end":
			arrow_end = bool(value)
		"arrow_start":
			arrow_start = bool(value)
		"label":
			label = String(value)
		"label_font_size":
			label_font_size = int(value)
		"from_item_id":
			from_item_id = String(value)
		"to_item_id":
			to_item_id = String(value)
		"from_anchor":
			from_anchor = String(value)
		"to_anchor":
			to_anchor = String(value)
		"waypoints":
			waypoints = []
			if typeof(value) == TYPE_ARRAY:
				for entry in (value as Array):
					if typeof(entry) == TYPE_VECTOR2:
						waypoints.append(entry)
					elif typeof(entry) == TYPE_ARRAY and (entry as Array).size() >= 2:
						waypoints.append(Vector2(float(entry[0]), float(entry[1])))


func references_item(item_id: String) -> bool:
	return from_item_id == item_id or to_item_id == item_id
