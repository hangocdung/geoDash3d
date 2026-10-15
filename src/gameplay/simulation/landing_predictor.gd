# Predicts the player's next landing a short time ahead, assuming nothing else happens (no tap, no pad): steps a
# copy of the vertical motion on the simulation grid. Read-only; the landing drum is played ahead with it (GD3-258).
# Related: run_simulation.gd, player_body.gd, vertical_motion.gd, src/presentation/level/presentation_router.gd
class_name LandingPredictor
extends RefCounted


## Beat of the landing within `max_beats` after the simulation's current beat, or NAN (none, or not airborne).
static func landing_beat(simulation: RunSimulation, max_beats: float) -> float:
	if not simulation.is_airborne() or max_beats <= 0.0:
		return NAN
	var config: GameplayConfig = simulation.config
	var now: float = simulation.current_beat
	var probe := VerticalMotion.new()
	probe.restore(simulation.motion_snapshot(), now)
	var step: float = config.simulation_step_beats
	var beat: float = (floorf(now / step) + 1.0) * step
	while beat <= now + max_beats:
		# Under the track the ground is the road's flat underside, as in RunSimulation.
		var support: float = 0.0 if simulation.is_underside() \
				else PlayerBody.support_under(simulation.chart, config, beat)
		match probe.step(beat, support, config.step_snap, config.fall_death_height):
			VerticalMotion.Contact.LANDED:
				return probe.grounded_since
			VerticalMotion.Contact.HIT_SIDE, VerticalMotion.Contact.FELL:
				return NAN
		beat += step
	return NAN
