class_name PresenceOverlay
extends Node2D

const CURSOR_SIZE: float = 16.0
const SELECTION_RECT_THICKNESS: float = 2.0
const VIEWPORT_RECT_THICKNESS: float = 1.5
const VIEWPORT_RECT_OPACITY: float = 0.20
const NAMETAG_FONT_SIZE: int = 12
const NAMETAG_OFFSET: Vector2 = Vector2(14.0, 6.0)
const PING_DURATION_SEC: float = 3.0
const PING_RADIUS_FROM: float = 8.0
const PING_RADIUS_TO: float = 64.0
const PING_THICKNESS: float = 3.0

const MODE_OFF: int = 0
const MODE_CURSORS_ONLY: int = 1
const MODE_FULL: int = 2

var _camera: EditorCameraController = null
var _mode: int = MODE_FULL
var _show_viewport_ghosts: bool = false
var _ping_markers: Array = []


func _ready() -> void:
	z_as_relative = false
	z_index = 100
	MultiplayerService.presence_updated.connect(_on_presence_updated)
	MultiplayerService.presence_removed.connect(_on_presence_removed)
	MultiplayerService.ping_marker_received.connect(_on_ping_marker)
	set_process(true)


func bind_camera(camera: EditorCameraController) -> void:
	_camera = camera


func set_mode(mode: int) -> void:
	if _mode == mode:
		return
	_mode = mode
	queue_redraw()


func current_mode() -> int:
	return _mode


func toggle_viewport_ghosts() -> void:
	_show_viewport_ghosts = not _show_viewport_ghosts
	queue_redraw()


func show_viewport_ghosts() -> bool:
	return _show_viewport_ghosts


func _process(_delta: float) -> void:
	if _mode == MODE_OFF and _ping_markers.is_empty():
		return
	queue_redraw()
	_scrub_ping_markers()


func _draw() -> void:
	if _mode == MODE_OFF and _ping_markers.is_empty():
		return
	if not MultiplayerService.is_in_session():
		_draw_ping_markers()
		return
	var local_stable_id: String = KeypairService.stable_id()
	for state_v: Variant in MultiplayerService.all_presence():
		var state: PresenceState = state_v as PresenceState
		if state == null or state.stable_id == "" or state.stable_id == local_stable_id:
			continue
		if state.board_id != "" and AppState.current_board != null and state.board_id != AppState.current_board.id:
			continue
		_draw_peer_state(state)
	_draw_ping_markers()


func _draw_peer_state(state: PresenceState) -> void:
	if _mode == MODE_FULL and state.has_selection_rect:
		_draw_selection_rect(state)
	if _show_viewport_ghosts and state.has_viewport_rect:
		_draw_viewport_rect(state)
	if state.has_cursor:
		_draw_peer_cursor(state)


func _draw_peer_cursor(state: PresenceState) -> void:
	var pos: Vector2 = state.cursor_world
	var color: Color = state.avatar_color
	var pts: PackedVector2Array = PackedVector2Array([
		pos,
		pos + Vector2(0, CURSOR_SIZE),
		pos + Vector2(CURSOR_SIZE * 0.4, CURSOR_SIZE * 0.65),
		pos + Vector2(CURSOR_SIZE * 0.55, CURSOR_SIZE * 0.95),
		pos + Vector2(CURSOR_SIZE * 0.7, CURSOR_SIZE * 0.85),
		pos + Vector2(CURSOR_SIZE * 0.55, CURSOR_SIZE * 0.55),
		pos + Vector2(CURSOR_SIZE * 0.85, CURSOR_SIZE * 0.55),
	])
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 1.0)
	var label_text: String = state.display_name
	if state.role == ParticipantsManifest.ROLE_OWNER:
		label_text = "★ " + label_text
	elif state.hosting:
		label_text = "● " + label_text
	var font: Font = ThemeDB.fallback_font
	var label_pos: Vector2 = pos + NAMETAG_OFFSET
	var text_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAMETAG_FONT_SIZE)
	var bg_rect: Rect2 = Rect2(label_pos + Vector2(-3, -3 - text_size.y), text_size + Vector2(6, 6))
	draw_rect(bg_rect, Color(color.r, color.g, color.b, 0.85), true)
	draw_string(font, label_pos - Vector2(0, 3), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAMETAG_FONT_SIZE, Color(0.05, 0.05, 0.10, 1.0))


func _draw_selection_rect(state: PresenceState) -> void:
	var color: Color = state.avatar_color
	var fill: Color = Color(color.r, color.g, color.b, 0.10)
	draw_rect(state.selection_world_rect, fill, true)
	draw_rect(state.selection_world_rect, color, false, SELECTION_RECT_THICKNESS)


func _draw_viewport_rect(state: PresenceState) -> void:
	var color: Color = state.avatar_color
	var ghost_color: Color = Color(color.r, color.g, color.b, VIEWPORT_RECT_OPACITY)
	draw_rect(state.viewport_world_rect, ghost_color, false, VIEWPORT_RECT_THICKNESS)


func _draw_ping_markers() -> void:
	var now_ms: int = Time.get_ticks_msec()
	for entry_v: Variant in _ping_markers:
		var entry: Dictionary = entry_v
		var t: float = float(now_ms - int(entry.get("t0_ms", now_ms))) / (PING_DURATION_SEC * 1000.0)
		if t > 1.0:
			continue
		var radius: float = PING_RADIUS_FROM + (PING_RADIUS_TO - PING_RADIUS_FROM) * t
		var color: Color = entry.get("color", Color(1, 1, 1, 1))
		color.a = 1.0 - t
		var pos: Vector2 = entry.get("pos", Vector2.ZERO)
		draw_arc(pos, radius, 0.0, TAU, 32, color, PING_THICKNESS, true)


func _scrub_ping_markers() -> void:
	if _ping_markers.is_empty():
		return
	var now_ms: int = Time.get_ticks_msec()
	var alive: Array = []
	for entry_v: Variant in _ping_markers:
		var entry: Dictionary = entry_v
		if now_ms - int(entry.get("t0_ms", 0)) < int(PING_DURATION_SEC * 1000.0):
			alive.append(entry)
	_ping_markers = alive


func _on_presence_updated(_stable_id: String) -> void:
	queue_redraw()


func _on_presence_removed(_stable_id: String) -> void:
	queue_redraw()


func _on_ping_marker(world_pos: Vector2, color: Color, _stable_id: String) -> void:
	_ping_markers.append({"pos": world_pos, "color": color, "t0_ms": Time.get_ticks_msec()})
	queue_redraw()
