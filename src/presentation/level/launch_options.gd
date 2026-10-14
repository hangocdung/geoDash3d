# Command-line options for the level scene (after `--`), used by capture/movie tools and debugging:
#   --chart=res://...  --start-beat=32  --autoplay  --invincible  --clock=delta|audio
#   --capture=12.5,40 --capture-out=res://tools/capture/out  (screenshot song times, then quit)
#   --capture-manual (capture without autoplay, to see deaths)  --debug-clock (print audio drift)
#   --capture-continuous (one run from the start for all capture times, instead of a restart per time)
#   --practice --rate=0.75 (practice mode with checkpoints, slower playback)
#   --autoplay-miss=34,66.5 (autoplay skips the cues on these beats: shows misses, shields, deaths)
# Related: src/presentation/level/level_runner.gd, tools/capture/README.md
class_name LaunchOptions
extends RefCounted

const DEBUG_ARGS_PATH: String = "user://debug_args.txt"
const LEVEL_ARGUMENT_KEYS: PackedStringArray = ["chart", "start-beat", "autoplay", "invincible", "clock", "capture",
		"capture-out", "capture-manual", "skip-start", "debug-clock", "practice", "rate", "perf", "autoplay-miss",
		"capture-continuous"]

var chart_path: String = ""
var start_beat: float = NAN
var autoplay: bool = false
## Cue beats the autoplay bot deliberately skips.
var autoplay_missed_beats: PackedFloat64Array = []
var invincible: bool = false
var frame_delta_clock: bool = false
var capture_times: PackedFloat64Array = []
var capture_directory: String = "res://tools/capture/out"
var skip_start_screen: bool = false
var capture_without_autoplay: bool = false
var capture_continuous: bool = false
var debug_clock: bool = false
## Debug performance experiments, e.g. --perf=noglow,nosky,scale=0.5 (see LevelRunner._apply_perf_flags).
var perf_flags: PackedStringArray = []
## Menu background: autoplay, no HUD, no input, loops forever.
var attract_mode: bool = false
## Practice: checkpoints, restart from the last one, optional slower playback.
var practice: bool = false
var playback_rate: float = 1.0

## Options handed from a menu to the next level scene (consumed once).
static var _next_run: LaunchOptions


## Arguments after `--`, plus (debug builds) whitespace-separated arguments from user://debug_args.txt,
## which tools/device/perf_matrix.sh writes on Android where launch extras are not forwarded.
static func user_args() -> PackedStringArray:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if OS.is_debug_build() and FileAccess.file_exists(DEBUG_ARGS_PATH):
		arguments.append_array(FileAccess.get_file_as_string(DEBUG_ARGS_PATH).strip_edges().split(" ", false))
	return arguments


static func from_command_line() -> LaunchOptions:
	var options := LaunchOptions.new()
	for argument: String in user_args():
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
			"capture-continuous":
				options.capture_continuous = true
			"debug-clock":
				options.debug_clock = true
			"perf":
				options.perf_flags = value.replace("+", ",").split(",", false)
			"practice":
				options.practice = true
			"rate":
				options.playback_rate = clampf(value.to_float(), 0.25, 1.0)
			"autoplay-miss":
				for item: String in value.split(",", false):
					options.autoplay_missed_beats.append(item.to_float())
			_:
				push_warning("LaunchOptions: unknown argument '%s'" % argument)
	if not options.capture_times.is_empty():
		options.autoplay = not options.capture_without_autoplay
		options.frame_delta_clock = true
		options.skip_start_screen = true
	if options.autoplay:
		options.skip_start_screen = true
	return options


static func set_next_run(next_options: LaunchOptions) -> void:
	_next_run = next_options


static func take_next_run() -> LaunchOptions:
	var next_options: LaunchOptions = _next_run
	_next_run = null
	return next_options


static func practice_run(rate: float, chart: String) -> LaunchOptions:
	var options := LaunchOptions.new()
	options.practice = true
	options.playback_rate = rate
	options.chart_path = chart
	return options


static func chart_run(chart: String) -> LaunchOptions:
	var options := LaunchOptions.new()
	options.chart_path = chart
	return options


static func attract() -> LaunchOptions:
	var options := LaunchOptions.new()
	options.autoplay = true
	options.skip_start_screen = true
	options.attract_mode = true
	return options


## True when the command line asks for the level directly (tools, capture, debugging).
static func has_level_arguments() -> bool:
	for argument: String in user_args():
		var key: String = argument.trim_prefix("--").get_slice("=", 0)
		if LEVEL_ARGUMENT_KEYS.has(key):
			return true
	return false


func is_capture_run() -> bool:
	return not capture_times.is_empty()
