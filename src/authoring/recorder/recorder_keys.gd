# Keyboard shortcuts of the recorder, mapped to the same action names as the on-screen buttons
# (RecorderToolbar) plus a few keyboard-only ones. Related: src/authoring/recorder/recorder.gd
class_name RecorderKeys
extends RefCounted

const PLAIN: Dictionary[Key, StringName] = {
	KEY_SPACE: &"pad_0", KEY_J: &"pad_0", KEY_K: &"pad_1", KEY_L: &"pad_2",
	KEY_P: &"play", KEY_ENTER: &"play", KEY_LEFT: &"back_beat", KEY_RIGHT: &"forward_beat",
	KEY_PAGEUP: &"previous_segment", KEY_PAGEDOWN: &"next_segment", KEY_HOME: &"start",
	KEY_DELETE: &"delete", KEY_BACKSPACE: &"delete", KEY_TAB: &"select_next", KEY_G: &"next_grid",
	KEY_MINUS: &"slower", KEY_EQUAL: &"faster", KEY_S: &"save", KEY_ESCAPE: &"exit",
}


## Action for a key press, or &"" when the key is not a shortcut.
static func action_for(event: InputEventKey) -> StringName:
	var key: Key = event.physical_keycode
	if event.ctrl_pressed and key == KEY_Z:
		return &"redo" if event.shift_pressed else &"undo"
	if event.ctrl_pressed and key == KEY_Y:
		return &"redo"
	if event.shift_pressed and key == KEY_LEFT:
		return &"nudge_left"
	if event.shift_pressed and key == KEY_RIGHT:
		return &"nudge_right"
	if event.shift_pressed and key == KEY_TAB:
		return &"select_previous"
	return PLAIN.get(key, &"")
