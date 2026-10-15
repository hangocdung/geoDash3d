# Menu controls for content synchronization, download progress and cache cleanup.
# Related: SongListPanel, ContentDownloader; this node never survives a gameplay launch.
class_name SongOnlinePanel
extends VBoxContainer

signal changed
var downloader: ContentDownloader
var _status: Label


func _ready() -> void:
	downloader = ContentDownloader.new()
	add_child(downloader)
	downloader.changed.connect(func() -> void: changed.emit())
	var row := HBoxContainer.new()
	add_child(row)
	var refresh: Button = UiKit.button("Refresh songs", &"", "", false, Vector2(0, 48))
	refresh.pressed.connect(downloader.refresh)
	row.add_child(refresh)
	var clear: Button = UiKit.button("Delete downloads", &"", "", false, Vector2(0, 48))
	clear.pressed.connect(downloader.remove_downloads)
	row.add_child(clear)
	_status = UiKit.label("", "Caption")
	add_child(_status)
	downloader.progress.connect(func(text: String) -> void: _status.text = text)
	downloader.refresh.call_deferred()


func download_row(entry: SongCatalog.Entry) -> Control:
	var button: Button = UiKit.button("%s · Download %.1f MB" % [entry.title,
			float(entry.remote.get("size", 0)) / 1048576.0], &"music", "", false, Vector2(0, 96))
	button.pressed.connect(func() -> void: downloader.download(entry.remote))
	return button


func _process(_delta: float) -> void:
	if downloader.busy and downloader._http.download_file != "":
		var size: int = downloader._http.get_body_size()
		_status.text = "Downloading %.1f / %.1f MB" % [float(downloader._http.get_downloaded_bytes()) / 1048576.0,
				float(maxi(size, 0)) / 1048576.0]
