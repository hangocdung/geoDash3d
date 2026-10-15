# Adds the GeoDashFirebase AAR (built by tools/android/build_firebase_plugin.sh) and the Firebase libraries to
# Android exports. Needs the Gradle build (export preset: gradle_build/use_gradle_build); the google-services and
# Crashlytics Gradle plugins are applied by tools/android/setup_gradle_build.sh when google-services.json exists.
# Versions: Firebase BOM 34.0.0 (keep in sync with android_plugins/geodash_firebase/build.gradle).
@tool
extends EditorExportPlugin

const PLUGIN_NAME: String = "GeoDashFirebase"
const FIREBASE_DEPENDENCIES: PackedStringArray = [
	"com.google.firebase:firebase-analytics:23.0.0",
	"com.google.firebase:firebase-crashlytics-ndk:20.0.0",
	"com.google.firebase:firebase-config:23.0.0",
]


func _get_name() -> String:
	return PLUGIN_NAME


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid


func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	return PackedStringArray(["geodash_firebase/bin/geodash_firebase-%s.aar" % ("debug" if debug else "release")])


func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return FIREBASE_DEPENDENCIES
