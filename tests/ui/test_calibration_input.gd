extends TestCase
# Drives the real calibration scene through the input pipeline (mouse/touch press over the screen),
# so a full-screen Control that swallows taps is caught. Clock runs in MANUAL mode.

const SCENE: PackedScene = preload("res://src/ui/calibration/calibration_screen.tscn")
const LATE_SEC: float = 0.03

var _tree: SceneTree


func before_each() -> void:
	_tree = Engine.get_main_loop() as SceneTree


func test_screen_taps_are_measured_and_produce_an_offset() -> void:
	var screen: CalibrationScreen = SCENE.instantiate() as CalibrationScreen
	_tree.root.add_child(screen)
	# Regression (Android): a full-screen Control with the default STOP filter swallowed every touch.
	assert_eq(screen.mouse_filter, Control.MOUSE_FILTER_IGNORE, "screen root must let taps through")
	screen._start()
	screen._clock.drive_mode = SongClock.DriveMode.MANUAL
	var taps: int = CalibrationScreen.WARMUP_TAPS + CalibrationScreen.MEASURED_TAPS
	for beat: int in taps:
		screen._clock.set_manual_time(screen._tempo.beat_to_time(float(beat)) + LATE_SEC)
		_tree.root.push_input(_touch(_tree.root.get_visible_rect().size * 0.5))
	assert_eq(screen._errors.size(), CalibrationScreen.MEASURED_TAPS, "every tap after the warm-up is measured")
	screen._clock.set_manual_time(screen._tempo.beat_to_time(float(taps)))
	screen._process(0.0)
	assert_eq(screen._phase, CalibrationScreen.Phase.RESULT)
	assert_almost_eq(screen._estimate.offset_sec, LATE_SEC, 0.001)
	screen.queue_free()


func _touch(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	event.global_position = position
	return event
