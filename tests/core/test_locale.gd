# Translations: every Locale.t("...") pattern in the code has a Vietnamese entry with the same format placeholders,
# and switching language changes translated text. Related: src/core/locale.gd, assets/i18n/vi.json
extends TestCase

const SOURCE_DIRECTORIES: PackedStringArray = ["res://src"]


func after_each() -> void:
	Locale.apply(Locale.SOURCE_LANGUAGE)


func test_every_translated_pattern_has_a_vietnamese_entry() -> void:
	var entries: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/i18n/vi.json"))
	var call := RegEx.create_from_string("Locale\\.t\\(\"((?:[^\"\\\\]|\\\\.)*)\"")
	var found: int = 0
	for path: String in _scripts():
		for match_result: RegExMatch in call.search_all(FileAccess.get_file_as_string(path)):
			var key: String = match_result.get_string(1).c_unescape()
			found += 1
			assert_true(entries.has(key), "%s: no vi.json entry for '%s'" % [path.get_file(), key])
	assert_true(found > 15, "found %d Locale.t calls" % found)


func test_placeholders_match() -> void:
	var entries: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/i18n/vi.json"))
	var placeholder := RegEx.create_from_string("%[-+ 0-9.]*[dsf%]")
	for key: Variant in entries:
		var expected: PackedStringArray = []
		for found: RegExMatch in placeholder.search_all(str(key)):
			expected.append(found.get_string())
		var actual: PackedStringArray = []
		for found: RegExMatch in placeholder.search_all(str(entries[key])):
			actual.append(found.get_string())
		assert_eq(",".join(actual), ",".join(expected), "placeholders of '%s'" % key)


func test_switching_language() -> void:
	Locale.apply("vi")
	assert_eq(Locale.t("ATTEMPT %d") % 3, "LẦN 3")
	assert_eq(Locale.t("no such text"), "no such text")
	Locale.apply("en")
	assert_eq(Locale.t("ATTEMPT %d") % 3, "ATTEMPT 3")


func _scripts() -> PackedStringArray:
	var result: PackedStringArray = []
	var pending: PackedStringArray = SOURCE_DIRECTORIES.duplicate()
	while not pending.is_empty():
		var directory: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		for sub: String in DirAccess.get_directories_at(directory):
			pending.append(directory.path_join(sub))
		for file_name: String in DirAccess.get_files_at(directory):
			if file_name.ends_with(".gd"):
				result.append(directory.path_join(file_name))
	return result
