# Vertical list that scrolls by dragging anywhere on its content (finger or mouse), with momentum, as phones expect.
# A drag that moves past DRAG_THRESHOLD cancels the press of the button under the finger, so scrolling never selects
# a row. Content controls must let events through: call make_draggable() after (re)filling the list.
# Related: src/ui/menu/song_list_panel.gd, src/ui/menu/settings_panel.gd, src/ui/theme/ui_theme.gd
class_name TouchScroll
extends ScrollContainer

## Canvas units the pointer must travel vertically before a press becomes a scroll.
const DRAG_THRESHOLD: float = 18.0
## Momentum decay per second (exponential) and the speed below which it stops (canvas units / s).
const FRICTION: float = 5.0
const MIN_SPEED: float = 40.0
const MAX_SPEED: float = 9000.0

var _pressing: bool = false
var _dragging: bool = false
var _press_y: float = 0.0
var _press_scroll: float = 0.0
var _last_y: float = 0.0
var _last_time: float = 0.0
var _velocity: float = 0.0
var _scroll_position: float = 0.0


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	set_process(false)


## True while the current press has turned into a scroll (buttons can ignore their release).
func is_dragging() -> bool:
	return _dragging


## Lets presses on `root`'s controls reach this container (STOP → PASS), except sliders and text fields, which keep
## their own drag.
func make_draggable(root: Node) -> void:
	for node: Node in root.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control is Range or control is LineEdit or control is TextEdit:
			continue
		if control.mouse_filter == Control.MOUSE_FILTER_STOP:
			control.mouse_filter = Control.MOUSE_FILTER_PASS


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_begin(button.position.y)
		else:
			_end()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null or not _pressing or (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		return
	var travel: float = motion.position.y - _press_y
	if not _dragging and absf(travel) > DRAG_THRESHOLD and absf(motion.relative.y) >= absf(motion.relative.x):
		_dragging = true
		_cancel_press()
	if _dragging:
		_drag_to(motion.position.y)
		accept_event()


func _process(delta: float) -> void:
	# Something else scrolled meanwhile (mouse wheel, keyboard focus): it wins over the fling.
	if absf(scroll_vertical - roundf(_scroll_position)) > 1.0:
		_velocity = 0.0
	if _pressing or absf(_velocity) < MIN_SPEED:
		_velocity = 0.0
		set_process(false)
		return
	_scroll_position += _velocity * delta
	var limit: float = _max_scroll()
	if _scroll_position <= 0.0 or _scroll_position >= limit:
		_scroll_position = clampf(_scroll_position, 0.0, limit)
		_velocity = 0.0
	scroll_vertical = roundi(_scroll_position)
	_velocity *= exp(-FRICTION * delta)


func _begin(y: float) -> void:
	_pressing = true
	_dragging = false
	_press_y = y
	_press_scroll = float(scroll_vertical)
	_scroll_position = _press_scroll
	_last_y = y
	_last_time = _now()
	_velocity = 0.0
	set_process(false)


func _end() -> void:
	_pressing = false
	if _dragging and absf(_now() - _last_time) > 0.1:
		_velocity = 0.0
	if _dragging and absf(_velocity) >= MIN_SPEED:
		set_process(true)


func _drag_to(y: float) -> void:
	var now: float = _now()
	var elapsed: float = now - _last_time
	if elapsed > 0.0:
		var speed: float = clampf((_last_y - y) / elapsed, -MAX_SPEED, MAX_SPEED)
		# Smoothed so one jittery sample does not decide the fling.
		_velocity = lerpf(_velocity, speed, 0.6)
	_last_y = y
	_last_time = now
	_scroll_position = clampf(_press_scroll - (y - _press_y), 0.0, _max_scroll())
	scroll_vertical = roundi(_scroll_position)


## The button that took the press must not fire on release: toggling `disabled` clears its press state.
func _cancel_press() -> void:
	var hovered: Control = get_viewport().gui_get_hovered_control()
	while hovered != null and hovered != self:
		if hovered is BaseButton and not (hovered as BaseButton).disabled:
			(hovered as BaseButton).disabled = true
			(hovered as BaseButton).disabled = false
			return
		hovered = hovered.get_parent() as Control


func _max_scroll() -> float:
	var bar: VScrollBar = get_v_scroll_bar()
	return maxf(bar.max_value - bar.page, 0.0)


static func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0
