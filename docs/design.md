# dot-locale design

Why the addon exists and the decisions behind it. The one-line rules are in [CLAUDE.md](../CLAUDE.md).

## Why this exists

Before it, nothing in the family localised anything: no addon or game called `TranslationServer`, and every string on every screen was an English literal. Meanwhile website-city is translated into nine languages (`locales/{de,en,es,fr,ja,nl,pt,ru,zh}/*.json`, about fifty namespaces each, rendered by next-intl) and refuses API requests with **keys** (`party.join.deny.full`) rather than prose. dot-party carries those keys in `DotError.detail`. This addon turns one into a sentence in the player's language without a second table. Its first consumer is dot-server-deploy's client shell.

## The chain ends in the key

`pt-BR → pt → en → "party.join.deny.full"`. An empty label is a bug nobody reports; a key is searchable and a screenshot of it names the line to add.

## Plural rules follow the pattern's language, not the player's

A message found in the English fallback for a Russian player is an English sentence, so it is pluralised by English rules. Russian rules would choose `few` and find no such branch. The suite's first section is the one to keep: every English check would pass against a plural rule that is wrong in Russian, Polish, French and Portuguese.

`DotLocalePlural` uses CLDR's own operands (`i`, `v`). An unknown language gets `other`, which every ICU plural must have.

## A pattern that does not parse is shown raw

`DotLocaleFormat` compiles the ICU subset the site uses (argument, `number`, `plural` with `=N` and `#`, `select`, quoting) to a tree once. A pattern that fails to parse is displayed as written: wrong-looking text on screen is reported, a blank is not.

## A catalogue load does not print engine errors

`JSON.parse_string` prints an engine `ERROR` for a translator's trailing comma and then tells the caller nothing. `load_dir` uses a `JSON` instance instead: stderr stays clean, and the file, line and message go into the result. One bad file refuses itself only.

## Only argument-free messages become an engine `Translation`

`tr()` knows nothing of ICU. `to_translation()` exists so a `Control` with auto-translate shows static text from the same catalogue; a plural handed to the engine would show its braces.

## Not an autoload, and not a Node

A server rendering messages for players in four languages needs four translators. `register()` puts one in `DotRegistry` for code that wants to find it without naming it.

## Pseudo-localisation reaches branch bodies

`DotLocalePseudo` accents, brackets and expands by 35% (`EXPANSION`) while leaving the ICU structure alone. Each `{` flips between header and body and each `}` restores what its `{` interrupted, so `other {# rounds}` is transformed too: a message that looks untouched on a pseudo build reads as hard-coded, which is the one thing pseudo-localisation exists to tell you. The suite checks that a transformed plural still compiles and still formats.

## The site's locale files are not copied into this repository

They are the site's content, in a private repository, and change on the site's schedule. A game ships the ones it uses, or fetches them: dot-cloud can deliver a locale pack like any other content.

## Things deliberately not here

- **Right-to-left layout.** The site ships no RTL language. A game that adds one needs `Control.layout_direction`, which is the engine's.
- **Date and time formatting.** `{d, date}` is accepted and rendered as the raw value. Nobody here formats one yet, and a half-right date format is worse than an honest number.
- **Ordinals** (`selectordinal`) are parsed as plurals, which is wrong for English "1st, 2nd". Nothing uses them yet.
- **Font fallback for CJK.** A game showing Japanese needs a font with the glyphs; that is a theme decision, not a string one.
