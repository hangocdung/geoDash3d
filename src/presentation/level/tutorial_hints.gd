# First-time hints (GD3-250): the first time each kind of tap comes up (in any song), the HUD says what to do before
# that cue, in the action's color. A kind counts as learned once the player hits it (UserSettings.hints_seen); after a
# miss the hint comes back on the next attempt. Off in attract, autoplay (and so autoplay captures) and video clips.
# Related: src/presentation/level/presentation_router.gd (binds it), src/ui/hud/hud.gd (show_hint)
class_name TutorialHints
extends RefCounted

## Action id → hint group (several actions share one lesson).
const GROUPS: Dictionary[StringName, String] = {
	&"jump": "jump", &"orb": "orb", &"orb_big": "orb", &"orb_drop": "orb",
	&"dodge_left": "dodge", &"dodge_right": "dodge", &"flip": "flip", &"roll": "roll",
	&"flip_down": "under", &"flip_up": "under_up",
}
const TEXTS: Dictionary[String, String] = {
	"jump": "TAP as the cube reaches the pink ring: JUMP over the spikes",
	"orb": "TAP while passing through a ring in the air: JUMP AGAIN",
	"dodge": "TAP to SIDESTEP the orange wall into the open lane",
	"flip": "TAP to FLIP under the track through the green gate",
	"roll": "TAP to ROLL all the way around the track",
	"under": "TAP to drop UNDER the track and run upside down",
	"under_up": "TAP to FLIP BACK on top of the track",
}

var _hud: Hud
var _chart: LevelChart
var _enabled: bool
var _group: String = ""


func _init(hud: Hud, chart: LevelChart, enabled: bool) -> void:
	_hud = hud
	_chart = chart
	_enabled = enabled


func bind(simulation: RunSimulation, start_beat: float) -> void:
	_group = ""
	_hud.show_hint("", Color.WHITE)
	if not _enabled:
		return
	simulation.cue_judged.connect(_on_cue_judged)
	for index: int in _chart.cues.size():
		if _chart.cues[index].beat >= start_beat:
			_show_for(index)
			return


func _on_cue_judged(cue_index: int, grade: Judgement.Grade, _error_sec: float) -> void:
	var cue_group: String = GROUPS.get(_chart.cues[cue_index].action.id, "")
	if grade != Judgement.Grade.MISS and not cue_group.is_empty():
		UserSettings.mark_hint_seen(cue_group)
	_show_for(cue_index + 1)


## Shows the hint of cue `index` if its kind is still new, else clears the hint.
func _show_for(index: int) -> void:
	if index >= _chart.cues.size():
		_hud.show_hint("", Color.WHITE)
		return
	var action: ActionDefinition = _chart.cues[index].action
	var group: String = GROUPS.get(action.id, "")
	if group.is_empty() or UserSettings.hints_seen.has(group):
		_group = ""
		_hud.show_hint("", Color.WHITE)
		return
	_group = group
	_hud.show_hint(Locale.t(TEXTS[group]), action.color)
