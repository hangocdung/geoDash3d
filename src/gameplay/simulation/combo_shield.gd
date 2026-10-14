# Combo (consecutive cue hits; a miss or an absorbed hit resets it) and the shields it earns: every
# `shield_combo` hits charge one shield (up to `max_shields`), which absorbs one fatal hit.
# Related: run_simulation.gd, src/gameplay/defs/gameplay_config.gd
class_name ComboShield
extends RefCounted

var combo: int = 0
var max_combo: int = 0
var shields: int = 0
var _shield_combo: int = 1
var _max_shields: int = 0


func _init(shield_combo: int, max_shields: int) -> void:
	if shield_combo < 1:
		push_error("ComboShield: shield_combo must be >= 1 (got %d)" % shield_combo)
	_shield_combo = maxi(shield_combo, 1)
	_max_shields = maxi(max_shields, 0)


## Counts a judged hit; returns true when it charged a new shield.
func register_hit() -> bool:
	combo += 1
	max_combo = maxi(max_combo, combo)
	if combo % _shield_combo == 0 and shields < _max_shields:
		shields += 1
		return true
	return false


func register_miss() -> void:
	combo = 0


## Spends a shield, and the combo with it, if one is ready.
func use_shield() -> bool:
	if shields <= 0:
		return false
	shields -= 1
	combo = 0
	return true


## 0..1 progress toward the next shield (1 while one is ready and the stock is full).
func charge() -> float:
	if shields >= _max_shields:
		return 1.0
	return float(combo % _shield_combo) / float(_shield_combo)
