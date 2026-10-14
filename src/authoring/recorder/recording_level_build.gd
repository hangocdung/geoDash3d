# Runs tools/charting/recording_level.py from the recorder (desktop dev builds; needs `python` on PATH)
# and reports the built chart path plus the tool's summary/warnings.
# Related: src/authoring/recorder/recorder.gd, tools/charting/recording_level.py
class_name RecordingLevelBuild
extends RefCounted

const TOOL_PATH: String = "res://tools/charting/recording_level.py"
const PYTHON: String = "python"

var ok: bool = false
var chart_path: String = ""
var message: String = ""


static func built_chart_for(source_chart: String) -> String:
	return source_chart.trim_suffix(".chart.json").trim_suffix(Recording.BUILT_CHART_SUFFIX) \
			+ Recording.BUILT_CHART_SUFFIX + ".chart.json"


static func run(source_chart: String) -> RecordingLevelBuild:
	var result := RecordingLevelBuild.new()
	var output: Array = []
	var arguments: PackedStringArray = [ProjectSettings.globalize_path(TOOL_PATH),
			ProjectSettings.globalize_path(source_chart)]
	var exit_code: int = OS.execute(PYTHON, arguments, output, true)
	var text: String = "\n".join(output).strip_edges()
	if exit_code != 0:
		result.message = "Build failed (exit %d): %s" % [exit_code, text if not text.is_empty() else "is python on PATH?"]
		push_error("RecordingLevelBuild: " + result.message)
		return result
	result.ok = true
	result.chart_path = built_chart_for(source_chart)
	var lines: PackedStringArray = text.split("\n", false)
	var warnings: int = 0
	for line: String in lines:
		if line.begins_with("WARN"):
			warnings += 1
	# Summary line: "wrote <path>: N of M recorded taps placed, K warnings".
	var summary: String = lines[lines.size() - 2] if lines.size() >= 2 else text
	result.message = "Level built: %s%s" % [summary.get_slice(": ", summary.get_slice_count(": ") - 1),
			" (details in the console)" if warnings > 0 else ""]
	print(text)
	return result
