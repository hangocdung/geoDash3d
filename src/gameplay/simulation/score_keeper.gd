# Run score: each judged cue earns its grade's points times a combo bonus (1 + combo_bonus x min(combo, cap)),
# deterministic like the rest of the simulation; `max_score` is the all-PERFECT total of a chart (accuracy).
# Related: run_simulation.gd, combo_shield.gd, src/gameplay/defs/gameplay_config.gd, src/core/high_scores.gd
class_name ScoreKeeper
extends RefCounted

var score: int = 0
var _config: GameplayConfig


func _init(gameplay_config: GameplayConfig) -> void:
	_config = gameplay_config


## Adds the points of a cue judged `grade` with `combo` the combo after it; returns them.
func add(grade: Judgement.Grade, combo: int) -> int:
	var points: int = points_for(grade, combo, _config)
	score += points
	return points


static func points_for(grade: Judgement.Grade, combo: int, config: GameplayConfig) -> int:
	if grade < 0 or grade >= config.grade_points.size():
		push_error("ScoreKeeper: no points defined for grade %d" % grade)
		return 0
	var bonus: float = 1.0 + config.combo_bonus * float(mini(combo, config.combo_bonus_cap))
	return roundi(float(config.grade_points[grade]) * bonus)


## Score of a run that hits every one of `cue_count` cues PERFECT.
static func max_score(cue_count: int, config: GameplayConfig) -> int:
	var total: int = 0
	for combo: int in range(1, cue_count + 1):
		total += points_for(Judgement.Grade.PERFECT, combo, config)
	return total
