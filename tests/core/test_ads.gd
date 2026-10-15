# Ad safety: debug exports must use Google demo units despite configured live units.
# Related: src/core/ads.gd, project.godot, docs/release/admob_setup.md.
extends TestCase


func test_debug_never_selects_live_units() -> void:
	for format: String in ["banner", "interstitial", "rewarded"]:
		assert_eq(Ads._unit(format), Ads.TEST_UNITS[format])
		var live_unit: String = str(ProjectSettings.get_setting(Ads.UNIT_SETTING % format, ""))
		assert_ne(live_unit, "", "Live unit must be configured for release")
		assert_ne(Ads._unit(format), live_unit, "Debug must not request live inventory")
