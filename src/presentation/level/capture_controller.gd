# Screenshot mode (`--capture=t1,t2 --capture-out=dir`): for each song time, restarts the run
# a little earlier with autoplay + frame-delta clock, lets effects warm up, saves a PNG, then quits.
# Related: src/presentation/level/launch_options.gd, tools/capture/README.md
class_name CaptureController
extends Node

const WARMUP_SEC: float = 2.0
const DEATH_SETTLE_FRAMES: int = 9

var _active: bool = false


func is_active() -> bool:
	return _active


func begin(runner: LevelRunner, options: LaunchOptions) -> void:
	_active = true
	AudioServer.set_bus_mute(0, true)
	var directory: String = ProjectSettings.globalize_path(options.capture_directory)
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		push_error("CaptureController: cannot create '%s' (%s)" % [directory, error_string(error)])
		runner.get_tree().quit(1)
		return
	_run_captures(runner, options.capture_times, directory)


func _run_captures(runner: LevelRunner, times: PackedFloat64Array, directory: String) -> void:
	for capture_time: float in times:
		runner.start_beat = runner.chart.safe_start_beat(runner.chart.beat_at_time(capture_time - WARMUP_SEC))
		runner.restart()
		while runner.song_clock.frame_time() < capture_time and not runner.simulation.is_dead:
			await runner.get_tree().process_frame
		if runner.simulation.is_dead:
			# Let the death burst expand before taking the picture.
			for frame: int in DEATH_SETTLE_FRAMES:
				await runner.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = runner.get_viewport().get_texture().get_image()
		var file_path: String = directory.path_join("capture_%07.2f.png" % capture_time)
		var error: Error = image.save_png(file_path)
		if error != OK:
			push_error("CaptureController: cannot save '%s' (%s)" % [file_path, error_string(error)])
		else:
			print("CAPTURE %s beat=%.2f dead=%s" % [file_path, runner.current_beat(), runner.simulation.is_dead])
	runner.get_tree().quit(0)
