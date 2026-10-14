# Graphics quality tiers shared by UserSettings and presentation nodes.
# Presentation reads the tier to scale glow, particles, render resolution and MSAA.
# Related: src/core/user_settings.gd
class_name QualityTier
extends RefCounted

enum Tier { LOW, MEDIUM, HIGH }


static func default_for_platform() -> Tier:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return Tier.MEDIUM
	return Tier.HIGH


static func from_int(value: int) -> Tier:
	match value:
		Tier.LOW:
			return Tier.LOW
		Tier.MEDIUM:
			return Tier.MEDIUM
		Tier.HIGH:
			return Tier.HIGH
	push_error("QualityTier: unknown tier %d, falling back to platform default" % value)
	return default_for_platform()


## Particle amount multiplier for the tier.
static func particle_scale(tier: Tier) -> float:
	match tier:
		Tier.LOW:
			return 0.35
		Tier.MEDIUM:
			return 0.7
	return 1.0


## 3D render scale: below 1.0 renders fewer pixels and upscales (big fill-rate win on phones).
## Measured on a Mali-G72 phone: glow costs a fixed ~14 FPS, so LOW drops glow and keeps more pixels.
static func render_scale(tier: Tier) -> float:
	match tier:
		Tier.LOW:
			return 0.7
		Tier.MEDIUM:
			return 0.6
	return 1.0


## The glow post-process is the most expensive effect on tile-based mobile GPUs; LOW uses shader halos.
static func uses_glow(tier: Tier) -> bool:
	return tier != Tier.LOW


static func apply_to_viewport(viewport: Viewport, tier: Tier) -> void:
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = render_scale(tier)
	viewport.msaa_3d = Viewport.MSAA_2X if tier == Tier.HIGH else Viewport.MSAA_DISABLED


## Speed lines (thin additive streaks beside the track): none on LOW, which has no fill-rate to spare.
static func speed_line_count(tier: Tier) -> int:
	match tier:
		Tier.LOW:
			return 0
		Tier.MEDIUM:
			return 18
	return 32


## Sky brightening on the beat. Off on LOW: measured on a Mali-G72 phone, a sky that changes every frame
## costs ~3 FPS there (up to ~10 in the chorus; likely lost tile transaction elimination), free on MEDIUM.
static func uses_sky_pulse(tier: Tier) -> bool:
	return tier != Tier.LOW


## Detail textures on the road, blocks, pillars and scenery (the *_detail shader variants: one extra texture
## sample per pixel there). HIGH only: measured on a Mali-G72 phone they cost ~1.6 FPS at MEDIUM (~3.5 %).
static func uses_detail_textures(tier: Tier) -> bool:
	return tier == Tier.HIGH


## Helices, loops, rolls and banked turns. Off on LOW (TrackPath.build flattens them): measured on a Mali-G72
## phone, a helix cost 5-7 FPS there; gameplay is unchanged (collision lives in track space).
static func uses_spectacle_track(tier: Tier) -> bool:
	return tier != Tier.LOW


## Phase palette changes blend over a beat; on LOW they switch on one frame (a sky that changes every frame
## costs ~3 FPS there, see uses_sky_pulse), hidden under the phase flash.
static func blends_phase_changes(tier: Tier) -> bool:
	return tier != Tier.LOW


## Fraction of background scenery kept (fill-rate on phones).
static func scenery_density(tier: Tier) -> float:
	match tier:
		Tier.LOW:
			return 0.55
		Tier.MEDIUM:
			return 0.8
	return 1.0
