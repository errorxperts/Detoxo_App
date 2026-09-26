# EVO-068 — Show what a rule will cover, live, in the editor

- Status: approved
- Tier: 2 (enhancement) — requires explicit per-proposal approval
- Feature: `lib/features/limits/rules` (domain + presentation), reading `lib/features/catalog` through its barrel
- Commit: 68827cf (working tree uncommitted — the 2026-09-08 rules Tier-1 batch is not yet committed)
- Date: 2026-09-08
- Effort: S

## Why
The editor's Block section names what the user *picked*, never what that flattens to. A category
chip is abstract — "Social" is 11 packages and 13 domains in the seed
(`lib/features/catalog/domain/app_category_seed.dart:76-142`), and the new **All distracting**
quick-pick selects four of them in one tap. `RuleSummary.targets`
(`lib/features/limits/rules/domain/usecases/rule_summary.dart:65-75`) renders "2 apps, 1 category"
— counts of picks, by design, so the *list* needs no scan. Nothing on the editor tells the user
the blast radius before Save; the flattening exists only inside the resolver
(`lib/features/limits/rules/domain/usecases/resolve_snapshot.dart`, `_flatten`).

## Expected user impact
One caption under the category rail: **"Covers 41 apps · 30 sites · 2 reel feeds"**, updating as
chips and tiles change. The quick-pick becomes tangible, an over-broad rule is visible before it
blocks something the user needed, and an under-scoped one (a website chip that covers only one
brand) is visible too. Peripheral to the in-the-moment loop, but it lowers the wrong-block rate
that drives overrides and mistrust of the wall.

## Technical complexity
Dart only. The resolver's private `_flatten` becomes a public pure function so the caption and the
snapshot are computed by the SAME code; a static `RuleSummary.coverage` counts it; the editor
renders one line. No channel key, no storage key, no manifest change.

## Performance impact
Runs on the editor's build after a selection change — ten categories, indexed catalog lookups
(`Catalog.packagesIn` is a map read). Never on the accessibility hot path, never on resync.

## Business value
`docs/info_docs/01-product-overview.md` §"Why Detoxo is different": *blocks the reels, not the
app — you can still message, search, and post*. Precision is the promise; a caption that says
"41 apps" before Save is how the user keeps it.

## Rejected alternative
Rendering the flattened list itself (every package and domain) in a sheet — rejected: 85 packages
is a wall of text nobody reads, and the list would need the installed-apps scan for labels. Counts
first; a sheet can come later if users ask what the 41 are.

## Rollback
Delete the caption and `RuleSummary.coverage`; keep `flattenTargets` public or fold it back into
the resolver. No persisted state.

## Implementation Plan

### Current state
`lib/features/limits/rules/domain/usecases/resolve_snapshot.dart` (working tree, after the
2026-09-08 batch):

```dart
/// Categories become their services' packages AND domains (a category is "the
/// service"); an explicitly picked app stays app-only, like the App Blocker.
/// A website that is a popular-site chip covers its aliases too: …
_Targets _flatten(RuleSelection sel, Catalog cat) {
  final packages = <String>{...sel.apps};
  final domains = <String>{
    for (final w in sel.websites) ...[
      Catalog.normalizeHost(w),
      ...PopularSites.aliasesFor(Catalog.normalizeHost(w)),
    ],
  };
  for (final id in sel.categories) {
    for (final pkg in cat.packagesIn(id)) {
      packages.add(pkg);
      domains.addAll(cat.domainsForPackage(pkg));
    }
  }
  domains.remove('');
  return _Targets(
    packages.toList(),
    domains.toList(),
    …
```

`lib/features/limits/rules/presentation/rule_editor_screen.dart`, the Block section ends with the
category rail:

```dart
          ChipRail(
            leading: AppChip(
              label: 'All distracting',
              …
            chips: [
              for (final c in AppCategorySeed.categories)
                AppChip(
                  …
          ),
          const SizedBox(height: AppSpacing.md),
          const SectionHeader('Commitment'),
```

### Target state
- `resolve_snapshot.dart`: `_Targets` and `_flatten` become public `FlattenedTargets` and
  `flattenTargets(RuleSelection, Catalog)` (same body, same doc comment). The resolver calls the
  public name; nothing else changes.
- `rule_summary.dart` gains
  `static ({int apps, int sites, int feeds}) coverage(RuleSelection s, Catalog cat)` returning
  `(apps: flat.packages.length, sites: flat.domains.length, feeds: s.platforms.length)`, and
  `static String coverageLine(RuleSelection s, Catalog cat)` rendering
  `"Covers 41 apps · 30 sites · 2 reel feeds"` with `RuleSummary.count` for each non-zero part,
  joined by ` · `; empty string when every count is zero.
- The editor renders, directly under the `ChipRail` and above the `Commitment` header:
  ```dart
  if (RuleSummary.coverageLine(_draftSelection, Catalog.bundled).isNotEmpty) ...[
    const SizedBox(height: AppSpacing.xs),
    Text(RuleSummary.coverageLine(_draftSelection, Catalog.bundled),
         style: text.bodySmall?.copyWith(color: context.glass.onGlassMuted)),
  ],
  ```
  where `_draftSelection` is a getter building the same `RuleSelection` `_save` builds (apps,
  categories, websites for schedules, platforms except for open limits) — extract that construction
  into the getter so `_save` and the caption cannot disagree.

### Repo conventions to follow
Pure static on `RuleSummary` with a test in `test/rules_engine_test.dart`'s `RuleSummary` group
(exemplar: `RuleSummary.targets`, tested there). Muted caption colour via `context.glass.onGlassMuted`
(`lib/core/design_system/theme/app_theme.dart`), as `InlineHint` does. Copy: one line, no paragraph.

### Steps
1. Rename `_Targets` → `FlattenedTargets`, `_flatten` → `flattenTargets` in `resolve_snapshot.dart`;
   update its internal call sites.
2. Add `RuleSummary.coverage` and `RuleSummary.coverageLine` in `rule_summary.dart`, importing the
   catalog barrel and `resolve_snapshot.dart`.
3. In `rule_editor_screen.dart`, extract `RuleSelection get _draftSelection` from `_save`'s
   `selection:` argument and use it in both places; render the caption under the rail.
4. Test in `rules_engine_test.dart`: `coverage` of `RuleSelection(categories: ['social'])` equals
   the seed's social package/domain counts; a website `x.com` counts 2 sites; an empty selection
   yields an empty line; the line uses ` · ` and singular/plural correctly.
5. `/docs-sync`: doc 27 §7 (editor) and `docs/info_docs/02` §14 (one sentence).

### Boundaries
Do NOT change what `flattenTargets` returns or how `resolveSnapshot` uses it. Do NOT add the
caption to the rules list (it must stay scan-free). If the code at the cited lines has drifted
from the Commit stamp above, STOP and report — do not improvise.

### Validation
- [ ] `bash tool/dev.sh precommit` passes (format, analyze, test, boundaries)
- [ ] `tool/boundaries_baseline.txt` line count ≤ before
- [ ] New logic has a test in the repo pattern (bloc_test/mocktail)
- [ ] Invariants grep clean: names Detoxo/errorxperts only; `curious`/"CURIOUS"
      intact in wire/code, "Conscious" in UI strings
- [ ] Production readiness: no state (nothing to survive process death); no permission;
      works offline; no new failure path
- [ ] Native untouched — no device sanity list needed
- [ ] `/docs-sync` run; mapped docs updated
