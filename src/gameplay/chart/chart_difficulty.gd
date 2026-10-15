# Difficulty of a chart from its raw JSON (the song menu sorts by it without loading whole levels): weighted taps
# per minute of play, each tap scaled by the run speed at its beat (same action weights as the shipped-charts test:
# jump / orbs 1, dodges 1.25, flips / rolls / underside flips 1.75). Related: src/ui/menu/song_list_panel.gd, docs/chart_format.md
class_name ChartDifficulty
extends RefCounted

const BASE_SPEED: float = 7.0
## Score bounds of the five labels (EASY ... EXPERT); measured scores 2026-10-15 run from 30 to 70.
const TIER_LIMITS: Array[float] = [35.0, 45.0, 55.0, 65.0]
const TIER_NAMES: PackedStringArray = ["EASY", "NORMAL", "HARD", "HARDER", "EXPERT"]
const WEIGHTS: Dictionary[String, float] = {
	"jump": 1.0, "orb": 1.0, "orb_big": 1.0, "orb_drop": 1.0, "dodge_left": 1.25, "dodge_right": 1.25,
	"flip": 1.75, "roll": 1.75, "flip_down": 1.75, "flip_up": 1.75,
}


static func score(chart: Dictionary) -> float:
	var tempo: Array = chart.get("tempo", [])
	var bpm: float = float((tempo[0] as Dictionary).get("bpm", 120.0)) if not tempo.is_empty() else 120.0
	var minutes: float = float(chart.get("end_beat", 0.0)) / maxf(bpm, 1.0)
	if minutes <= 0.0:
		return 0.0
	var speeds: Array = chart.get("speed", [])
	var total: float = 0.0
	for event: Variant in chart.get("events", []):
		var entry: Dictionary = event as Dictionary
		var weight: float = WEIGHTS.get(str(entry.get("type", "")), 0.0)
		if weight > 0.0:
			total += weight * _speed_at(speeds, float(entry.get("beat", 0.0))) / BASE_SPEED
	return total / minutes


## 0 (EASY) .. 4 (EXPERT).
static func tier(chart_score: float) -> int:
	var result: int = 0
	for limit: float in TIER_LIMITS:
		if chart_score >= limit:
			result += 1
	return result


static func tier_name(chart_score: float) -> String:
	return TIER_NAMES[tier(chart_score)]


static func _speed_at(speeds: Array, beat: float) -> float:
	var rate: float = BASE_SPEED
	var best_beat: float = -INF
	for key: Variant in speeds:
		var entry: Dictionary = key as Dictionary
		var key_beat: float = float(entry.get("beat", 0.0))
		if key_beat <= beat and key_beat >= best_beat:
			best_beat = key_beat
			rate = float(entry.get("units_per_beat", BASE_SPEED))
	return rate
