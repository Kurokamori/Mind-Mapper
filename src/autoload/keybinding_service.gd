extends Node

signal bindings_changed()

const ACTION_UNDO: String = "undo"
const ACTION_REDO: String = "redo"
const ACTION_COPY: String = "copy"
const ACTION_PASTE: String = "paste"
const ACTION_CUT: String = "cut"
const ACTION_DUPLICATE: String = "duplicate"
const ACTION_SAVE: String = "save"
const ACTION_SELECT_ALL: String = "select_all"
const ACTION_GROUP: String = "group"
const ACTION_DELETE: String = "delete"
const ACTION_NUDGE_LEFT: String = "nudge_left"
const ACTION_NUDGE_RIGHT: String = "nudge_right"
const ACTION_NUDGE_UP: String = "nudge_up"
const ACTION_NUDGE_DOWN: String = "nudge_down"
const ACTION_OPEN_PALETTE: String = "open_palette"
const ACTION_PRESENT: String = "present"
const ACTION_BRING_FORWARD: String = "bring_forward"
const ACTION_BRING_TO_FRONT: String = "bring_to_front"
const ACTION_SEND_BACKWARD: String = "send_backward"
const ACTION_SEND_TO_BACK: String = "send_to_back"
const ACTION_LOCK_TOGGLE: String = "lock_toggle"

const ALL_ACTIONS: Array[String] = [
	ACTION_UNDO, ACTION_REDO, ACTION_COPY, ACTION_PASTE, ACTION_CUT,
	ACTION_DUPLICATE, ACTION_SAVE, ACTION_SELECT_ALL, ACTION_GROUP, ACTION_DELETE,
	ACTION_NUDGE_LEFT, ACTION_NUDGE_RIGHT, ACTION_NUDGE_UP, ACTION_NUDGE_DOWN,
	ACTION_OPEN_PALETTE, ACTION_PRESENT,
	ACTION_BRING_FORWARD, ACTION_BRING_TO_FRONT, ACTION_SEND_BACKWARD, ACTION_SEND_TO_BACK,
	ACTION_LOCK_TOGGLE,
]


func _ready() -> void:
	UserPrefs.keybindings_changed.connect(func() -> void: emit_signal("bindings_changed"))


func default_binding(action_id: String) -> Dictionary:
	match action_id:
		ACTION_UNDO: return {"keycode": KEY_Z, "ctrl": true, "shift": false, "alt": false}
		ACTION_REDO: return {"keycode": KEY_Y, "ctrl": true, "shift": false, "alt": false}
		ACTION_COPY: return {"keycode": KEY_C, "ctrl": true, "shift": false, "alt": false}
		ACTION_PASTE: return {"keycode": KEY_V, "ctrl": true, "shift": false, "alt": false}
		ACTION_CUT: return {"keycode": KEY_X, "ctrl": true, "shift": false, "alt": false}
		ACTION_DUPLICATE: return {"keycode": KEY_D, "ctrl": true, "shift": false, "alt": false}
		ACTION_SAVE: return {"keycode": KEY_S, "ctrl": true, "shift": false, "alt": false}
		ACTION_SELECT_ALL: return {"keycode": KEY_A, "ctrl": true, "shift": false, "alt": false}
		ACTION_GROUP: return {"keycode": KEY_G, "ctrl": true, "shift": false, "alt": false}
		ACTION_DELETE: return {"keycode": KEY_DELETE, "ctrl": false, "shift": false, "alt": false}
		ACTION_NUDGE_LEFT: return {"keycode": KEY_LEFT, "ctrl": false, "shift": false, "alt": false}
		ACTION_NUDGE_RIGHT: return {"keycode": KEY_RIGHT, "ctrl": false, "shift": false, "alt": false}
		ACTION_NUDGE_UP: return {"keycode": KEY_UP, "ctrl": false, "shift": false, "alt": false}
		ACTION_NUDGE_DOWN: return {"keycode": KEY_DOWN, "ctrl": false, "shift": false, "alt": false}
		ACTION_OPEN_PALETTE: return {"keycode": KEY_K, "ctrl": true, "shift": false, "alt": false}
		ACTION_PRESENT: return {"keycode": KEY_F5, "ctrl": false, "shift": false, "alt": false}
		ACTION_BRING_FORWARD: return {"keycode": KEY_BRACKETRIGHT, "ctrl": true, "shift": false, "alt": false}
		ACTION_BRING_TO_FRONT: return {"keycode": KEY_BRACKETRIGHT, "ctrl": true, "shift": true, "alt": false}
		ACTION_SEND_BACKWARD: return {"keycode": KEY_BRACKETLEFT, "ctrl": true, "shift": false, "alt": false}
		ACTION_SEND_TO_BACK: return {"keycode": KEY_BRACKETLEFT, "ctrl": true, "shift": true, "alt": false}
		ACTION_LOCK_TOGGLE: return {"keycode": KEY_L, "ctrl": true, "shift": false, "alt": false}
	return {}


func binding(action_id: String) -> Dictionary:
	var override: Variant = UserPrefs.keybindings.get(action_id, null)
	if typeof(override) == TYPE_DICTIONARY:
		return override
	return default_binding(action_id)


func display_label(action_id: String) -> String:
	var b: Dictionary = binding(action_id)
	if b.is_empty():
		return ""
	var parts: Array[String] = []
	if bool(b.get("ctrl", false)):
		parts.append("Ctrl")
	if bool(b.get("shift", false)):
		parts.append("Shift")
	if bool(b.get("alt", false)):
		parts.append("Alt")
	parts.append(OS.get_keycode_string(int(b.get("keycode", 0))))
	return "+".join(parts)


func matches(event: InputEvent, action_id: String) -> bool:
	if not (event is InputEventKey):
		return false
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return false
	var b: Dictionary = binding(action_id)
	if b.is_empty():
		return false
	var keycode: int = int(b.get("keycode", 0))
	var event_keycode: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
	if event_keycode != keycode:
		return false
	var want_ctrl: bool = bool(b.get("ctrl", false))
	var want_shift: bool = bool(b.get("shift", false))
	var want_alt: bool = bool(b.get("alt", false))
	var have_ctrl: bool = k.ctrl_pressed or k.meta_pressed
	if have_ctrl != want_ctrl:
		return false
	if k.shift_pressed != want_shift:
		return false
	if k.alt_pressed != want_alt:
		return false
	return true


func first_match(event: InputEvent) -> String:
	for a in ALL_ACTIONS:
		if matches(event, a):
			return a
	return ""
