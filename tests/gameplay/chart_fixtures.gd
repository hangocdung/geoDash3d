# Builds small charts for tests from event lists, so each test states only what matters.
# Related: src/gameplay/chart/chart_loader.gd
class_name ChartFixtures
extends RefCounted


static func make_chart(events: Array[Dictionary], bpm: float = 120.0, units_per_beat: float = 7.0,
		end_beat: float = 32.0, terrain: Array[Dictionary] = [], extra: Dictionary = {}) -> LevelChart:
	var root: Dictionary = {
		"version": 1,
		"title": "fixture",
		"song": "res://assets/music/the_dawn_assembly.mp3",
		"offset_sec": 0.0,
		"end_beat": end_beat,
		"tempo": [{"beat": 0, "bpm": bpm}],
		"speed": [{"beat": 0, "units_per_beat": units_per_beat}],
		"events": events,
		"terrain": terrain,
	}
	root.merge(extra, true)
	return ChartLoader.parse_text(JSON.stringify(root), GameplayConfig.create_default(), "fixture")
