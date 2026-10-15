# Shared UiKit star selector used by completed runs and the song detail card.
# Related: SongRatings; store-review invitations remain independent.
class_name SongRatingWidget
extends VBoxContainer

var song_id: String = ""
var _label: Label
var _ratings: SongRatings


func _ready() -> void:
	_ratings = SongRatings.start(get_tree())
	_label = UiKit.label("", "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	for stars: int in range(1, 6):
		var button: Button = UiKit.button("★%d" % stars, &"", "", false, Vector2(76, 52))
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: _ratings.vote(song_id, stars))
		row.add_child(button)
	_ratings.changed.connect(_update)
	_update()


func _update() -> void:
	_label.text = _ratings.vote_label(song_id)
