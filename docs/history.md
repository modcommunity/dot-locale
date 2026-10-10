# dot-locale history

What building it found. The rules these left are in [CLAUDE.md](../CLAUDE.md) and [design.md](design.md).

## `namespace` is a reserved word

`func add(locale, namespace, tree)` failed to parse, every file that referenced the catalogue failed with it, and the suite scene **hung** rather than failing: the hazard in [gdscript-hazards.md](../../../docs/gdscript-hazards.md), reached again. The parameter is `ns`.

## A green run with an error on stderr

`JSON.parse_string` prints its own `ERROR` line for the deliberately broken file in the suite, so a passing run still had an error on stderr. Hence the `JSON` instance ([design](design.md#a-catalogue-load-does-not-print-engine-errors)).

## The pseudo-localiser skipped plural bodies

The first version treated everything after a `{` as a header, branch bodies included, so `other {# rounds}` came out unaccented. Caught on review before the suite first ran. Fixed by the header/body flip described in [design](design.md#pseudo-localisation-reaches-branch-bodies).
