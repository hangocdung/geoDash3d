# UI language (GD3-252): English source strings are the keys; other languages come from assets/i18n/<code>.json
# ({"English text": "translation"}), loaded at runtime so no import step is needed. Controls translate their static
# text automatically; code that formats text translates the pattern first: Locale.t("ATTEMPT %d") % attempt.
# Related: src/core/user_settings.gd (language), src/ui/menu/settings_panel.gd, assets/i18n/vi.json
class_name Locale
extends RefCounted

const AUTO: String = "auto"
const SOURCE_LANGUAGE: String = "en"
## Languages offered in Settings, besides AUTO (follow the phone).
const LANGUAGES: PackedStringArray = ["en", "vi"]
const NATIVE_NAMES: Dictionary[String, String] = {"en": "English", "vi": "Tiếng Việt"}
const DIRECTORY: String = "res://assets/i18n"
## `-- --lang=vi` overrides the setting (screenshots of each language).
const ARGUMENT_PREFIX: String = "--lang="

static var _loaded: Dictionary[String, bool] = {}


## Switches the UI to `language` ("auto", "en", "vi"); "auto" follows the device language, else English.
static func apply(language: String) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(ARGUMENT_PREFIX):
			language = argument.trim_prefix(ARGUMENT_PREFIX)
	var code: String = language if LANGUAGES.has(language) else _device_language()
	if code != SOURCE_LANGUAGE:
		_load(code)
	TranslationServer.set_locale(code)


## `text` in the current language (the English text itself when there is no translation).
static func t(text: String) -> String:
	return String(TranslationServer.translate(text))


static func _device_language() -> String:
	var device: String = OS.get_locale_language()
	return device if LANGUAGES.has(device) else SOURCE_LANGUAGE


static func _load(code: String) -> void:
	if _loaded.has(code):
		return
	_loaded[code] = true
	var path: String = DIRECTORY.path_join(code + ".json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Locale: cannot read translations '%s'" % path)
		return
	var translation := Translation.new()
	translation.locale = code
	var entries: Dictionary = parsed
	for source: Variant in entries:
		translation.add_message(str(source), str(entries[source]))
	TranslationServer.add_translation(translation)
