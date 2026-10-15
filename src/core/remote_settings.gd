# Values tunable without an app update (GD3-233): defaults here, Firebase Remote Config overrides them once fetched
# (GeoDashFirebase plugin; PC and tests always see the defaults). Gameplay reads them when a level loads
# (GameplayConfig.create_for_play), so a run never changes mid-way and stays deterministic. A value of the wrong type
# from the console falls back to the default with an error.
# Related: src/core/telemetry.gd, src/gameplay/defs/gameplay_config.gd, src/core/ads.gd, src/core/song_unlocks.gd
class_name RemoteSettings
extends RefCounted

const DEFAULTS: Dictionary[String, Variant] = {
	## Ads: play time between two interstitials.
	"ads_interstitial_gap_sec": 180.0,
	## Song unlocks (GD3-242).
	"unlock_free_songs": 3,
	"unlock_progress": 0.8,
	"rewarded_trials": true,
	## Gameplay: PERFECT hits per shield charge, and a scale on every timing window (1 = as designed).
	"shield_combo": 16,
	"timing_window_scale": 1.0,
}
const WINDOW_SCALE_RANGE := Vector2(0.75, 1.5)

static var _values: Dictionary[String, Variant] = {}
static var _started: bool = false


## Once at startup: sends the defaults to Remote Config and fetches; values update when the fetch completes.
static func start() -> void:
	if _started or not Engine.has_singleton(Telemetry.PLUGIN_SINGLETON):
		return
	_started = true
	var plugin: Object = Engine.get_singleton(Telemetry.PLUGIN_SINGLETON)
	plugin.connect(&"remote_config_updated", func(_success: bool) -> void: load_json(str(plugin.call(&"remote_config_json"))))
	load_json(str(plugin.call(&"remote_config_json")))
	plugin.call(&"fetch_remote_config", DEFAULTS)


static func get_float(key: String) -> float:
	return float(_value(key))


static func get_int(key: String) -> int:
	return int(_value(key))


static func get_bool(key: String) -> bool:
	return bool(_value(key))


## Applies Remote Config's values (a JSON object of strings), typed after DEFAULTS; unknown keys are ignored.
static func load_json(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("RemoteSettings: bad Remote Config JSON")
		return
	var remote: Dictionary = parsed
	for key: String in DEFAULTS:
		if not remote.has(key):
			continue
		var raw: String = str(remote[key])
		match typeof(DEFAULTS[key]):
			TYPE_BOOL:
				if raw in ["true", "false"]:
					_values[key] = raw == "true"
				else:
					push_error("RemoteSettings: '%s' is not a bool: %s" % [key, raw])
			TYPE_INT:
				if raw.is_valid_int():
					_values[key] = raw.to_int()
				else:
					push_error("RemoteSettings: '%s' is not an int: %s" % [key, raw])
			_:
				if raw.is_valid_float():
					_values[key] = raw.to_float()
				else:
					push_error("RemoteSettings: '%s' is not a number: %s" % [key, raw])


## Back to the defaults (tests).
static func reset() -> void:
	_values.clear()


static func _value(key: String) -> Variant:
	if not DEFAULTS.has(key):
		push_error("RemoteSettings: unknown key '%s'" % key)
		return 0
	return _values.get(key, DEFAULTS[key])
