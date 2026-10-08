This is the **locale** asset for TMC's **Dot** collection. It translates a game's text into the player's language, using the same files, message format and keys as the TMC website — so a game can show the website's own messages, such as why a party would not let you in, in any of the nine languages the website already speaks.

This collection of assets provides modular building blocks for creating games and applications within the TMC ecosystem, ensuring consistency and interoperability across all `dot-*` assets. This includes core functionality, networking, authentication, cloud integration, and more.

**These assets are COMPLETELY OPEN SOURCE**. You are free to use, modify, and distribute them under the terms of the MIT license. The only thing not open source is the back-end web infrastructure. So if you opt into using your own authentication backend instead of integrating with TMC, you will need to build and integrate your own back-end infrastructure.

## From Maintainer & WARNING
This asset, along with all the others, was built initially with **Claude Code** and will continue to be maintained and extended using it. This is because I (`gamemann`) cannot build the entire TMC platform alone (I wish I could lol).

**Please treat this as partially tested.** Every asset has its own headless test suite and those suites pass, but very little of this has been in front of real players yet. Expect rough edges, and please report anything you run into.

I intend on reviewing code, testing, and editing documentation regularly. If you're interested in helping out, please let me know!

## What it does
It translates a game's text into the player's language. It reads the same files the TMC website uses, in the same message format and with the same keys. So when the website refuses something (a party that is full, say), the game can show the website's own message in any of the nine languages it already has, with nothing to keep in sync.

Messages use the ICU format, so one message can handle names, numbers, choices and plurals. Plurals follow each language's real rules: Russian has several forms chosen by the last digits, French puts 0 with 1, and Japanese has only one form. Numbers are grouped the way each reader expects: `12,500` in English, `12.500` in German, `12 500` in French.

A label is never blank. If the player's language has no translation, it falls back to the language without its region (`de-AT` to `de`), then to the default language, and finally shows **the key itself**, so a missing line is easy to spot and search for.

## Getting started
You need [Godot 4.7](https://godotengine.org/download). The easiest way to get this addon and the ones it needs is [dot-bootstrap](https://github.com/modcommunity/dot-bootstrap), which clones every project and links the addons into each one.

To add it to your own project by hand, copy `addons/dot_locale/` and [dot-core](https://github.com/modcommunity/dot-core)'s `addons/dot_core/` into it and enable dot-locale in **Project → Project Settings → Plugins**. dot-core is the only dependency.

## The files
One folder per language, one JSON file per area, with nested objects inside. This is the website's own layout:

```
locales/
  en/party.json    { "join": { "deny": { "full": "This party is full." } } }
  de/party.json    { "join": { "deny": { "full": "Diese Party ist voll." } } }
```

A message's key is the file name plus its path: `party.join.deny.full`. That is the same key the website's API sends back when it refuses something.

## Using it

```gdscript
var config := DotLocaleConfig.new()
config.load_layered()                        # so --locale-language and --locale-pseudo apply
var loc: DotLocale = config.make().value     # reads res://locales

label.text = loc.t("party.join.deny.full")
label.text = loc.t("party.ready.count", {"count": 3})
status.text = loc.explain(result.error)      # a website refusal, in the player's language

loc.set_locale("de")                         # when the player picks a language
```

Messages look like this:

```
{user} joined.
{n, number} points
{kind, select, host {You are the host.} other {Waiting for the host.}}
{count, plural, one {# player ready} other {# players ready}}
```

`explain(error)` shows the translation for the key in the error's detail, and falls back to the error's own message if there is none. `to_translation("de")` turns the messages with no placeholders into an engine `Translation`, so a `Control` with auto-translate shows them too.

## Finding missing translations

```bash
godot --path my-game -- --locale-pseudo true    # every message accented, bracketed and a third longer
godot --path my-game -- --locale-language de    # run the game in German
```

Pseudo-localisation shows `Sam joined.` as `[Sam ĵóíñéð. ~·~]`. Any text still in plain English never went through the catalogue and will be English in every language. A missing closing bracket means a label that fits English will cut off a longer language.

- `loc.missing_keys()` lists every key the game asked for that no language had.
- `loc.catalogue.missing_in("de")` lists the keys German lacks compared with English.
- `loc.catalogue.argument_mismatches("de")` lists German messages whose placeholders differ from the English ones, which would otherwise show `{player}` on screen.

## Settings
`DotLocaleConfig` is layered like every Dot config: inspector defaults, then a JSON file, then the environment, then the command line. Call `load_layered()` before `make()`.

| Setting | Default | What it does |
| --- | --- | --- |
| `language` | empty | The player's language (`de`, `pt-BR`). Empty uses the operating system's |
| `default_language` | `en` | The last language tried, and the one every key must exist in |
| `directory` | `res://locales` | The folder with one sub-folder per language |
| `pseudo` | false | Show every message pseudo-localised |

From the environment they are `DOT_LOCALE_LANGUAGE` and so on, and on the command line `--locale-language`.

## Testing

```bash
godot --headless --path . --import
godot --headless --path . res://examples/locale_selftest.tscn
```

## License
MIT. See [LICENSE](LICENSE).
