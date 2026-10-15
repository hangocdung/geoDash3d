# Landscape and portrait in one build (GD3-210): menus follow the phone's rotation, a level locks the orientation it
# started in until the player is back in the menu. The UI canvas is 1920x1080 or 1080x1920 to match the window, and
# presentation asks is_portrait() per viewport. `-- --portrait` (also from user://debug_args.txt on a debug APK) forces
# portrait: a 720x1280 window on desktop, portrait lock on phones; `--landscape` forces landscape (device perf runs).
# Related: src/ui/scenes.gd (lock/unlock on scene change), src/presentation/camera/camera_shots.gd
class_name DisplayOrientation
extends RefCounted

const ARGUMENT: String = "--portrait"
## Forces landscape on phones (device perf runs: a phone lying flat would otherwise start in portrait).
const LANDSCAPE_ARGUMENT: String = "--landscape"
const LANDSCAPE_CANVAS := Vector2i(1920, 1080)
const PORTRAIT_CANVAS := Vector2i(1080, 1920)
const DESKTOP_PORTRAIT_WINDOW := Vector2i(720, 1280)
const _CONNECTED_META: StringName = &"display_orientation_connected"


static func forced_portrait() -> bool:
	return LaunchOptions.user_args().has(ARGUMENT)


## Called once at startup (main menu): fits the canvas now and on every resize/rotation.
static func setup(window: Window) -> void:
	if not window.has_meta(_CONNECTED_META):
		window.set_meta(_CONNECTED_META, true)
		window.size_changed.connect(func() -> void: _fit_canvas(window))
		if forced_portrait() and not OS.has_feature("mobile"):
			DisplayServer.window_set_size(DESKTOP_PORTRAIT_WINDOW)
			var screen: Rect2i = DisplayServer.screen_get_usable_rect()
			DisplayServer.window_set_position(screen.position + (screen.size - DESKTOP_PORTRAIT_WINDOW) / 2)
	_fit_canvas(window)


## Menus: follow the sensor (any orientation), unless portrait is forced.
static func allow_rotation() -> void:
	if not OS.has_feature("mobile"):
		return
	if forced_portrait():
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_PORTRAIT)
	elif LaunchOptions.user_args().has(LANDSCAPE_ARGUMENT):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	else:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)


## Levels and tools: keep the current orientation (180-degree flips still allowed) until allow_rotation().
static func lock_current(window: Window) -> void:
	if not OS.has_feature("mobile"):
		return
	# A forced orientation wins: the menu may hand over before the requested rotation has happened.
	var portrait: bool = forced_portrait() or (_window_is_portrait(window)
			and not LaunchOptions.user_args().has(LANDSCAPE_ARGUMENT))
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_PORTRAIT if portrait
			else DisplayServer.SCREEN_SENSOR_LANDSCAPE)


## True when the viewport is taller than wide.
static func is_portrait(viewport: Viewport) -> bool:
	var size: Vector2 = viewport.get_visible_rect().size
	return size.y > size.x


static func _window_is_portrait(window: Window) -> bool:
	return window.size.y > window.size.x


static func _fit_canvas(window: Window) -> void:
	window.content_scale_size = PORTRAIT_CANVAS if _window_is_portrait(window) else LANDSCAPE_CANVAS
