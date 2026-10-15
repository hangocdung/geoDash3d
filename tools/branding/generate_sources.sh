#!/usr/bin/env bash
# Generates the BeatGlide brand source images (logo, icon, one cover per song for the song list) (art_source/brand/<name>.png, not committed) with Codex image
# generation, one Codex session per image; then run tools/branding/build_brand.py.
# Usage: bash tools/branding/generate_sources.sh [out_dir] [work_dir]  (skips names that already exist; delete a file
# to regenerate it). Needs the codex CLI logged in. Related: tools/branding/build_brand.py
OUT="${1:-art_source/brand}"; WORK="${2:-${TMPDIR:-/tmp}/codex_brand}"
mkdir -p "$OUT" "$WORK"
STYLE="Neon synthwave style: glowing hot pink (#ff3fd8) and electric cyan (#38e8ff) light tubes with soft bloom, crisp vector-like shapes, high contrast, premium mobile game branding. No watermark, no extra text."
COVER="Square composition, cinematic digital painting, synthwave neon palette of purple, magenta and cyan, rich detail, readable as a small thumbnail, no text, no letters, no logo, no watermark."
declare -A PROMPTS=(
  [logo_a]="Game logo wordmark that reads exactly \"BeatGlide\" in bold, italic, rounded futuristic letters, with a smaller line underneath that reads exactly \"RIDE THE RHYTHM\". A thin glowing audio waveform line sweeps under the word like a rail, a small glowing cube glides on it. Centered on a pure solid black background, wide 16:9 composition, generous empty margin. $STYLE"
  [logo_b]="Game title logo that reads exactly \"BeatGlide\" in heavy, slanted, sleek sci-fi lettering with speed streaks trailing to the left, and a tagline under it that reads exactly \"RIDE THE RHYTHM\" in thin wide-spaced capitals. The letter i is dotted with a small glowing square. Centered on a pure solid black background, wide 16:9 composition, generous empty margin. $STYLE"
  [icon_a]="Square mobile app icon, full bleed, no rounded corners drawn, no text. A glowing cyan cube gliding fast along a curved neon pink rail that rises like an audio waveform, motion trail behind the cube, deep dark navy-purple background (#120a2a) with a faint perspective grid. Bold simple silhouette readable at small size, subject centered with safe margin. $STYLE"
  [icon_b]="Square mobile app icon, full bleed, no rounded corners drawn, no text. A bold stylised letter B formed by a glowing neon rail track that loops like a sound wave, a small bright cube riding on the curve, deep dark navy-purple background (#120a2a). Bold simple silhouette readable at small size, subject centered with safe margin. $STYLE"
  [cover_the_dawn_assembly]="Album cover art: sunrise breaking over a futuristic neon city skyline, light rays, a glowing rail road leading to the horizon. $COVER"
  [cover_fault_line]="Album cover art: a cracked dark landscape split by glowing neon fault lines, energy bursting from the cracks, floating rock shards. $COVER"
  [cover_pulse_drive]="Album cover art: a neon highway at night seen from low angle, streaks of light racing forward, speedometer-like rings of light. $COVER"
  [cover_temple_battle_taiko]="Album cover art: a silhouetted Japanese pagoda temple on a cliff at dusk, huge taiko drum in front, misty mountains, glowing sky. $COVER"
  [cover_temple_battle_taiko_alt]="Album cover art: a Japanese temple gate at night lit by floating lanterns, a taiko drum glowing with neon rim light, cherry petals. $COVER"
  [cover_neon_rhythm_stabs]="Album cover art: sharp glowing neon crystal shards exploding outward from a bright core, like sound stabs, deep space background. $COVER"
  [cover_neon_rhythm_stabs_alt]="Album cover art: a neon city canyon of skyscrapers at night with glowing equalizer bars in the windows, magenta and cyan. $COVER"
  [cover_tribal_battle_rhythm]="Album cover art: tribal war drums glowing with neon patterns around a bonfire under a starry sky, sparks rising. $COVER"
  [cover_tribal_battle_rhythm_alt]="Album cover art: a glowing neon tribal mask floating in a dark jungle, bioluminescent leaves, rhythmic light rings. $COVER"
)
COVERS=(cover_the_dawn_assembly cover_fault_line cover_pulse_drive cover_temple_battle_taiko cover_temple_battle_taiko_alt
  cover_neon_rhythm_stabs cover_neon_rhythm_stabs_alt cover_tribal_battle_rhythm cover_tribal_battle_rhythm_alt)
for NAME in logo_a logo_b icon_a icon_b "${COVERS[@]}"; do
  if [ -f "$OUT/$NAME.png" ]; then echo "skip $NAME"; continue; fi
  LOG="$WORK/$NAME.log"
  codex exec --skip-git-repo-check -s read-only -C "$WORK" "Use your built-in image generation tool to create exactly ONE image. Do not run any shell commands or tools other than image generation. Image: ${PROMPTS[$NAME]}" < /dev/null > "$LOG" 2>&1
  SID=$(grep -a -m1 "session id:" "$LOG" | awk '{print $3}' | tr -d '\r')
  IMG=$(ls -t "$HOME/.codex/generated_images/$SID/"*.png 2>/dev/null | head -1)
  if [ -n "$IMG" ]; then cp "$IMG" "$OUT/$NAME.png"; echo "ok $NAME <- $IMG"; else echo "FAILED $NAME (session $SID)"; fi
done
