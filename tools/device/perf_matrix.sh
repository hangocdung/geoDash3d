#!/usr/bin/env bash
# Runs the installed debug APK on a USB-connected Android device with different --perf flags and prints
# the average FPS / CPU time per configuration (autoplay level, ~15 s each). Keep the phone unlocked.
# Usage: bash tools/device/perf_matrix.sh [variant ...]   (default: the full list below)
ADB="${ADB:-$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe}"
PACKAGE="com.dunghn.geodash3d"
ACTIVITY="$PACKAGE/com.godot.game.GodotAppLauncher"
VARIANTS=("$@")
if [ ${#VARIANTS[@]} -eq 0 ]; then
	VARIANTS=(baseline scale=0.5 noglow nosky nofog noparticles noscenery noobstacles notrack "noglow+nosky+nofog+noparticles+noscenery")
fi
for variant in "${VARIANTS[@]}"; do
	params="--,--autoplay"
	[ "$variant" != "baseline" ] && params="$params,--perf=$variant"
	"$ADB" logcat -c
	"$ADB" shell am start -S -n "$ACTIVITY" --esa command_line_params "$params" > /dev/null 2>&1
	sleep 4
	stats=$(timeout 12 "$ADB" logcat -s godot:V 2>/dev/null | grep "PERF fps" | sed -E 's/.*fps=([0-9.]+).*cpu_ms=([0-9.]+).*draw_calls=([0-9]+).*/\1 \2 \3/')
	echo "$stats" | awk -v v="$variant" 'NF==3 {f+=$1; c+=$2; d+=$3; n++} END {if (n) printf "%-50s fps=%5.1f cpu_ms=%5.1f draw_calls=%3.0f (%d samples)\n", v, f/n, c/n, d/n, n; else printf "%-50s no data (screen locked?)\n", v}'
done
"$ADB" shell am force-stop "$PACKAGE"
