Translates a game's text into the player's language. It reads the same files, message format and keys as the TMC website, so when the website refuses something (a full party, say), the game can show the website's own message in any language the website has, with nothing to keep in sync.

Part of TMC's **Dot** collection: modular, MIT-licensed building blocks for games on the TMC platform (only the TMC website back end is closed). It was built with Claude Code and its headless suite passes, but little of it has met real players yet, so expect rough edges and please report what you find.

## Features

- Messages use the ICU format: names, numbers, choices and plurals in one message. Plurals follow each language's real rules (Russian by last digits, French puts 0 with 1, Japanese has one form).
- Numbers are grouped the way the reader expects: `12,500` in English, `12.500` in German, `12 500` in French.
- A label is never blank. A missing translation falls back from `de-AT` to `de`, then to the default language, then shows the key itself so it is easy to find.

## Install

You need [Godot 4.7](https://godotengine.org/download). [dot-bootstrap](https://github.com/modcommunity/dot-bootstrap) clones every project and links the addons for you.

By hand: copy `addons/dot_locale/` and [dot-core](https://github.com/modcommunity/dot-core)'s `addons/dot_core/` into your project and enable dot-locale in **Project > Project Settings > Plugins**. dot-core is the only dependency.

## Files

One folder per language, one JSON file per area, objects nested inside (the website's layout):

```
locales/
  en/party.json    { "join": { "deny": { "full": "This party is full." } } }
  de/party.json    { "join": { "deny": { "full": "Diese Party ist voll." } } }
```

A key is the file name plus the path: `party.join.deny.full`, the same key the website's API returns on a refusal.

## Use

```gdscript
var config := DotLocaleConfig.new()
config.load_layered()                        # so --locale-language and --locale-pseudo apply
var loc: DotLocale = config.make().value     # reads res://locales

label.text = loc.t("party.join.deny.full")
label.text = loc.t("party.ready.count", {"count": 3})
status.text = loc.explain(result.error)      # a website refusal, in the player's language

loc.set_locale("de")                         # when the player picks a language
```

Message examples:

```
{user} joined.
{n, number} points
{kind, select, host {You are the host.} other {Waiting for the host.}}
{count, plural, one {# player ready} other {# players ready}}
```

`explain(error)` shows the translation for the key in the error's detail, or the error's own message if there is none. `to_translation("de")` turns the placeholder-free messages into an engine `Translation`, so a `Control` with auto-translate shows them too.

## Finding missing translations

```bash
godot --path my-game -- --locale-pseudo true    # every message accented, bracketed and a third longer
godot --path my-game -- --locale-language de    # run the game in German
```

Pseudo-localisation shows `Sam joined.` as `[Sam ĵóíñéð. ~·~]`. Text still in plain English never went through the catalogue. A missing closing bracket means a longer language will be cut off.

| Call | Lists |
| --- | --- |
| `loc.missing_keys()` | Keys the game asked for that no language had. |
| `loc.catalogue.missing_in("de")` | Keys German lacks compared with English. |
| `loc.catalogue.argument_mismatches("de")` | German messages whose placeholders differ from the English. |

## Settings

`DotLocaleConfig` is layered like every Dot config: inspector defaults, a JSON file, the environment, then the command line. Call `load_layered()` before `make()`. Environment names look like `DOT_LOCALE_LANGUAGE`, flags like `--locale-language`.

| Setting | Default | What it does |
| --- | --- | --- |
| `language` | empty | The player's language (`de`, `pt-BR`). Empty uses the operating system's. |
| `default_language` | `en` | The last language tried, and the one every key must exist in. |
| `directory` | `res://locales` | Folder with one sub-folder per language. |
| `pseudo` | false | Show every message pseudo-localised. |

## Test

```bash
godot --headless --path . --import
godot --headless --path . res://examples/locale_selftest.tscn
```

## Licence

MIT. See [LICENSE](LICENSE).
