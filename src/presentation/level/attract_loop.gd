# Menu demo (attract mode) loop: plays the song's first PREVIEW_SEC, or up to the furthest point the player has
# reached when that is later (a cleared song plays to the end), fading the music out before it starts over.
# Related: src/presentation/level/level_runner.gd, src/core/high_scores.gd, src/ui/menu/main_menu.gd
class_name AttractLoop
extends RefCounted

const PREVIEW_SEC: float = 60.0
const FADE_SEC: float = 1.5
## The demo is quieter than a real run.
const VOLUME_OFFSET_DB: float = -4.0
## Without a demo limit, loop this long after the chart ends (the song may run much longer).
const OUTRO_BEATS: float = 8.0
const SILENT_DB: float = -60.0

## Song time at which the demo loops (INF = only the chart end loops it).
var end_sec: float = INF
var _end_beat: float


func _init(chart: LevelChart, best: HighScores.Record) -> void:
	end_sec = end_time(chart, best)
	_end_beat = chart.end_beat + OUTRO_BEATS


## Song time where the demo of `chart` stops, given the player's best record.
static func end_time(chart: LevelChart, best: HighScores.Record) -> float:
	if best.completed:
		return INF
	var furthest_sec: float = chart.time_at(clampf(best.progress, 0.0, 1.0) * chart.end_beat)
	return maxf(PREVIEW_SEC, furthest_sec)


## Music volume factor (1 → 0 over the last FADE_SEC before the loop).
func fade(song_time: float) -> float:
	if is_inf(end_sec):
		return 1.0
	return clampf((end_sec - song_time) / FADE_SEC, 0.0, 1.0)


## Called every frame: sets the faded demo volume; true when the demo should start over.
func update(clock: SongClock, beat: float) -> bool:
	var time: float = clock.frame_time()
	clock.use_music_bus(VOLUME_OFFSET_DB + maxf(linear_to_db(fade(time)), SILENT_DB))
	return time >= end_sec or beat > _end_beat
