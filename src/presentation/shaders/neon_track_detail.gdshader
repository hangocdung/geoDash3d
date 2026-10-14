// Track shader with detail textures (tiers where QualityTier.uses_detail_textures); otherwise identical to
// neon_track.gdshader. Related: neon_track.gdshaderinc, src/presentation/track/track_view.gd
shader_type spatial;

#define DETAIL_TEXTURES
#include "res://src/presentation/shaders/neon_track.gdshaderinc"
