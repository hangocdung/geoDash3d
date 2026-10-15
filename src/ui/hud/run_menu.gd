# Overlay shown when the run is paused or complete: a glowing card with the title, stats and RESUME, RESTART and MENU;
# results also show the rank (S/A/B/C) and NEXT SONG when another song is open (GD3-251).
# Buttons never take keyboard focus, so Space keeps meaning "tap" in the level.
# Related: src/ui/hud/hud.gd, src/presentation/level/level_runner.gd, src/ui/theme/ui_kit.gd
class_name RunMenu
extends Control

signal resume_pressed
signal restart_pressed
signal menu_pressed
signal next_pressed

const RANK_COLORS: Dictionary[String, Color] = {"S": Color(1.0, 0.85, 0.3), "A": Color(0.4, 1.0, 0.7),
		"B": Color(0.5, 0.8, 1.0), "C": Color(0.75, 0.75, 0.85)}
const CARD_WIDTH: float = 640.0

var _icon: TextureRect
var _title: Label
var _details: Label
var _resume_button: Button
var _next_button: Button
var _rating: SongRatingWidget
var _column: VBoxContainer
var _rank: Label


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.0, 0.05, 0.62)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = "Dialog"
	center.add_child(card)
	var column := VBoxContainer.new()
	_column = column
	column.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	column.add_theme_constant_override("separation", 16)
	card.add_child(column)
	_rank = UiKit.label("", "", HORIZONTAL_ALIGNMENT_CENTER)
	_rank.add_theme_font_override("font", UiTheme.heading_font())
	_rank.add_theme_font_size_override("font_size", 132)
	_rank.add_theme_constant_override("outline_size", 14)
	column.add_child(_rank)
	var heading := HBoxContainer.new()
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 18)
	_icon = UiKit.icon_rect(&"pause", 52, UiTheme.HOT)
	heading.add_child(_icon)
	_title = UiKit.label("", "SectionTitle", HORIZONTAL_ALIGNMENT_CENTER)
	_title.add_theme_font_size_override("font_size", 52)
	heading.add_child(_title)
	column.add_child(heading)
	# Wraps on narrow (portrait) screens instead of running off the edges.
	_details = UiKit.label("", "", HORIZONTAL_ALIGNMENT_CENTER)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size", 28)
	_details.add_theme_color_override("font_color", UiTheme.MUTED)
	column.add_child(_details)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	column.add_child(spacer)
	_next_button = _add_button(column, "NEXT SONG", &"next", true, next_pressed)
	_resume_button = _add_button(column, "RESUME", &"play", true, resume_pressed)
	_add_button(column, "RESTART", &"restart", false, restart_pressed)
	_add_button(column, "MENU", &"home", false, menu_pressed)
	visible = false


## `title`: first line is the heading, the rest the details.
func open(title: String, can_resume: bool) -> void:
	var lines: PackedStringArray = title.split("\n", true, 1)
	_title.text = lines[0]
	_details.text = lines[1] if lines.size() > 1 else ""
	_details.visible = not _details.text.is_empty()
	_icon.texture = UiIcons.get_icon(&"pause", 52, UiTheme.HOT)
	_rank.visible = false
	_next_button.visible = false
	_resume_button.visible = can_resume
	if is_instance_valid(_rating):
		_rating.queue_free()
	visible = true


## Level complete: big rank, the stats, NEXT SONG when `has_next`.
func open_results(text: String, rank: String, has_next: bool) -> void:
	open(text, false)
	_icon.texture = UiIcons.get_icon(&"trophy", 52, UiTheme.HOT)
	_rank.text = rank
	_rank.add_theme_color_override("font_color", RANK_COLORS.get(rank, Color.WHITE))
	_rank.add_theme_color_override("font_outline_color", Color(RANK_COLORS.get(rank, Color.WHITE), 0.25))
	_rank.visible = true
	_next_button.visible = has_next


func close() -> void:
	visible = false


func _add_button(parent: Control, text: String, icon: StringName, primary: bool, emitted: Signal) -> Button:
	var button: Button = UiKit.button(text, icon, "PrimaryButton" if primary else "", false, Vector2(0, 72))
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: emitted.emit())
	parent.add_child(button)
	return button


func offer_song_rating(id: String) -> void:
	var ratings: SongRatings = SongRatings.start(get_tree())
	if ratings.prompted(id):
		return
	ratings.mark_prompted(id)
	_rating = SongRatingWidget.new()
	_rating.song_id = id
	_column.add_child(_rating)
	_column.move_child(_rating, _details.get_index() + 1)
