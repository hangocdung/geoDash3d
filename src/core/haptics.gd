# Short phone vibrations for game feedback (GD3-253): PERFECT hits, shield breaks and deaths. No-op on desktop and when
# the player turns haptics off in Settings. Durations/strengths live here, callers name the moment.
# Related: src/presentation/level/presentation_router.gd, src/core/user_settings.gd (haptics), export_presets.cfg (vibrate)
class_name Haptics
extends RefCounted

enum Kind { PERFECT, SHIELD_BREAK, DEATH }

## [duration ms, amplitude 0..1] per Kind.
const PATTERNS: Dictionary[Kind, Vector2] = {
	Kind.PERFECT: Vector2(12.0, 0.35),
	Kind.SHIELD_BREAK: Vector2(35.0, 0.6),
	Kind.DEATH: Vector2(70.0, 1.0),
}


static func pulse(kind: Kind) -> void:
	if not UserSettings.haptics or not OS.has_feature("mobile"):
		return
	var pattern: Vector2 = PATTERNS[kind]
	Input.vibrate_handheld(int(pattern.x), pattern.y)
