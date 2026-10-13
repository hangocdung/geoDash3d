# Logger that records engine errors (push_error, script errors) while a test runs,
# so the runner can fail tests that error silently.
# Related: tests/framework/test_runner.gd
class_name TestErrorLogger
extends Logger

var captured_errors: PackedStringArray = []
var _mutex: Mutex = Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var description: String = rationale if not rationale.is_empty() else code
	_mutex.lock()
	captured_errors.append("%s (%s:%d in %s)" % [description, file.get_file(), line, function])
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass
