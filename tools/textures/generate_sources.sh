#!/usr/bin/env bash
# Generates the texture source images (art_source/textures/<name>.png, not committed) with Codex image
# generation, one Codex session per image; then run tools/textures/build_textures.py.
# Usage: bash tools/textures/generate_sources.sh [out_dir] [work_dir]  (skips names that already exist; delete
# a file to regenerate it). Needs the codex CLI logged in. Related: tools/textures/build_textures.py
OUT="${1:-art_source/textures}"; WORK="${2:-${TMPDIR:-/tmp}/codex_textures}"
mkdir -p "$OUT" "$WORK"
COMMON="Seamless tileable square texture, perfectly tileable on all four edges, flat orthographic top-down view, no perspective, no shadows from a light direction, even flat lighting, grayscale only, high contrast, crisp details, no text, no logos, no watermark."
declare -A PROMPTS=(
  [track_panel]="Sci-fi racing track floor: a grid of dark metal floor plates separated by thin engraved grooves, small rectangular inset panels, a few hexagonal bolts, subtle brushed-metal noise and tiny scratches. Plates mostly mid-dark gray, grooves near black. $COMMON"
  [hex_plate]="Futuristic armored floor made of interlocking hexagonal plates, each hexagon slightly beveled with a thin dark seam between them, a few hexagons with small inner circuit-like engraved lines, subtle metal noise. $COMMON"
  [side_panel]="Side wall of a futuristic elevated highway: horizontal bands of metal paneling with long horizontal vents, rivets, thin seams and a few rectangular access hatches, mostly dark gray. Pattern repeats horizontally and vertically. $COMMON"
  [tower_facade]="Facade of a futuristic skyscraper seen straight on: a regular grid of small rectangular windows, about 70 percent of windows dark and 30 percent glowing bright white, separated by thin dark metal mullions and horizontal floor bands, black background between windows. $COMMON"
  [circuit]="Glowing circuit board traces: thin bright white lines with right-angle and 45-degree turns and small round pads on a black background, sparse and clean, like a sci-fi energy circuit pattern. $COMMON"
  [pillar_ribs]="Industrial sci-fi support column surface unrolled flat: vertical ribs and grooves, horizontal segment joints every so often, bolts along the joints, dark metal with subtle wear. $COMMON"
)
for NAME in track_panel hex_plate side_panel tower_facade circuit pillar_ribs; do
  if [ -f "$OUT/$NAME.png" ]; then echo "skip $NAME"; continue; fi
  LOG="$WORK/$NAME.log"
  codex exec --skip-git-repo-check -s read-only -C "$WORK" "Use your built-in image generation tool to create exactly ONE image. Do not run any shell commands or tools other than image generation. Image: ${PROMPTS[$NAME]}" > "$LOG" 2>&1
  SID=$(grep -m1 "session id:" "$LOG" | awk '{print $3}' | tr -d '\r')
  IMG=$(ls -t "$HOME/.codex/generated_images/$SID/"*.png 2>/dev/null | head -1)
  if [ -n "$IMG" ]; then cp "$IMG" "$OUT/$NAME.png"; echo "ok $NAME <- $IMG"; else echo "FAILED $NAME (session $SID)"; fi
done
