# EVO-069 — Warn when a rule overlaps one that already exists

- Status: approved
- Tier: 2 (enhancement) — requires explicit per-proposal approval
- Feature: `lib/features/limits/rules` (domain + presentation)
- Commit: 68827cf (working tree uncommitted — the 2026-09-08 rules Tier-1 batch is not yet committed)
- Date: 2026-09-08
- Effort: S

## Why
Two rules on the same targets at overlapping hours, or a second daily limit on an app that already
has one, save silently. `RulesCubit.save`
(`lib/features/limits/rules/presentation/rules_cubit.dart`) checks `Rule.validate()` and the
50-rule cap, nothing else. Native takes the **first** blocking entry
(`docs/code_docs/27-rules-engine.md` §3 step 1), so with two overlapping schedules the wall's
reason and "Unlocks at …" name whichever was created first — which is not necessarily the one the
user is thinking of. EVO-061 (approved) covers only the Activity row minting a duplicate limit;
the editor's own Save path has no guard, and presets make duplicates one tap away (`RulePreset.all`
opens the editor pre-filled every time).

## Expected user impact
Before Save, one hint above the button: **Overlaps "Work hours" (Mon–Fri · 09:00–17:00) — the
earlier rule decides what the wall says.** Save stays enabled: overlapping rules are legitimate
(a strict Sleep rule over a wider Evening schedule). The user learns about the overlap at the
moment they can still change it, not from a confusing wall a week later. Peripheral to the
in-the-moment loop; directly improves trust in what the wall reports.

## Technical complexity
Dart only, pure domain logic: one static `RuleOverlap.firstWith(Rule draft, List<Rule> others)`
plus one `InlineHint` in the editor. No channel key, no storage key, no manifest change.

## Performance impact
Runs on the editor's build (≤ 50 rules × a set intersection per dimension × a weekly-window
overlap test). Never on resync, never on the hot path.

## Business value
`docs/info_docs/01-product-overview.md` §"The solution": *a firm, friendly nudge exactly when you
need it* — a wall that names the wrong rule is neither. Fewer "why does it say Sleep at 2 pm"
support questions.

## Rejected alternative
Refusing the save (like the 50-rule cap) — rejected: a stricter rule layered over a looser one is
a real commitment pattern the product wants to allow, and a refusal would make the user delete
the wide rule to keep the narrow one.

## Rollback
Delete `RuleOverlap` and the hint. No persisted state.

## Implementation Plan

### Current state
`lib/features/limits/rules/presentation/rule_editor_screen.dart`, end of `build`:

```dart
          ..._lockSection(context),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: _isEdit ? 'Save changes' : 'Save rule',
            expand: true,
            onPressed: _saving ? null : _save,
          ),
```

`lib/features/limits/rules/domain/usecases/rule_calendar.dart` exposes
`bool inWeeklyWindow(Set<int> days, int startMin, int endMin, DateTime t)` and
`RuleSummary.describe(rule, time:)` renders "Weekdays · 09:00–17:00 · 2 apps".

### Target state
- New `lib/features/limits/rules/domain/usecases/rule_overlap.dart`:
  ```dart
  /// The first ENABLED rule of the same kind that shares a picked target with
  /// [draft] and, for schedules, an hour of the week. Raw picks, not the
  /// flattened set: "Social" and com.instagram.android do overlap in effect,
  /// but the user reads the hint against the chips they can see.
  abstract final class RuleOverlap {
    static Rule? firstWith(Rule draft, List<Rule> others) { … }
    @visibleForTesting
    static bool sharesTarget(RuleSelection a, RuleSelection b) => …; // any of the four sets intersect
    @visibleForTesting
    static bool weeksOverlap(RuleSchedule a, RuleSchedule b) => …;
  }
  ```
  `weeksOverlap`: for each shared day, the two minute ranges overlap, treating an overnight window
  as `[start, 1440) ∪ [0, end)` — reuse the overnight semantics `inWeeklyWindow` documents
  (`rule_calendar.dart`), where the morning slice belongs to the START day, so a `Fri 22:00 → 06:00`
  rule and a `Sat 05:00 → 09:00` rule overlap on Saturday morning.
  Skip `others` entries with `id == draft.id` (editing does not overlap itself) and `!enabled`.
- Editor: above the Save button,
  ```dart
  if (_overlap != null) ...[
    InlineHint(
      icon: Icons.layers_outlined,
      text: 'Overlaps "${_overlap!.name}" (${RuleSummary.describe(_overlap!, time: localTimeFormat(context))}) — the earlier rule decides what the wall says.',
    ),
    const SizedBox(height: AppSpacing.sm),
  ],
  ```
  with `Rule? get _overlap => RuleOverlap.firstWith(_draftRule, context.read<RulesCubit>().state.rules)`,
  where `_draftRule` is the `Rule` `_save` builds (extract its construction into a getter; EVO-068
  extracts `_draftSelection` the same way — coordinate if both land).
- Export `rule_overlap.dart` from `lib/features/limits/limits.dart` beside the other usecases.

### Repo conventions to follow
Pure static class in `domain/usecases/` with `@visibleForTesting` helpers (exemplar: `LockGuard`,
`lib/features/limits/rules/domain/usecases/lock_guard.dart`). Tests in a new
`test/rule_overlap_test.dart` (exemplar shape: `test/rules_calendar_test.dart`).

### Steps
1. Add `rule_overlap.dart` with the three statics.
2. Export it from `limits.dart`.
3. Extract `_draftRule` in the editor from `_save`; add `_overlap` and the hint.
4. `test/rule_overlap_test.dart`: shared app; shared category; disjoint; same kind required
   (a schedule never overlaps a time limit); a disabled rule is ignored; editing itself is
   ignored; overnight Friday vs Saturday morning overlaps; Mon–Fri vs Sat–Sun does not.
5. `/docs-sync`: doc 27 §7 (editor) and `docs/info_docs/02` §14 (one sentence).

### Boundaries
Do NOT refuse the save or touch `RulesCubit`. Do NOT flatten through the catalog here (that is
EVO-068's caption; this hint reads against the chips). If the code at the cited lines has drifted
from the Commit stamp above, STOP and report — do not improvise.

### Validation
- [ ] `bash tool/dev.sh precommit` passes (format, analyze, test, boundaries)
- [ ] `tool/boundaries_baseline.txt` line count ≤ before
- [ ] New logic has a test in the repo pattern (bloc_test/mocktail)
- [ ] Invariants grep clean: names Detoxo/errorxperts only; `curious`/"CURIOUS"
      intact in wire/code, "Conscious" in UI strings
- [ ] Production readiness: no state; no permission; works offline; no new failure path
- [ ] Native untouched — no device sanity list needed
- [ ] `/docs-sync` run; mapped docs updated
