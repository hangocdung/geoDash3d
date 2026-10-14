# Phases: chart parsing, the palette timeline as a function of the beat, and the shipped charts' phase ladders.
# Related: src/presentation/environment/phase_palettes.gd, src/gameplay/chart/chart_loader.gd
extends TestCase

const MUSIC_DIRECTORY: String = "res://assets/music"


func _phase_chart(phases: Array) -> LevelChart:
	var text: String = JSON.stringify({
		"version": 1, "song": "res://assets/music/the_dawn_assembly.mp3", "end_beat": 64,
		"tempo": [{"beat": 0, "bpm": 120}],
		"speed": [{"beat": 0, "units_per_beat": 7}, {"beat": 32, "units_per_beat": 9}],
		"phases": phases,
	})
	return ChartLoader.parse_text(text, GameplayConfig.create_default(), "fixture")


func test_phases_are_parsed_sorted_and_found_by_beat() -> void:
	var chart: LevelChart = _phase_chart([{"beat": 32, "palette": "ocean"}, {"beat": 0, "palette": "indigo"}])
	assert_eq(chart.phases.size(), 2)
	assert_eq(chart.phases[0].palette, &"indigo")
	assert_eq(chart.phase_index_at(-4.0), 0, "before the first phase")
	assert_eq(chart.phase_index_at(31.9), 0)
	assert_eq(chart.phase_index_at(32.0), 1)
	assert_almost_eq(chart.speed_at(40.0), 9.0)


func test_chart_without_phases_has_none() -> void:
	var chart: LevelChart = _phase_chart([])
	assert_eq(chart.phase_index_at(10.0), -1)
	var palettes: PhasePalettes = PhasePalettes.from_chart(chart, 1.0)
	assert_eq(palettes.phase_count(), 1)
	assert_eq(palettes.palette_at(50.0).track_grid, PaletteLibrary.get_palette(PaletteLibrary.DEFAULT).track_grid)


func test_bad_phase_entries_fail() -> void:
	expect_errors(2)
	assert_null(_phase_chart([{"beat": 8}]), "missing palette")
	assert_null(_phase_chart([{"beat": 8, "palette": "ocean"}, {"beat": 8, "palette": "void"}]), "same beat twice")


func test_palette_blends_over_the_transition_then_settles() -> void:
	var chart: LevelChart = _phase_chart([{"beat": 0, "palette": "indigo"}, {"beat": 32, "palette": "ocean"}])
	var palettes: PhasePalettes = PhasePalettes.from_chart(chart, 1.0)
	var indigo: ScenePalette = PaletteLibrary.get_palette(&"indigo")
	var ocean: ScenePalette = PaletteLibrary.get_palette(&"ocean")
	assert_eq(palettes.palette_at(31.99).track_rail, indigo.track_rail)
	assert_eq(palettes.palette_at(32.0).track_rail, indigo.track_rail, "the blend starts on the phase beat")
	assert_almost_eq(palettes.blend_at(32.5), 0.5)
	var halfway: Color = palettes.palette_at(32.5).track_rail
	assert_true(halfway != indigo.track_rail and halfway != ocean.track_rail, "midway between the palettes")
	assert_eq(palettes.palette_at(33.0).track_rail, ocean.track_rail)
	var instant: PhasePalettes = PhasePalettes.from_chart(chart, 0.0)
	assert_eq(instant.palette_at(32.0).track_rail, ocean.track_rail, "LOW: switch on the phase beat")


func test_every_library_palette_has_all_fields() -> void:
	for palette_name: StringName in PaletteLibrary.names():
		var palette: ScenePalette = PaletteLibrary.get_palette(palette_name)
		for property: StringName in ScenePalette.color_properties():
			assert_true((palette.get(property) as Color).a > 0.0, "%s.%s is unset" % [palette_name, property])


func test_shipped_phases_use_known_palettes_and_speed_up() -> void:
	var config: GameplayConfig = GameplayConfig.create_default()
	for file_name: String in DirAccess.get_files_at(MUSIC_DIRECTORY):
		if not file_name.ends_with(".chart.json"):
			continue
		var chart: LevelChart = ChartLoader.load_file(MUSIC_DIRECTORY.path_join(file_name), config)
		var previous_speed: float = 0.0
		for phase: ChartItems.Phase in chart.phases:
			assert_true(PaletteLibrary.has_palette(phase.palette), "%s: unknown palette %s" % [file_name, phase.palette])
			assert_almost_eq(fmod(phase.beat, 4.0), 0.0, 0.0001, "%s: phase at %.2f is not on a bar line" % [file_name,
					phase.beat])
			var speed: float = chart.speed_at(phase.beat)
			assert_true(speed > previous_speed, "%s: phase at %.1f does not speed up" % [file_name, phase.beat])
			previous_speed = speed
