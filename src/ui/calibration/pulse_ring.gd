# Big circular target for the calibration screen: `pulse` (0..1) animates with the clicks while the
# player learns the rhythm, `flash` (0..1) lights up on every tap. Pure drawing; input passes through.
# Related: src/ui/calibration/calibration_screen.gd
class_name PulseRing
extends Control

const RADIUS: float = 150.0
const DECAY_PER_SEC: float = 5.0

var pulse: float = 0.0
var flash: float = 0.0
var ring_color: Color = UiTheme.ACCENT
var tap_color: Color = UiTheme.HOT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(RADIUS * 2.0 + 40.0, RADIUS * 2.0 + 40.0)


func _process(delta: float) -> void:
	pulse = maxf(pulse - delta * DECAY_PER_SEC, 0.0)
	flash = maxf(flash - delta * DECAY_PER_SEC, 0.0)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = RADIUS * (1.0 + pulse * 0.12)
	draw_circle(center, radius, Color(tap_color, 0.12 + flash * 0.5))
	draw_arc(center, radius, 0.0, TAU, 96, ring_color.lerp(Color.WHITE, pulse * 0.6), 6.0 + pulse * 6.0, true)
	if flash > 0.0:
		draw_arc(center, radius + 18.0 * (1.0 - flash), 0.0, TAU, 96, Color(tap_color, flash), 4.0, true)
