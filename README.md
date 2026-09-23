This is the **locale** asset for TMC's **Dot** collection. It translates a game's text into the player's language, using the same files, message format and keys as the TMC website — so a game can show the website's own messages, such as why a party would not let you in, in any of the nine languages the website already speaks.

This collection of assets provides modular building blocks for creating games and applications within the TMC ecosystem, ensuring consistency and interoperability across all `dot-*` assets. This includes core functionality, networking, authentication, cloud integration, and more.

**These assets are COMPLETELY OPEN SOURCE**. You are free to use, modify, and distribute them under the terms of the MIT license. The only thing not open source is the back-end web infrastructure. So if you opt into using your own authentication backend instead of integrating with TMC, you will need to build and integrate your own back-end infrastructure.

## From Maintainer & WARNING
This asset, along with all the others, was built initially with **Claude Code** and will continue to be maintained and extended using it. This is because I (`gamemann`) cannot build the entire TMC platform alone (I wish I could lol).

**Please treat this as partially tested.** Every asset has its own headless test suite and those suites pass, but very little of this has been in front of real players yet. Expect rough edges, and please report anything you run into.

## The website's layout, read as it is

One folder per language, one JSON file per area, nested objects inside:

```
locales/
  en/party.json    { "join": { "deny": { "full": "This party is full." } } }
  de/party.json    { "join": { "deny": { "full": "Diese Party ist voll." } } }
```

A message's key is the file name plus its path: `party.join.deny.full`. That is exactly the key the website's API refuses with, so there is no mapping table between what the website says and what the game shows.

```gdscript
var loc: DotLocale = DotLocaleConfig.new().make().value   # reads res://locales
label.text = loc.t("party.ready.count", {"count": 3})
status.text = loc.explain(result.error)                    # a website refusal, in the player's language
```

## Messages are ICU, like the website's

`{user} joined.`, `{n, number}`, `{kind, select, host {…} other {…}}` and plurals — `{count, plural, one {# round} few {# раунда} many {# раундов} other {# rounds}}` — nested to any depth. Plurals use the real rules for each language: Russian picks between four forms by the last one and two digits, French puts zero with one, and Japanese has one form. The English rule "1 is singular, everything else plural" is wrong in most of the languages the website already ships.

Numbers are grouped the way the reader expects: `12,500` in English, `12.500` in German, `12 500` in French.

## Nothing is ever blank

The player's language falls back to the language without its region, then to the default language, and finally to **the key itself**. A missing translation is normal for a game that updates faster than its translators work. A blank label is a bug nobody reports; a key on screen is ugly, searchable, and tells the developer exactly which line to add. `missing_keys()` lists every key asked for that no language had.

## Finding problems before paying for a translation

**Pseudo-localisation** (`--locale-pseudo true`) shows every message accented, bracketed and about a third longer: `[Ŝáɱ ĵóíñéð. ~·~·]`.

- A string still in plain English on that screen never went through the catalogue. It is hard-coded, and will be English in every language.
- A missing closing bracket is a label that fits English and cuts German off.

`missing_in("de")` lists the keys a language lacks. `argument_mismatches("de")` finds translations that use a different placeholder from the English, which would otherwise show `{player}` to every German player.

## Installing

Copy `addons/dot_locale/` and [`dot-core`](https://github.com/modcommunity/dot-core)'s `addons/dot_core/` into your project and enable it in **Project → Project Settings → Plugins**.

## Dependencies

[dot-core](https://github.com/modcommunity/dot-core). Nothing else.

## Licence

MIT. See [LICENSE](LICENSE).
