class_name DotLocale
extends RefCounted

## Turns a message key into a sentence in the player's language.
##
## [codeblock]
## var loc := DotLocale.new(catalogue, "de")
## label.text = loc.t("party.ready.countdown", {"seconds": 5})
## status.text = loc.explain(result.error)   # a refusal, in German, from the site's own key
## [/codeblock]
##
## [b]The fallback chain is the whole design.[/b] "pt-BR" asks pt-BR, then pt, then the
## default language, then shows the key. A message that is missing from a translation is
## the normal state of a game that ships updates faster than translators work, and the
## answer to it is the nearest language that has it — never an empty label, and never a
## crash. The key as a last resort is deliberate: it is ugly, and it is searchable, and a
## player's screenshot of it tells the developer exactly which line to add.
##
## [b]Plural rules follow the pattern, not the player.[/b] A message found in the English
## fallback for a Russian player is an English sentence, so it is pluralised with English
## rules; Russian ones would pick "few" and find no such branch.
##
## [b]A refusal is a key.[/b] website-city refuses with keys — [code]party.join.deny.full[/code]
## — and dot-party carries them in [member DotError.detail]. [method explain] renders one
## if the catalogue has it and falls back to the error's own English message if not, so a
## game gets the site's translation for free where it has the site's files and loses
## nothing where it does not.
##
## No autoload. [method register] puts one in [DotRegistry] under [constant SERVICE] for
## addons that want to find it without naming it.

const CHANNEL := "locale"
const SERVICE := &"dot_locale"

signal locale_changed(locale: String)

var catalogue: DotLocaleCatalogue = null
var default_locale: String = "en"

## Show every message pseudo-localised. See [DotLocalePseudo].
var pseudo: bool = false

var _locale: String = "en"
var _chain: PackedStringArray = PackedStringArray()
var _compiled: Dictionary = {}
var _missing: Dictionary = {}


func _init(p_catalogue: DotLocaleCatalogue = null, p_locale: String = "", p_default: String = "en") -> void:
	catalogue = p_catalogue if p_catalogue != null else DotLocaleCatalogue.new()
	default_locale = DotLocaleCatalogue.normalise(p_default)
	set_locale(p_locale if p_locale != "" else DotLocale.detect())


## The operating system's language, as a tag. "en" when it will not say.
static func detect() -> String:
	var tag := DotLocaleCatalogue.normalise(OS.get_locale())
	return tag if tag != "" else "en"


func locale() -> String:
	return _locale


func set_locale(tag: String) -> void:
	var next := DotLocaleCatalogue.normalise(tag)
	if next == "":
		next = default_locale
	_chain = DotLocale.chain_for(next, default_locale)
	if next == _locale:
		return
	_locale = next
	DotLog.debug(CHANNEL, "language set", {"locale": next, "chain": ",".join(_chain)})
	locale_changed.emit(next)


## "pt-BR" with default "en" → pt-BR, pt, en.
static func chain_for(tag: String, fallback: String) -> PackedStringArray:
	var out := PackedStringArray()
	var t := DotLocaleCatalogue.normalise(tag)
	while t != "":
		if not out.has(t):
			out.append(t)
		var dash := t.rfind("-")
		t = t.substr(0, dash) if dash > 0 else ""
	var f := DotLocaleCatalogue.normalise(fallback)
	if f != "" and not out.has(f):
		out.append(f)
	return out


func chain() -> PackedStringArray:
	return _chain


func has(key: String) -> bool:
	for tag in _chain:
		if catalogue.has_key(tag, key):
			return true
	return false


## The message for [param key], formatted with [param args]; the key itself when no
## language in the chain has it.
func t(key: String, args: Dictionary = {}) -> String:
	for tag in _chain:
		var p: Variant = catalogue.pattern(tag, key)
		if p == null:
			continue
		return _render(str(p), args, tag)
	if not _missing.has(key):
		_missing[key] = true
		DotLog.debug(CHANNEL, "no message for a key in any language of the chain", {"key": key, "chain": ",".join(_chain)})
	return key


## A refusal in the player's language: its key if the catalogue knows it, its message if not.
func explain(error: DotError, args: Dictionary = {}) -> String:
	if error == null:
		return ""
	if error.detail != "" and has(error.detail):
		return t(error.detail, args)
	return error.message


## Keys asked for that no language had, since this was made. A to-do list from real play.
func missing_keys() -> PackedStringArray:
	var out := PackedStringArray()
	for k in _missing:
		out.append(str(k))
	out.sort()
	return out


## The messages with no arguments, as an engine [Translation] for [param tag], so a
## [Control] with auto-translate shows static text through the same catalogue.
##
## Only the argument-free ones: the engine's [code]tr()[/code] knows nothing of ICU, and a
## plural handed to it would show its braces.
func to_translation(tag: String) -> Translation:
	var translation := Translation.new()
	translation.locale = DotLocaleCatalogue.normalise(tag).replace("-", "_")
	for key in catalogue.keys(tag):
		var p := str(catalogue.pattern(tag, key))
		if not p.contains("{"):
			translation.add_message(key, DotLocalePseudo.transform(p) if pseudo else p)
	return translation


func register(scope: StringName = &"") -> void:
	DotRegistry.register(DotRegistry.scoped_name(SERVICE, scope), self)


func describe_lines() -> PackedStringArray:
	var out := PackedStringArray()
	out.append("locale: %s (chain %s)%s" % [_locale, " > ".join(_chain), ", pseudo" if pseudo else ""])
	for tag in catalogue.locales():
		out.append("  %-6s %d messages" % [tag, catalogue.count(tag)])
	if not _missing.is_empty():
		out.append("  %d keys asked for and missing everywhere" % _missing.size())
	return out


func _render(pattern: String, args: Dictionary, tag: String) -> String:
	var source := DotLocalePseudo.transform(pattern) if pseudo else pattern
	if not source.contains("{") and not source.contains("'"):
		return source
	var nodes: Variant = _compiled.get(source)
	if nodes == null:
		var compiled := DotLocaleFormat.compile(source)
		if not compiled.ok:
			DotLog.warn(CHANNEL, "a message does not parse and is shown raw", {"locale": tag, "detail": compiled.error.message})
			_compiled[source] = []
			return source
		nodes = compiled.value
		_compiled[source] = nodes
	if (nodes as Array).is_empty():
		return source
	return DotLocaleFormat.render(nodes as Array, args, tag)
