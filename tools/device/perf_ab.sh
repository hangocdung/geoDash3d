#!/usr/bin/env bash
# A/B FPS comparison of two debug APKs on the connected phone at the real LOW and MEDIUM tiers: the tier is
# written into the game's own settings file (backed up, restored at the end), so scenery density, particles
# and speed lines follow it (the --perf=tier= flag only changes viewport/glow after setup). Runs A, B, B, A
# to cancel thermal drift; each run is autoplay with 3 x 5 s samples. Phone unlocked, screen on.
# Usage: bash tools/device/perf_ab.sh <a.apk> <b.apk> ["level args"]   (default args: --start-beat=64)
# Related: tools/device/perf_matrix.sh, src/core/perf_probe.gd
ADB="${ADB:-$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe}"
PKG="com.dunghn.geodash3d"
ACTIVITY="$PKG/com.godot.game.GodotAppLauncher"
APK_A="$1"
APK_B="$2"
ARGS="--autoplay ${3:---start-beat=64}"
if [ ! -f "$APK_A" ] || [ ! -f "$APK_B" ]; then
	echo "usage: bash tools/device/perf_ab.sh <a.apk> <b.apk> [\"level args\"]"
	exit 1
fi

restore_settings() {
	"$ADB" shell am force-stop "$PKG"
	"$ADB" shell "run-as $PKG sh -c 'cp files/settings.cfg.perfbak files/settings.cfg; rm -f files/settings.cfg.perfbak files/debug_args.txt'"
}

set_tier() { # 0 = LOW, 1 = MEDIUM
	"$ADB" shell "run-as $PKG sed -i 's/^quality_tier=.*/quality_tier=$1/' files/settings.cfg"
}

wake() { # the game keeps the screen on while it runs; between runs (installs) the phone may time out
	"$ADB" shell input keyevent KEYCODE_WAKEUP
	if "$ADB" shell dumpsys window | grep -q "isKeyguardShowing=true"; then
		echo "LOCK SCREEN is showing: unlock the phone and run again"
		restore_settings
		exit 1
	fi
}

run() { # $1 label
	wake
	"$ADB" shell am force-stop "$PKG"
	"$ADB" shell "run-as $PKG sh -c 'echo \"$ARGS\" > files/debug_args.txt'"
	"$ADB" logcat -c
	"$ADB" shell am start -n "$ACTIVITY" > /dev/null 2>&1
	sleep 4
	timeout 27 "$ADB" logcat -s godot:V 2>/dev/null | grep "PERF fps" | grep "scene=Level" | tail -n +2 \
		| sed -E 's/.*fps=([0-9.]+) worst_ms=([0-9.]+) hitches=([0-9]+).*draw_calls=([0-9]+).*/\1 \2 \3 \4/' \
		| awk -v l="$1" '{f+=$1; if($2>w)w=$2; h+=$3; d+=$4; n++; s=s sprintf("%.1f ",$1)} END {if (n) printf "%-40s fps=%5.1f [%s] worst_ms=%5.1f hitches=%d draw=%3.0f\n", l, f/n, s, w, h, d/n; else printf "%-40s no data (screen off?)\n", l}'
}

"$ADB" shell "run-as $PKG cp files/settings.cfg files/settings.cfg.perfbak"
for apk in "$APK_A" "$APK_B" "$APK_B" "$APK_A"; do
	"$ADB" install -r "$apk" 2>&1 | tail -1 | grep -v Success
	set_tier 0
	run "LOW    $(basename "$apk")"
	set_tier 1
	run "MEDIUM $(basename "$apk")"
done
restore_settings
"$ADB" shell dumpsys thermalservice | grep "Thermal Status"
echo "Installed now: $(basename "$APK_A") (reinstall the build you want to keep)"
