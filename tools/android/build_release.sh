#!/usr/bin/env bash
# Builds the Google Play bundle (GD3-260): sets version/code from the git commit count (always increasing) and
# version/name from the argument in the "Android Release" preset, prepares the Gradle build and exports a signed AAB.
# The release keystore stays out of the repository: pass it through Godot's environment variables
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH, GODOT_ANDROID_KEYSTORE_RELEASE_USER, GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
# Usage: bash tools/android/build_release.sh <version name, e.g. 1.0.0>   Output: build/GeoDash3D.aab
# Related: export_presets.cfg (preset.2), tools/android/setup_gradle_build.sh, docs/release/android_release.md
set -e
GODOT="${GODOT:-D:/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NAME="$1"
if ! [[ "$NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "usage: bash tools/android/build_release.sh <version name like 1.0.0>"
	exit 1
fi
for variable in GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; do
	if [ -z "${!variable}" ]; then
		echo "build_release: $variable is not set (release keystore, see docs/release/android_release.md)"
		exit 1
	fi
done
if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
	echo "build_release: commit or stash your changes first (the version code comes from the commit count)"
	exit 1
fi
CODE=$(git -C "$ROOT" rev-list --count HEAD)
python - "$ROOT/export_presets.cfg" "$CODE" "$NAME" <<'PYEOF'
import re
import sys
path, code, name = sys.argv[1:4]
text = open(path, encoding="utf-8").read()
start = text.index('name="Android Release"\n')
options = text.index("[preset.2.options]", start)
end = text.find("\n[preset.", options + 1)
end = len(text) if end < 0 else end
section = text[options:end]
section = re.sub(r"version/code=\d+", "version/code=%s" % code, section)
section = re.sub(r'version/name="[^"]*"', 'version/name="%s"' % name, section)
open(path, "w", encoding="utf-8", newline="\n").write(text[:options] + section + text[end:])
PYEOF
bash "$ROOT/tools/android/setup_gradle_build.sh"
"$GODOT" --headless --path "$ROOT" --export-release "Android Release" "$ROOT/build/GeoDash3D.aab"
echo "built build/GeoDash3D.aab: version $NAME (code $CODE). Commit export_presets.cfg to record the version."
