#!/usr/bin/env bash
# Prepares android/build (Godot's Android Gradle build template, not committed): extracts it from the installed export
# templates when missing or outdated, adds the google-services and Crashlytics Gradle plugins (applied only when
# google-services.json is present) and copies android_plugins/google-services.json in. Idempotent; rerun after a
# Godot upgrade or after adding the Firebase config.
# Usage: bash tools/android/setup_gradle_build.sh   Related: docs/release/firebase_setup.md, export_presets.cfg
set -e
GODOT_VERSION="${GODOT_VERSION:-4.6.1.stable}"
GOOGLE_SERVICES_VERSION="4.4.2"
CRASHLYTICS_GRADLE_VERSION="3.0.2"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="$APPDATA/Godot/export_templates/$GODOT_VERSION/android_source.zip"
BUILD="$ROOT/android/build"
MARKER="GeoDash3D firebase patch"

if [ "$(cat "$ROOT/android/.build_version" 2>/dev/null)" != "$GODOT_VERSION" ]; then
	if [ ! -f "$TEMPLATE" ]; then
		echo "setup_gradle_build: missing $TEMPLATE (install the Godot $GODOT_VERSION export templates)"
		exit 1
	fi
	rm -rf "$ROOT/android"
	mkdir -p "$BUILD"
	(cd "$BUILD" && unzip -q "$TEMPLATE")
	printf "%s" "$GODOT_VERSION" > "$ROOT/android/.build_version"
	touch "$BUILD/.gdignore"
	echo "extracted the $GODOT_VERSION Android build template"
fi

if ! grep -q "$MARKER" "$BUILD/build.gradle"; then
	python - "$BUILD/build.gradle" "$GOOGLE_SERVICES_VERSION" "$CRASHLYTICS_GRADLE_VERSION" <<'PYEOF'
import sys
# The marker is not passed as an argument: Git Bash rewrites arguments that start with "//".
path, services, crashlytics = sys.argv[1:4]
marker = "// GeoDash3D firebase patch"
text = open(path, encoding="utf-8").read()
anchor = "    id 'org.jetbrains.kotlin.android'\n"
assert anchor in text, "plugins block not found in build.gradle"
text = text.replace(anchor, anchor + "    id 'com.google.gms.google-services' version '%s' apply false\n"
                    "    id 'com.google.firebase.crashlytics' version '%s' apply false\n" % (services, crashlytics), 1)
text += """
%s: Firebase needs the project's google-services.json (android_plugins/google-services.json).
if (file('google-services.json').exists()) {
    apply plugin: 'com.google.gms.google-services'
    apply plugin: 'com.google.firebase.crashlytics'
}
""" % marker
open(path, "w", encoding="utf-8", newline="\n").write(text)
PYEOF
	echo "patched build.gradle (google-services $GOOGLE_SERVICES_VERSION, crashlytics $CRASHLYTICS_GRADLE_VERSION)"
fi

# No Gradle daemon: a daemon left running keeps the headless Godot export from exiting.
if ! grep -q "org.gradle.daemon=false" "$BUILD/gradle.properties"; then
	printf '\norg.gradle.daemon=false\n' >> "$BUILD/gradle.properties"
fi

if [ -f "$ROOT/android_plugins/google-services.json" ]; then
	cp "$ROOT/android_plugins/google-services.json" "$BUILD/google-services.json"
	echo "copied google-services.json: Firebase is on in Android builds"
else
	rm -f "$BUILD/google-services.json"
	echo "no android_plugins/google-services.json: Android builds run without Firebase (telemetry stays local)"
fi
