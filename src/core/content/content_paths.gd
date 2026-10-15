# Shared runtime loading for built-in and downloaded music/cover assets.
# Related: ChartLoader, LevelLoader, SongRow, ContentCatalog.
class_name ContentPaths
extends RefCounted


static func resolve(reference: String, chart_path: String) -> String:
	if reference.begins_with("res://"):
		return reference if not chart_path.begins_with("user://") else ""
	if reference.is_absolute_path() or reference.contains(":") or reference.contains("\\"):
		return ""
	for part: String in reference.split("/"):
		if part == ".." or part.is_empty():
			return ""
	return chart_path.get_base_dir().path_join(reference)


static func audio(path: String) -> AudioStream:
	if path.begins_with("res://"):
		return load(path) as AudioStream
	if path.begins_with("user://content/") and path.get_extension() == "mp3":
		return AudioStreamMP3.load_from_file(path)
	return null


static func cover(path: String) -> Texture2D:
	if path.begins_with("res://"):
		return load(path) as Texture2D if ResourceLoader.exists(path) else null
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load_jpg_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return ImageTexture.create_from_image(image)


static func revision(path: String) -> int:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return maxi(1, int((data as Dictionary).get("chart_revision", 1))) if data is Dictionary else 1


static func score_key(path: String) -> String:
	var version: int = revision(path)
	return path.get_file() + ("@r%d" % version if version > 1 else "")
