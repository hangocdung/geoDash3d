# Analytics facade (GD3-230/231): game code logs events here and never talks to a plugin directly. Events are checked
# against Firebase Analytics limits, kept in a short in-memory history (tests, debugging) and handed to the backend:
# the Firebase Android plugin's singleton when present, else a "TELEMETRY" console line in debug builds, else nothing.
# Callers decide when not to log (attract mode, autoplay, captures). start() also sends script errors to Crashlytics.
# Related: src/presentation/level/run_telemetry.gd, src/core/telemetry_logger.gd, android_plugins/geodash_firebase
class_name Telemetry
extends RefCounted

## Engine singleton the Firebase plugin (GD3-230) will register; it must expose log_event(name, Dictionary) and
## set_user_property(name, value).
const PLUGIN_SINGLETON: String = "GeoDashFirebase"
const MAX_NAME_LENGTH: int = 40
const MAX_PARAMS: int = 25
const MAX_TEXT_LENGTH: int = 100
const HISTORY_SIZE: int = 32
const RESERVED_PREFIXES: PackedStringArray = ["firebase_", "google_", "ga_"]

## Last events as {"name": String, "params": Dictionary}, oldest first.
static var history: Array[Dictionary] = []
## False stops the backend (tests); events are still validated and kept in `history`.
static var send_enabled: bool = true
static var _logger: TelemetryLogger


## Once at startup (UserSettings): on a build with the Firebase plugin, errors become Crashlytics non-fatals.
static func start() -> void:
	if _logger != null or not Engine.has_singleton(PLUGIN_SINGLETON):
		return
	_logger = TelemetryLogger.new()
	OS.add_logger(_logger)
	var plugin: Object = Engine.get_singleton(PLUGIN_SINGLETON)
	plugin.call(&"set_custom_key", "godot_version", Engine.get_version_info()["string"])
	plugin.call(&"set_custom_key", "quality_tier", QualityTier.Tier.keys()[UserSettings.quality_tier])


## True on a build where Firebase is configured and running.
static func is_live() -> bool:
	return Engine.has_singleton(PLUGIN_SINGLETON) and bool(Engine.get_singleton(PLUGIN_SINGLETON).call(&"is_ready"))


## Analytics app-instance ID ("" until known or without Firebase), for data deletion requests (privacy policy).
static func app_instance_id() -> String:
	if not Engine.has_singleton(PLUGIN_SINGLETON):
		return ""
	return str(Engine.get_singleton(PLUGIN_SINGLETON).call(&"get_app_instance_id"))


## A non-fatal Crashlytics issue (TelemetryLogger sends push_error messages here).
static func record_error(message: String) -> void:
	if send_enabled and Engine.has_singleton(PLUGIN_SINGLETON):
		Engine.get_singleton(PLUGIN_SINGLETON).call(&"record_error", message.left(1000))


## A line attached to the next crash report (where the player was: scene, song, beat).
static func breadcrumb(message: String) -> void:
	if send_enabled and Engine.has_singleton(PLUGIN_SINGLETON):
		Engine.get_singleton(PLUGIN_SINGLETON).call(&"crash_log", message)


static func log_event(event_name: String, params: Dictionary[String, Variant] = {}) -> void:
	var problem: String = validate(event_name, params)
	if not problem.is_empty():
		push_error("Telemetry: %s" % problem)
		return
	history.append({"name": event_name, "params": params})
	if history.size() > HISTORY_SIZE:
		history.pop_front()
	if not send_enabled:
		return
	if Engine.has_singleton(PLUGIN_SINGLETON):
		Engine.get_singleton(PLUGIN_SINGLETON).call(&"log_event", event_name, params)
		breadcrumb("%s %s" % [event_name, params.get("song_id", "")])
	elif OS.is_debug_build():
		print("TELEMETRY %s %s" % [event_name, JSON.stringify(params)])


static func set_user_property(property_name: String, value: String) -> void:
	if not _is_valid_name(property_name, 24) or value.length() > 36:
		push_error("Telemetry: bad user property '%s'='%s'" % [property_name, value])
		return
	if send_enabled and Engine.has_singleton(PLUGIN_SINGLETON):
		Engine.get_singleton(PLUGIN_SINGLETON).call(&"set_user_property", property_name, value)


## "" when the event fits Firebase Analytics' rules, else what is wrong.
static func validate(event_name: String, params: Dictionary[String, Variant]) -> String:
	if not _is_valid_name(event_name, MAX_NAME_LENGTH):
		return "bad event name '%s'" % event_name
	if params.size() > MAX_PARAMS:
		return "%s: %d params (max %d)" % [event_name, params.size(), MAX_PARAMS]
	for key: String in params:
		if not _is_valid_name(key, MAX_NAME_LENGTH):
			return "%s: bad param name '%s'" % [event_name, key]
		var value_type: int = typeof(params[key])
		if value_type == TYPE_STRING or value_type == TYPE_STRING_NAME:
			if str(params[key]).length() > MAX_TEXT_LENGTH:
				return "%s: param '%s' longer than %d" % [event_name, key, MAX_TEXT_LENGTH]
		elif not [TYPE_INT, TYPE_FLOAT, TYPE_BOOL].has(value_type):
			return "%s: param '%s' has type %s" % [event_name, key, type_string(value_type)]
	return ""


## ASCII letter first, then letters, digits and "_"; no reserved prefix.
static func _is_valid_name(text: String, max_length: int) -> bool:
	if text.length() > max_length:
		return false
	for prefix: String in RESERVED_PREFIXES:
		if text.begins_with(prefix):
			return false
	var pattern := RegEx.create_from_string("^[A-Za-z][A-Za-z0-9_]*$")
	return pattern.search(text) != null
