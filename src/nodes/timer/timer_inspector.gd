class_name TimerInspector
extends VBoxContainer

const MODE_DURATION_INDEX: int = 0
const MODE_TARGET_INDEX: int = 1
const QUICK_HOUR_SECONDS: int = 3600
const QUICK_DAY_SECONDS: int = 86400
const QUICK_WEEK_SECONDS: int = 604800

@onready var _label_edit: LineEdit = %LabelEdit
@onready var _mode_select: OptionButton = %ModeSelect
@onready var _duration_panel: Control = %DurationPanel
@onready var _target_panel: Control = %TargetPanel
@onready var _years_spin: SpinBox = %YearsSpin
@onready var _weeks_spin: SpinBox = %WeeksSpin
@onready var _days_spin: SpinBox = %DaysSpin
@onready var _hours_spin: SpinBox = %HoursSpin
@onready var _minutes_spin: SpinBox = %MinutesSpin
@onready var _seconds_spin: SpinBox = %SecondsSpin
@onready var _target_year_spin: SpinBox = %TargetYearSpin
@onready var _target_month_spin: SpinBox = %TargetMonthSpin
@onready var _target_day_spin: SpinBox = %TargetDaySpin
@onready var _target_hour_spin: SpinBox = %TargetHourSpin
@onready var _target_minute_spin: SpinBox = %TargetMinuteSpin
@onready var _target_second_spin: SpinBox = %TargetSecondSpin
@onready var _now_button: Button = %NowButton
@onready var _plus_hour_button: Button = %PlusHourButton
@onready var _plus_day_button: Button = %PlusDayButton
@onready var _plus_week_button: Button = %PlusWeekButton
@onready var _target_preview: Label = %TargetPreview

var _item: TimerNode
var _editor: Node
var _binders: Dictionary = {}
var _suppress_signals: bool = false


func bind(item: TimerNode) -> void:
	_item = item
	_editor = _find_editor()


func _ready() -> void:
	ThemeManager.apply_relative_font_sizes(self, {
		"Header": 1.15,
		"DurationPanel/DurationRow1/YearsVBox/YearsLabel": 0.80,
		"DurationPanel/DurationRow1/WeeksVBox/WeeksLabel": 0.80,
		"DurationPanel/DurationRow1/DaysVBox/DaysLabel": 0.80,
		"DurationPanel/DurationRow2/HoursVBox/HoursLabel": 0.80,
		"DurationPanel/DurationRow2/MinutesVBox/MinutesLabel": 0.80,
		"DurationPanel/DurationRow2/SecondsVBox/SecondsLabel": 0.80,
		"TargetPanel/TargetDateRow/TargetYearVBox/TargetYearLabel": 0.80,
		"TargetPanel/TargetDateRow/TargetMonthVBox/TargetMonthLabel": 0.80,
		"TargetPanel/TargetDateRow/TargetDayVBox/TargetDayLabel": 0.80,
		"TargetPanel/TargetTimeRow/TargetHourVBox/TargetHourLabel": 0.80,
		"TargetPanel/TargetTimeRow/TargetMinuteVBox/TargetMinuteLabel": 0.80,
		"TargetPanel/TargetTimeRow/TargetSecondVBox/TargetSecondLabel": 0.80,
		"TargetPanel/TargetPreview": 0.80,
	})
	if _item == null:
		return
	_setup_mode_options()
	_suppress_signals = true
	_label_edit.text = _item.label_text
	_populate_duration_spinboxes(_item.initial_duration_sec)
	_populate_target_spinboxes(_resolve_initial_target_unix())
	_select_mode_in_ui(_item.mode)
	_suppress_signals = false
	_binders["label_text"] = PropertyBinder.new(_editor, _item, "label_text", _item.label_text)
	_binders["initial_duration_sec"] = PropertyBinder.new(_editor, _item, "initial_duration_sec", _item.initial_duration_sec)
	_binders["mode"] = PropertyBinder.new(_editor, _item, "mode", _item.mode)
	_binders["target_unix"] = PropertyBinder.new(_editor, _item, "target_unix", _item.target_unix)
	_label_edit.text_changed.connect(func(t: String) -> void: _binders["label_text"].live(t))
	_label_edit.focus_exited.connect(func() -> void: _binders["label_text"].commit(_label_edit.text))
	_label_edit.text_submitted.connect(func(t: String) -> void: _binders["label_text"].commit(t))
	for spin: SpinBox in [_years_spin, _weeks_spin, _days_spin, _hours_spin, _minutes_spin, _seconds_spin]:
		spin.value_changed.connect(_on_duration_part_changed)
	for spin: SpinBox in [_target_year_spin, _target_month_spin, _target_day_spin, _target_hour_spin, _target_minute_spin, _target_second_spin]:
		spin.value_changed.connect(_on_target_part_changed)
	_mode_select.item_selected.connect(_on_mode_changed)
	_now_button.pressed.connect(_on_now_pressed)
	_plus_hour_button.pressed.connect(func() -> void: _shift_target_seconds(QUICK_HOUR_SECONDS))
	_plus_day_button.pressed.connect(func() -> void: _shift_target_seconds(QUICK_DAY_SECONDS))
	_plus_week_button.pressed.connect(func() -> void: _shift_target_seconds(QUICK_WEEK_SECONDS))
	_refresh_panel_visibility(_item.mode)
	_refresh_target_preview()


func _setup_mode_options() -> void:
	_mode_select.clear()
	_mode_select.add_item("Duration", MODE_DURATION_INDEX)
	_mode_select.add_item("Target Date", MODE_TARGET_INDEX)


func _select_mode_in_ui(mode: String) -> void:
	if mode == TimerNode.MODE_TARGET:
		_mode_select.select(MODE_TARGET_INDEX)
	else:
		_mode_select.select(MODE_DURATION_INDEX)


func _resolve_initial_target_unix() -> int:
	if _item.target_unix > 0:
		return _item.target_unix
	return int(Time.get_unix_time_from_system()) + int(max(60.0, _item.initial_duration_sec))


func _populate_duration_spinboxes(total_seconds: float) -> void:
	var safe_total: int = int(max(0.0, total_seconds))
	@warning_ignore("integer_division")
	var years: int = safe_total / TimerRegistry.SECONDS_PER_YEAR
	var rem: int = safe_total % TimerRegistry.SECONDS_PER_YEAR
	@warning_ignore("integer_division")
	var weeks: int = rem / TimerRegistry.SECONDS_PER_WEEK
	rem = rem % TimerRegistry.SECONDS_PER_WEEK
	@warning_ignore("integer_division")
	var days: int = rem / TimerRegistry.SECONDS_PER_DAY
	rem = rem % TimerRegistry.SECONDS_PER_DAY
	@warning_ignore("integer_division")
	var hours: int = rem / TimerRegistry.SECONDS_PER_HOUR
	rem = rem % TimerRegistry.SECONDS_PER_HOUR
	@warning_ignore("integer_division")
	var minutes: int = rem / TimerRegistry.SECONDS_PER_MINUTE
	var secs: int = rem % TimerRegistry.SECONDS_PER_MINUTE
	_years_spin.value = float(years)
	_weeks_spin.value = float(weeks)
	_days_spin.value = float(days)
	_hours_spin.value = float(hours)
	_minutes_spin.value = float(minutes)
	_seconds_spin.value = float(secs)


func _populate_target_spinboxes(unix: int) -> void:
	var safe_unix: int = unix if unix > 0 else int(Time.get_unix_time_from_system())
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(safe_unix)
	_target_year_spin.value = float(int(dt.get("year", 2026)))
	_target_month_spin.value = float(int(dt.get("month", 1)))
	_target_day_spin.value = float(int(dt.get("day", 1)))
	_target_hour_spin.value = float(int(dt.get("hour", 0)))
	_target_minute_spin.value = float(int(dt.get("minute", 0)))
	_target_second_spin.value = float(int(dt.get("second", 0)))


func _find_editor() -> Node:
	return EditorLocator.find_for(_item)


func _current_total_seconds() -> float:
	var y: float = _years_spin.value * float(TimerRegistry.SECONDS_PER_YEAR)
	var w: float = _weeks_spin.value * float(TimerRegistry.SECONDS_PER_WEEK)
	var d: float = _days_spin.value * float(TimerRegistry.SECONDS_PER_DAY)
	var h: float = _hours_spin.value * float(TimerRegistry.SECONDS_PER_HOUR)
	var m: float = _minutes_spin.value * float(TimerRegistry.SECONDS_PER_MINUTE)
	var s: float = _seconds_spin.value
	return y + w + d + h + m + s


func _current_target_unix() -> int:
	var dt: Dictionary = {
		"year": int(_target_year_spin.value),
		"month": int(_target_month_spin.value),
		"day": int(_target_day_spin.value),
		"hour": int(_target_hour_spin.value),
		"minute": int(_target_minute_spin.value),
		"second": int(_target_second_spin.value),
	}
	return int(Time.get_unix_time_from_datetime_dict(dt))


func _on_duration_part_changed(_v: float) -> void:
	if _suppress_signals:
		return
	var total: float = _current_total_seconds()
	_binders["initial_duration_sec"].live(total)
	_binders["initial_duration_sec"].commit(total)


func _on_target_part_changed(_v: float) -> void:
	if _suppress_signals:
		return
	var unix: int = _current_target_unix()
	_binders["target_unix"].live(unix)
	_binders["target_unix"].commit(unix)
	_refresh_target_preview()


func _on_mode_changed(idx: int) -> void:
	if _suppress_signals:
		return
	var new_mode: String = TimerNode.MODE_TARGET if idx == MODE_TARGET_INDEX else TimerNode.MODE_DURATION
	if new_mode == TimerNode.MODE_TARGET:
		var current_target: int = _current_target_unix()
		var now: int = int(Time.get_unix_time_from_system())
		if current_target <= now:
			var fallback_offset: int = int(max(60.0, _item.initial_duration_sec))
			current_target = now + fallback_offset
			_suppress_signals = true
			_populate_target_spinboxes(current_target)
			_suppress_signals = false
		if current_target != _item.target_unix:
			_binders["target_unix"].live(current_target)
			_binders["target_unix"].commit(current_target)
	_binders["mode"].live(new_mode)
	_binders["mode"].commit(new_mode)
	_refresh_panel_visibility(new_mode)
	_refresh_target_preview()


func _refresh_panel_visibility(mode: String) -> void:
	var is_target: bool = mode == TimerNode.MODE_TARGET
	_duration_panel.visible = not is_target
	_target_panel.visible = is_target


func _on_now_pressed() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	_suppress_signals = true
	_populate_target_spinboxes(now)
	_suppress_signals = false
	_binders["target_unix"].live(now)
	_binders["target_unix"].commit(now)
	_refresh_target_preview()


func _shift_target_seconds(delta: int) -> void:
	var unix: int = _current_target_unix()
	if unix <= 0:
		unix = int(Time.get_unix_time_from_system())
	unix += delta
	_suppress_signals = true
	_populate_target_spinboxes(unix)
	_suppress_signals = false
	_binders["target_unix"].live(unix)
	_binders["target_unix"].commit(unix)
	_refresh_target_preview()


func _refresh_target_preview() -> void:
	if _target_preview == null:
		return
	var unix: int = _current_target_unix()
	if unix <= 0:
		_target_preview.text = ""
		return
	var when: String = Time.get_datetime_string_from_unix_time(unix, true)
	var now: int = int(Time.get_unix_time_from_system())
	var delta: int = unix - now
	if delta <= 0:
		_target_preview.text = "%s (in the past)" % when
	else:
		_target_preview.text = "%s — in %s" % [when, TimerRegistry.format_duration(float(delta), false)]
