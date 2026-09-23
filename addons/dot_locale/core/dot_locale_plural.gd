class_name DotLocalePlural
extends RefCounted

## Which plural form a number takes, per language, from the CLDR rules.
##
## [b]"one" and "other" is an English idea.[/b] Russian has four forms and chooses between
## them by the last digit and the last two — 21 is "one", 12 is "many", 22 is "few" —
## Japanese and Chinese have one, and French puts zero with one. A game that writes
## [code]"%d round" + ("s" if n != 1 else "")[/code] is wrong in most of the languages
## the website already ships, and wrong in a way nobody who speaks only English will see.
##
## The rules are CLDR's cardinal rules, transcribed for the languages website-city
## translates into plus the neighbours that share them. A language not here answers
## "other", which is always a valid ICU branch, so the worst case is a grammatically
## flat sentence rather than a missing one.
##
## [code]i[/code] is the integer part, [code]v[/code] the number of visible fraction
## digits: CLDR's own operands, because "1 round" and "1.0 rounds" are both correct
## English, and only the operands can tell them apart.

const ONE := "one"
const FEW := "few"
const MANY := "many"
const OTHER := "other"


## The category of [param n] in [param locale]. [param fraction_digits] is how many
## digits after the point will be SHOWN, which is what CLDR decides by, not the value.
static func category(locale: String, n: float, fraction_digits: int = -1) -> String:
	var lang := language_of(locale)
	var v := fraction_digits
	if v < 0:
		v = 0 if is_equal_approx(n, floorf(n)) else _visible_digits(n)
	var i := int(absf(n))

	match lang:
		"en", "de", "nl", "sv", "da", "no", "nb", "fi", "et", "it", "ca":
			return ONE if i == 1 and v == 0 else OTHER
		"es":
			return ONE if is_equal_approx(absf(n), 1.0) else OTHER
		"pt":
			# Brazilian Portuguese, which is what the site's pt is: 0 and 1 are both "one".
			if locale.to_lower().replace("_", "-") == "pt-pt":
				return ONE if i == 1 and v == 0 else OTHER
			return ONE if i <= 1 else OTHER
		"fr":
			return ONE if i <= 1 else OTHER
		"ru", "uk", "be":
			if v != 0:
				return OTHER
			var m10 := i % 10
			var m100 := i % 100
			if m10 == 1 and m100 != 11:
				return ONE
			if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
				return FEW
			return MANY
		"pl":
			if v != 0:
				return OTHER
			if i == 1:
				return ONE
			var m10 := i % 10
			var m100 := i % 100
			if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
				return FEW
			return MANY
		"cs", "sk":
			if v != 0:
				return MANY
			if i == 1:
				return ONE
			if i >= 2 and i <= 4:
				return FEW
			return OTHER
		"ja", "zh", "ko", "th", "vi", "id", "ms":
			return OTHER
	return OTHER


## "pt-BR" → "pt", "zh_Hans_CN" → "zh".
static func language_of(locale: String) -> String:
	var tag := locale.to_lower().replace("_", "-")
	var dash := tag.find("-")
	return tag if dash < 0 else tag.substr(0, dash)


static func _visible_digits(n: float) -> int:
	var s := str(n)
	var dot := s.find(".")
	return 0 if dot < 0 else s.length() - dot - 1
