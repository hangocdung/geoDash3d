# Audio bus layout created at startup (no hand-edited bus .tres): Music, SFX and UI under Master.
# UserSettings drives their volumes. Related: src/core/user_settings.gd, src/core/audio/sfx.gd
class_name AudioBuses
extends RefCounted

const MUSIC: StringName = &"Music"
const SFX: StringName = &"SFX"
const UI: StringName = &"UI"
const MUTED_DB: float = -80.0


static func ensure_layout() -> void:
	for bus_name: StringName in [MUSIC, SFX, UI]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")


static func set_volume(bus_name: StringName, volume_db: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_error("AudioBuses: bus '%s' does not exist" % bus_name)
		return
	AudioServer.set_bus_volume_db(index, volume_db)
	AudioServer.set_bus_mute(index, volume_db <= MUTED_DB + 0.5)
