class_name TimerNode
extends BoardItem

const BG_COLOR: Color = Color(0.18, 0.13, 0.16, 1.0)
const FG_COLOR: Color = Color(0.97, 0.93, 0.85, 1.0)
const RUNNING_ACCENT: Color = Color(0.95, 0.55, 0.30, 1.0)
const FINISHED_ACCENT: Color = Color(0.95, 0.30, 0.30, 1.0)
const TICK_INTERVAL_SEC: float = 0.1
const MODE_DURATION: String = "duration"
const MODE_TARGET: String = "target"

@export var initial_duration_sec: float = 600.0
@export var label_text: String = "Timer"
@export var sound_asset_name: String = ""
@export var mode: String = MODE_DURATION
@export var target_unix: int = 0

@onready var _label: Label = %Label
@onready var _time_label: Label = %TimeLabel
@onready var _target_label: Label = %TargetLabel
@onready var _start_button: Button = %StartButton
@onready var _reset_button: Button = %ResetButton
@onready var _tick_timer: Timer = %TickTimer
@onready var _audio: AudioStreamPlayer = %Audio

var _remaining_sec: float = 0.0
var _running: bool = false
var _finished: bool = false
var _expires_at_unix: int = 0
var _state_initialized: bool = false


func _ready() -> void:
	super._ready()
	ThemeManager.apply_relative_font_size(_label, 0.92)
	ThemeManager.apply_relative_font_size(_time_label, 2.15)
	ThemeManager.apply_relative_font_size(_target_label, 0.80)
	if not _state_initialized:
		_refresh_remaining_from_state()
		_state_initialized = true
	_start_button.pressed.connect(_on_start_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_tick_timer.wait_time = TICK_INTERVAL_SEC
	_tick_timer.timeout.connect(_on_tick)
	if _running and not _finished:
		_tick_timer.start()
	_refresh_visuals()
	_register_with_tray()
	tree_exiting.connect(_on_tree_exit)


func _on_tree_exit() -> void:
	TimerRegistry.unregister(item_id)


func default_size() -> Vector2:
	return Vector2(320, 190)


func display_name() -> String:
	return "Timer"


func _draw_body() -> void:
	var border: Color = BG_COLOR.darkened(0.3)
	var border_width: int = NODE_BORDER_WIDTH
	if _finished:
		border = FINISHED_ACCENT
		border_width = 2
	elif _running:
		border = RUNNING_ACCENT
		border_width = 2
	_draw_rounded_panel(BG_COLOR, border, 0.0, Color(0, 0, 0, 0), border_width)


func _refresh_visuals() -> void:
	if _label != null:
		_label.text = label_text
	_update_time_display()
	_update_target_caption()
	_update_start_button()
	queue_redraw()
	_register_with_tray()


func _register_with_tray() -> void:
	TimerRegistry.register(item_id, board_id, label_text, _remaining_sec, _running)


func _update_time_display() -> void:
	if _time_label == null:
		return
	_time_label.text = TimerRegistry.format_duration(_remaining_sec, false)


func _update_target_caption() -> void:
	if _target_label == null:
		return
	if mode == MODE_TARGET and target_unix > 0:
		_target_label.visible = true
		_target_label.text = "→ %s" % Time.get_datetime_string_from_unix_time(target_unix, true)
	else:
		_target_label.visible = false
		_target_label.text = ""


func _update_start_button() -> void:
	if _start_button == null:
		return
	if _finished:
		_start_button.text = "Done"
		_start_button.disabled = true
	elif mode == MODE_TARGET and target_unix <= 0:
		_start_button.text = "Set target"
		_start_button.disabled = true
	else:
		_start_button.disabled = false
		_start_button.text = "Pause" if _running else "Start"


func _on_start_pressed() -> void:
	if _finished:
		return
	if mode == MODE_TARGET and target_unix <= 0:
		return
	_running = not _running
	if _running:
		if mode == MODE_TARGET:
			_remaining_sec = max(0.0, float(target_unix) - Time.get_unix_time_from_system())
			_expires_at_unix = 0
		else:
			_expires_at_unix = int(Time.get_unix_time_from_system()) + int(ceil(_remaining_sec))
		_tick_timer.start()
	else:
		if mode == MODE_DURATION and _expires_at_unix > 0:
			_remaining_sec = max(0.0, float(_expires_at_unix) - Time.get_unix_time_from_system())
		_expires_at_unix = 0
		_tick_timer.stop()
	_refresh_visuals()
	_request_save()


func _on_reset_pressed() -> void:
	_running = false
	_finished = false
	_expires_at_unix = 0
	_tick_timer.stop()
	_refresh_remaining_from_state()
	_refresh_visuals()
	_request_save()


func _refresh_remaining_from_state() -> void:
	if mode == MODE_TARGET:
		_remaining_sec = max(0.0, float(target_unix) - Time.get_unix_time_from_system())
	else:
		_remaining_sec = initial_duration_sec


func _on_tick() -> void:
	if not _running:
		return
	if mode == MODE_TARGET:
		_remaining_sec = max(0.0, float(target_unix) - Time.get_unix_time_from_system())
	elif _expires_at_unix > 0:
		_remaining_sec = max(0.0, float(_expires_at_unix) - Time.get_unix_time_from_system())
	else:
		_remaining_sec = max(0.0, _remaining_sec - TICK_INTERVAL_SEC)
	if _remaining_sec <= 0.0:
		_running = false
		_finished = true
		_expires_at_unix = 0
		_tick_timer.stop()
		_play_expiry_sound()
		_refresh_visuals()
		_request_save()
		return
	_refresh_visuals()


func _play_expiry_sound() -> void:
	if sound_asset_name == "" or AppState.current_project == null:
		return
	var path: String = AppState.current_project.resolve_asset_path(sound_asset_name)
	if not FileAccess.file_exists(path):
		return
	var stream: AudioStream = _load_audio(path)
	if stream != null:
		_audio.stream = stream
		_audio.play()


func _load_audio(path: String) -> AudioStream:
	var ext: String = path.get_extension().to_lower()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() == 0:
		return null
	match ext:
		"mp3":
			var s: AudioStreamMP3 = AudioStreamMP3.new()
			s.data = bytes
			return s
		"ogg":
			return AudioStreamOggVorbis.load_from_buffer(bytes)
		"wav":
			var w: AudioStreamWAV = AudioStreamWAV.new()
			w.data = bytes
			return w
	return null


func set_initial_duration(seconds: float) -> void:
	initial_duration_sec = max(0.0, seconds)
	if mode == MODE_DURATION and not _running:
		_finished = false
		_remaining_sec = initial_duration_sec
		_refresh_visuals()


func set_mode(new_mode: String) -> void:
	var normalized: String = new_mode if (new_mode == MODE_DURATION or new_mode == MODE_TARGET) else MODE_DURATION
	if mode == normalized:
		return
	mode = normalized
	_running = false
	_finished = false
	_expires_at_unix = 0
	if _tick_timer != null:
		_tick_timer.stop()
	_refresh_remaining_from_state()
	_refresh_visuals()


func set_target_unix(unix: int) -> void:
	target_unix = max(0, unix)
	if mode == MODE_TARGET and not _running:
		_finished = false
		_refresh_remaining_from_state()
		_refresh_visuals()


func _snapshot_remaining() -> float:
	if _running and mode == MODE_DURATION and _expires_at_unix > 0:
		return max(0.0, float(_expires_at_unix) - Time.get_unix_time_from_system())
	if _running and mode == MODE_TARGET and target_unix > 0:
		return max(0.0, float(target_unix) - Time.get_unix_time_from_system())
	return _remaining_sec


func serialize_payload() -> Dictionary:
	return {
		"initial_duration_sec": initial_duration_sec,
		"label_text": label_text,
		"sound_asset_name": sound_asset_name,
		"mode": mode,
		"target_unix": target_unix,
		"running": _running,
		"finished": _finished,
		"remaining_sec": _snapshot_remaining(),
		"expires_at_unix": _expires_at_unix,
	}


func deserialize_payload(d: Dictionary) -> void:
	initial_duration_sec = float(d.get("initial_duration_sec", initial_duration_sec))
	label_text = String(d.get("label_text", label_text))
	sound_asset_name = String(d.get("sound_asset_name", sound_asset_name))
	var raw_mode: String = String(d.get("mode", MODE_DURATION))
	mode = raw_mode if (raw_mode == MODE_DURATION or raw_mode == MODE_TARGET) else MODE_DURATION
	target_unix = int(d.get("target_unix", target_unix))
	_running = bool(d.get("running", false))
	_finished = bool(d.get("finished", false))
	_expires_at_unix = int(d.get("expires_at_unix", 0))
	var stored_remaining: float = float(d.get("remaining_sec", initial_duration_sec))
	var now_unix: int = int(Time.get_unix_time_from_system())
	if _finished:
		_remaining_sec = 0.0
		_running = false
		_expires_at_unix = 0
	elif mode == MODE_TARGET:
		if target_unix > 0:
			_remaining_sec = max(0.0, float(target_unix) - float(now_unix))
		else:
			_remaining_sec = stored_remaining
		if _running and _remaining_sec <= 0.0:
			_finished = true
			_running = false
	else:
		if _running and _expires_at_unix > 0:
			_remaining_sec = max(0.0, float(_expires_at_unix) - float(now_unix))
			if _remaining_sec <= 0.0:
				_finished = true
				_running = false
				_expires_at_unix = 0
		else:
			_remaining_sec = stored_remaining
			_running = false
			_expires_at_unix = 0
	_state_initialized = true
	if _label != null:
		_refresh_visuals()
	if _tick_timer != null:
		if _running and not _finished:
			_tick_timer.start()
		else:
			_tick_timer.stop()


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"initial_duration_sec":
			set_initial_duration(float(value))
		"label_text":
			label_text = String(value)
		"sound_asset_name":
			sound_asset_name = String(value)
		"mode":
			set_mode(String(value))
		"target_unix":
			set_target_unix(int(value))
	_refresh_visuals()


func _request_save() -> void:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("request_save"):
			node.request_save()
			return
		node = node.get_parent()


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/timer/timer_inspector.tscn")
	var inst: TimerInspector = scene.instantiate()
	inst.bind(self)
	return inst
