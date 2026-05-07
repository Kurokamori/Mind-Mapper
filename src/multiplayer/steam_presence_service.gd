extends Node

signal co_author_sync_offer(steam_id: int, persona: String, project_id: String, friend_lobby_id: int, divergence: String)
signal discovery_state_changed(enabled: bool)

const STEAM_PROBE_SINGLETONS: Array[String] = ["Steam", "GodotSteam"]
const POLL_INTERVAL_SEC: float = 30.0
const POLL_INITIAL_DELAY_SEC: float = 4.0

const RP_KEY_PROJECT_ID: String = "mm_project_id"
const RP_KEY_PROJECT_NAME: String = "mm_project_name"
const RP_KEY_ROOT_BOARD_ID: String = "mm_root_board_id"
const RP_KEY_CLOCK_SIG: String = "mm_clock_sig"
const RP_KEY_PERSONA: String = "mm_persona"
const RP_KEY_LOBBY_ID: String = "mm_lobby_id"
const RP_KEY_FORMAT_VERSION: String = "mm_format_version"

var _steam: Object = null
var _steam_singleton_name: String = ""
var _poll_timer: Timer = null
var _initial_delay_timer: Timer = null
var _enabled: bool = true
var _current_project: Project = null
var _current_clock_sig: String = ""
var _current_lobby_id: int = 0
var _last_offered_steam_ids: Dictionary = {}


func _ready() -> void:
	_resolve_steam_singleton()
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL_SEC
	_poll_timer.one_shot = false
	_poll_timer.autostart = false
	_poll_timer.timeout.connect(_on_poll_tick)
	add_child(_poll_timer)
	_initial_delay_timer = Timer.new()
	_initial_delay_timer.wait_time = POLL_INITIAL_DELAY_SEC
	_initial_delay_timer.one_shot = true
	_initial_delay_timer.autostart = false
	_initial_delay_timer.timeout.connect(_on_initial_delay_tick)
	add_child(_initial_delay_timer)
	AppState.project_opened.connect(_on_project_opened)
	AppState.project_closed.connect(_on_project_closed)
	if Engine.has_singleton("MultiplayerService") or get_tree().root.has_node("MultiplayerService"):
		MultiplayerService.session_state_changed.connect(_on_multiplayer_session_state_changed)
	_connect_steam_signals()
	if AppState.current_project != null:
		_on_project_opened(AppState.current_project)


func is_available() -> bool:
	return _steam != null


func set_enabled(enabled: bool) -> void:
	if _enabled == enabled:
		return
	_enabled = enabled
	if _enabled:
		_publish_rich_presence()
		_kickstart_polling()
	else:
		_clear_rich_presence()
		_poll_timer.stop()
		_initial_delay_timer.stop()
	emit_signal("discovery_state_changed", _enabled)


func is_enabled() -> bool:
	return _enabled


func refresh_presence() -> void:
	_compute_current_clock_sig()
	_publish_rich_presence()


func register_lobby(lobby_id: int) -> void:
	_current_lobby_id = lobby_id
	_publish_rich_presence()


func clear_lobby() -> void:
	_current_lobby_id = 0
	_publish_rich_presence()


func _resolve_steam_singleton() -> void:
	var root: Node = Engine.get_main_loop().root if Engine.get_main_loop() != null else null
	if root != null:
		for name: String in STEAM_PROBE_SINGLETONS:
			if root.has_node(name):
				_steam = root.get_node(name)
				_steam_singleton_name = name
				return
	for name: String in STEAM_PROBE_SINGLETONS:
		if Engine.has_singleton(name):
			_steam = Engine.get_singleton(name)
			_steam_singleton_name = name
			return


func _connect_steam_signals() -> void:
	if _steam == null:
		return
	if _steam.has_signal("friend_rich_presence_update") and not _steam.is_connected("friend_rich_presence_update", _on_friend_rich_presence_update):
		_steam.connect("friend_rich_presence_update", _on_friend_rich_presence_update)


func _on_project_opened(project: Project) -> void:
	_current_project = project
	_last_offered_steam_ids.clear()
	_compute_current_clock_sig()
	_publish_rich_presence()
	if _is_active():
		_kickstart_polling()


func _on_project_closed() -> void:
	_current_project = null
	_current_clock_sig = ""
	_current_lobby_id = 0
	_last_offered_steam_ids.clear()
	_clear_rich_presence()
	_poll_timer.stop()
	_initial_delay_timer.stop()


func _on_multiplayer_session_state_changed(state: int) -> void:
	if state == MultiplayerService.STATE_HOSTING:
		var adapter: NetworkAdapter = MultiplayerService.adapter_for(NetworkAdapter.ADAPTER_KIND_STEAM)
		var lobby_id: int = 0
		if adapter is SteamAdapter:
			lobby_id = (adapter as SteamAdapter).current_lobby_id()
		_current_lobby_id = lobby_id
	elif state == MultiplayerService.STATE_IDLE or state == MultiplayerService.STATE_ERROR:
		_current_lobby_id = 0
	_publish_rich_presence()


func _kickstart_polling() -> void:
	if not _is_active() or _steam == null or _current_project == null:
		return
	_initial_delay_timer.start()
	_poll_timer.start()


func _is_active() -> bool:
	if not _enabled:
		return false
	if _current_project == null:
		return false
	return _current_project.discovery_enabled


func notify_project_discovery_changed() -> void:
	if _is_active():
		_publish_rich_presence()
		_kickstart_polling()
	else:
		_clear_rich_presence()
		_poll_timer.stop()
		_initial_delay_timer.stop()
	emit_signal("discovery_state_changed", _is_active())


func _on_initial_delay_tick() -> void:
	_request_friend_rich_presence_for_all()


func _on_poll_tick() -> void:
	if not _is_active():
		return
	_compute_current_clock_sig()
	_publish_rich_presence()
	_request_friend_rich_presence_for_all()


func _compute_current_clock_sig() -> void:
	if _current_project == null or OpBus.oplog() == null:
		_current_clock_sig = ""
		return
	var combined: PackedStringArray = PackedStringArray()
	combined.append(_current_project.id)
	for board_id: String in OpBus.oplog().all_known_boards():
		OpBus.oplog().ensure_loaded(board_id)
		var clock: VectorClock = OpBus.oplog().vector_clock_for_board(board_id)
		var entries: Dictionary = clock.entries()
		var keys: Array = entries.keys()
		keys.sort()
		var line: String = "%s|" % board_id
		for k_v: Variant in keys:
			line += "%s:%d," % [String(k_v), int(entries[k_v])]
		combined.append(line)
	var blob: String = "\n".join(combined)
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(blob.to_utf8_buffer())
	var bytes: PackedByteArray = ctx.finish()
	var sig: String = ""
	for i in range(min(8, bytes.size())):
		sig += "%02x" % int(bytes[i])
	_current_clock_sig = sig


func _publish_rich_presence() -> void:
	if _steam == null:
		return
	if not _is_active():
		_clear_rich_presence()
		return
	_set_rich_presence(RP_KEY_FORMAT_VERSION, str(Project.FORMAT_VERSION))
	_set_rich_presence(RP_KEY_PROJECT_ID, _current_project.id)
	_set_rich_presence(RP_KEY_PROJECT_NAME, _current_project.name)
	_set_rich_presence(RP_KEY_ROOT_BOARD_ID, _current_project.root_board_id)
	_set_rich_presence(RP_KEY_CLOCK_SIG, _current_clock_sig)
	_set_rich_presence(RP_KEY_PERSONA, KeypairService.display_name())
	if _current_lobby_id != 0:
		_set_rich_presence(RP_KEY_LOBBY_ID, str(_current_lobby_id))
	else:
		_set_rich_presence(RP_KEY_LOBBY_ID, "")


func _clear_rich_presence() -> void:
	if _steam == null:
		return
	for key: String in [RP_KEY_PROJECT_ID, RP_KEY_PROJECT_NAME, RP_KEY_ROOT_BOARD_ID, RP_KEY_CLOCK_SIG, RP_KEY_PERSONA, RP_KEY_LOBBY_ID, RP_KEY_FORMAT_VERSION]:
		_set_rich_presence(key, "")


func _set_rich_presence(key: String, value: String) -> void:
	if _steam == null:
		return
	if _steam.has_method("setRichPresence"):
		_steam.call("setRichPresence", key, value)
	elif _steam.has_method("set_rich_presence"):
		_steam.call("set_rich_presence", key, value)


func _request_friend_rich_presence_for_all() -> void:
	if _steam == null:
		return
	var count: int = _friend_count()
	for i in range(count):
		var fid: int = _friend_by_index(i)
		if fid == 0:
			continue
		if _steam.has_method("requestFriendRichPresence"):
			_steam.call("requestFriendRichPresence", fid)
		elif _steam.has_method("request_friend_rich_presence"):
			_steam.call("request_friend_rich_presence", fid)


func _on_friend_rich_presence_update(steam_id: int, _app_id: int) -> void:
	if not _is_active():
		return
	_evaluate_friend(steam_id)


func _evaluate_friend(steam_id: int) -> void:
	if _steam == null or _current_project == null:
		return
	var project_id: String = _get_friend_rich_presence(steam_id, RP_KEY_PROJECT_ID)
	if project_id == "" or project_id != _current_project.id:
		return
	var clock_sig: String = _get_friend_rich_presence(steam_id, RP_KEY_CLOCK_SIG)
	if clock_sig == "" or clock_sig == _current_clock_sig:
		return
	if int(_last_offered_steam_ids.get(steam_id, 0)) > 0:
		var elapsed_ms: int = Time.get_ticks_msec() - int(_last_offered_steam_ids[steam_id])
		if elapsed_ms < int(POLL_INTERVAL_SEC * 1000.0 * 4.0):
			return
	_last_offered_steam_ids[steam_id] = Time.get_ticks_msec()
	var persona: String = _get_friend_rich_presence(steam_id, RP_KEY_PERSONA)
	if persona == "":
		persona = _friend_persona_name(steam_id)
	var friend_lobby_str: String = _get_friend_rich_presence(steam_id, RP_KEY_LOBBY_ID)
	var friend_lobby_id: int = int(friend_lobby_str) if friend_lobby_str.is_valid_int() else 0
	emit_signal("co_author_sync_offer", steam_id, persona, project_id, friend_lobby_id, "clock signatures differ")


func _get_friend_rich_presence(steam_id: int, key: String) -> String:
	if _steam == null:
		return ""
	if _steam.has_method("getFriendRichPresence"):
		return String(_steam.call("getFriendRichPresence", steam_id, key))
	if _steam.has_method("get_friend_rich_presence"):
		return String(_steam.call("get_friend_rich_presence", steam_id, key))
	return ""


func _friend_count() -> int:
	if _steam == null:
		return 0
	if _steam.has_method("getFriendCount"):
		return int(_steam.call("getFriendCount", 0x04))
	if _steam.has_method("get_friend_count"):
		return int(_steam.call("get_friend_count", 0x04))
	return 0


func _friend_by_index(index: int) -> int:
	if _steam == null:
		return 0
	if _steam.has_method("getFriendByIndex"):
		return int(_steam.call("getFriendByIndex", index, 0x04))
	if _steam.has_method("get_friend_by_index"):
		return int(_steam.call("get_friend_by_index", index, 0x04))
	return 0


func _friend_persona_name(steam_id: int) -> String:
	if _steam == null:
		return "Steam User"
	if _steam.has_method("getFriendPersonaName"):
		return String(_steam.call("getFriendPersonaName", steam_id))
	if _steam.has_method("get_friend_persona_name"):
		return String(_steam.call("get_friend_persona_name", steam_id))
	return "Steam User"
