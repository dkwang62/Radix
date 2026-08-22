# Variant Meaning Migration - 22 Aug 2026

This was a one-time, conservative correction of dictionary entries whose entire
meaning was a `variant of ...` reference. The migration tooling was removed
after verification.

## Applied

- `phrases.db`: enriched 1,171 meanings with the directly referenced phrase's
  nonvariant definition while preserving the original variant relationship.
- Character dictionary: enriched four definitions (`丂`, `㐱`, `歨`, `玨`) and
  persisted the complete records in `component_map_changes.json`.
- No phrase rows were added or deleted. Phrase words and pinyin were unchanged.

Example: `variant of 洄游[huí yóu]` became
`variant of 洄游[huí yóu]; (of fish) to migrate`.

## Intentionally Skipped

- 105 entries that already contained meaning beyond the variant reference.
- 103 unresolved or self-only references.
- 9 references whose target was itself only a variant.
- 0 conflicting target definitions.

## Verification

- Phrase rows before and after: 108,596.
- SQLite integrity check: `ok`.
- A second apply attempt found zero eligible records, refused to run, and left
  both dictionaries byte-identical.
- Before SHA-256, `phrases.db`:
  `98086c92c41236dec2f2669c0a0ef37446f635955f0835809e46e80f333c9bcf`.
- After SHA-256, `phrases.db`:
  `c8469912a95a6598a9a29e6bac83ed68fc682640989fdd4af9d1f271f9fbbec8`.
- Before SHA-256, character JSON:
  `4959a52b8811c8b5161bb08f46744bfdc02dc4aea1381a850a1cef98e8ff34c7`.
- After SHA-256, character JSON:
  `cbbdfc6ce09ef72169202738ba7ccdb35d2b27524ceec9383945b046f32910df`.

Local pre-migration copies and detailed reports are under
`Backups/variant_meaning_migration_20260822/`; `Backups/` remains outside Git.
