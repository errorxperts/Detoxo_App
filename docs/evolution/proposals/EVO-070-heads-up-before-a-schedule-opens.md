# EVO-070 — A quiet heads-up before a schedule window opens

- Status: approved
- Tier: 2 (enhancement) — requires explicit per-proposal approval
- Feature: `lib/features/limits/rules` (native `receivers/WatchdogJobService.kt` + `engine/RuleEngine.kt` + `engine/ConfigStore.kt`) and `lib/features/blocking` settings (one toggle, one pushed key)
- Commit: 68827cf (working tree uncommitted — the 2026-09-08 rules Tier-1 batch is not yet committed)
- Date: 2026-09-08
- Effort: M
- **Revisits a documented deferral:** `docs/code_docs/27-rules-engine.md` §8 lists "boundary
  notifications" as lean-core deferred. The user approved reopening it on 2026-09-08.

## Why
A schedule closes its targets at the second its window opens. The user finds out mid-message,
mid-video-call setup, mid-purchase — the wall lands with no warning, and the only way out is a
Pause or an override. Native already knows the moment: `ConfigStore.nextBoundaryMs` mirrors the
earliest window edge (`27` §5), every `Entry.windows` carries absolute starts, and
`WatchdogJobService` ticks every 15 minutes with the snapshot in memory (`27` §6). Nothing reads
that knowledge *ahead* of the edge.

## Expected user impact
Opt-in (off by default). When on, a **silent, low-importance notification** posts on the watchdog
tick that precedes a schedule's start — up to 15 minutes ahead, never after — reading
**"Work hours starts at 09:00 — Instagram, YouTube and 3 more will block."** Tap → the Rules
screen. Once per window, never for limits (they have no edge to announce), never for a rule the
user disabled. The user finishes what they are doing and hands over; the intervention loop gets a
consenting user instead of an ambushed one.

## Technical complexity
Native Kotlin: a companion function in `WatchdogJobService` that walks `RuleEngine`'s entries for
the earliest `SCHEDULE` window start in `(now, now + 15 min]`, dedupes on `(id, startMs)` in
`detoxo_engine_prefs` (`rules_heads_up_last` = `"id:startMs"`), and posts through
`NotificationManager`. One new **settings key** on the existing `pushSettings` payload —
`ruleHeadsUp: Boolean` — read by `ConfigStore` (`rule_heads_up`, default false). Dart: one
`AppToggleTile` on the Settings screen's rules/blocking group, persisted in `AppSettings` like its
siblings, pushed by `SettingsCubit`. **No new manifest permission** if the app already declares
`POST_NOTIFICATIONS` for its status notification — Step 0 verifies this; if it does not, STOP: a
permission addition must be declared here first. A new notification channel `detoxo_rules`
(IMPORTANCE_LOW) needs no permission.

## Performance impact
One pass over ≤ 51 entries' `LongArray` windows per 15-minute tick, on the watchdog's thread —
not the accessibility hot path. No new job, no alarm, no wake lock: piggybacks the existing tick.
Latency ceiling of one tick is accepted and stated in the copy ("starts at 09:00", not "in 5 min").

## Business value
`docs/info_docs/01-product-overview.md` §"The solution": *a firm, friendly nudge exactly when you
need it* and §"Runs quietly, always on". Predictable blocking is retained blocking; an ambush is
what gets an app uninstalled after the first "I was in the middle of something".

## Rejected alternative
An exact `AlarmManager` alarm N minutes before each start — rejected: `SCHEDULE_EXACT_ALARM` is a
Play-reviewed permission on Android 12+, adds a manifest change and a prominent-disclosure answer,
and buys precision the copy does not need. Dart-side `flutter_local_notifications` — rejected: it
"stays unwired" by decision (`27` §8) and would not fire with Flutter dead, which is the case the
watchdog exists for.

## Rollback
Delete the companion function, the two prefs keys and the settings toggle; the `pushSettings`
key is ignored by an older native build. One-way doors: none (no schema migration; the channel id
can be left registered).

## Implementation Plan

### Current state
`android/app/src/main/kotlin/com/errorxperts/detoxo/receivers/WatchdogJobService.kt` companion
(working tree): `checkRuleBoundary(context)` (reads the live service's mirror or
`ConfigStore.nextBoundaryMs`), `reconcileLimits(context)` (gated on `hasPendingRuleLimits()`),
and `onStartJob` calling `checkAndNotify` → `checkRuleBoundary` → `reconcileLimits`.
`engine/RuleEngine.kt`: `class Entry(id, reason, …, windows: LongArray [from0, until0, …], …)`,
`fun pendingLimits(): List<Entry>`; no accessor for schedule entries' next start.
`DetoxoAccessibilityService.hasPendingRuleLimits()` is the wrapper pattern to copy.
Settings: `lib/features/blocking/shared/domain/entities/app_settings.dart` (fields pushed by
`SettingsCubit` through `EngineRepository.pushSettings`); native `CommandHandler.kt` `"pushSettings"`
arm writes `ConfigStore` keys.

### Target state
- `RuleEngine.nextScheduleStart(now: Long, within: Long): Entry?` — the entry whose earliest
  window start `s` satisfies `now < s <= now + within`, smallest `s` wins; `SCHEDULE` reason only,
  `always == false`.
- `WatchdogJobService.headsUp(context)`: if `!ConfigStore(context).ruleHeadsUp` return; take the
  live service's `ruleEngine` (there is no heads-up without a service, as with `reconcileLimits`);
  `nextScheduleStart(now, 15 * 60_000L)`; dedupe key `"${entry.id}:$startMs"` against
  `rules_heads_up_last`; post notification: channel `detoxo_rules` (create if absent, IMPORTANCE_LOW,
  name "Rule reminders"), title `"<rule name> starts at HH:MM"`, text
  `"<first two labels> and N more will block"` — **the rule name and app labels are not in the
  snapshot**; add `name: String` to the wire entry (Dart `SnapshotEntry.toJson` adds `"name"`,
  `RuleEngine.parse` reads `optString("name")`, `27` §5 gains the key) and resolve package labels
  through the existing `PackageManager` label helper the block screen uses. Content intent: the
  app's launcher intent with the existing deep-link extra to `Routes.rules` if one exists, else
  the launcher intent.
- Call `headsUp(context)` from `onStartJob` after `reconcileLimits`.
- `ConfigStore`: `var ruleHeadsUp: Boolean` (`rule_heads_up`, default false);
  `CommandHandler` `"pushSettings"` arm reads `call.argument<Boolean>("ruleHeadsUp")`.
- Dart: `AppSettings.ruleHeadsUp` (default false, JSON key `ruleHeadsUp`), pushed in the settings
  map; `SettingsCubit.setRuleHeadsUp(bool)`; one `AppToggleTile` on the Settings screen:
  title "Warn before a schedule starts", subtitle "A quiet notification up to 15 minutes ahead".

### Repo conventions to follow
Companion-function shape and the "needs the live service" guard: `reconcileLimits` in
`WatchdogJobService.kt`. Settings field + setter + push: any existing `AppSettings` boolean and its
`SettingsCubit` setter (the nudge toggles are the newest exemplar, `27`/`M7` docs). Notification
channel creation: the status notification's channel setup (Step 0 finds it). Tests: JVM
`RuleEngineTest` for `nextScheduleStart`; Dart `settings_cubit` test for the new setter; the wire
key change pinned in `test/rules_engine_test.dart`'s "wire keys" test.

### Steps
0. Verify: `grep -n POST_NOTIFICATIONS android/app/src/main/AndroidManifest.xml` (must exist —
   else STOP and amend this proposal's header); `grep -rn "NotificationChannel(" android/app/src/main/kotlin`
   to find the channel-creation exemplar; `grep -rn "fun label\|getApplicationLabel" android/app/src/main/kotlin`
   for the label helper.
1. Wire: add `name` to `SnapshotEntry.toJson`/`fromJson` (Dart) and `RuleEngine.parse` (Kotlin);
   update the wire-keys test and `27` §5.
2. `RuleEngine.nextScheduleStart` + JVM test (a start inside the window wins; a start already
   passed is ignored; limits and `always` entries are ignored; the earliest of two wins).
3. `ConfigStore.ruleHeadsUp` + `CommandHandler` read + `rules_heads_up_last` dedupe key.
4. `WatchdogJobService.headsUp` + call from `onStartJob`.
5. Dart settings field, setter, push key, toggle tile; cubit test.
6. `/docs-sync`: `27` §5, §6, §8 (remove the deferral), `18` (new settings key), `05`/settings doc,
   `docs/info_docs/02` §14 and `04` (one Q&A).

### Boundaries
Do NOT add an alarm, a job, a wake lock or a manifest permission. Do NOT post for limits or for a
window that already opened. Do NOT change timing budgets. If the code at the cited sites has
drifted from the Commit stamp above, STOP and report — do not improvise.

### Validation
- [ ] `bash tool/dev.sh precommit` passes (format, analyze, test, boundaries)
- [ ] `tool/boundaries_baseline.txt` line count ≤ before
- [ ] New logic has a test in the repo pattern (bloc_test/mocktail + JVM)
- [ ] Invariants grep clean: names Detoxo/errorxperts only; `curious`/"CURIOUS"
      intact in wire/code, "Conscious" in UI strings
- [ ] Production readiness: the toggle and dedupe key survive process death and reboot
      (`ConfigStore` prefs); notifications denied → silent no-op; works offline;
      no new manifest permission (Step 0); the notification path is try/caught and logged
- [ ] Native touched → manual device sanity list: service reconnects after toggling
      accessibility; a 2-minute-ahead schedule posts exactly one heads-up on the next tick
      and none after the window opens; bubble drag/snap/tap; home-widget refresh
- [ ] `/docs-sync` run; mapped docs updated
