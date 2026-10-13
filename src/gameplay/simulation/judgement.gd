# Timing grades for cue hits and the helper that maps a timing error to a grade.
# Related: src/gameplay/simulation/action_resolver.gd, src/ui/hud/judgement_popup.gd
class_name Judgement
extends RefCounted

enum Grade { PERFECT, GREAT, GOOD, MISS }


static func grade_for_error(error_sec: float, config: GameplayConfig) -> Grade:
	var magnitude: float = absf(error_sec)
	if magnitude <= config.perfect_window_sec:
		return Grade.PERFECT
	if magnitude <= config.great_window_sec:
		return Grade.GREAT
	if magnitude <= config.cue_window_sec:
		return Grade.GOOD
	return Grade.MISS


static func label(grade: Grade) -> String:
	match grade:
		Grade.PERFECT:
			return "PERFECT"
		Grade.GREAT:
			return "GREAT"
		Grade.GOOD:
			return "GOOD"
	return "MISS"
