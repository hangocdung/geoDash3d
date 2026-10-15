# Content-only remote settings. Firebase RemoteSettings remains the gameplay source.
# Related: ContentManifest, ContentDownloader, SongCatalog.
class_name ContentCatalog
extends RefCounted

const ROOT: String = "user://content"
const URL: String = "https://cdn.sntgames.com/beatglide/prod/manifest.json"
static var manifest: Dictionary = {}
static var loaded: bool = false


static func settings() -> Dictionary:
	if OS.is_debug_build() and FileAccess.file_exists("user://content_staging.json"):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://content_staging.json"))
		if value is Dictionary and value.get("token", "") is String:
			return value
	return {}


static func headers() -> PackedStringArray:
	var local: Dictionary = settings()
	var result: PackedStringArray = ["User-Agent: BeatGlide/1.0"]
	if local.has("token"):
		result.append("Authorization: Bearer " + str(local["token"]))
	return result


static func manifest_url() -> String:
	return "https://api.sntgames.com/v1/beatglide/staging/manifest.json" if not settings().is_empty() else URL


static func cache_path() -> String:
	return ROOT + ("/staging_manifest.json" if not settings().is_empty() else "/manifest.json")


static func load_cache() -> void:
	if loaded:
		return
	loaded = true
	if FileAccess.file_exists(cache_path()):
		manifest = ContentManifest.parse(FileAccess.get_file_as_string(cache_path()))


static func songs() -> Array:
	load_cache()
	return manifest.get("songs", [])


static func directory(song: Dictionary) -> String:
	return "%s/%s/%d" % [ROOT, song["package_id"], int(song["version"])]


static func chart_path(song: Dictionary) -> String:
	return directory(song).path_join(str(song["chart"]))


static func installed(song: Dictionary) -> bool:
	var marker: String = directory(song).path_join("installed.json")
	if not FileAccess.file_exists(marker):
		return false
	for item: Dictionary in song["files"]:
		var file := FileAccess.open(directory(song).path_join(str(item["name"])), FileAccess.READ)
		if file == null or file.get_length() != int(item["size"]):
			return false
	return FileAccess.get_file_as_string(marker) == JSON.stringify(song["files"])


static func cover_path(id: String) -> String:
	for song: Dictionary in songs():
		if song["id"] == id and installed(song):
			return directory(song).path_join("cover.jpg")
	return "res://assets/covers/" + id.trim_suffix("_led") + ".jpg"
