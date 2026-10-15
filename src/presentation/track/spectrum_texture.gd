# Loads a song's precomputed equalizer (<song>.spectrum.json, tools/audio/build_spectrum.py) into an RG8 texture
# for the LED wall on the road's camera-side face (R = VU level, G = peak dot); null when the song has none.
# Related: src/presentation/track/track_view.gd, src/presentation/shaders/neon_track.gdshaderinc
class_name SpectrumTexture
extends RefCounted

## Must match the shader's SPECTRUM_BANDS.
const BANDS: int = 16

var texture: ImageTexture
var frames: int = 0
var fps: float = 30.0
## Frames per image row block (the shader wraps long songs onto further rows).
var row: int = 2048


## Data next to `song_path` (res://assets/music/<id>.mp3 → <id>.spectrum.json), or null if there is none.
static func load_for_song(song_path: String) -> SpectrumTexture:
	var path: String = song_path.get_basename() + ".spectrum.json"
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("SpectrumTexture: cannot parse '%s'" % path)
		return null
	var root: Dictionary = data
	var result := SpectrumTexture.new()
	result.frames = int(root.get("frames", 0))
	result.fps = float(root.get("fps", 30.0))
	result.row = int(root.get("row", 2048))
	if int(root.get("bands", 0)) != BANDS or result.frames <= 0 or result.row <= 0:
		push_error("SpectrumTexture: '%s' needs %d bands and frames > 0" % [path, BANDS])
		return null
	var bytes: PackedByteArray = Marshalls.base64_to_raw(str(root.get("data", "")))
	var height: int = BANDS * ceili(float(result.frames) / float(result.row))
	if bytes.size() != result.row * height * 2:
		push_error("SpectrumTexture: '%s' holds %d bytes, expected %d" % [path, bytes.size(), result.row * height * 2])
		return null
	result.texture = ImageTexture.create_from_image(Image.create_from_data(result.row, height, false,
			Image.FORMAT_RG8, bytes))
	return result
