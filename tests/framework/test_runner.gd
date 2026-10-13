# Minimal headless test runner (no external addon). Discovers res://tests/**/test_*.gd,
# runs every test_* method, counts engine errors as failures, exits with code 1 on failure.
# Usage: godot --headless --path . -s res://tests/framework/test_runner.gd [-- --filter=substring]
extends SceneTree

const TESTS_ROOT: String = "res://tests"
const FRAMEWORK_DIRECTORY: String = "framework"

var _error_logger: TestErrorLogger = TestErrorLogger.new()


func _initialize() -> void:
	OS.add_logger(_error_logger)
	var filter_text: String = _read_filter()
	var script_paths: PackedStringArray = _find_test_scripts(TESTS_ROOT)
	var passed_count: int = 0
	var failed_names: PackedStringArray = []

	for script_path: String in script_paths:
		var script: GDScript = load(script_path) as GDScript
		if script == null:
			failed_names.append("%s (cannot load)" % script_path)
			continue
		for method_name: String in _list_test_methods(script):
			var full_name: String = "%s::%s" % [script_path.get_file(), method_name]
			if not filter_text.is_empty() and not full_name.contains(filter_text):
				continue
			var failures: PackedStringArray = _run_single_test(script, method_name)
			if failures.is_empty():
				passed_count += 1
			else:
				failed_names.append(full_name)
				print("FAIL %s" % full_name)
				for failure: String in failures:
					print("     - %s" % failure)

	OS.remove_logger(_error_logger)
	print("")
	print("Tests: %d passed, %d failed" % [passed_count, failed_names.size()])
	quit(0 if failed_names.is_empty() else 1)


func _run_single_test(script: GDScript, method_name: String) -> PackedStringArray:
	var test_case: TestCase = script.new() as TestCase
	if test_case == null:
		return PackedStringArray(["script does not extend TestCase"])
	_error_logger.captured_errors.clear()
	test_case.before_each()
	test_case.call(method_name)
	test_case.after_each()
	var failures: PackedStringArray = test_case.failures.duplicate()
	var error_count: int = _error_logger.captured_errors.size()
	if error_count != test_case.expected_error_count:
		failures.append("expected %d engine error(s), got %d" % [test_case.expected_error_count, error_count])
		for error_text: String in _error_logger.captured_errors:
			failures.append("engine error: %s" % error_text)
	return failures


func _list_test_methods(script: GDScript) -> PackedStringArray:
	var names: PackedStringArray = []
	for method_info: Dictionary in script.get_script_method_list():
		var method_name: String = str(method_info.get("name", ""))
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	return names


func _find_test_scripts(directory_path: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(directory_path):
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			result.append(directory_path.path_join(file_name))
	for sub_directory: String in DirAccess.get_directories_at(directory_path):
		if sub_directory == FRAMEWORK_DIRECTORY:
			continue
		result.append_array(_find_test_scripts(directory_path.path_join(sub_directory)))
	result.sort()
	return result


func _read_filter() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--filter="):
			return argument.trim_prefix("--filter=")
	return ""
