# Validates untrusted content catalogs before replacing the cached manifest.
# Related: ContentCatalog, ContentDownloader, docs/chart_format.md.
class_name ContentManifest
extends RefCounted

const APP_VERSION: String = "1.0.0"
const MAX_FILE_BYTES: int = 64 * 1024 * 1024
const MAX_PACKAGE_BYTES: int = 128 * 1024 * 1024


static func compatible(version: String) -> bool:
	var parts: PackedStringArray = version.split(".")
	var current: PackedStringArray = APP_VERSION.split(".")
	if parts.size() != 3:
		return false
	for part: String in parts:
		if not part.is_valid_int() or int(part) < 0:
			return false
	for index: int in 3:
		if int(parts[index]) != int(current[index]):
			return int(parts[index]) < int(current[index])
	return true


static func safe_name(value: String) -> bool:
	if value.is_empty() or value.length() > 100:
		return false
	for character: String in value:
		if not (character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-"):
			return false
	return value != "." and value != ".."


static func parse(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var value: Variant = json.data
	if not value is Dictionary:
		return {}
	var root: Dictionary = value
	if root.get("schema_version") != 1 or not root.get("songs") is Array:
		return {}
	if not _integer(root.get("catalog_version")) or int(root["catalog_version"]) < 1:
		return {}
	if not compatible(str(root.get("min_app_version", ""))) or root["songs"].size() > 500:
		return {}
	var ids: Dictionary[String, bool] = {}
	for item: Variant in root["songs"]:
		if not item is Dictionary or not _valid_song(item):
			return {}
		var id: String = str(item["id"])
		if ids.has(id):
			return {}
		ids[id] = true
	return root


static func _valid_song(song: Dictionary) -> bool:
	for key: String in ["id", "package_id", "chart"]:
		if not safe_name(str(song.get(key, ""))):
			return false
	if not _integer(song.get("version")):
		return false
	if not song.get("enabled", true) is bool or not song.get("featured", false) is bool:
		return false
	for key: String in ["bpm", "length", "difficulty", "order"]:
		if song.has(key) and (not _number(song[key]) or float(song[key]) < 0.0):
			return false
	if int(song["version"]) < 1 or int(song["version"]) > 2147483647 \
			or not song.get("files") is Array or not song.get("license") is Dictionary:
		return false
	var names: Dictionary[String, bool] = {}
	var size: int = 0
	for file: Variant in song["files"]:
		if not file is Dictionary or not safe_name(str(file.get("name", ""))):
			return false
		var name: String = str(file["name"])
		var hash_value: String = str(file.get("sha256", ""))
		if not _integer(file.get("size")):
			return false
		var bytes: int = int(file.get("size", 0))
		if names.has(name) or bytes <= 0 or bytes > MAX_FILE_BYTES or hash_value.length() != 64 \
				or not hash_value.is_valid_hex_number():
			return false
		var url: String = str(file.get("url", ""))
		if not (url.begins_with("https://cdn.sntgames.com/beatglide/prod/") \
				or url.begins_with("https://api.sntgames.com/v1/beatglide/staging/files/")):
			return false
		names[name] = true
		size += bytes
	return size <= MAX_PACKAGE_BYTES and names.has(str(song["chart"])) and names.has("song.mp3") \
			and names.has("song.spectrum.json") and names.has("cover.jpg")


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _integer(value: Variant) -> bool:
	return _number(value) and float(value) == floorf(float(value))
