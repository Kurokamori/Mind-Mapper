class_name PopupSizer
extends Object

## Sizes a [Window] (dialog, popup) to its content, clamps it to the usable
## area of whatever screen it will appear on, then centers and shows it.
##
## Use [method popup_fit] in place of [code]Window.popup_centered()[/code] when a
## dialog's natural size should follow its contents but must never exceed the
## user's screen. Use [method fit] to re-apply the sizing to an already visible
## window after its content changed.
##
## Recognised [param opts] keys (all optional):
## [codeblock]
## min_size:      Vector2i  Lower bound for the final window size (px). 240x160.
## max_size:      Vector2i  Upper bound before the screen clamp (px). 0 = unbounded.
## screen_margin: Vector2i  Clear space kept on each screen edge (px). Default 80x80.
## padding:       Vector2i  Extra space added to the measured content (content
##                          units, i.e. scaled by `content_scale_factor`).
## preferred:     Vector2i  Lower bound per axis in content units (typically the
##                          size a scene was authored at). The window is never
##                          smaller than this, but still grows to fit content
##                          that needs more room. Scaled by `content_scale_factor`.
## ratio:         Vector2   Target size as a fraction of the usable screen span
##                          (already in px); a positive component overrides that
##                          axis. `ratio` is applied after `preferred`.
## [/codeblock]
##
## Sizing is computed in content units and multiplied by the window's
## [code]content_scale_factor[/code], so dialogs keep their authored proportions
## under DPI / UI-zoom scaling instead of opening too small.

const DEFAULT_MIN_SIZE: Vector2i = Vector2i(240, 160)
const DEFAULT_SCREEN_MARGIN: Vector2i = Vector2i(80, 80)
const ABSOLUTE_MIN_SCREEN_SPAN: int = 120


## Resizes [param window] to fit its content, clamps it to the target screen,
## centers it there and shows it via [code]Window.popup()[/code]. Safe to call
## without [code]await[/code]; the correction pass runs deferred on its own.
##
## On mobile runtimes the window is instead shown borderless and sized to the
## host viewport, so popups feel like full-screen panels rather than draggable
## floating windows.
static func popup_fit(window: Window, opts: Dictionary = {}) -> void:
	if window == null:
		return
	if Bootstrap._is_mobile_runtime():
		_popup_mobile_fullscreen(window)
		return
	var cfg: Dictionary = _resolve_config(window, opts)
	if not window.is_inside_tree():
		push_warning("PopupSizer.popup_fit: window is not inside the scene tree; showing without fit")
		window.popup()
		return
	_fit(window, cfg)
	window.popup()
	var tree: SceneTree = window.get_tree()
	if tree == null:
		return
	await tree.process_frame
	if is_instance_valid(window) and window.visible:
		_fit(window, cfg)


## Re-applies content-fit sizing and screen clamping to an already visible
## [param window] without re-showing it. Useful after the content changed or the
## window moved to a different screen.
static func fit(window: Window, opts: Dictionary = {}) -> void:
	if window == null or not window.is_inside_tree():
		return
	if Bootstrap._is_mobile_runtime():
		_fit_mobile_fullscreen(window)
		return
	_fit(window, _resolve_config(window, opts))


## Shows [param window] as a borderless full-viewport panel. Used on mobile so
## that dialogs occupy the same surface as a "screen" rather than appearing as
## a floating sub-window. The host viewport must have
## [code]gui_embed_subwindows = true[/code] (mobile already enables it).
static func _popup_mobile_fullscreen(window: Window) -> void:
	if window == null:
		return
	window.borderless = true
	window.unresizable = true
	window.transient = true
	window.always_on_top = false
	window.min_size = Vector2i.ZERO
	window.max_size = Vector2i.ZERO
	if not window.is_inside_tree():
		push_warning("PopupSizer._popup_mobile_fullscreen: window is not inside the scene tree; showing without fit")
		window.popup()
		return
	_fit_mobile_fullscreen(window)
	window.popup()
	var tree: SceneTree = window.get_tree()
	if tree == null:
		return
	await tree.process_frame
	if is_instance_valid(window) and window.visible:
		_fit_mobile_fullscreen(window)


static func _fit_mobile_fullscreen(window: Window) -> void:
	if not is_instance_valid(window) or not window.is_inside_tree():
		return
	var parent_window: Window = _resolve_parent_window(window)
	if parent_window == null:
		parent_window = window.get_tree().root
	if parent_window == null:
		return
	var vp_size: Vector2i = Vector2i(parent_window.get_visible_rect().size)
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = Vector2i(parent_window.size)
	if vp_size.x <= 0 or vp_size.y <= 0:
		return
	window.size = vp_size
	window.position = Vector2i.ZERO


static func _resolve_config(window: Window, opts: Dictionary) -> Dictionary:
	var min_size: Vector2i = opts.get("min_size", DEFAULT_MIN_SIZE)
	min_size = min_size.max(window.min_size)
	return {
		"min_size": min_size,
		"max_size": Vector2i(opts.get("max_size", Vector2i.ZERO)),
		"screen_margin": Vector2i(opts.get("screen_margin", DEFAULT_SCREEN_MARGIN)),
		"padding": Vector2i(opts.get("padding", Vector2i.ZERO)),
		"preferred": Vector2i(opts.get("preferred", Vector2i.ZERO)),
		"ratio": Vector2(opts.get("ratio", Vector2.ZERO)),
	}


static func _fit(window: Window, cfg: Dictionary) -> void:
	if not is_instance_valid(window) or not window.is_inside_tree():
		return

	var scale: float = maxf(window.content_scale_factor, 0.001)
	var content_size: Vector2 = _content_min_size(window) + Vector2(cfg["padding"])

	# `preferred` is a floor in content units: the window never opens smaller
	# than it, but content that needs more room still wins.
	content_size = content_size.max(Vector2(cfg["preferred"]))

	var desired: Vector2i = Vector2i(
		ceili(content_size.x * scale),
		ceili(content_size.y * scale)
	)

	var screen_rect: Rect2i = _usable_screen_rect(window, cfg["screen_margin"])

	var ratio: Vector2 = cfg["ratio"]
	if ratio.x > 0.0:
		desired.x = roundi(ratio.x * float(screen_rect.size.x))
	if ratio.y > 0.0:
		desired.y = roundi(ratio.y * float(screen_rect.size.y))

	var floor_size: Vector2i = cfg["min_size"]
	desired.x = maxi(desired.x, floor_size.x)
	desired.y = maxi(desired.y, floor_size.y)

	var ceil_size: Vector2i = cfg["max_size"]
	if ceil_size.x > 0:
		desired.x = mini(desired.x, ceil_size.x)
	if ceil_size.y > 0:
		desired.y = mini(desired.y, ceil_size.y)
	if window.max_size.x > 0:
		desired.x = mini(desired.x, window.max_size.x)
	if window.max_size.y > 0:
		desired.y = mini(desired.y, window.max_size.y)

	desired.x = mini(desired.x, screen_rect.size.x)
	desired.y = mini(desired.y, screen_rect.size.y)

	window.size = desired
	window.position = screen_rect.position + (screen_rect.size - desired) / 2


## Returns the minimum size the window's content needs, in content (GUI) units.
static func _content_min_size(window: Window) -> Vector2:
	if window is AcceptDialog:
		# AcceptDialog already folds in its label, button row and inner margins.
		var dialog_min: Vector2 = (window as AcceptDialog).get_contents_minimum_size()
		return dialog_min.max(Vector2(window.min_size))

	var result: Vector2 = Vector2.ZERO
	for child in window.get_children():
		if child is Control:
			result = result.max(_control_footprint(child as Control))
	return result.max(Vector2(window.min_size))


## Combined minimum size of [param control], plus the edge padding it reserves
## when it is anchored to fill its parent (the common dialog layout where a
## container is pinned to all four sides with inset offsets).
static func _control_footprint(control: Control) -> Vector2:
	var footprint: Vector2 = control.get_combined_minimum_size()
	var reserved: Vector2 = Vector2.ZERO
	if is_equal_approx(control.anchor_left, 0.0) and is_equal_approx(control.anchor_right, 1.0):
		reserved.x = maxf(control.offset_left - control.offset_right, 0.0)
	if is_equal_approx(control.anchor_top, 0.0) and is_equal_approx(control.anchor_bottom, 1.0):
		reserved.y = maxf(control.offset_top - control.offset_bottom, 0.0)
	return footprint + reserved


## Usable rectangle (taskbar excluded) of the screen the window will appear on,
## inset by [param margin] on every edge.
static func _usable_screen_rect(window: Window, margin: Vector2i) -> Rect2i:
	var screen_index: int = _screen_index(window)
	var rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_index)
	rect.position += margin
	rect.size -= margin * 2
	rect.size.x = maxi(rect.size.x, ABSOLUTE_MIN_SCREEN_SPAN)
	rect.size.y = maxi(rect.size.y, ABSOLUTE_MIN_SCREEN_SPAN)
	return rect


## Walks up from [param window] to the first ancestor [Window] it is embedded
## in (its host viewport / parent dialog). Returns [code]null[/code] when the
## window has no parent window — typically because it is the scene root or has
## not been added to the tree yet.
static func _resolve_parent_window(window: Window) -> Window:
	if window == null:
		return null
	var parent_node: Node = window.get_parent()
	if parent_node == null:
		return null
	var host: Viewport = parent_node.get_viewport()
	if host is Window:
		return host as Window
	return null


static func _screen_index(window: Window) -> int:
	var count: int = DisplayServer.get_screen_count()
	if count <= 0:
		return DisplayServer.get_primary_screen()

	var idx: int = window.current_screen
	var window_id: int = window.get_window_id()
	if window_id != DisplayServer.INVALID_WINDOW_ID:
		var live_index: int = DisplayServer.window_get_current_screen(window_id)
		if live_index >= 0:
			idx = live_index

	if idx < 0 or idx >= count:
		var parent: Window = _resolve_parent_window(window)
		if parent != null:
			idx = parent.current_screen

	if idx < 0 or idx >= count:
		idx = DisplayServer.get_primary_screen()
	if idx < 0 or idx >= count:
		idx = 0
	return idx
