#!/usr/bin/env bash
# Builds the GeoDashFirebase Godot Android plugin (android_plugins/geodash_firebase) and copies its debug/release AARs
# into addons/geodash_firebase/bin, where the export plugin picks them up. Needs JDK 17+ (Android Studio's JBR).
# Usage: bash tools/android/build_firebase_plugin.sh   Related: addons/geodash_firebase/export_plugin.gd
set -e
export JAVA_HOME="${JAVA_HOME:-C:/Program Files/Android/Android Studio/jbr}"
SDK="${ANDROID_HOME:-$LOCALAPPDATA/Android/Sdk}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PLUGIN="$ROOT/android_plugins/geodash_firebase"
echo "sdk.dir=$(cygpath -m "$SDK" 2>/dev/null || echo "$SDK")" > "$PLUGIN/local.properties"
(cd "$PLUGIN" && ./gradlew --quiet assembleDebug assembleRelease)
mkdir -p "$ROOT/addons/geodash_firebase/bin"
cp "$PLUGIN/build/outputs/aar/geodash_firebase-debug.aar" "$ROOT/addons/geodash_firebase/bin/"
cp "$PLUGIN/build/outputs/aar/geodash_firebase-release.aar" "$ROOT/addons/geodash_firebase/bin/"
ls -l "$ROOT/addons/geodash_firebase/bin"
