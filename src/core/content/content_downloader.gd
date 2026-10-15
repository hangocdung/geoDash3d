# Menu-owned downloader: bounded files, frame-chunked SHA256, atomic cache activation.
# Leaving the menu frees HTTPRequest and aborts the job; gameplay never runs this worker.
class_name ContentDownloader
extends Node

signal changed
signal progress(text: String)
const CACHE_LIMIT: int = 512 * 1024 * 1024
var busy: bool = false
var cache_limit: int = CACHE_LIMIT
var _http: HTTPRequest
var _validation_task: int = -1

class ChartCheck extends RefCounted:
	var valid: bool = false

	func run(path: String, config: GameplayConfig) -> void:
		valid = ChartLoader.load_file(path, config) != null


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = 30.0
	_http.max_redirects = 0
	add_child(_http)


func refresh() -> void:
	if busy:
		return
	busy = true
	_http.body_size_limit = 2 * 1024 * 1024
	if _http.request(ContentCatalog.manifest_url(), ContentCatalog.headers()) == OK:
		var result: Array = await _http.request_completed
		if result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200:
			var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
			var parsed: Dictionary = ContentManifest.parse(text)
			if not parsed.is_empty() and int(parsed["catalog_version"]) >= int(ContentCatalog.manifest.get("catalog_version", 0)):
				DirAccess.make_dir_recursive_absolute(ContentCatalog.ROOT)
				var file := FileAccess.open(ContentCatalog.cache_path() + ".tmp", FileAccess.WRITE)
				if file != null:
					file.store_string(text)
					file.close()
					DirAccess.rename_absolute(ContentCatalog.cache_path() + ".tmp", ContentCatalog.cache_path())
					ContentCatalog.manifest = parsed
					ContentCatalog.loaded = true
	busy = false
	changed.emit()


func download(song: Dictionary) -> void:
	if busy:
		return
	busy = true
	var directory: String = ContentCatalog.directory(song)
	var required: int = 0
	for item: Dictionary in song["files"]:
		required += int(item["size"])
	if _used_bytes(ContentCatalog.ROOT) + required > cache_limit:
		_finish("Content storage limit reached")
		return
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		_finish("Cannot create content folder")
		return
	for item: Dictionary in song["files"]:
		var path: String = directory.path_join(str(item["name"]))
		if await _verified(path, item):
			continue
		progress.emit("Downloading %s" % item["name"])
		_http.download_file = path + ".part"
		_http.body_size_limit = int(item["size"])
		if _http.request(str(item["url"]), ContentCatalog.headers()) != OK:
			_finish("Download failed; tap to retry")
			return
		var result: Array = await _http.request_completed
		if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 200 \
				or not await _verified(path + ".part", item):
			DirAccess.remove_absolute(path + ".part")
			_finish("Download interrupted or invalid (%d/%d); tap to retry" % [int(result[0]), int(result[1])])
			return
		if DirAccess.rename_absolute(path + ".part", path) != OK:
			_finish("Cannot save download")
			return
	var check := ChartCheck.new()
	_validation_task = WorkerThreadPool.add_task(check.run.bind(
			ContentCatalog.chart_path(song), GameplayConfig.create_default()), false, "Validate download")
	while not WorkerThreadPool.is_task_completed(_validation_task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(_validation_task)
	_validation_task = -1
	if not check.valid:
		_finish("Invalid chart")
		return
	var marker := FileAccess.open(directory.path_join("installed.json"), FileAccess.WRITE)
	if marker == null:
		_finish("Cannot save content index")
		return
	marker.store_string(JSON.stringify(song["files"]))
	marker.close()
	_finish("Download complete")


func _verified(path: String, item: Dictionary) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != int(item["size"]):
		return false
	var hash_value := HashingContext.new()
	hash_value.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length():
		hash_value.update(file.get_buffer(65536))
		await get_tree().process_frame
	file.close()
	return hash_value.finish().hex_encode() == str(item["sha256"])


func remove_downloads() -> void:
	if not busy:
		_remove_tree(ContentCatalog.ROOT)
		ContentCatalog.manifest = {}
		ContentCatalog.loaded = false
		changed.emit()


func _remove_tree(directory: String) -> void:
	for name: String in DirAccess.get_directories_at(directory):
		_remove_tree(directory.path_join(name))
	for name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)


func _used_bytes(directory: String) -> int:
	var total: int = 0
	for name: String in DirAccess.get_files_at(directory):
		var file := FileAccess.open(directory.path_join(name), FileAccess.READ)
		if file != null:
			total += file.get_length()
	for name: String in DirAccess.get_directories_at(directory):
		total += _used_bytes(directory.path_join(name))
	return total


func _finish(message: String) -> void:
	_http.download_file = ""
	busy = false
	progress.emit(message)
	changed.emit()


func _exit_tree() -> void:
	if _validation_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_validation_task)
		_validation_task = -1
