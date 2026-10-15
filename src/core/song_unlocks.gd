# Which songs can be played (GD3-242, approved 2026-10-15, docs/design/song_unlocks.md). Main chain = songs that are
# neither EXPERT variants (*_led) nor bonus songs, easiest first: the first FREE_SONGS are open, each next one opens
# when the one before it is open and was cleared or reached PROGRESS_TO_UNLOCK. A variant or bonus song opens when its
# base song is open and cleared. unlock_all_songs (IAP) or `-- --unlock-all` open everything; a rewarded "trial" opens
# one locked song until the player leaves the level. Computed from HighScores each time, so nothing extra is saved.
# Related: src/core/song_catalog.gd, src/core/high_scores.gd, src/core/entitlements.gd, src/ui/menu/song_list_panel.gd
class_name SongUnlocks
extends RefCounted

const FREE_SONGS: int = 3
const PROGRESS_TO_UNLOCK: float = 0.8
const VARIANT_SUFFIX: String = "_led"
## Bonus song id → the song whose clear opens it (outside the main chain).
const BONUS: Dictionary[String, String] = {"the_dawn_assembly": "fault_line"}
const UNLOCK_ALL_ARGUMENT: String = "--unlock-all"

## Chart path of the song opened by a rewarded trial ("" = none); cleared when the main menu opens again.
static var trial_path: String = ""


## Open song paths of `ordered` (SongCatalog order) as a set.
static func unlocked(ordered: PackedStringArray) -> Dictionary[String, bool]:
	var result: Dictionary[String, bool] = {}
	var open_all: bool = Entitlements.has(Entitlements.UNLOCK_ALL_SONGS) \
			or OS.get_cmdline_user_args().has(UNLOCK_ALL_ARGUMENT)
	var by_id: Dictionary[String, String] = {}
	for path: String in ordered:
		by_id[SongCatalog.song_id(path)] = path
	var previous_open: bool = true
	var previous_done: bool = true
	var index: int = 0
	for path: String in main_chain(ordered):
		var open: bool = open_all or index < FREE_SONGS or (previous_open and previous_done)
		if open:
			result[path] = true
		var record: HighScores.Record = HighScores.best(path)
		previous_open = open
		previous_done = record.completed or record.progress >= PROGRESS_TO_UNLOCK
		index += 1
	# Variants and bonus songs: open when their base is open and cleared. A base can itself be a bonus song (the bonus
	# song's EXPERT variant), so repeat until nothing changes.
	var changed: bool = true
	while changed:
		changed = false
		for path: String in ordered:
			var base: String = base_song(SongCatalog.song_id(path))
			if base.is_empty() or result.has(path):
				continue
			var base_path: String = by_id.get(base, "")
			if open_all or (result.has(base_path) and HighScores.best(base_path).completed):
				result[path] = true
				changed = true
	return result


static func is_unlocked(path: String, ordered: PackedStringArray) -> bool:
	return unlocked(ordered).has(path) or path == trial_path


## The main chain (no variants, no bonus songs), keeping `ordered`'s order.
static func main_chain(ordered: PackedStringArray) -> PackedStringArray:
	var chain: PackedStringArray = []
	for path: String in ordered:
		if base_song(SongCatalog.song_id(path)).is_empty():
			chain.append(path)
	return chain


## Id of the song a variant or bonus song depends on ("" for main-chain songs).
static func base_song(id: String) -> String:
	if BONUS.has(id):
		return BONUS[id]
	if id.ends_with(VARIANT_SUFFIX):
		return id.trim_suffix(VARIANT_SUFFIX)
	return ""


## The song to clear (or reach PROGRESS_TO_UNLOCK on, for the main chain) to open `path` ("" when open or unknown).
static func requirement(path: String, ordered: PackedStringArray) -> String:
	var base: String = base_song(SongCatalog.song_id(path))
	if not base.is_empty():
		for candidate: String in ordered:
			if SongCatalog.song_id(candidate) == base:
				return candidate
		return ""
	var chain: PackedStringArray = main_chain(ordered)
	var index: int = chain.find(path)
	return chain[index - 1] if index > 0 else ""


## True when `requirement` needs a full clear (variants, bonus songs) rather than clear-or-80 %.
static func needs_clear(path: String) -> bool:
	return not base_song(SongCatalog.song_id(path)).is_empty()


static func ordered_paths() -> PackedStringArray:
	var paths: PackedStringArray = []
	for entry: SongCatalog.Entry in SongCatalog.list_songs():
		paths.append(entry.path)
	return paths
