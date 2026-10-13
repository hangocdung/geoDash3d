# Command-line options for the level scene (after `--`), used by capture/movie tools and debugging:
#   --chart=res://...  --start-beat=32  --autoplay  --invincible  --clock=delta|audio
#   --capture=12.5,40 --capture-out=res://tools/capture/out  (screenshot song times, then quit)
#   --capture-manual (capture without autoplay, to see deaths)  --debug-clock (print audio drift)
# Related: src/presentation/level/level_runner.gd, tools/capture/README.md
class_name LaunchOptions
extends RefCounted

const LEVEL_ARGUMENT_KEYS: PackedStringArray = ["chart", "start-beat", "autoplay", "invincible", "clock", "capture",
		"capture-out", "capture-manual", "skip-start", "debug-clock"]

var chart_path: String = ""
var start_beat: float = NAN
var autoplay: bool = false
var invincible: bool = false
var frame_delta_clock: bool = false
var capture_times: PackedFloat64Array = []
var capture_directory: String = "res://tools/capture/out"
var skip_start_screen: bool = false
var capture_without_autoplay: bool = false
var debug_clock: bool = false
## Menu background: autoplay, no HUD, no input, loops forever.
var attract_mode: bool = false


static func from_command_line() -> LaunchOptions:
	var options := LaunchOptions.new()
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		var key: String = parts[0]
		var value: String = parts[1] if parts.size() > 1 else ""
		match key:
			"chart":
				options.chart_path = value
			"start-beat":
				options.start_beat = value.to_float()
			"autoplay":
				options.autoplay = true
			"invincible":
				options.invincible = true
			"clock":
				options.frame_delta_clock = value == "delta"
			"capture":
				for item: String in value.split(",", false):
					options.capture_times.append(item.to_float())
			"capture-out":
				options.capture_directory = value
			"skip-start":
				options.skip_start_screen = true
			"capture-manual":
				options.capture_without_autoplay = true
			"debug-clock":
				options.debug_clock = true
			_:
				push_warning("LaunchOptions: unknown argument '%s'" % argument)
	if not options.capture_times.is_empty():
		options.autoplay = not options.capture_without_autoplay
		options.frame_delta_clock = true
		options.skip_start_screen = true
	if options.autoplay:
		options.skip_start_screen = true
	return options


static func attract() -> LaunchOptions:
	var options := LaunchOptions.new()
	options.autoplay = true
	options.skip_start_screen = true
	options.attract_mode = true
	return options


## True when the command line asks for the level directly (tools, capture, debugging).
static func has_level_arguments() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		var key: String = argument.trim_prefix("--").get_slice("=", 0)
		if LEVEL_ARGUMENT_KEYS.has(key):
			return true
	return false


func is_capture_run() -> bool:
	return not capture_times.is_empty()
