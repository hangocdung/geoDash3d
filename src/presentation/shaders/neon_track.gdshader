// Track surface: dark tiles with a glowing grid on top and bright neon rails along both edges.
// COLOR.r = 1 on the top face, 0 on side faces; COLOR.g = 1 on end caps (step risers, gap edges).
// UV.x across (top) / down (sides, caps); UV.y = distance (top, sides) / 0..1 across (caps).
// On every beat an energy wave leaves the player and races ahead: a thin front across the track with a
// tail along the lane lines (pure function of the song beat and the player's track distance, so it never
// drifts from the music).
// `palette_role` 1 (road) / 2 (raised blocks) takes the colors from the phase palette globals instead.
// This variant has no detail texture code (tiers without detail textures run the original cost). The detail
// variant, neon_track_detail.gdshader, adds one sample of the packed detail texture (assets/textures, built by
// tools/textures/build_textures.py): plates with lit grooves and beat-pulsing circuit traces on the road, hex
// plates on raised blocks, vented panels on the sides. Shared body: neon_track.gdshaderinc.
shader_type spatial;

#include "res://src/presentation/shaders/neon_track.gdshaderinc"
