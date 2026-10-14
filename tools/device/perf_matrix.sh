#!/usr/bin/env bash
# Runs the installed debug APK on a USB-connected Android device with different --perf flags and prints
# the average FPS / CPU time per configuration (autoplay level, ~20 s each; the first 5 s window,
# which includes level loading, is skipped). Keep the phone unlocked.
# Arguments reach the game through user://debug_args.txt (written with `run-as`, debug builds only).
# Usage: bash tools/device/perf_matrix.sh [variant ...]   (default: the full list below)
# EXTRA_ARGS adds level arguments to every run, e.g.
#   EXTRA_ARGS="--chart=res://assets/music/the_dawn_assembly.classic.chart.json --start-beat=84" bash ... baseline
ADB="${ADB:-$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe}"
PACKAGE="com.dunghn.geodash3d"
ACTIVITY="$PACKAGE/com.godot.game.GodotAppLauncher"
VARIANTS=("$@")
if [ ${#VARIANTS[@]} -eq 0 ]; then
	VARIANTS=(baseline scale=0.5 noglow nosky nofog noparticles noscenery noobstacles notrack "noglow+nosky+nofog+noparticles+noscenery")
fi
for variant in "${VARIANTS[@]}"; do
	args="--autoplay${EXTRA_ARGS:+ $EXTRA_ARGS}"
	[ "$variant" != "baseline" ] && args="$args --perf=$variant"
	"$ADB" shell am force-stop "$PACKAGE"
	"$ADB" shell "run-as $PACKAGE sh -c 'mkdir -p files && echo \"$args\" > files/debug_args.txt'"
	"$ADB" logcat -c
	"$ADB" shell am start -n "$ACTIVITY" > /dev/null 2>&1
	sleep 4
	stats=$(timeout "${SAMPLE_SEC:-17}" "$ADB" logcat -s godot:V 2>/dev/null | grep "PERF fps" | grep "scene=Level" | tail -n +2 \
		| sed -E 's/.*fps=([0-9.]+).*cpu_ms=([0-9.]+).*draw_calls=([0-9]+).*/\1 \2 \3/')
	echo "$stats" | awk -v v="$variant${EXTRA_ARGS:+ $EXTRA_ARGS}" 'NF==3 {f+=$1; c+=$2; d+=$3; n++} END {if (n) printf "%-60s fps=%5.1f cpu_ms=%5.1f draw_calls=%3.0f (%d samples)\n", v, f/n, c/n, d/n, n; else printf "%-60s no data (screen locked?)\n", v}'
done
"$ADB" shell am force-stop "$PACKAGE"
"$ADB" shell "run-as $PACKAGE rm -f files/debug_args.txt"
