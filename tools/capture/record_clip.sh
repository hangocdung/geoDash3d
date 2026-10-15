#!/usr/bin/env bash
# Records a gameplay clip for TikTok / Shorts / Reels (GD3-212): Godot's Movie Maker renders the level frame by frame
# at 60 FPS with autoplay (--video: clean HUD, sound effects on), then ffmpeg turns the AVI into an H.264 MP4.
# Portrait (default) is 720x1280 scaled to 1080x1920; landscape keeps the 1280x720 window, scaled to 1920x1080.
# Usage: bash tools/capture/record_clip.sh <chart id> [start beat] [seconds] [portrait|landscape] [--lang=vi]
#   e.g. bash tools/capture/record_clip.sh pulse_drive_led 64 20
# Output: tools/capture/out/clips/<id>_<start>_<orientation>.mp4   Related: src/presentation/level/launch_options.gd
GODOT="${GODOT:-D:/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe}"
FFMPEG="${FFMPEG:-D:/ffmpeg-8.1-essentials_build/bin/ffmpeg.exe}"
ID="$1"
START="${2:-0}"
SECONDS_LONG="${3:-20}"
ORIENTATION="${4:-portrait}"
EXTRA="${5:-}"
if [ -z "$ID" ] || [ ! -f "assets/music/$ID.chart.json" ]; then
	echo "usage: bash tools/capture/record_clip.sh <chart id> [start beat] [seconds] [portrait|landscape] [--lang=vi]"
	exit 1
fi
OUT_DIR="tools/capture/out/clips"
mkdir -p "$OUT_DIR"
NAME="$OUT_DIR/${ID}_${START}_${ORIENTATION}"
FRAMES=$((SECONDS_LONG * 60 + 120))
ARGS=(--chart="res://assets/music/$ID.chart.json" --start-beat="$START" --video)
SCALE="1920:1080"
WINDOW="1280x720"
if [ "$ORIENTATION" = "portrait" ]; then
	ARGS+=(--portrait)
	SCALE="1080:1920"
	WINDOW="720x1280"
fi
[ -n "$EXTRA" ] && ARGS+=("$EXTRA")
# The movie writer takes its frame size from the project's window override at startup (--resolution does not
# change it): a temporary override.cfg (read by Godot from the project folder) sets it, and is removed afterwards.
if [ -e override.cfg ]; then
	echo "record_clip: override.cfg already exists, not touching it"
	exit 1
fi
trap 'rm -f override.cfg' EXIT
printf '[display]\nwindow/size/window_width_override=%s\nwindow/size/window_height_override=%s\n' \
	"${WINDOW%x*}" "${WINDOW#*x}" > override.cfg
"$GODOT" --path . --write-movie "$NAME.avi" --fixed-fps 60 --quit-after "$FRAMES" -- "${ARGS[@]}" > /dev/null 2>&1
if [ ! -f "$NAME.avi" ]; then
	echo "record_clip: Godot wrote no movie"
	exit 1
fi
# Skip the first 2 s (level loading, count-in) and scale to the social-media size.
"$FFMPEG" -y -loglevel error -ss 2 -i "$NAME.avi" -t "$SECONDS_LONG" -vf "scale=$SCALE:flags=lanczos" \
	-c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart "$NAME.mp4"
rm -f "$NAME.avi"
echo "wrote $NAME.mp4"
