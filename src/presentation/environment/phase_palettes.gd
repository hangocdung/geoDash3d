# The level's palette as a pure function of the beat: each chart phase wears its palette, and the change
# into a phase blends over `transition_beats` from the phase's first beat (0 = instant switch, used on LOW
# so the sky only changes on one frame). Charts without phases keep the default palette.
# Related: palette_library.gd, environment_director.gd, src/gameplay/chart/level_chart.gd (phases)
class_name PhasePalettes
extends RefCounted

var transition_beats: float = 1.0
var _beats: PackedFloat64Array = []
var _palettes: Array[ScenePalette] = []


static func from_chart(chart: LevelChart, transition: float) -> PhasePalettes:
	var result := PhasePalettes.new()
	result.transition_beats = maxf(transition, 0.0)
	for phase: ChartItems.Phase in chart.phases:
		result._beats.append(phase.beat)
		result._palettes.append(PaletteLibrary.get_palette(phase.palette))
	if result._palettes.is_empty():
		result._beats.append(-INF)
		result._palettes.append(PaletteLibrary.get_palette(PaletteLibrary.DEFAULT))
	return result


func phase_count() -> int:
	return _palettes.size()


func phase_beat(index: int) -> float:
	return _beats[index]


## Phase in effect at `beat` (the first one before it starts).
func index_at(beat: float) -> int:
	return maxi(_beats.bsearch(beat, false) - 1, 0)


## 0..1 progress of the blend into the phase at `beat` (1 = settled).
func blend_at(beat: float) -> float:
	var index: int = index_at(beat)
	if index == 0 or transition_beats <= 0.0:
		return 1.0
	return clampf((beat - _beats[index]) / transition_beats, 0.0, 1.0)


func settled_palette(index: int) -> ScenePalette:
	return _palettes[clampi(index, 0, _palettes.size() - 1)]


func palette_at(beat: float) -> ScenePalette:
	var index: int = index_at(beat)
	var weight: float = blend_at(beat)
	if weight >= 1.0:
		return _palettes[index]
	return _palettes[index - 1].blended(_palettes[index], smoothstep(0.0, 1.0, weight))
