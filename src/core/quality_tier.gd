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
static func render_scale(tier: Tier) -> float:
	match tier:
		Tier.LOW:
			return 0.6
		Tier.MEDIUM:
			return 0.75
	return 1.0


static func apply_to_viewport(viewport: Viewport, tier: Tier) -> void:
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = render_scale(tier)
	viewport.msaa_3d = Viewport.MSAA_2X if tier == Tier.HIGH else Viewport.MSAA_DISABLED
