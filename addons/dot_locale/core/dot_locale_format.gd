class_name DotLocaleFormat
extends RefCounted

## ICU MessageFormat, the subset website-city's locale files actually use.
##
## [code]{user} joined.[/code], [code]{n, number}[/code],
## [code]{count, plural, =0 {nobody} one {# round} few {# раунда} other {# rounds}}[/code] and
## [code]{kind, select, host {…} other {…}}[/code], nested to any depth, with [code]'[/code]
## quoting. That is what next-intl renders on the site, so a string written once for the
## website renders the same in a game.
##
## [b]Parsed into a tree once, formatted many times.[/b] A HUD line reformatted every frame
## must not re-parse its pattern every frame; [DotLocale] caches the tree per pattern.
##
## [b]A pattern that does not parse is shown, not hidden.[/b] [method format] falls back
## to the raw pattern, braces and all. An empty string where a sentence should be is a
## bug nobody reports; a sentence with braces in it is one somebody screenshots.

## node kinds
const TEXT := 0
const ARG := 1
const NUMBER := 2
const PLURAL := 3
const SELECT := 4
const HASH := 5


## Parses [param pattern]. Value: an Array of nodes.
static func compile(pattern: String) -> DotResult:
	var st := {"s": pattern, "i": 0}
	var nodes := _parse_nodes(st, false, false)
	if st.has("error"):
		return DotResult.fail(DotError.CODE_PARSE, str(st["error"]), pattern)
	return DotResult.success(nodes)


## Formats [param pattern] with [param args] for [param locale]; the raw pattern if it
## does not parse.
static func format(pattern: String, args: Dictionary = {}, locale: String = "en") -> String:
	if not pattern.contains("{") and not pattern.contains("'"):
		return pattern
	var compiled := compile(pattern)
	if not compiled.ok:
		return pattern
	return render(compiled.value, args, locale)


static func render(nodes: Array, args: Dictionary, locale: String, hash_value: Variant = null) -> String:
	var out := ""
	for n_v in nodes:
		var n: Array = n_v
		match int(n[0]):
			TEXT:
				out += str(n[1])
			HASH:
				out += _number(hash_value, locale) if hash_value != null else "#"
			ARG:
				out += str(args.get(n[1], "{%s}" % n[1]))
			NUMBER:
				out += _number(args.get(n[1]), locale)
			PLURAL:
				var value: Variant = args.get(n[1])
				var num := float(value) if (value is int or value is float) else 0.0
				var branches: Dictionary = n[2]
				var exact := "=%d" % int(num)
				var key := exact if branches.has(exact) and is_equal_approx(num, floorf(num)) \
					else DotLocalePlural.category(locale, num)
				if not branches.has(key):
					key = "other"
				out += render(branches.get(key, []), args, locale, value)
			SELECT:
				var branches: Dictionary = n[2]
				var pick := str(args.get(n[1], "other"))
				if not branches.has(pick):
					pick = "other"
				out += render(branches.get(pick, []), args, locale, hash_value)
	return out


## Every argument name a pattern uses, for a check that a caller supplies them all.
static func arguments(pattern: String) -> PackedStringArray:
	var out := PackedStringArray()
	var compiled := compile(pattern)
	if compiled.ok:
		_collect(compiled.value, out)
	return out


static func _collect(nodes: Array, out: PackedStringArray) -> void:
	for n_v in nodes:
		var n: Array = n_v
		var kind := int(n[0])
		if kind == ARG or kind == NUMBER or kind == PLURAL or kind == SELECT:
			if not out.has(str(n[1])):
				out.append(str(n[1]))
		if kind == PLURAL or kind == SELECT:
			for b in (n[2] as Dictionary).values():
				_collect(b as Array, out)


# --- The parser ----------------------------------------------------------------

static func _parse_nodes(st: Dictionary, in_branch: bool, in_plural: bool) -> Array:
	var s: String = st["s"]
	var nodes := []
	var text := ""
	while int(st["i"]) < s.length():
		var i: int = st["i"]
		var c := s[i]
		if c == "'":
			# '' is a literal quote; 'x…' quotes up to the next lone quote.
			if i + 1 < s.length() and s[i + 1] == "'":
				text += "'"
				st["i"] = i + 2
				continue
			if i + 1 < s.length() and (s[i + 1] == "{" or s[i + 1] == "}" or s[i + 1] == "#"):
				var close := s.find("'", i + 1)
				if close < 0:
					close = s.length()
				text += s.substr(i + 1, close - i - 1)
				st["i"] = close + 1
				continue
			text += "'"
			st["i"] = i + 1
			continue
		if c == "}":
			if in_branch:
				break
			st["error"] = "an unmatched } at %d" % i
			return nodes
		if c == "#" and in_plural:
			if text != "":
				nodes.append([TEXT, text])
				text = ""
			nodes.append([HASH])
			st["i"] = i + 1
			continue
		if c == "{":
			if text != "":
				nodes.append([TEXT, text])
				text = ""
			st["i"] = i + 1
			var node := _parse_argument(st)
			if st.has("error"):
				return nodes
			nodes.append(node)
			continue
		text += c
		st["i"] = i + 1
	if text != "":
		nodes.append([TEXT, text])
	return nodes


static func _parse_argument(st: Dictionary) -> Array:
	var s: String = st["s"]
	var name := _read_until(st, [",", "}"]).strip_edges()
	if name == "":
		st["error"] = "an argument with no name"
		return []
	if int(st["i"]) >= s.length():
		st["error"] = "an argument that never closes: {%s" % name
		return []
	if s[int(st["i"])] == "}":
		st["i"] = int(st["i"]) + 1
		return [ARG, name]

	st["i"] = int(st["i"]) + 1
	var kind := _read_until(st, [",", "}"]).strip_edges()
	if kind == "number" or kind == "date" or kind == "time":
		# A style after the kind ("{n, number, integer}") is accepted and not applied.
		_read_until(st, ["}"])
		st["i"] = int(st["i"]) + 1
		return [NUMBER if kind == "number" else ARG, name]
	if kind != "plural" and kind != "select" and kind != "selectordinal":
		st["error"] = "unknown argument type '%s'" % kind
		return []
	if int(st["i"]) >= s.length() or s[int(st["i"])] != ",":
		st["error"] = "%s with no branches" % kind
		return []
	st["i"] = int(st["i"]) + 1

	var branches := {}
	while int(st["i"]) < s.length():
		_skip_space(st)
		if int(st["i"]) < s.length() and s[int(st["i"])] == "}":
			st["i"] = int(st["i"]) + 1
			if not branches.has("other"):
				st["error"] = "%s without an 'other' branch, which ICU requires" % kind
			return [SELECT if kind == "select" else PLURAL, name, branches]
		var key := _read_until(st, ["{", "}"]).strip_edges()
		if key.begins_with("offset:"):
			st["error"] = "plural offsets are not supported"
			return []
		if int(st["i"]) >= s.length() or s[int(st["i"])] != "{" or key == "":
			st["error"] = "a branch without a body in '%s'" % name
			return []
		st["i"] = int(st["i"]) + 1
		branches[key] = _parse_nodes(st, true, kind != "select")
		if st.has("error"):
			return []
		if int(st["i"]) >= s.length():
			st["error"] = "a branch that never closes in '%s'" % name
			return []
		st["i"] = int(st["i"]) + 1
	st["error"] = "an argument that never closes: {%s" % name
	return []


static func _read_until(st: Dictionary, stops: Array) -> String:
	var s: String = st["s"]
	var start: int = st["i"]
	var i := start
	while i < s.length() and not stops.has(s[i]):
		i += 1
	st["i"] = i
	return s.substr(start, i - start)


static func _skip_space(st: Dictionary) -> void:
	var s: String = st["s"]
	var i: int = st["i"]
	while i < s.length() and (s[i] == " " or s[i] == "\n" or s[i] == "\t"):
		i += 1
	st["i"] = i


## A number with the locale's grouping and decimal separator.
##
## Grouping is what a reader notices first — "12,500" read in German is twelve and a
## half — so it is done per language rather than left as the engine's bare digits.
static func _number(v: Variant, locale: String) -> String:
	if not (v is int or v is float):
		return str(v) if v != null else ""
	var lang := DotLocalePlural.language_of(locale)
	var group := ","
	var point := "."
	match lang:
		"de", "nl", "es", "pt", "it", "da", "id":
			group = "."
			point = ","
		"fr", "ru", "uk", "pl", "cs", "sk", "sv", "fi", "nb", "no":
			group = " "
			point = ","
	var neg := float(v) < 0.0
	var whole := absi(int(float(v)))
	var frac := ""
	if v is float and not is_equal_approx(float(v), floorf(float(v))):
		var s := String.num(absf(float(v)), 3)
		var dot := s.find(".")
		if dot >= 0:
			frac = s.substr(dot + 1).rstrip("0")
	var digits := str(whole)
	var grouped := ""
	var count := 0
	for k in range(digits.length() - 1, -1, -1):
		grouped = digits[k] + grouped
		count += 1
		if count % 3 == 0 and k > 0:
			grouped = group + grouped
	var out := ("-" if neg else "") + grouped
	if frac != "":
		out += point + frac
	return out
