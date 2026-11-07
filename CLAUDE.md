# dot-locale

Localisation that reads website-city's own locale files: ICU MessageFormat, CLDR plural rules, a fallback chain that ends in the key, and pseudo-localisation. It turns the reason keys the site and dot-party return into sentences in the player's language.

Read the family [CLAUDE.md](../../CLAUDE.md) first.

**The distributable is `addons/dot_locale/`.** It requires [dot-core](../dot-core) and nothing else (`ln -s ../../dot-core/addons/dot_core addons/dot_core`, gitignored).

## Read before

| Read | Before |
| --- | --- |
| [docs/design.md](docs/design.md) | changing anything: why it exists, the chain, plural language, raw patterns, JSON loading, engine `Translation`, pseudo, what is deliberately not here |
| [docs/history.md](docs/history.md) | the three things building it found |

## Layout

| Path | What |
| --- | --- |
| `core/dot_locale_plural.gd` | `DotLocalePlural`: CLDR cardinal rules with CLDR's operands; unknown language → `other` |
| `core/dot_locale_format.gd` | `DotLocaleFormat`: the ICU subset, compiled to a tree once |
| `core/dot_locale_catalogue.gd` | `DotLocaleCatalogue`: locale → key → pattern; `load_dir`, `add(locale, ns, tree)`, `missing_in`, `argument_mismatches` |
| `core/dot_locale_pseudo.gd` | `DotLocalePseudo`: accent, bracket, expand, keep the ICU structure |
| `runtime/dot_locale.gd` | `DotLocale`: the translator; `t`, `explain(DotError)`, `chain`, `missing_keys`, `to_translation`, `register` |
| `dot_locale_config.gd` | `DotLocaleConfig`: `language`, `default_language`, `directory`, `pseudo`, layered (`--locale-language de`, `--locale-pseudo true`) |
| `examples/locale_selftest.tscn` | the suite; writes nothing outside `user://` |

Paths except `examples/` are in `addons/dot_locale/`.

## Running and testing

The family's two steps ([family CLAUDE.md](../../CLAUDE.md#validating-anything)), then `timeout 60 godot --headless --path . res://examples/locale_selftest.tscn`. Stderr should be empty.

## Rules that bite

- The fallback chain ends in the key, never an empty string. [design](docs/design.md#the-chain-ends-in-the-key)
- Pluralise by the language the pattern was found in, not the player's; keep the suite's non-English plural section. [design](docs/design.md#plural-rules-follow-the-patterns-language-not-the-players)
- A pattern that does not parse is shown raw. [design](docs/design.md#a-pattern-that-does-not-parse-is-shown-raw)
- Load JSON with a `JSON` instance, never `JSON.parse_string`; one bad file refuses only itself. [design](docs/design.md#a-catalogue-load-does-not-print-engine-errors)
- Only argument-free messages go into an engine `Translation`. [design](docs/design.md#only-argument-free-messages-become-an-engine-translation)
- One `DotLocale` per language in use, found through `DotRegistry`; no autoload, no Node. [design](docs/design.md#not-an-autoload-and-not-a-node)
- `namespace` is reserved in GDScript; the parameter is `ns`. [history](docs/history.md#namespace-is-a-reserved-word)
- The site's locale files are never copied into this repository. [design](docs/design.md#the-sites-locale-files-are-not-copied-into-this-repository)

Not yet supported: right-to-left layout, date and time formatting, ordinals, CJK font fallback. [design](docs/design.md#things-deliberately-not-here)
