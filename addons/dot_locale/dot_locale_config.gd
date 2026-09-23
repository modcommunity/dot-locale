@tool
class_name DotLocaleConfig
extends DotConfig

## Which language, where the messages are, and whether to pseudo-localise.
##
## Layered like every config here, so a tester can run a build in German with
## `--locale-language de` or pseudo-localised with `--locale-pseudo true` without a
## settings screen, and a player's choice from dot-settings is one more layer on top.

## The player's language, as a tag ("de", "pt-BR"). Empty asks the operating system.
@export var language: String = ""

## Where the chain ends. The language every key must exist in.
@export var default_language: String = "en"

## The directory holding one sub-directory per language, each with one JSON file per
## namespace — the website's own layout.
@export var directory: String = "res://locales"

## Show every message pseudo-localised: accented, bracketed, a third longer.
@export var pseudo: bool = false


func env_prefix() -> String:
	return "DOT_LOCALE_"


func cli_prefix() -> String:
	return "--locale-"


func validate() -> DotResult:
	if DotLocaleCatalogue.normalise(default_language) == "":
		return DotResult.fail(DotError.CODE_INVALID, "a default language is required: it is where every fallback ends")
	return DotResult.success(null)


## Builds a [DotLocale] from this configuration, reading [member directory] if it exists.
## A missing directory is not an error: a game with no translations yet still gets keys
## back, and a key on screen is how the first missing string is found.
func make() -> DotResult:
	var valid := validate()
	if not valid.ok:
		return valid
	var cat := DotLocaleCatalogue.new()
	if DirAccess.dir_exists_absolute(directory):
		var loaded := cat.load_dir(directory)
		if not loaded.ok:
			DotLog.warn("locale", "some locale files did not load", {"detail": loaded.error.detail})
	var loc := DotLocale.new(cat, language, default_language)
	loc.pseudo = pseudo
	return DotResult.success(loc)


func describe_lines(_redact_sensitive: bool = true) -> PackedStringArray:
	return PackedStringArray([
		"locale: %s, falling back to %s, from %s%s" % [
			language if language != "" else "(the system's)", default_language, directory,
			", pseudo" if pseudo else "",
		],
	])
