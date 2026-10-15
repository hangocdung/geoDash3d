# What the player has bought (GD3-241), saved in user://entitlements.cfg so it works offline; the Play Store purchase
# list re-confirms it at every launch (Store). REMOVE_ADS turns off interstitials and the banner (Ads.enabled);
# UNLOCK_ALL_SONGS is kept for the song locks of GD3-242 (no song is locked yet).
# Related: src/core/store.gd, src/core/ads.gd, src/ui/menu/shop_panel.gd
class_name Entitlements
extends RefCounted

const REMOVE_ADS: StringName = &"remove_ads"
const UNLOCK_ALL_SONGS: StringName = &"unlock_all_songs"
const ALL: Array[StringName] = [REMOVE_ADS, UNLOCK_ALL_SONGS]
const SECTION: String = "owned"

static var path: String = "user://entitlements.cfg"
static var _owned: Dictionary[StringName, bool] = {}
static var _loaded: bool = false


static func has(entitlement: StringName) -> bool:
	_ensure_loaded()
	return _owned.get(entitlement, false)


## Records `entitlement` (saved at once); returns true when it is new.
static func grant(entitlement: StringName) -> bool:
	if not ALL.has(entitlement):
		push_error("Entitlements: unknown entitlement '%s'" % entitlement)
		return false
	_ensure_loaded()
	if _owned.get(entitlement, false):
		return false
	_owned[entitlement] = true
	_save()
	if entitlement == REMOVE_ADS:
		Ads.enabled = false
		Ads.hide_banner()
	return true


## Applies the saved entitlements to the services that read them (startup).
static func apply() -> void:
	Ads.enabled = not has(REMOVE_ADS)


## Forgets everything in memory and reloads from `path` on next use (tests).
static func reset_cache() -> void:
	_owned.clear()
	_loaded = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	var error: Error = config.load(path)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		push_error("Entitlements: cannot read %s (%s)" % [path, error_string(error)])
		return
	for entitlement: StringName in ALL:
		_owned[entitlement] = bool(config.get_value(SECTION, String(entitlement), false))


static func _save() -> void:
	var config := ConfigFile.new()
	for entitlement: StringName in _owned:
		config.set_value(SECTION, String(entitlement), _owned[entitlement])
	var error: Error = config.save(path)
	if error != OK:
		push_error("Entitlements: cannot write %s (%s)" % [path, error_string(error)])
