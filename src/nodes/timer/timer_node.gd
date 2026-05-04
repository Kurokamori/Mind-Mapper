class_name TimerNode
extends BoardItem

const BG_COLOR: Color = Color(0.18, 0.13, 0.16, 1.0)
const FG_COLOR: Color = Color(0.97, 0.93, 0.85, 1.0)
const RUNNING_ACCENT: Color = Color(0.95, 0.55, 0.30, 1.0)
const FINISHED_ACCENT: Color = Color(0.95, 0.30, 0.30, 1.0)
const TICK_INTERVAL_SEC: float = 0.1

@export var initial_duration_sec: float = 600.0
@export var label_text: String = "Timer"
@export var sound_asset_name: String = ""

@onready var _label: Label = %Label
@onready var _time_label: Label = %TimeLabel
@onready var _start_button: Button = %StartButton
@onready var _reset_button: Button = %ResetButton
@onready var _tick_timer: Timer = %TickTimer
@onready var _audio: AudioStreamPlayer = %Audio

var _remaining_sec: float = 0.0
var _running: bool = false
var _finished: bool = false


func _ready() -> void:
	super._ready()
	_remaining_sec = initial_duration_sec
	_start_button.pressed.connect(_on_start_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_tick_timer.wait_time = TICK_INTERVAL_SEC
	_tick_timer.timeout.connect(_on_tick)
	_refresh_visuals()
	_register_with_tray()
	tree_exiting.connect(_on_tree_exit)


func _on_tree_exit() -> void:
	TimerRegistry.unregister(item_id)


func default_size() -> Vector2:
	return Vector2(240, 130)


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
	_update_start_button()
	queue_redraw()
	_register_with_tray()


func _register_with_tray() -> void:
	TimerRegistry.register(item_id, board_id, label_text, _remaining_sec, _running)


func _update_time_display() -> void:
	if _time_label == null:
		return
	_time_label.text = _format_time(_remaining_sec)


func _format_time(seconds: float) -> String:
	if seconds < 0.0 or is_nan(seconds):
		seconds = 0.0
	var total: int = int(ceil(seconds))
	@warning_ignore("integer_division")
	var h: int = total / 3600
	@warning_ignore("integer_division")
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%d:%02d" % [m, s]


func _update_start_button() -> void:
	if _start_button == null:
		return
	if _finished:
		_start_button.text = "Done"
		_start_button.disabled = true
	else:
		_start_button.disabled = false
		_start_button.text = "Pause" if _running else "Start"


func _on_start_pressed() -> void:
	if _finished:
		return
	_running = not _running
	if _running:
		_tick_timer.start()
	else:
		_tick_timer.stop()
	_refresh_visuals()


func _on_reset_pressed() -> void:
	_running = false
	_finished = false
	_tick_timer.stop()
	_remaining_sec = initial_duration_sec
	_refresh_visuals()


func _on_tick() -> void:
	if not _running:
		return
	_remaining_sec = max(0.0, _remaining_sec - TICK_INTERVAL_SEC)
	if _remaining_sec <= 0.0:
		_running = false
		_finished = true
		_tick_timer.stop()
		_play_expiry_sound()
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
	if not _running:
		_remaining_sec = initial_duration_sec
		_finished = false
		_refresh_visuals()


func serialize_payload() -> Dictionary:
	return {
		"initial_duration_sec": initial_duration_sec,
		"label_text": label_text,
		"sound_asset_name": sound_asset_name,
	}


func deserialize_payload(d: Dictionary) -> void:
	initial_duration_sec = float(d.get("initial_duration_sec", initial_duration_sec))
	label_text = String(d.get("label_text", label_text))
	sound_asset_name = String(d.get("sound_asset_name", sound_asset_name))
	_remaining_sec = initial_duration_sec
	_running = false
	_finished = false
	if _label != null:
		_refresh_visuals()


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"initial_duration_sec":
			set_initial_duration(float(value))
		"label_text":
			label_text = String(value)
		"sound_asset_name":
			sound_asset_name = String(value)
	_refresh_visuals()


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/timer/timer_inspector.tscn")
	var inst: TimerInspector = scene.instantiate()
	inst.bind(self)
	return inst
