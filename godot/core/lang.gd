class_name Lang
extends RefCounted
## Translations. Source strings are the English text itself; tables in res://i18n/<code>.json map them to translations.
## Placeholders use {0}, {1} ... so translations may reorder them. Missing entries fall back to English.

const LANGS := ["en", "pt_BR", "es", "fr", "it", "zh_CN"]
const NATIVE := {"en": "English", "pt_BR": "Português (Brasil)", "es": "Español", "fr": "Français", "it": "Italiano", "zh_CN": "简体中文"}

static var code := "en"
static var table := {}
## When true, every looked-up source string is recorded (used by tests to find untranslated text).
static var record := false
static var seen := {}

static func set_lang(c: String) -> void:
	code = c if LANGS.has(c) else "en"
	table = {}
	if code != "en":
		var path := "res://i18n/%s.json" % code
		if FileAccess.file_exists(path):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary:
				table = d

## Best match for the device language (e.g. "pt_BR", "pt", "zh_CN", "fr_CA").
static func from_locale(loc: String) -> String:
	if LANGS.has(loc):
		return loc
	var base := loc.split("_")[0]
	if base == "pt":
		return "pt_BR"
	if base == "zh":
		return "zh_CN"
	return base if LANGS.has(base) else "en"

## Keyed strings whose English text alone would be ambiguous as a key.
const KEYED := {"HERO_TITLE": "{0} {1}", "NAME_THE_HERO": "{0} the {1}"}

static func t(src: String) -> String:
	if record and src != "":
		seen[src] = true
	var v: Variant = table.get(src, "")
	if v == "" or v == null:
		return KEYED.get(src, src)
	return str(v)

static func f(src: String, args: Array) -> String:
	return t(src).format(args)
