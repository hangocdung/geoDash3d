# Editor side of the GeoDashFirebase Android plugin: registers the export plugin that adds the AAR and Firebase
# libraries to Android Gradle builds. Related: addons/geodash_firebase/export_plugin.gd
@tool
extends EditorPlugin

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = preload("res://addons/geodash_firebase/export_plugin.gd").new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null
