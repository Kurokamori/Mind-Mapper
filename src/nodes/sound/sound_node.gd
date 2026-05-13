class_name SoundNode
extends BoardItem

enum SourceMode { LINKED, EMBEDDED }

const PADDING: Vector2 = Vector2(10, 8)
const BG_COLOR: Color = Color(0.12, 0.18, 0.22, 1.0)
const FG_COLOR: Color = Color(0.95, 0.96, 0.98, 1.0)
const ACCENT_COLOR: Color = Color(0.30, 0.78, 0.95, 1.0)
const PROGRESS_TICK_SEC: float = 0.05

@export var source_mode: int = SourceMode.LINKED
@export var source_path: String = ""
@export var asset_name: String = ""
@export var display_label: String = "Audio"
@export var volume_db: float = 0.0

@onready var _name_label: Label = %NameLabel
@onready var _time_label: Label = %TimeLabel
@onready var _progress: ProgressBar = %Progress
@onready var _play_button: Button = %PlayButton
@onready var _stop_button: Button = %StopButton
@onready var _player: AudioStreamPlayer = %Player
@onready var _tick_timer: Timer = %TickTimer

var _stream_loaded: bool = false
var _last_load_path: String = ""


func _ready() -> void:
	super._ready()
	ThemeManager.apply_relative_font_size(_time_label, 0.85)
	_play_button.pressed.connect(_on_play_pressed)
	_stop_button.pressed.connect(_on_stop_pressed)
	_player.finished.connect(_on_finished)
	_tick_timer.wait_time = PROGRESS_TICK_SEC
	_tick_timer.timeout.connect(_on_tick)
	_layout()
	_reload_stream()
	_refresh_visuals()


func default_size() -> Vector2:
	return Vector2(280, 110)


func display_name() -> String:
	return "Sound"


func _draw_body() -> void:
	_draw_rounded_panel(BG_COLOR, BG_COLOR.darkened(0.3))


func _layout() -> void:
	pass


func _refresh_visuals() -> void:
	if _name_label != null:
		_name_label.text = _label_for_display()
	_update_time_display()


func _label_for_display() -> String:
	if display_label != "" and display_label != "Audio":
		return display_label
	if asset_name != "":
		return asset_name
	if source_path != "":
		return source_path.get_file()
	return "No audio"


func notify_asset_available(streamed_asset_name: String) -> void:
	if streamed_asset_name == "" or asset_name == "":
		return
	if streamed_asset_name != asset_name:
		return
	if source_mode != SourceMode.EMBEDDED:
		return
	_reload_stream()
	_refresh_visuals()


func resolve_absolute_path() -> String:
	if source_mode == SourceMode.EMBEDDED:
		if AppState.current_project == null or asset_name == "":
			return ""
		return AppState.current_project.resolve_asset_path(asset_name)
	return source_path


func set_source_linked(absolute_path: String) -> void:
	source_mode = SourceMode.LINKED
	source_path = absolute_path
	asset_name = ""
	_reload_stream()
	_refresh_visuals()


func set_source_embedded_from(absolute_path: String) -> void:
	if AppState.current_project == null:
		set_source_linked(absolute_path)
		return
	var copied_name: String = AppState.current_project.copy_asset_into_project(absolute_path)
	if copied_name == "":
		set_source_linked(absolute_path)
		return
	source_mode = SourceMode.EMBEDDED
	asset_name = copied_name
	source_path = ""
	_reload_stream()
	_refresh_visuals()


func _reload_stream() -> void:
	_player.stop()
	_player.stream = null
	_stream_loaded = false
	_progress.value = 0.0
	var path: String = resolve_absolute_path()
	if path == "" or not FileAccess.file_exists(path):
		_last_load_path = ""
		_update_time_display()
		return
	var stream: AudioStream = _load_stream_from_disk(path)
	if stream == null:
		_last_load_path = ""
		_update_time_display()
		return
	_player.stream = stream
	_player.volume_db = volume_db
	_stream_loaded = true
	_last_load_path = path
	_update_time_display()


func _load_stream_from_disk(path: String) -> AudioStream:
	var ext: String = path.get_extension().to_lower()
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	if bytes.size() == 0:
		return null
	match ext:
		"mp3":
			var s := AudioStreamMP3.new()
			s.data = bytes
			return s
		"ogg":
			return AudioStreamOggVorbis.load_from_buffer(bytes)
		"wav":
			if ClassDB.class_has_method("AudioStreamWAV", "load_from_buffer"):
				return AudioStreamWAV.load_from_buffer(bytes)
			return null
	return null


func _on_play_pressed() -> void:
	if not _stream_loaded:
		return
	if _player.playing:
		_player.stream_paused = not _player.stream_paused
	else:
		_player.play()
	_tick_timer.start()
	_update_play_button()


func _on_stop_pressed() -> void:
	_player.stop()
	_tick_timer.stop()
	_progress.value = 0.0
	_update_play_button()
	_update_time_display()


func _on_finished() -> void:
	_tick_timer.stop()
	_progress.value = 0.0
	_update_play_button()
	_update_time_display()


func _on_tick() -> void:
	if not _player.playing or _player.stream == null:
		_tick_timer.stop()
		return
	var length: float = _player.stream.get_length()
	if length > 0.0:
		_progress.max_value = length
		_progress.value = clamp(_player.get_playback_position(), 0.0, length)
	_update_time_display()


func _update_play_button() -> void:
	if _player.playing and not _player.stream_paused:
		_play_button.text = "Pause"
	else:
		_play_button.text = "Play"


func _update_time_display() -> void:
	if _player == null or _time_label == null:
		return
	var pos: float = _player.get_playback_position() if _player.playing else 0.0
	var length: float = _player.stream.get_length() if _player.stream != null else 0.0
	_time_label.text = "%s / %s" % [_format_time(pos), _format_time(length)]


func _format_time(seconds: float) -> String:
	if seconds < 0.0 or is_nan(seconds):
		seconds = 0.0
	var s: int = int(round(seconds))
	@warning_ignore("integer_division")
	var m: int = s / 60
	var sec: int = s % 60
	return "%d:%02d" % [m, sec]


func serialize_payload() -> Dictionary:
	return {
		"source_mode": source_mode,
		"source_path": source_path,
		"asset_name": asset_name,
		"display_label": display_label,
		"volume_db": volume_db,
	}


func deserialize_payload(d: Dictionary) -> void:
	source_mode = int(d.get("source_mode", source_mode))
	source_path = String(d.get("source_path", ""))
	asset_name = String(d.get("asset_name", ""))
	display_label = String(d.get("display_label", "Audio"))
	volume_db = float(d.get("volume_db", volume_db))
	if _player != null:
		_reload_stream()
		_refresh_visuals()


func apply_typed_property(key: String, value: Variant) -> void:
	match key:
		"source_path":
			source_path = String(value)
			_reload_stream()
		"asset_name":
			asset_name = String(value)
			_reload_stream()
		"source_mode":
			source_mode = int(value)
			_reload_stream()
		"display_label":
			display_label = String(value)
		"volume_db":
			volume_db = float(value)
			if _player != null:
				_player.volume_db = volume_db
	_refresh_visuals()


func build_inspector() -> Control:
	var scene: PackedScene = preload("res://src/nodes/sound/sound_inspector.tscn")
	var inst: SoundInspector = scene.instantiate()
	inst.bind(self)
	return inst
