# Graphics quality tiers shared by UserSettings and presentation nodes.
# Presentation reads the tier to scale glow, particles and optional post effects.
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
