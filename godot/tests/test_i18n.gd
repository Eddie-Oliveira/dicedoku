extends RefCounted
# Every language has every source string, with the same {n} placeholders and edge spaces.

func placeholders(s: String) -> Array:
	var out := []
	var re := RegEx.new()
	re.compile("\\{\\d+\\}")
	for m in re.search_all(s):
		out.append(m.get_string())
	out.sort()
	return out

func test_tables_complete(t) -> void:
	var src: Array = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/source_en.json"))
	t.check(src.size() > 200, "source list loaded (%d)" % src.size())
	for code in Lang.LANGS:
		if code == "en":
			continue
		var tb: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/%s.json" % code))
		t.check(tb is Dictionary, "%s parses" % code)
		if not (tb is Dictionary):
			continue
		var missing := 0
		for s in src:
			if not tb.has(s) or str(tb[s]) == "":
				missing += 1
				continue
			var en: String = Lang.KEYED.get(s, s)
			var tr: String = tb[s]
			t.check(placeholders(tr) == placeholders(en), "%s placeholders: %s" % [code, s])
			t.check(tr.begins_with(" ") == en.begins_with(" ") and tr.ends_with(" ") == en.ends_with(" "), "%s edge spaces: '%s'" % [code, s])
		t.check(missing == 0, "%s: %d strings missing" % [code, missing])

func test_runtime_switch(t) -> void:
	for code in Lang.LANGS:
		Lang.set_lang(code)
		var s := Lang.f("{0} cleared the dungeon!", ["Ana"])
		t.check(s.contains("Ana") and not s.contains("{0}"), "%s formats" % code)
		if code != "en":
			t.check(Lang.t("Roll") != "Roll", "%s translates Roll" % code)
	Lang.set_lang("en")
