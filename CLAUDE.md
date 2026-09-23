# dot-locale

Localisation that reads website-city's own locale files: ICU MessageFormat, CLDR plural rules, a fallback chain that ends in the key, and pseudo-localisation.

**The distributable is `addons/dot_locale/`.** It requires [dot-core](../dot-core), a separate repository, and nothing else.

```bash
ln -s ../../dot-core/addons/dot_core addons/dot_core
```

## Why this exists

**Nothing in the family localised anything.** No addon or game called `TranslationServer`, every string on every screen was an English literal, and dot-ui is proud of shipping no art assets while shipping only English. Meanwhile website-city is translated into nine languages (`locales/{de,en,es,fr,ja,nl,pt,ru,zh}/*.json`, about fifty namespaces, rendered by next-intl) and refuses API requests with **keys** — `party.join.deny.full` — rather than prose. dot-party carries those keys in `DotError.detail`. This addon is what turns one into a sentence in the player's language without a second table.

## The pieces

| | |
| --- | --- |
| `DotLocalePlural` | CLDR cardinal rules for the site's languages and their neighbours, with CLDR's own operands (`i`, `v`). Unknown language → `other`, which every ICU plural must have. |
| `DotLocaleFormat` | The ICU subset the site uses: argument, `number`, `plural` (with `=N` and `#`), `select`, quoting. Compiled to a tree once. A pattern that does not parse is **shown raw**. |
| `DotLocaleCatalogue` | locale → key → pattern. `load_dir` reads the site's layout; one bad file refuses itself only. `missing_in`, `argument_mismatches`. |
| `DotLocale` | The translator: chain, `t`, `explain`, `missing_keys`, `to_translation`. |
| `DotLocalePseudo` | Accent, bracket, expand by 35%, leave the ICU structure alone. |
| `DotLocaleConfig` | `language`, `default_language`, `directory`, `pseudo` — layered, so `--locale-language de` and `--locale-pseudo true` work without a settings screen. |

## Decisions

### The chain ends in the key

`pt-BR → pt → en → "party.join.deny.full"`. An empty label is a bug nobody reports; a key is searchable and a screenshot of it names the line to add.

### Plural rules follow the pattern's language, not the player's

A message found in the English fallback for a Russian player is an English sentence, so it is pluralised by English rules. Russian rules would choose `few` and find no such branch.

### A catalogue load does not print engine errors

`JSON.parse_string` prints an engine `ERROR` for a translator's trailing comma and then tells the caller nothing. A `JSON` instance is used instead: stderr stays clean, and the file, line and message go into the result.

### Only argument-free messages become an engine `Translation`

`tr()` knows nothing of ICU. `to_translation()` exists so a `Control` with auto-translate shows static text from the same catalogue; a plural handed to the engine would show its braces.

### Not an autoload, and not a Node

A server rendering messages for players in four languages needs four translators. `register()` puts one in `DotRegistry` for code that wants to find it without naming it.

### The site's locale files are not copied into this repository

They are the site's content, in a private repository, and change on the site's schedule. A game ships the ones it uses, or fetches them — dot-cloud can deliver a locale pack like any other content.

## What building it found

**`namespace` is a reserved word in GDScript 4.** `func add(locale, namespace, tree)` failed to parse, every file that referenced the catalogue failed with it, and the suite scene **hung** rather than failing — the hazard `docs/gdscript-hazards.md` describes, reached again. The parameter is `ns`.

**`JSON.parse_string` prints its own `ERROR` line** for the deliberately broken file in section 3, so a green run had an error on stderr. See Decisions.

**The first pseudo-localiser left every plural and select body alone.** It treated everything after a `{` as a header, branch bodies included, so `other {# rounds}` came out unaccented — and a message that looks untouched on a pseudo build reads as hard-coded, which is the one thing pseudo-localisation exists to tell you. That one was caught on review before the suite first ran, not by running it, so it is not the kind of finding this family counts. Each `{` now flips between header and body and each `}` restores what its `{` interrupted, and section 6 checks that a transformed plural still compiles and still formats.

## Things deliberately not here

- **Right-to-left layout.** The site ships no RTL language. A game that adds one needs `Control.layout_direction`, which is the engine's.
- **Date and time formatting.** `{d, date}` is accepted and rendered as the raw value. Nobody here formats one yet, and a half-right date format is worse than an honest number.
- **Ordinals** (`selectordinal`) are parsed as plurals, which is wrong for English "1st, 2nd". Nothing uses them yet.
- **Font fallback for CJK.** A game showing Japanese needs a font with the glyphs; that is a theme decision, not a string one.

## Validating

```bash
godot --headless --path . --import
find . -name '*.gd' -not -path './.godot/*' | while read f; do
    godot --headless --path . --check-only --script "res://${f#./}"
done
timeout 60 godot --headless --path . res://examples/locale_selftest.tscn
```

7 sections, 59 checks, no files outside `user://`. **Section 1 is the one to keep**: every English check passes against a plural rule that is wrong in Russian, Polish, French and Portuguese.
