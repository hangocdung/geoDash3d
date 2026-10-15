// Box with glowing edges of constant world width (works for scaled MultiMesh instances).
// Mesh must be a unit cube (±0.5). Instance/vertex COLOR tints the edge color.
// Optional face (two eyes and a mouth, kept upright as the cube rolls) on the local +Z side for the player cube.
// `palette_role` 1 (scenery: COLOR.r = brightness, COLOR.g = mix between the two scenery colors) / 2 (pillars)
// takes the edge tint from the phase palette globals. The detail variant (neon_box_detail.gdshader) also
// samples the packed scenery texture once per pixel for those roles, in world units on each face: lit
// windows and facade structure on scenery, vertical ribs on pillars. Shared body: neon_box.gdshaderinc.
shader_type spatial;

#include "res://src/presentation/shaders/neon_box.gdshaderinc"
