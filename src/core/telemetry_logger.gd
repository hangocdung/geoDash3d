# Forwards engine and script errors (push_error, failed checks) to Crashlytics as non-fatal issues (GD3-230). Each
# distinct message is sent once per session, at most MAX_REPORTS in all; errors raised off the main thread wait for
# the next main-thread call (the plugin is called from the main thread only).
# Related: src/core/telemetry.gd (installs it), tests/framework (its own Logger for test assertions)
class_name TelemetryLogger
extends Logger

const MAX_REPORTS: int = 25

var _sent: Dictionary[String, bool] = {}
var _pending: PackedStringArray = []
var _mutex := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var message: String = "%s (%s:%d %s)" % [rationale if not rationale.is_empty() else code, file.get_file(), line,
			function]
	_mutex.lock()
	if not _sent.has(message) and _sent.size() < MAX_REPORTS:
		_sent[message] = true
		_pending.append(message)
	var ready: PackedStringArray = []
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		ready = _pending
		_pending = []
	_mutex.unlock()
	for pending: String in ready:
		Telemetry.record_error(pending)
