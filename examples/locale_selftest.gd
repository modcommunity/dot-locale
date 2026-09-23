extends Node

## Exercises dot-locale with the message shapes website-city's locale files actually contain.
##
## [b]Section 1 is the one to keep.[/b] Plural rules are where a localisation layer is
## quietly wrong: every English check passes against a rule that says "1 is one, the rest
## are other", and every Russian player reads "21 раундов". The cases here are CLDR's own
## examples for each rule, chosen because each one separates a correct rule from the
## obvious wrong one.
##
## [codeblock]
## godot --headless --path . res://examples/locale_selftest.tscn
## [/codeblock]

const SECTIONS := 7
const CHECKS := 59

var _passed := 0
var _failed := 0
var _section_count := 0


func _ready() -> void:
	DotLog.set_level(DotLog.Level.ERROR)
	_run()


func _run() -> void:
	_line("dot-locale self-test")
	_line("")

	_test_plurals()
	_test_format()
	_test_catalogue()
	_test_chain()
	_test_explain()
	_test_pseudo()
	_test_config()

	_line("")
	_line("%d sections, %d passed, %d failed" % [_section_count, _passed, _failed])

	if _section_count != SECTIONS:
		_line("ERROR: %d of %d sections ran." % [_section_count, SECTIONS])
		get_tree().quit(1)
		return

	if _passed + _failed != CHECKS:
		_line(
			"ERROR: %d checks ran, %d expected. A section aborted part-way."
			% [_passed + _failed, CHECKS]
		)
		get_tree().quit(1)
		return

	get_tree().quit(1 if _failed > 0 else 0)


# --- 1 ----------------------------------------------------------------------

func _test_plurals() -> void:
	_section("Plural categories are CLDR's, per language")

	_check(DotLocalePlural.category("en", 1) == "one" and DotLocalePlural.category("en", 0) == "other", "English: 1 is one, 0 is other")
	_check(DotLocalePlural.category("en", 1.0, 1) == "other", "and '1.0' is other, because a visible decimal changes the form")
	_check(DotLocalePlural.category("fr", 0) == "one", "French puts 0 with 1")
	_check(DotLocalePlural.category("pt-BR", 0) == "one" and DotLocalePlural.category("pt-PT", 0) == "other", "Brazilian Portuguese does too, and European does not")

	var ru := [[1, "one"], [21, "one"], [11, "many"], [2, "few"], [22, "few"], [12, "many"], [5, "many"], [111, "many"], [101, "one"]]
	var wrong := PackedStringArray()
	for pair in ru:
		var got := DotLocalePlural.category("ru", float(pair[0]))
		if got != str(pair[1]):
			wrong.append("%d→%s" % [pair[0], got])
	_check(wrong.is_empty(), "Russian: 1 21 101 one, 2 22 few, 5 11 12 111 many %s" % str(wrong))
	_check(DotLocalePlural.category("ru", 1.5) == "other", "and a fraction is other")
	_check(DotLocalePlural.category("pl", 22) == "few" and DotLocalePlural.category("pl", 21) == "many" and DotLocalePlural.category("pl", 1) == "one", "Polish: 22 few but 21 many, unlike Russian")
	_check(DotLocalePlural.category("ja", 1) == "other" and DotLocalePlural.category("zh-Hans", 1) == "other", "Japanese and Chinese have one form")
	_check(DotLocalePlural.category("xx", 1) == "other", "an unknown language answers other, which every ICU plural must have")


# --- 2 ----------------------------------------------------------------------

func _test_format() -> void:
	_section("ICU MessageFormat, as the site writes it")

	_check(DotLocaleFormat.format("{user} joined.", {"user": "Sam"}) == "Sam joined.", "an argument")
	_check(DotLocaleFormat.format("{user} joined.", {}) == "{user} joined.", "a missing argument is shown by name, not as nothing")
	_check(DotLocaleFormat.format("{n, number} rounds", {"n": 12500}, "en") == "12,500 rounds", "numbers are grouped for English")
	_check(DotLocaleFormat.format("{n, number}", {"n": 12500}, "de") == "12.500", "and for German, the other way round")
	_check(DotLocaleFormat.format("{n, number}", {"n": 1234.5}, "fr") == "1 234,5", "and for French, with a comma for the point")

	var rounds := "{count, plural, =0 {no rounds} one {# round} other {# rounds}}"
	_check(DotLocaleFormat.format(rounds, {"count": 0}) == "no rounds", "an exact =0 branch wins over the category")
	_check(DotLocaleFormat.format(rounds, {"count": 1}) == "1 round", "# is the number")
	_check(DotLocaleFormat.format(rounds, {"count": 1500}) == "1,500 rounds", "and is formatted like one")

	var ru := "{count, plural, one {# раунд} few {# раунда} many {# раундов} other {# раунда}}"
	_check(DotLocaleFormat.format(ru, {"count": 21}, "ru") == "21 раунд" and DotLocaleFormat.format(ru, {"count": 24}, "ru") == "24 раунда", "a Russian plural picks by the last digit")

	var who := "{role, select, host {You host} other {{name} hosts}} {count, plural, one {# game} other {# games}}"
	_check(DotLocaleFormat.format(who, {"role": "member", "name": "Ada", "count": 3}) == "Ada hosts 3 games", "select, nesting, and two arguments of different kinds")
	_check(DotLocaleFormat.format("It''s '{'literal'}'", {}) == "It's {literal}", "ICU quoting: '' is a quote, '{' is a brace")
	_check(DotLocaleFormat.format("don't", {}) == "don't", "and a lone apostrophe is just one")

	_check(not DotLocaleFormat.compile("{count, plural, one {x}}").ok, "a plural without 'other' is refused, as ICU requires")
	_check(DotLocaleFormat.format("{count, plural, one {x}}", {"count": 1}) == "{count, plural, one {x}}", "and shown raw rather than as nothing")
	_check(not DotLocaleFormat.compile("{a, frobnicate}").ok, "an unknown argument type is refused")
	_check(not DotLocaleFormat.compile("oops }").ok, "as is an unmatched brace")
	var args := DotLocaleFormat.arguments(who)
	args.sort()
	_check(args == PackedStringArray(["count", "name", "role"]), "every argument a pattern uses can be listed")


# --- 3 ----------------------------------------------------------------------

func _test_catalogue() -> void:
	_section("The catalogue reads the site's one-file-per-namespace layout")

	var root := "user://locale_selftest"
	_write(root + "/en/party.json", {"join": {"deny": {"full": "This party is full.", "banned": "You have been banned from this party."}}, "ready": {"count": "{n, plural, one {# ready} other {# ready}}"}})
	_write(root + "/de/party.json", {"join": {"deny": {"full": "Diese Party ist voll."}}, "ready": {"count": "{count, plural, one {# bereit} other {# bereit}}"}})
	_write_text(root + "/ru/party.json", "{ \"join\": { \"deny\": { \"full\": \"Эта группа заполнена.\", } }")
	_write(root + "/ru/chat.json", {"sent": "Отправлено"})

	var cat := DotLocaleCatalogue.new()
	var loaded := cat.load_dir(root)
	_check(not loaded.ok and loaded.error.detail.contains("ru/party.json"), "a broken file is named")
	_check(int(loaded.error.context.get("loaded", 0)) == 6, "and refuses only itself: the other files loaded (6 messages)")
	_check(cat.pattern("en", "party.join.deny.full") == "This party is full.", "a key is the namespace and the path, as the site's API refuses with")
	_check(cat.pattern("ru", "chat.sent") == "Отправлено", "Russian's other file still loaded")
	_check(cat.missing_in("de") == PackedStringArray(["party.join.deny.banned"]), "a translator's to-do list is the reference's keys the language lacks")
	_check(cat.argument_mismatches("de") == PackedStringArray(["party.ready.count"]), "a translation whose arguments disagree with the reference is found")
	_check(DotLocaleCatalogue.normalise("pt_br") == "pt-BR" and DotLocaleCatalogue.normalise("ZH-hans-cn") == "zh-Hans-CN", "tags are normalised")
	_remove_tree(ProjectSettings.globalize_path(root))


# --- 4 ----------------------------------------------------------------------

func _test_chain() -> void:
	_section("The fallback chain ends in a searchable key, never in nothing")

	_check(DotLocale.chain_for("pt-BR", "en") == PackedStringArray(["pt-BR", "pt", "en"]), "pt-BR falls back to pt and then English")
	_check(DotLocale.chain_for("en-GB", "en") == PackedStringArray(["en-GB", "en"]), "without repeating the default")

	var cat := _catalogue()
	var loc := DotLocale.new(cat, "pt-BR")
	_check(loc.t("party.join.deny.full") == "Esta party está cheia.", "the region-less language answers for the region")
	_check(loc.t("party.join.deny.banned") == "You have been banned from this party.", "and English for what Portuguese lacks")
	_check(loc.t("party.nope") == "party.nope", "and the key itself when nobody has it")
	_check(loc.missing_keys() == PackedStringArray(["party.nope"]), "which is remembered for a report")

	# A Russian player shown the English fallback gets English plural rules: Russian ones
	# would pick "few" and there is no such branch in an English sentence.
	var ru := DotLocale.new(cat, "ru")
	_check(ru.t("party.rounds", {"count": 22}) == "22 rounds", "a fallback message is pluralised by its own language")
	_check(ru.t("party.players", {"count": 22}) == "22 игрока", "and a Russian one by Russian's")

	var changed: Array = []
	loc.locale_changed.connect(func(tag: String) -> void: changed.append(tag))
	loc.set_locale("de_DE")
	_check(changed == ["de-DE"] and loc.chain()[1] == "de", "changing language is announced, normalised")
	_check(loc.has("party.join.deny.full"), "and whether a key exists is asked of the whole chain")


# --- 5 ----------------------------------------------------------------------

func _test_explain() -> void:
	_section("A refusal from the website, in the player's language")

	var loc := DotLocale.new(_catalogue(), "de")
	var err := DotError.make(DotError.CODE_CONFLICT, "This party is full.", "party.join.deny.full")
	_check(loc.explain(err) == "Diese Party ist voll.", "the site's key is rendered from the catalogue")
	var unknown := DotError.make(DotError.CODE_CONFLICT, "Something else went wrong.", "not a key at all")
	_check(loc.explain(unknown) == "Something else went wrong.", "an error with no known key keeps its own message")
	_check(loc.explain(null) == "", "and no error explains as nothing")


# --- 6 ----------------------------------------------------------------------

func _test_pseudo() -> void:
	_section("Pseudo-localisation finds what a translator cannot")

	var p := DotLocalePseudo.transform("{user} joined.")
	_check(p.begins_with("[") and p.ends_with("]"), "a message is bracketed, so a clipped end shows")
	_check(p.contains("{user}"), "an argument name is untouched")
	_check(p.contains("ĵóíñéð"), "the text is accented")
	_check(p.length() > "{user} joined.".length() + 2, "and made longer")

	var plural := DotLocalePseudo.transform("{count, plural, one {# round} other {# rounds}}")
	_check(DotLocaleFormat.compile(plural).ok, "a plural still parses after the transform")
	_check(plural.contains("one {") and plural.contains("other {"), "with its keywords intact")

	var cat := _catalogue()
	var loc := DotLocale.new(cat, "en")
	loc.pseudo = true
	var shown := loc.t("party.rounds", {"count": 3})
	_check(shown.contains("3") and shown.contains("ŕóúñðš"), "and formats with real arguments")

	loc.pseudo = false
	var translation := loc.to_translation("en")
	_check(translation.get_message("party.join.deny.full") == "This party is full.", "static messages become an engine Translation")
	_check(translation.get_message("party.rounds") == "", "and plurals do not, since the engine cannot format them")


# --- 7 ----------------------------------------------------------------------

func _test_config() -> void:
	_section("The configuration builds a translator even with nothing to read")

	var c := DotLocaleConfig.new()
	c.directory = "res://no/such/dir"
	c.language = "de"
	var made := c.make()
	_check(made.ok, "a missing locale directory is not an error")
	var loc: DotLocale = made.value
	_check(loc.t("menu.play") == "menu.play", "and the translator shows keys, which is how the first missing string is found")
	c.default_language = ""
	_check(not c.validate().ok, "a configuration with nowhere for the chain to end is refused")
	_check(c.sensitive_keys().is_empty() and c.describe_lines().size() == 1, "it describes itself")


# --- helpers ------------------------------------------------------------------

func _catalogue() -> DotLocaleCatalogue:
	var cat := DotLocaleCatalogue.new()
	cat.add("en", "party", {
		"join": {"deny": {"full": "This party is full.", "banned": "You have been banned from this party."}},
		"rounds": "{count, plural, one {# round} other {# rounds}}",
	})
	cat.add("pt", "party", {"join": {"deny": {"full": "Esta party está cheia."}}})
	cat.add("de", "party", {"join": {"deny": {"full": "Diese Party ist voll."}}})
	cat.add("ru", "party", {"players": "{count, plural, one {# игрок} few {# игрока} many {# игроков} other {# игрока}}"})
	return cat


func _write(path: String, tree: Dictionary) -> void:
	_write_text(path, JSON.stringify(tree))


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _remove_tree(abs_path: String) -> void:
	var d := DirAccess.open(abs_path)
	if d == null:
		return
	for sub in d.get_directories():
		_remove_tree(abs_path.path_join(sub))
	for file in d.get_files():
		DirAccess.remove_absolute(abs_path.path_join(file))
	DirAccess.remove_absolute(abs_path)


func _section(title: String) -> void:
	_section_count += 1
	_line("-- %d. %s" % [_section_count, title])


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
		_line("   ok    %s" % what)
	else:
		_failed += 1
		_line("   FAIL  %s" % what)


func _line(s: String) -> void:
	print(s)
