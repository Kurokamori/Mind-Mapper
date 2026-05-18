class_name WysiwygRichEditor
extends Control

signal text_changed()
signal selection_changed()

const DEFAULT_FONT_SIZE: int = 16
const CARET_BLINK_INTERVAL: float = 0.55
const CODE_BG_COLOR: Color = Color(1, 1, 1, 0.08)
const LINK_DEFAULT_COLOR: Color = Color(0.55, 0.78, 1.0)
const SELECTION_COLOR: Color = Color(0.32, 0.55, 0.95, 0.45)
const UNDO_LIMIT: int = 80
const ITALIC_SHEAR: float = 0.18
const SCROLL_STEP: float = 32.0

var default_font_size: int = DEFAULT_FONT_SIZE:
	set(value):
		default_font_size = max(6, value)
		_invalidate_layout()
		queue_redraw()

var default_text_color: Color = Color(0.95, 0.96, 0.98):
	set(value):
		default_text_color = value
		queue_redraw()

var default_background: Color = Color(0, 0, 0, 0):
	set(value):
		default_background = value
		queue_redraw()

var _runs: Array = []
var _caret: int = 0
var _anchor: int = -1
var _pending_attrs: Dictionary = {}
var _has_pending_attrs: bool = false

var _glyphs: Array = []
var _lines: Array = []
var _layout_dirty: bool = true
var _last_layout_width: float = -1.0
var _content_size: Vector2 = Vector2.ZERO
var _scroll_y: float = 0.0

var _caret_visible_phase: bool = true
var _blink_accum: float = 0.0

var _dragging: bool = false
var _undo_stack: Array = []
var _redo_stack: Array = []
var _suppress_undo: bool = false

var _font_regular: Font
var _font_bold: Font
var _font_italic: Font
var _font_bold_italic: Font
var _font_mono: Font
var _italic_is_synthetic: bool = false
var _bold_italic_is_synthetic: bool = false

var max_image_width: int = 0
var _texture_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	if _runs.is_empty():
		_runs = [WysiwygCodec.make_run("", WysiwygCodec.empty_attrs())]
	_setup_fonts()
	set_process(true)
	resized.connect(_on_resized)
	focus_entered.connect(func() -> void: _caret_visible_phase = true; _blink_accum = 0.0; queue_redraw())
	focus_exited.connect(func() -> void: queue_redraw())
	ThemeManager.theme_applied.connect(_on_theme_or_fonts_changed)
	ThemeManager.font_manifest_changed.connect(_on_theme_or_fonts_changed)


func _on_theme_or_fonts_changed() -> void:
	_setup_fonts()
	_invalidate_layout()
	queue_redraw()


func _setup_fonts() -> void:
	var regular: Font = ThemeManager.active_font_for_variant(FontPreset.VARIANT_REGULAR)
	var bold: Font = ThemeManager.active_font_for_variant(FontPreset.VARIANT_BOLD)
	var italic: Font = ThemeManager.active_font_for_variant(FontPreset.VARIANT_ITALIC)
	var bold_italic: Font = ThemeManager.active_font_for_variant(FontPreset.VARIANT_BOLD_ITALIC)
	var mono: Font = ThemeManager.active_font_for_variant(FontPreset.VARIANT_MONO)
	if regular == null:
		regular = get_theme_default_font()
	if regular == null:
		regular = ThemeDB.fallback_font
	_font_regular = regular
	if bold == null:
		var synth_bold: FontVariation = FontVariation.new()
		synth_bold.base_font = regular
		synth_bold.variation_embolden = 0.75
		_font_bold = synth_bold
	else:
		_font_bold = bold
	if italic == null:
		_font_italic = regular
		_italic_is_synthetic = true
	else:
		_font_italic = italic
		_italic_is_synthetic = false
	if bold_italic == null:
		_font_bold_italic = _font_bold
		_bold_italic_is_synthetic = true
	else:
		_font_bold_italic = bold_italic
		_bold_italic_is_synthetic = false
	if mono == null:
		_font_mono = regular
	else:
		_font_mono = mono


func _process(delta: float) -> void:
	if not has_focus():
		return
	_blink_accum += delta
	if _blink_accum >= CARET_BLINK_INTERVAL:
		_blink_accum = 0.0
		_caret_visible_phase = not _caret_visible_phase
		queue_redraw()


func _on_resized() -> void:
	if absf(size.x - _last_layout_width) > 0.5:
		_invalidate_layout()
		queue_redraw()


func set_bbcode(source: String) -> void:
	_runs = WysiwygCodec.parse(source)
	if _runs.is_empty():
		_runs = [WysiwygCodec.make_run("", WysiwygCodec.empty_attrs())]
	_caret = 0
	_anchor = -1
	_clear_pending_attrs()
	_undo_stack.clear()
	_redo_stack.clear()
	_invalidate_layout()
	queue_redraw()


func get_bbcode() -> String:
	return WysiwygCodec.serialize(_runs)


func plain_text_value() -> String:
	return WysiwygCodec.plain_text(_runs)


func has_selection() -> bool:
	return _anchor >= 0 and _anchor != _caret


func selection_range() -> Vector2i:
	if not has_selection():
		return Vector2i(_caret, _caret)
	return Vector2i(min(_caret, _anchor), max(_caret, _anchor))


func get_selected_text() -> String:
	var sr: Vector2i = selection_range()
	if sr.x == sr.y:
		return ""
	return WysiwygCodec.plain_text(_runs).substr(sr.x, sr.y - sr.x)


func apply_attribute_to_selection(key: String, value: Variant) -> void:
	if has_selection():
		var sr: Vector2i = selection_range()
		_push_undo()
		_apply_attr_range(sr.x, sr.y, key, value)
		_invalidate_layout()
		emit_signal("text_changed")
		queue_redraw()
		return
	if not _has_pending_attrs:
		_pending_attrs = _attrs_at_caret().duplicate()
		_has_pending_attrs = true
	_pending_attrs[key] = value
	queue_redraw()


func toggle_attribute_in_selection(key: String) -> void:
	if has_selection():
		var sr: Vector2i = selection_range()
		var any_off: bool = _any_attr_off_in_range(sr.x, sr.y, key)
		apply_attribute_to_selection(key, any_off)
		return
	var current: Dictionary = _effective_attrs_for_input()
	apply_attribute_to_selection(key, not bool(current.get(key, false)))


func clear_formatting_in_selection() -> void:
	if not has_selection():
		_clear_pending_attrs()
		return
	var sr: Vector2i = selection_range()
	_push_undo()
	_split_at(sr.x)
	_split_at(sr.y)
	var acc: int = 0
	for i in range(_runs.size()):
		var t: String = String(_runs[i]["text"])
		var run_s: int = acc
		var run_e: int = acc + t.length()
		if run_s >= sr.x and run_e <= sr.y and t != "":
			var preserved: Dictionary = WysiwygCodec.empty_attrs()
			preserved["text"] = t
			_runs[i] = preserved
		acc = run_e
	_runs = WysiwygCodec.merge_runs(_runs)
	_invalidate_layout()
	emit_signal("text_changed")
	queue_redraw()


func insert_link(url: String, label: String) -> void:
	if url == "":
		return
	var text_to_insert: String = label if label != "" else url
	_push_undo()
	if has_selection():
		var sr: Vector2i = selection_range()
		_delete_range(sr.x, sr.y)
		_caret = sr.x
		_anchor = -1
	var attrs: Dictionary = _effective_attrs_for_input().duplicate()
	attrs["link"] = url
	_insert_at(_caret, text_to_insert, attrs)
	_caret += text_to_insert.length()
	_anchor = -1
	_clear_pending_attrs()
	_invalidate_layout()
	emit_signal("text_changed")
	queue_redraw()


func insert_text(text: String) -> void:
	_insert_text_at_caret(text)


func insert_image(path: String, width: int = 0, height: int = 0) -> void:
	if path == "":
		return
	_push_undo()
	if has_selection():
		_delete_selection_internal()
	var attrs: Dictionary = WysiwygCodec.empty_attrs()
	attrs["image"] = path
	attrs["img_w"] = max(0, width)
	attrs["img_h"] = max(0, height)
	_insert_at(_caret, WysiwygCodec.IMAGE_PLACEHOLDER, attrs)
	_caret += WysiwygCodec.IMAGE_PLACEHOLDER.length()
	_anchor = -1
	_clear_pending_attrs()
	_caret_visible_phase = true
	_blink_accum = 0.0
	_invalidate_layout()
	emit_signal("text_changed")
	queue_redraw()


func select_all() -> void:
	_anchor = 0
	_caret = WysiwygCodec.total_length(_runs)
	emit_signal("selection_changed")
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke: InputEventKey = event
		if ke.pressed:
			_handle_key(ke)
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				grab_focus()
				var local: Vector2 = mb.position + Vector2(0.0, _scroll_y)
				var pos: int = _pos_from_local(local)
				if mb.shift_pressed:
					if _anchor < 0:
						_anchor = _caret
					_caret = pos
				else:
					_caret = pos
					_anchor = -1
				_dragging = true
				_caret_visible_phase = true
				_blink_accum = 0.0
				emit_signal("selection_changed")
				queue_redraw()
				accept_event()
			else:
				_dragging = false
				accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_scroll_by(-SCROLL_STEP)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_scroll_by(SCROLL_STEP)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		var local2: Vector2 = mm.position + Vector2(0.0, _scroll_y)
		var pos2: int = _pos_from_local(local2)
		if _anchor < 0:
			_anchor = _caret
		_caret = pos2
		emit_signal("selection_changed")
		queue_redraw()
		accept_event()


func _handle_key(event: InputEventKey) -> void:
	var key: int = event.keycode
	var ctrl: bool = event.ctrl_pressed
	var shift: bool = event.shift_pressed
	if ctrl and key == KEY_A:
		select_all()
		accept_event()
		return
	if ctrl and key == KEY_C:
		_clipboard_copy()
		accept_event()
		return
	if ctrl and key == KEY_X:
		_clipboard_cut()
		accept_event()
		return
	if ctrl and key == KEY_V:
		_clipboard_paste()
		accept_event()
		return
	if ctrl and key == KEY_Z and not shift:
		undo()
		accept_event()
		return
	if ctrl and (key == KEY_Y or (key == KEY_Z and shift)):
		redo()
		accept_event()
		return
	if key == KEY_LEFT:
		_move_caret(_caret - 1, shift)
		accept_event()
		return
	if key == KEY_RIGHT:
		_move_caret(_caret + 1, shift)
		accept_event()
		return
	if key == KEY_UP:
		_move_caret_vertical(-1, shift)
		accept_event()
		return
	if key == KEY_DOWN:
		_move_caret_vertical(1, shift)
		accept_event()
		return
	if key == KEY_HOME:
		_move_caret(_line_start_of(_caret), shift)
		accept_event()
		return
	if key == KEY_END:
		_move_caret(_line_end_of(_caret), shift)
		accept_event()
		return
	if key == KEY_BACKSPACE:
		_do_backspace()
		accept_event()
		return
	if key == KEY_DELETE:
		_do_delete()
		accept_event()
		return
	if key == KEY_ENTER or key == KEY_KP_ENTER:
		_insert_text_at_caret("\n")
		accept_event()
		return
	if key == KEY_TAB:
		_insert_text_at_caret("\t")
		accept_event()
		return
	var u: int = event.unicode
	if u >= 32 and not ctrl:
		_insert_text_at_caret(String.chr(u))
		accept_event()


func _clipboard_copy() -> void:
	var sel_text: String = get_selected_text()
	if sel_text == "":
		return
	DisplayServer.clipboard_set(sel_text)


func _clipboard_cut() -> void:
	if not has_selection():
		return
	DisplayServer.clipboard_set(get_selected_text())
	_push_undo()
	_delete_selection_internal()
	_invalidate_layout()
	emit_signal("text_changed")
	queue_redraw()


func _clipboard_paste() -> void:
	var text: String = DisplayServer.clipboard_get()
	if text == "":
		return
	_insert_text_at_caret(text)


func _insert_text_at_caret(text: String) -> void:
	if text == "":
		return
	_push_undo()
	if has_selection():
		_delete_selection_internal()
	var attrs: Dictionary = _effective_attrs_for_input()
	_insert_at(_caret, text, attrs)
	_caret += text.length()
	_anchor = -1
	_clear_pending_attrs()
	_caret_visible_phase = true
	_blink_accum = 0.0
	_invalidate_layout()
	emit_signal("text_changed")
	queue_redraw()


func _do_backspace() -> void:
	if has_selection():
		_push_undo()
		_delete_selection_internal()
	elif _caret > 0:
		_push_undo()
		_delete_range(_caret - 1, _caret)
		_caret -= 1
	else:
		return
	_anchor = -1
	_clear_pending_attrs()
	_invalidate_layout()
	emit_signal("text_changed")
	queue_redraw()


func _do_delete() -> void:
	if has_selection():
		_push_undo()
		_delete_selection_internal()
	else:
		var total: int = WysiwygCodec.total_length(_runs)
		if _caret >= total:
			return
		_push_undo()
		_delete_range(_caret, _caret + 1)
	_anchor = -1
	_clear_pending_attrs()
	_invalidate_layout()
	emit_signal("text_changed")
	queue_redraw()


func _delete_selection_internal() -> void:
	var sr: Vector2i = selection_range()
	_delete_range(sr.x, sr.y)
	_caret = sr.x
	_anchor = -1


func _move_caret(new_pos: int, extend: bool) -> void:
	var total: int = WysiwygCodec.total_length(_runs)
	var clamped: int = clamp(new_pos, 0, total)
	if extend:
		if _anchor < 0:
			_anchor = _caret
	else:
		_anchor = -1
	_caret = clamped
	_caret_visible_phase = true
	_blink_accum = 0.0
	emit_signal("selection_changed")
	_ensure_caret_visible()
	queue_redraw()


func _move_caret_vertical(dir: int, extend: bool) -> void:
	_ensure_layout()
	var cv: Dictionary = _caret_visual(_caret)
	var target_line: int = int(cv["line"]) + dir
	if target_line < 0 or target_line >= max(_lines.size(), 1):
		if dir < 0:
			_move_caret(0, extend)
		else:
			_move_caret(WysiwygCodec.total_length(_runs), extend)
		return
	var target_x: float = float(cv["x"])
	var best_pos: int = _caret
	var best_dist: float = INF
	var total: int = WysiwygCodec.total_length(_runs)
	for p in range(total + 1):
		var pv: Dictionary = _caret_visual(p)
		if int(pv["line"]) != target_line:
			continue
		var d: float = absf(float(pv["x"]) - target_x)
		if d < best_dist:
			best_dist = d
			best_pos = p
	_move_caret(best_pos, extend)


func _line_start_of(pos: int) -> int:
	_ensure_layout()
	var cv: Dictionary = _caret_visual(pos)
	var line: int = int(cv["line"])
	var total: int = WysiwygCodec.total_length(_runs)
	for p in range(total + 1):
		var pv: Dictionary = _caret_visual(p)
		if int(pv["line"]) == line:
			return p
	return pos


func _line_end_of(pos: int) -> int:
	_ensure_layout()
	var cv: Dictionary = _caret_visual(pos)
	var line: int = int(cv["line"])
	var total: int = WysiwygCodec.total_length(_runs)
	var result: int = pos
	for p in range(total + 1):
		var pv: Dictionary = _caret_visual(p)
		if int(pv["line"]) == line:
			result = p
	return result


func _attrs_at_caret() -> Dictionary:
	if _runs.is_empty():
		return WysiwygCodec.empty_attrs()
	if _caret <= 0:
		return WysiwygCodec.attrs_of(_runs[0])
	var loc: Vector2i = _run_at_pos(_caret - 1)
	return WysiwygCodec.attrs_of(_runs[loc.x])


func _effective_attrs_for_input() -> Dictionary:
	if _has_pending_attrs:
		return _pending_attrs.duplicate()
	return _attrs_at_caret()


func _clear_pending_attrs() -> void:
	_pending_attrs.clear()
	_has_pending_attrs = false


func _run_at_pos(pos: int) -> Vector2i:
	if _runs.is_empty():
		return Vector2i(0, 0)
	var acc: int = 0
	for i in range(_runs.size()):
		var t_len: int = String(_runs[i]["text"]).length()
		if pos < acc + t_len:
			return Vector2i(i, pos - acc)
		acc += t_len
	var last_i: int = _runs.size() - 1
	return Vector2i(last_i, String(_runs[last_i]["text"]).length())


func _insert_at(pos: int, text: String, attrs: Dictionary) -> void:
	if text == "":
		return
	if _runs.is_empty():
		_runs.append(WysiwygCodec.make_run(text, attrs))
		return
	var loc: Vector2i = _run_at_pos(pos)
	var r: Dictionary = _runs[loc.x]
	var t: String = String(r["text"])
	var before: String = t.substr(0, loc.y)
	var after: String = t.substr(loc.y)
	var run_attrs: Dictionary = WysiwygCodec.attrs_of(r)
	if WysiwygCodec.attrs_equal(run_attrs, attrs):
		r["text"] = before + text + after
		_runs[loc.x] = r
		return
	var pieces: Array = []
	if before != "":
		var rb: Dictionary = r.duplicate()
		rb["text"] = before
		pieces.append(rb)
	pieces.append(WysiwygCodec.make_run(text, attrs))
	if after != "":
		var ra: Dictionary = r.duplicate()
		ra["text"] = after
		pieces.append(ra)
	var head: Array = _runs.slice(0, loc.x)
	var tail: Array = _runs.slice(loc.x + 1)
	_runs = head + pieces + tail
	_runs = WysiwygCodec.merge_runs(_runs)


func _delete_range(start_pos: int, end_pos: int) -> void:
	if start_pos >= end_pos:
		return
	var first: Vector2i = _run_at_pos(start_pos)
	var last: Vector2i = _run_at_pos(end_pos)
	if first.x == last.x:
		var r: Dictionary = _runs[first.x]
		var t: String = String(r["text"])
		r["text"] = t.substr(0, first.y) + t.substr(last.y)
		_runs[first.x] = r
	else:
		var rf: Dictionary = _runs[first.x].duplicate()
		var rl: Dictionary = _runs[last.x].duplicate()
		var tf: String = String(rf["text"])
		var tl: String = String(rl["text"])
		rf["text"] = tf.substr(0, first.y)
		rl["text"] = tl.substr(last.y)
		var head: Array = _runs.slice(0, first.x)
		var tail: Array = _runs.slice(last.x + 1)
		_runs = head + [rf, rl] + tail
	_runs = WysiwygCodec.merge_runs(_runs)
	if _runs.is_empty():
		_runs = [WysiwygCodec.make_run("", WysiwygCodec.empty_attrs())]


func _split_at(pos: int) -> void:
	var total: int = WysiwygCodec.total_length(_runs)
	if pos <= 0 or pos >= total:
		return
	var loc: Vector2i = _run_at_pos(pos)
	if loc.y == 0:
		return
	var r: Dictionary = _runs[loc.x]
	var t: String = String(r["text"])
	if loc.y >= t.length():
		return
	var before: Dictionary = r.duplicate()
	before["text"] = t.substr(0, loc.y)
	var after: Dictionary = r.duplicate()
	after["text"] = t.substr(loc.y)
	var head: Array = _runs.slice(0, loc.x)
	var tail: Array = _runs.slice(loc.x + 1)
	_runs = head + [before, after] + tail


func _apply_attr_range(start_pos: int, end_pos: int, key: String, value: Variant) -> void:
	if start_pos >= end_pos:
		return
	_split_at(start_pos)
	_split_at(end_pos)
	var acc: int = 0
	for i in range(_runs.size()):
		var t: String = String(_runs[i]["text"])
		var run_s: int = acc
		var run_e: int = acc + t.length()
		if run_s >= start_pos and run_e <= end_pos and t != "":
			_runs[i][key] = value
		acc = run_e
	_runs = WysiwygCodec.merge_runs(_runs)


func _any_attr_off_in_range(start_pos: int, end_pos: int, key: String) -> bool:
	var acc: int = 0
	for i in range(_runs.size()):
		var t: String = String(_runs[i]["text"])
		var run_s: int = acc
		var run_e: int = acc + t.length()
		var overlap_s: int = max(run_s, start_pos)
		var overlap_e: int = min(run_e, end_pos)
		if overlap_e > overlap_s and t != "":
			if not bool(_runs[i].get(key, false)):
				return true
		acc = run_e
	return false


func _push_undo() -> void:
	if _suppress_undo:
		return
	_undo_stack.append({"runs": _deep_copy_runs(_runs), "caret": _caret, "anchor": _anchor})
	if _undo_stack.size() > UNDO_LIMIT:
		_undo_stack.pop_front()
	_redo_stack.clear()


func _deep_copy_runs(runs: Array) -> Array:
	var copy: Array = []
	for r: Dictionary in runs:
		copy.append(r.duplicate())
	return copy


func undo() -> void:
	if _undo_stack.is_empty():
		return
	var snap: Dictionary = _undo_stack.pop_back()
	_redo_stack.append({"runs": _deep_copy_runs(_runs), "caret": _caret, "anchor": _anchor})
	_runs = snap["runs"]
	_caret = int(snap["caret"])
	_anchor = int(snap["anchor"])
	_clear_pending_attrs()
	_invalidate_layout()
	emit_signal("text_changed")
	queue_redraw()


func redo() -> void:
	if _redo_stack.is_empty():
		return
	var snap: Dictionary = _redo_stack.pop_back()
	_undo_stack.append({"runs": _deep_copy_runs(_runs), "caret": _caret, "anchor": _anchor})
	_runs = snap["runs"]
	_caret = int(snap["caret"])
	_anchor = int(snap["anchor"])
	_clear_pending_attrs()
	_invalidate_layout()
	emit_signal("text_changed")
	queue_redraw()


func _font_for(run: Dictionary) -> Font:
	if bool(run.get("code", false)):
		return _font_mono
	var b: bool = bool(run.get("bold", false))
	var i: bool = bool(run.get("italic", false))
	if b and i:
		return _font_bold_italic
	if b:
		return _font_bold
	if i:
		return _font_italic
	return _font_regular


func _size_for(run: Dictionary) -> int:
	var sz: int = int(run.get("size", 0))
	if sz <= 0:
		return default_font_size
	return sz


func _color_for(run: Dictionary) -> Color:
	var c: Variant = run.get("color", null)
	if c != null:
		return c as Color
	if String(run.get("link", "")) != "":
		return LINK_DEFAULT_COLOR
	return default_text_color


func _invalidate_layout() -> void:
	_layout_dirty = true


func _ensure_layout() -> void:
	if not _layout_dirty and absf(size.x - _last_layout_width) < 0.5:
		return
	_compute_layout()
	_last_layout_width = size.x
	_layout_dirty = false


func _compute_layout() -> void:
	_glyphs.clear()
	_lines.clear()
	var width: float = max(size.x, 32.0)
	var cur_x: float = 0.0
	var cur_line: int = 0
	var line_first_glyph: int = 0
	var line_ascent: float = _ascent_default()
	var line_descent: float = _descent_default()
	var last_space_glyph: int = -1
	var plain_pos: int = 0
	for run_idx in range(_runs.size()):
		var r: Dictionary = _runs[run_idx]
		var t: String = String(r["text"])
		if t == "":
			continue
		var font: Font = _font_for(r)
		var fsize: int = _size_for(r)
		var ascent: float = font.get_ascent(fsize)
		var descent: float = font.get_descent(fsize)
		var image_path: String = String(r.get("image", ""))
		var image_size: Vector2 = Vector2.ZERO
		if image_path != "":
			image_size = _image_render_size(image_path, int(r.get("img_w", 0)), int(r.get("img_h", 0)), width)
			ascent = image_size.y
			descent = 0.0
		for ci in range(t.length()):
			var ch: String = t[ci]
			var code: int = ch.unicode_at(0)
			if ch == "\n":
				_glyphs.append({
					"char": ch, "run_idx": run_idx, "plain_pos": plain_pos,
					"line": cur_line, "x": cur_x, "w": 0.0,
					"ascent": ascent, "descent": descent,
					"font": font, "size": fsize, "is_newline": true,
				})
				line_ascent = maxf(line_ascent, ascent)
				line_descent = maxf(line_descent, descent)
				_finalize_line(line_ascent, line_descent)
				cur_line += 1
				cur_x = 0.0
				line_ascent = _ascent_default()
				line_descent = _descent_default()
				last_space_glyph = -1
				line_first_glyph = _glyphs.size()
				plain_pos += 1
				continue
			var adv: float = image_size.x if image_path != "" else font.get_char_size(code, fsize).x
			if cur_x + adv > width and _glyphs.size() > line_first_glyph:
				if last_space_glyph >= line_first_glyph:
					_wrap_at_space(last_space_glyph, cur_line)
					cur_line += 1
					line_first_glyph = last_space_glyph + 1
					var rebuilt: Dictionary = _rebuild_line_metrics(line_first_glyph)
					cur_x = float(rebuilt["x"])
					line_ascent = float(rebuilt["ascent"])
					line_descent = float(rebuilt["descent"])
					last_space_glyph = -1
				else:
					_finalize_line(line_ascent, line_descent)
					cur_line += 1
					cur_x = 0.0
					line_ascent = _ascent_default()
					line_descent = _descent_default()
					last_space_glyph = -1
					line_first_glyph = _glyphs.size()
			_glyphs.append({
				"char": ch, "run_idx": run_idx, "plain_pos": plain_pos,
				"line": cur_line, "x": cur_x, "w": adv,
				"ascent": ascent, "descent": descent,
				"font": font, "size": fsize, "is_newline": false,
			})
			cur_x += adv
			line_ascent = maxf(line_ascent, ascent)
			line_descent = maxf(line_descent, descent)
			if ch == " ":
				last_space_glyph = _glyphs.size() - 1
			plain_pos += 1
	_finalize_line(line_ascent, line_descent)
	_content_size = Vector2(size.x, _lines_total_height())


func _wrap_at_space(space_glyph: int, current_line: int) -> void:
	var prev_ascent: float = 0.0
	var prev_descent: float = 0.0
	for gi in range(space_glyph + 1):
		var g: Dictionary = _glyphs[gi]
		if int(g["line"]) == current_line:
			prev_ascent = maxf(prev_ascent, float(g["ascent"]))
			prev_descent = maxf(prev_descent, float(g["descent"]))
	if prev_ascent == 0.0:
		prev_ascent = _ascent_default()
	if prev_descent == 0.0:
		prev_descent = _descent_default()
	_finalize_line(prev_ascent, prev_descent)
	var new_x: float = 0.0
	for gi in range(space_glyph + 1, _glyphs.size()):
		var g2: Dictionary = _glyphs[gi]
		g2["line"] = current_line + 1
		g2["x"] = new_x
		new_x += float(g2["w"])
		_glyphs[gi] = g2


func _rebuild_line_metrics(first_glyph: int) -> Dictionary:
	var asc: float = _ascent_default()
	var desc: float = _descent_default()
	var x: float = 0.0
	for gi in range(first_glyph, _glyphs.size()):
		var g: Dictionary = _glyphs[gi]
		asc = maxf(asc, float(g["ascent"]))
		desc = maxf(desc, float(g["descent"]))
		x = float(g["x"]) + float(g["w"])
	return {"ascent": asc, "descent": desc, "x": x}


func _finalize_line(asc: float, desc: float) -> void:
	var prev_y: float = 0.0
	if _lines.size() > 0:
		var p: Dictionary = _lines[_lines.size() - 1]
		prev_y = float(p["y"]) + float(p["height"])
	_lines.append({"y": prev_y, "ascent": asc, "descent": desc, "height": asc + desc})


func _ascent_default() -> float:
	if _font_regular == null:
		return 12.0
	return _font_regular.get_ascent(default_font_size)


func _descent_default() -> float:
	if _font_regular == null:
		return 4.0
	return _font_regular.get_descent(default_font_size)


func _lines_total_height() -> float:
	if _lines.is_empty():
		return _ascent_default() + _descent_default()
	var last: Dictionary = _lines[_lines.size() - 1]
	return float(last["y"]) + float(last["height"])


func _caret_visual(pos: int) -> Dictionary:
	_ensure_layout()
	var total: int = WysiwygCodec.total_length(_runs)
	var clamped: int = clamp(pos, 0, total)
	if _glyphs.is_empty():
		return {"x": 0.0, "y": 0.0, "line": 0, "height": _ascent_default() + _descent_default(), "ascent": _ascent_default()}
	if clamped < _glyphs.size():
		var g: Dictionary = _glyphs[clamped]
		var li: Dictionary = _lines[int(g["line"])]
		return {"x": float(g["x"]), "y": float(li["y"]), "line": int(g["line"]), "height": float(li["height"]), "ascent": float(li["ascent"])}
	var g_last: Dictionary = _glyphs[_glyphs.size() - 1]
	var li_last: Dictionary = _lines[int(g_last["line"])]
	if bool(g_last.get("is_newline", false)):
		var lh: float = _ascent_default() + _descent_default()
		return {"x": 0.0, "y": float(li_last["y"]) + float(li_last["height"]), "line": int(g_last["line"]) + 1, "height": lh, "ascent": _ascent_default()}
	return {"x": float(g_last["x"]) + float(g_last["w"]), "y": float(li_last["y"]), "line": int(g_last["line"]), "height": float(li_last["height"]), "ascent": float(li_last["ascent"])}


func _pos_from_local(local: Vector2) -> int:
	_ensure_layout()
	if _glyphs.is_empty():
		return 0
	var target_line: int = -1
	for i in range(_lines.size()):
		var ln: Dictionary = _lines[i]
		if local.y < float(ln["y"]) + float(ln["height"]):
			target_line = i
			break
	if target_line < 0:
		target_line = _lines.size() - 1
	var best_pos: int = 0
	var best_dist: float = INF
	var total: int = WysiwygCodec.total_length(_runs)
	for p in range(total + 1):
		var pv: Dictionary = _caret_visual(p)
		if int(pv["line"]) != target_line:
			continue
		var d: float = absf(float(pv["x"]) - local.x)
		if d < best_dist:
			best_dist = d
			best_pos = p
	return best_pos


func _ensure_caret_visible() -> void:
	_ensure_layout()
	var cv: Dictionary = _caret_visual(_caret)
	var caret_top: float = float(cv["y"])
	var caret_bottom: float = caret_top + float(cv["height"])
	if caret_top < _scroll_y:
		_scroll_y = caret_top
	elif caret_bottom > _scroll_y + size.y:
		_scroll_y = caret_bottom - size.y
	_clamp_scroll()


func _scroll_by(delta: float) -> void:
	_scroll_y += delta
	_clamp_scroll()
	queue_redraw()


func _clamp_scroll() -> void:
	var max_scroll: float = max(0.0, _content_size.y - size.y)
	_scroll_y = clamp(_scroll_y, 0.0, max_scroll)


func _draw() -> void:
	_ensure_layout()
	_clamp_scroll()
	if default_background.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), default_background, true)
	var sel: Vector2i = selection_range()
	if sel.x != sel.y:
		_draw_selection(sel.x, sel.y)
	for gi in range(_glyphs.size()):
		var g: Dictionary = _glyphs[gi]
		if bool(g.get("is_newline", false)):
			continue
		var run: Dictionary = _runs[int(g["run_idx"])]
		var font: Font = g["font"] as Font
		var fsize: int = int(g["size"])
		var line: Dictionary = _lines[int(g["line"])]
		var baseline_y: float = float(line["y"]) + float(line["ascent"]) - _scroll_y
		var px: float = float(g["x"])
		var pw: float = float(g["w"])
		var image_path: String = String(run.get("image", ""))
		if image_path != "":
			var image_h: float = float(g["ascent"])
			var image_top: float = baseline_y - image_h
			var draw_rect_image: Rect2 = Rect2(Vector2(px, image_top), Vector2(pw, image_h))
			var texture: Texture2D = _resolve_texture(image_path)
			if texture != null:
				draw_texture_rect(texture, draw_rect_image, false)
			else:
				draw_rect(draw_rect_image, Color(0.4, 0.2, 0.2, 0.4), true)
				draw_rect(draw_rect_image, Color(0.8, 0.4, 0.4, 0.9), false, 1.0)
				if _font_regular != null:
					var label_text: String = "(image)"
					_font_regular.draw_string(get_canvas_item(), Vector2(px + 4.0, baseline_y), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, default_font_size, Color(0.95, 0.7, 0.7))
			continue
		if bool(run.get("code", false)):
			var bg_rect: Rect2 = Rect2(Vector2(px, float(line["y"]) - _scroll_y), Vector2(pw, float(line["height"])))
			draw_rect(bg_rect, CODE_BG_COLOR, true)
		var color: Color = _color_for(run)
		var code_point: int = String(g["char"]).unicode_at(0)
		var needs_synthetic_italic: bool = bool(run.get("italic", false)) and (
			(not bool(run.get("bold", false)) and _italic_is_synthetic)
			or (bool(run.get("bold", false)) and _bold_italic_is_synthetic)
		)
		if needs_synthetic_italic:
			var shear_xform: Transform2D = Transform2D(Vector2(1.0, 0.0), Vector2(-ITALIC_SHEAR, 1.0), Vector2(px, baseline_y))
			draw_set_transform_matrix(shear_xform)
			font.draw_char(get_canvas_item(), Vector2.ZERO, code_point, fsize, color)
			draw_set_transform_matrix(Transform2D.IDENTITY)
		else:
			font.draw_char(get_canvas_item(), Vector2(px, baseline_y), code_point, fsize, color)
		if bool(run.get("underline", false)) or String(run.get("link", "")) != "":
			var uy: float = baseline_y + float(g["descent"]) * 0.4
			draw_line(Vector2(px, uy), Vector2(px + pw, uy), color, 1.0)
		if bool(run.get("strike", false)):
			var sy: float = baseline_y - float(g["ascent"]) * 0.35
			draw_line(Vector2(px, sy), Vector2(px + pw, sy), color, 1.0)
	if has_focus() and _caret_visible_phase:
		var cv: Dictionary = _caret_visual(_caret)
		var cx: float = float(cv["x"])
		var cy: float = float(cv["y"]) - _scroll_y
		var ch: float = float(cv["height"])
		draw_line(Vector2(cx, cy), Vector2(cx, cy + ch), default_text_color, 1.5)


func _draw_selection(start_pos: int, end_pos: int) -> void:
	var sv: Dictionary = _caret_visual(start_pos)
	var ev: Dictionary = _caret_visual(end_pos)
	var sl: int = int(sv["line"])
	var el: int = int(ev["line"])
	for li in range(sl, el + 1):
		if li >= _lines.size():
			break
		var ln: Dictionary = _lines[li]
		var x0: float = 0.0
		var x1: float = size.x
		if li == sl:
			x0 = float(sv["x"])
		if li == el:
			x1 = float(ev["x"])
		if li > sl and li < el:
			x1 = _line_extent(li)
		if li == sl and li != el:
			x1 = max(_line_extent(li), x0 + 4.0)
		var rect: Rect2 = Rect2(Vector2(x0, float(ln["y"]) - _scroll_y), Vector2(max(2.0, x1 - x0), float(ln["height"])))
		draw_rect(rect, SELECTION_COLOR, true)


func _line_extent(line_idx: int) -> float:
	var max_x: float = 0.0
	for g: Dictionary in _glyphs:
		if int(g["line"]) == line_idx:
			max_x = maxf(max_x, float(g["x"]) + float(g["w"]))
	return max_x


func _get_minimum_size() -> Vector2:
	return Vector2(80.0, _ascent_default() + _descent_default() + 8.0)


func _resolve_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var texture: Texture2D = MarkdownImageRenderer.resolve_texture(path, "")
	_texture_cache[path] = texture
	return texture


func _image_render_size(path: String, requested_w: int, requested_h: int, available_width: float) -> Vector2:
	var texture: Texture2D = _resolve_texture(path)
	var native_w: float = 0.0
	var native_h: float = 0.0
	if texture != null:
		var ns: Vector2i = texture.get_size()
		native_w = float(ns.x)
		native_h = float(ns.y)
	var w: float = float(requested_w)
	var h: float = float(requested_h)
	if w <= 0.0 and h <= 0.0:
		w = native_w
		h = native_h
	elif w > 0.0 and h <= 0.0:
		if native_w > 0.0:
			h = w * (native_h / native_w)
	elif h > 0.0 and w <= 0.0:
		if native_h > 0.0:
			w = h * (native_w / native_h)
	if w <= 0.0 or h <= 0.0:
		var fallback: float = max(64.0, float(default_font_size) * 3.0)
		w = fallback
		h = fallback
	var aspect_h_over_w: float = h / w if w > 0.0 else 1.0
	var max_w: float = available_width
	if max_image_width > 0:
		max_w = min(max_w, float(max_image_width))
	if w > max_w:
		w = max_w
		h = w * aspect_h_over_w
	return Vector2(w, h)
