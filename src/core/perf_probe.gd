# Autoload "PerfProbe" (debug builds, or release builds exported with the `perf_probe` feature): logs device info once, then every few seconds the FPS,
# worst frame time (hitches), draw calls and audio latency, prefixed "PERF" so `adb logcat` /
# console output can be filtered. Related: docs/roadmap.md (GD3-050/051), src/core/song_clock.gd
extends Node

const REPORT_INTERVAL_SEC: float = 5.0
const HITCH_THRESHOLD_MS: float = 33.4

var _elapsed: float = 0.0
var _frames: int = 0
var _worst_frame_ms: float = 0.0
var _hitches: int = 0
## Accumulated microseconds per named section (see `measure`), reported as average ms per frame.
var _sections: Dictionary[StringName, int] = {}


func _ready() -> void:
	if not (OS.is_debug_build() or OS.has_feature("perf_probe")):
		set_process(false)
		return
	print("PERF device model=%s os=%s %s renderer=%s adapter=%s screen=%s window=%s quality=%s latency_ms=%.1f" % [
		OS.get_model_name(), OS.get_name(), OS.get_version(),
		str(ProjectSettings.get_setting_with_override("rendering/renderer/rendering_method")),
		RenderingServer.get_video_adapter_name(), str(DisplayServer.screen_get_size()),
		str(DisplayServer.window_get_size()), QualityTier.Tier.keys()[UserSettings.quality_tier],
		AudioServer.get_output_latency() * 1000.0])


## Adds time spent in a named code section since `start_usec` (debug builds only).
func measure(section: StringName, start_usec: int) -> void:
	_sections[section] = _sections.get(section, 0) + Time.get_ticks_usec() - start_usec


func _process(delta: float) -> void:
	_elapsed += delta
	_frames += 1
	var frame_ms: float = delta * 1000.0
	_worst_frame_ms = maxf(_worst_frame_ms, frame_ms)
	if frame_ms > HITCH_THRESHOLD_MS:
		_hitches += 1
	if _elapsed < REPORT_INTERVAL_SEC:
		return
	var scene: Node = get_tree().current_scene
	print("PERF fps=%.1f worst_ms=%.1f hitches=%d cpu_ms=%.1f draw_calls=%d objects=%d primitives=%d video_mb=%.0f latency_ms=%.1f scene=%s" % [
		_frames / _elapsed, _worst_frame_ms, _hitches, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		AudioServer.get_output_latency() * 1000.0, scene.name if scene != null else "-"])
	if not _sections.is_empty():
		var parts: PackedStringArray = []
		for section: StringName in _sections:
			parts.append("%s=%.2f" % [section, _sections[section] / 1000.0 / maxf(_frames, 1)])
		print("PERF sections_ms " + " ".join(parts))
		_sections.clear()
	_elapsed = 0.0
	_frames = 0
	_worst_frame_ms = 0.0
	_hitches = 0
