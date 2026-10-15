# Portrait framing check (GD3-210): plays every chart with autoplay at 60 frames a song-second in a 720x1280 view (no
# rendering, no audio) and reports where the player's cube gets near the screen edges.
# Usage: "$GODOT" --headless --path . -s res://tools/capture/portrait_framing.gd -- [--chart=res://...] [--tier=0|1|2]
#        [--margin=0.02]
# Related: src/presentation/camera/camera_director.gd, src/presentation/level/display_orientation.gd
extends SceneTree

const VIEW_SIZE := Vector2i(720, 1280)
const FPS: float = 60.0
## A cube corner closer than this share of the screen to an edge counts as clipped (--margin= to change).
var _edge_margin: float = 0.02


var _started: bool = false


## Runs on the first frame: nodes added in _initialize() are not inside the tree yet.
func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var only: String = ""
	var tier: QualityTier.Tier = QualityTier.Tier.HIGH
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--chart="):
			only = argument.get_slice("=", 1)
		elif argument.begins_with("--margin="):
			_edge_margin = argument.get_slice("=", 1).to_float()
		elif argument.begins_with("--tier="):
			tier = argument.get_slice("=", 1).to_int() as QualityTier.Tier
	var paths: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at("res://assets/music"):
		if file_name.ends_with(".chart.json"):
			paths.append("res://assets/music/" + file_name)
	if not only.is_empty():
		paths = PackedStringArray([only])
	var worst_total: int = 0
	for path: String in paths:
		worst_total += _check(path, tier)
	print("FRAMING total clipped frames=%d" % worst_total)
	quit()


func _check(path: String, tier: QualityTier.Tier) -> int:
	var config: GameplayConfig = GameplayConfig.create_default()
	var chart: LevelChart = ChartLoader.load_file(path, config)
	if chart == null:
		push_error("portrait_framing: cannot load '%s'" % path)
		return 0
	var flatten: bool = not QualityTier.uses_spectacle_track(tier)
	var context := LevelContext.new(chart, config, TrackPath.build(chart, chart.end_beat + 16.0, flatten), tier)
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	view.disable_3d = false
	root.add_child(view)
	var player := PlayerView.new()
	var director := CameraDirector.new()
	view.add_child(player)
	view.add_child(director)
	player.setup(context)
	director.setup(context)
	var start: float = ReferenceRun.START_BEAT
	var simulation := RunSimulation.new(chart, config, start)
	var autoplay := Autoplay.new(chart, start)
	var clipped: int = 0
	var frames: int = 0
	var extreme := Rect2(Vector2.ONE, -Vector2.ONE)
	var bad_beats: PackedStringArray = []
	var time_sec: float = chart.time_at(start)
	while true:
		var beat: float = chart.beat_at_time(time_sec)
		if beat > chart.end_beat:
			break
		autoplay.drive(simulation, beat)
		player.update_pose(beat, simulation, 1.0 / FPS)
		director.update_camera(beat, simulation, 1.0 / FPS, player.center_position())
		var reach: Rect2 = _screen_reach(director.camera, player)
		extreme = Rect2(Vector2(minf(extreme.position.x, reach.position.x), minf(extreme.position.y, reach.position.y)),
				Vector2.ZERO).expand(Vector2(maxf(extreme.end.x, reach.end.x), maxf(extreme.end.y, reach.end.y)))
		if reach.position.x < _edge_margin or reach.position.y < _edge_margin or reach.end.x > 1.0 - _edge_margin \
				or reach.end.y > 1.0 - _edge_margin:
			clipped += 1
			if bad_beats.size() < 12 and (bad_beats.is_empty() or not bad_beats[-1].begins_with("%d" % int(beat))):
				bad_beats.append("%d(%.2f,%.2f-%.2f,%.2f)" % [int(beat), reach.position.x, reach.position.y, reach.end.x,
						reach.end.y])
		frames += 1
		time_sec += 1.0 / FPS
	print("FRAMING %-40s frames=%5d clipped=%4d  x %.2f..%.2f  y %.2f..%.2f  %s" % [path.get_file(), frames, clipped,
			extreme.position.x, extreme.end.x, extreme.position.y, extreme.end.y, " ".join(bad_beats)])
	view.queue_free()
	return clipped


## Screen-space bounds (0..1) of the cube's 8 corners.
func _screen_reach(camera: Camera3D, player: PlayerView) -> Rect2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var half: float = PlayerView.CUBE_SIZE * 0.5
	for corner: int in 8:
		var local := Vector3(half if corner & 1 else -half, half if corner & 2 else -half, half if corner & 4 else -half)
		var world: Vector3 = player.body.global_transform * local
		var point: Vector2 = camera.unproject_position(world) / Vector2(VIEW_SIZE)
		if camera.is_position_behind(world):
			point = Vector2(-1.0, -1.0)
		low = low.min(point)
		high = high.max(point)
	return Rect2(low, high - low)
