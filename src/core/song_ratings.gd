# Song ratings, random installation ID and retryable local votes; distinct from store reviews.
# Related: SongRatingWidget, MainMenu, docs/release/privacy_policy.md.
class_name SongRatings
extends Node

signal changed
const API: String = "https://api.sntgames.com/v1/beatglide/ratings"
const SNAPSHOT: String = "https://cdn.sntgames.com/beatglide/prod/ratings.json"
const PATH: String = "user://song_ratings.cfg"
static var instance: SongRatings
var _state := ConfigFile.new()
var _http: HTTPRequest
var _busy: bool = false
var totals: Dictionary = {}


static func start(tree: SceneTree) -> SongRatings:
	if not is_instance_valid(instance):
		instance = SongRatings.new()
		tree.root.get_node("UserSettings").add_child(instance)
	return instance


func _ready() -> void:
	_state.load(PATH)
	if not _state.has_section_key("device", "id"):
		var value: String = Crypto.new().generate_random_bytes(16).hex_encode()
		_state.set_value("device", "id", "%s-%s-4%s-a%s-%s" % [value.left(8), value.substr(8, 4),
				value.substr(13, 3), value.substr(17, 3), value.substr(20, 12)])
		_state.save(PATH)
	totals = _state.get_value("cache", "songs", {})
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = 15.0
	_http.max_redirects = 0
	_http.body_size_limit = 1024 * 1024
	add_child(_http)


func refresh() -> void:
	if _busy:
		return
	_busy = true
	var staging: bool = not ContentCatalog.settings().is_empty()
	if _http.request(API + "?channel=staging" if staging else SNAPSHOT, ContentCatalog.headers()) == OK:
		var result: Array = await _http.request_completed
		if result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200:
			var data: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
			if data is Dictionary and data.get("schema_version") == 1 and data.get("songs") is Dictionary:
				totals = data["songs"]
				_state.set_value("cache", "songs", totals)
				_state.save(PATH)
	_busy = false
	changed.emit()
	for id: String in _state.get_section_keys("pending") if _state.has_section("pending") else PackedStringArray():
		await vote(id, int(_state.get_value("pending", id)))


func suspend() -> void:
	_http.cancel_request()
	_busy = false


func vote(id: String, stars: int) -> void:
	if stars < 1 or stars > 5:
		return
	_state.set_value("votes", id, stars)
	_state.set_value("pending", id, stars)
	_state.save(PATH)
	changed.emit()
	if _busy:
		return
	_busy = true
	var body: String = JSON.stringify({"song_id": id, "stars": stars, "install_id": _state.get_value("device", "id")})
	var headers: PackedStringArray = ContentCatalog.headers()
	headers.append("Content-Type: application/json")
	var url: String = API
	if not ContentCatalog.settings().is_empty():
		url += "?channel=staging"
	if _http.request(url, headers, HTTPClient.METHOD_POST, body) == OK:
		var result: Array = await _http.request_completed
		if result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200:
			if int(_state.get_value("pending", id, 0)) == stars:
				_state.erase_section_key("pending", id)
			_state.save(PATH)
			Telemetry.log_event("song_rate", {"song_id": id, "stars": stars})
	_busy = false
	changed.emit()


func prompted(id: String) -> bool:
	return bool(_state.get_value("prompted", id, false)) or _state.has_section_key("votes", id)


func mark_prompted(id: String) -> void:
	_state.set_value("prompted", id, true)
	_state.save(PATH)


func vote_label(id: String) -> String:
	var stars: int = int(_state.get_value("votes", id, 0))
	if stars == 0:
		return "Rate this song"
	return "Your rating: %d/5 · %s" % [stars, "Pending sync" if _state.has_section_key("pending", id) else "Saved"]


func summary(id: String) -> String:
	var value: Variant = totals.get(id)
	if not value is Dictionary or not value.get("avg") is float and not value.get("avg") is int:
		return ""
	if not value.get("count") is int and not value.get("count") is float:
		return ""
	var average: float = float(value.get("avg", 0.0))
	var count: int = int(value.get("count", 0))
	return "★ %.1f (%d)" % [average, count] if average >= 1.0 and average <= 5.0 and count > 0 else ""
