// Box shader with detail textures for scenery and pillars (tiers where QualityTier.uses_detail_textures);
// otherwise identical to neon_box.gdshader. Related: neon_box.gdshaderinc, scenery_view.gd, track_view.gd
shader_type spatial;

#define DETAIL_TEXTURES
#include "res://src/presentation/shaders/neon_box.gdshaderinc"
