# Portrait prototype (GD3-210): a build exported with the "portrait" feature, or `-- --portrait` on desktop, runs
# 9:16 (UI laid out on a 1080x1920 canvas, desktop window 720x1280); on a debug APK `--portrait` can also come from
# user://debug_args.txt (perf A/B on one build). Presentation asks is_portrait() per viewport.
# Related: src/ui/menu/main_menu.gd (applies it at startup), src/presentation/camera/camera_shots.gd
class_name DisplayOrientation
extends RefCounted

const FEATURE: String = "portrait"
const ARGUMENT: String = "--portrait"
const PORTRAIT_CANVAS := Vector2i(1080, 1920)
const DESKTOP_PORTRAIT_WINDOW := Vector2i(720, 1280)


static func wants_portrait() -> bool:
	return OS.has_feature(FEATURE) or LaunchOptions.user_args().has(ARGUMENT)


static func apply(window: Window) -> void:
	if not wants_portrait():
		return
	window.content_scale_size = PORTRAIT_CANVAS
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_PORTRAIT)
		return
	DisplayServer.window_set_size(DESKTOP_PORTRAIT_WINDOW)
	var screen: Rect2i = DisplayServer.screen_get_usable_rect()
	DisplayServer.window_set_position(screen.position + (screen.size - DESKTOP_PORTRAIT_WINDOW) / 2)


## True when the viewport is taller than wide (portrait build, or a desktop window resized that way).
static func is_portrait(viewport: Viewport) -> bool:
	var size: Vector2 = viewport.get_visible_rect().size
	return size.y > size.x
