# Grades, combo, shields and score of one run: judges tapped cues and misses, breaks the combo and spends shields.
# RunSimulation owns one and forwards its signals (its public signals and fields are unchanged).
# Related: run_simulation.gd, combo_shield.gd, score_keeper.gd, judgement.gd
class_name RunScoring
extends RefCounted

signal cue_judged(cue_index: int, grade: Judgement.Grade, error_sec: float)
signal combo_changed(combo: int)
signal score_changed(score: int)
signal shield_changed(shields: int)

## Count per Judgement.Grade value.
var grade_counts: PackedInt32Array = [0, 0, 0, 0]
var streak: ComboShield
var score: ScoreKeeper
var _config: GameplayConfig


func _init(config: GameplayConfig) -> void:
	_config = config
	streak = ComboShield.new(config.shield_combo, config.max_shields)
	score = ScoreKeeper.new(config)


## A tapped cue: its grade, the combo (PERFECT only unless the config says otherwise: GREAT / GOOD then break it
## like a miss), shields and score.
func judge(cue_index: int, error_sec: float) -> void:
	var grade: Judgement.Grade = Judgement.grade_for_error(error_sec, _config)
	grade_counts[grade] += 1
	cue_judged.emit(cue_index, grade, error_sec)
	if grade == Judgement.Grade.PERFECT or not _config.perfect_only_combo:
		if streak.register_hit():
			shield_changed.emit(streak.shields)
		combo_changed.emit(streak.combo)
	else:
		break_combo()
	score.add(grade, streak.combo)
	score_changed.emit(score.score)


## A cue whose window closed without a tap.
func miss(cue_index: int) -> void:
	grade_counts[Judgement.Grade.MISS] += 1
	cue_judged.emit(cue_index, Judgement.Grade.MISS, NAN)
	break_combo()


func break_combo() -> void:
	if streak.combo > 0:
		streak.register_miss()
		combo_changed.emit(0)


## Spends a shield on a fatal hit; false when there is none. Call shield_spent() after announcing the save.
func use_shield() -> bool:
	return streak.use_shield()


func shield_spent() -> void:
	shield_changed.emit(streak.shields)
	combo_changed.emit(0)
