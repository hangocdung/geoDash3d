#!/usr/bin/env bash
# Screenshots of every screen at the phone/tablet shapes the store and QA need (GD3-254): 19.5:9, 16:9, 4:3 and
# portrait 9:19.5, in one language. Each shape runs the game in a window of that size (set through a temporary
# override.cfg, removed afterwards): main menu, song list, settings, shop, calibration, and the level at SONG_TIME.
# Usage: bash tools/capture/screens.sh [lang]   (default vi)   Output: tools/capture/out/screens/<shape>/<screen>.png
# Related: tools/capture/scene_shot.gd, tools/capture/previews/, tools/capture/record_clip.sh (same override trick)
GODOT="${GODOT:-D:/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe}"
LANG_CODE="${1:-vi}"
SONG_TIME="${SONG_TIME:-21.4}"
OUT="tools/capture/out/screens"
SHAPES=("19.5x9:1560x720" "16x9:1280x720" "4x3:960x720" "9x19.5:720x1560")
SCREENS=("menu:res://src/ui/menu/main_menu.tscn:240" "songs:res://tools/capture/previews/song_list_preview.tscn:30"
	"settings:res://tools/capture/previews/settings_preview.tscn:30" "shop:res://tools/capture/previews/shop_preview.tscn:30"
	"calibration:res://src/ui/calibration/calibration_screen.tscn:60")
if [ -e override.cfg ]; then
	echo "screens: override.cfg already exists, not touching it"
	exit 1
fi
trap 'rm -f override.cfg' EXIT
for shape in "${SHAPES[@]}"; do
	name="${shape%%:*}"
	size="${shape#*:}"
	mkdir -p "$OUT/$name"
	printf '[display]\nwindow/size/window_width_override=%s\nwindow/size/window_height_override=%s\n' \
		"${size%x*}" "${size#*x}" > override.cfg
	for screen in "${SCREENS[@]}"; do
		# label:scene:frames, where the scene path itself holds a colon ("res://").
		label="${screen%%:*}"
		rest="${screen#*:}"
		frames="${rest##*:}"
		scene="${rest%:*}"
		"$GODOT" --path . -s res://tools/capture/scene_shot.gd -- --scene="$scene" --frames="$frames" \
			--out="res://$OUT/$name/$label.png" --lang="$LANG_CODE" > /dev/null 2>&1
	done
	"$GODOT" --path . -- --capture="$SONG_TIME" --capture-out="res://$OUT/$name/level" --lang="$LANG_CODE" > /dev/null 2>&1
	echo "$name ($size): $(ls "$OUT/$name" | tr '\n' ' ')"
done
