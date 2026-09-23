class_name DotLocaleCatalogue
extends RefCounted

## Every message for every language, keyed the way the website keys them.
##
## [b]The site's layout, read as it is.[/b] website-city keeps one JSON file per namespace
## per language — [code]locales/de/party.json[/code] — with nested objects inside, and a
## key is the namespace and the path: [code]party.join.deny.full[/code]. That is the key
## the site's API refuses with, so a game holding the same files can show a refusal in the
## player's language without a translation table between the two. [method load_dir] reads
## that layout; [method add] takes one namespace's object from anywhere else (its parameter
## is [code]ns[/code] because [code]namespace[/code] is a reserved word).
##
## A key that exists in one language and not another is normal — translations lag — and
## is what the fallback chain in [DotLocale] is for. [method missing_in] lists them, so a
## translator can be handed the gap rather than asked to find it.

## locale -> {key -> pattern}
var _messages: Dictionary = {}


func add(locale: String, ns: String, tree: Dictionary) -> int:
	var tag := DotLocaleCatalogue.normalise(locale)
	if not _messages.has(tag):
		_messages[tag] = {}
	var into: Dictionary = _messages[tag]
	var before := into.size()
	_flatten(tree, ns, into)
	return into.size() - before


func add_message(locale: String, key: String, pattern: String) -> void:
	var tag := DotLocaleCatalogue.normalise(locale)
	if not _messages.has(tag):
		_messages[tag] = {}
	(_messages[tag] as Dictionary)[key] = pattern


## Reads [code]<dir>/<locale>/<namespace>.json[/code] for every locale directory under
## [param dir]. Value: how many messages were read.
##
## One bad file refuses the load of that file only, and says which — a translator's
## trailing comma in Russian must not take the English away.
func load_dir(dir: String) -> DotResult:
	var root := DirAccess.open(dir)
	if root == null:
		return DotResult.fail(DotError.CODE_IO, "There is no locale directory there.", dir)
	var count := 0
	var problems := PackedStringArray()
	for locale in root.get_directories():
		var sub := DirAccess.open(dir.path_join(locale))
		if sub == null:
			continue
		for file in sub.get_files():
			if file.get_extension() != "json":
				continue
			var path := dir.path_join(locale).path_join(file)
			# A JSON instance rather than JSON.parse_string: the static one prints an engine
			# ERROR for a translator's typo and then says nothing useful to the caller, and
			# this wants the reverse — silence on stderr, and the line in the result.
			var json := JSON.new()
			if json.parse(FileAccess.get_file_as_string(path)) != OK:
				problems.append("%s:%d %s" % [path, json.get_error_line(), json.get_error_message()])
				continue
			if not (json.data is Dictionary):
				problems.append("%s is not an object" % path)
				continue
			count += add(locale, file.get_basename(), json.data as Dictionary)
	if not problems.is_empty():
		var res := DotResult.fail(DotError.CODE_PARSE, "Some locale files could not be read.", ", ".join(problems))
		res.error.context["loaded"] = count
		return res
	return DotResult.success(count)


func pattern(locale: String, key: String) -> Variant:
	var table: Dictionary = _messages.get(DotLocaleCatalogue.normalise(locale), {})
	return table.get(key)


func has_key(locale: String, key: String) -> bool:
	return (_messages.get(DotLocaleCatalogue.normalise(locale), {}) as Dictionary).has(key)


func locales() -> PackedStringArray:
	var out := PackedStringArray()
	for k in _messages:
		out.append(str(k))
	out.sort()
	return out


func keys(locale: String) -> PackedStringArray:
	var out := PackedStringArray()
	for k in (_messages.get(DotLocaleCatalogue.normalise(locale), {}) as Dictionary):
		out.append(str(k))
	out.sort()
	return out


func count(locale: String = "") -> int:
	if locale != "":
		return (_messages.get(DotLocaleCatalogue.normalise(locale), {}) as Dictionary).size()
	var n := 0
	for t in _messages.values():
		n += (t as Dictionary).size()
	return n


## Keys [param reference] has and [param locale] does not: a translator's to-do list.
func missing_in(locale: String, reference: String = "en") -> PackedStringArray:
	var have: Dictionary = _messages.get(DotLocaleCatalogue.normalise(locale), {})
	var out := PackedStringArray()
	for k in keys(reference):
		if not have.has(k):
			out.append(k)
	return out


## Keys whose translation uses arguments the reference does not supply, or drops ones it
## does. A translation that says "{player} joined" where the code passes "{user}" renders
## the braces to every German player, and nothing fails.
func argument_mismatches(locale: String, reference: String = "en") -> PackedStringArray:
	var out := PackedStringArray()
	var ref: Dictionary = _messages.get(DotLocaleCatalogue.normalise(reference), {})
	var other: Dictionary = _messages.get(DotLocaleCatalogue.normalise(locale), {})
	for k in other:
		if not ref.has(k):
			continue
		var want := DotLocaleFormat.arguments(str(ref[k]))
		var got := DotLocaleFormat.arguments(str(other[k]))
		want.sort()
		got.sort()
		if want != got:
			out.append(str(k))
	return out


## "pt_BR", "PT-br" → "pt-BR". Language lower case, region upper, script title case.
static func normalise(locale: String) -> String:
	var parts := locale.strip_edges().replace("_", "-").split("-", false)
	if parts.is_empty():
		return ""
	var out := PackedStringArray([parts[0].to_lower()])
	for i in range(1, parts.size()):
		var p := parts[i]
		if p.length() == 4:
			out.append(p.substr(0, 1).to_upper() + p.substr(1).to_lower())
		else:
			out.append(p.to_upper())
	return "-".join(out)


static func _flatten(tree: Dictionary, prefix: String, into: Dictionary) -> void:
	for k in tree:
		var key := str(k) if prefix == "" else "%s.%s" % [prefix, k]
		var v: Variant = tree[k]
		if v is Dictionary:
			_flatten(v as Dictionary, key, into)
		elif v is String:
			into[key] = v
		elif v != null:
			into[key] = str(v)
