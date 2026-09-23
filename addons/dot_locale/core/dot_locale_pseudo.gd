class_name DotLocalePseudo
extends RefCounted

## Pseudo-localisation: every message made longer, accented and bracketed, placeholders intact.
##
## [b]What it finds is what no translator can.[/b] A string still in English on a pseudo
## build was never put through the catalogue — it is hard-coded, and it will be English in
## every language. A bracket missing from the end of a line was cut off by a label that fits
## English and not German, which runs about a third longer. A garbled placeholder is a
## pattern that builds its sentence by concatenation. All three are visible on one screen
## on the first run, long before anybody has paid for a translation.
##
## The ICU structure is left alone — argument names, plural keywords, the [code]#[/code] —
## because a pseudo build that broke its own patterns would find bugs it had made.

const MAP := {
	"a": "á", "b": "ƀ", "c": "ç", "d": "ð", "e": "é", "f": "ƒ", "g": "ĝ", "h": "ĥ", "i": "í",
	"j": "ĵ", "k": "ķ", "l": "ĺ", "m": "ɱ", "n": "ñ", "o": "ó", "p": "þ", "q": "ǫ", "r": "ŕ",
	"s": "š", "t": "ţ", "u": "ú", "v": "ṽ", "w": "ŵ", "x": "ẋ", "y": "ý", "z": "ž",
	"A": "Á", "B": "Ɓ", "C": "Ç", "D": "Ð", "E": "É", "F": "Ƒ", "G": "Ĝ", "H": "Ĥ", "I": "Í",
	"J": "Ĵ", "K": "Ķ", "L": "Ĺ", "M": "Ṁ", "N": "Ñ", "O": "Ó", "P": "Þ", "Q": "Ǫ", "R": "Ŕ",
	"S": "Š", "T": "Ţ", "U": "Ú", "V": "Ṽ", "W": "Ŵ", "X": "Ẋ", "Y": "Ý", "Z": "Ž",
}

## How much longer. German and French run 30-40% over English in interface text.
const EXPANSION := 0.35


static func transform(pattern: String) -> String:
	var out := ""
	# Inside an argument's header ("{count, plural, one ") nothing is text; inside a
	# branch body it is text again. A brace opened from text starts a header, and a brace
	# opened from a header starts a body, so each "{" flips the state and each "}" restores
	# whatever the matching "{" interrupted.
	var stack: Array[bool] = []
	var header := false
	var letters := 0
	for ch in pattern:
		if ch == "{":
			stack.append(header)
			header = not header
			out += ch
			continue
		if ch == "}":
			header = stack.pop_back() if not stack.is_empty() else false
			out += ch
			continue
		if header:
			out += ch
			continue
		if MAP.has(ch):
			out += str(MAP[ch])
			letters += 1
		else:
			out += ch
	var pad_length := int(ceil(letters * EXPANSION))
	var pad := ""
	for i in range(pad_length):
		pad += "~" if i % 2 == 0 else "·"
	return "[" + out + (" " + pad if pad != "" else "") + "]"
