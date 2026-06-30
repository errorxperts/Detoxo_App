# Module: Core Data & Storage

## 1. Purpose & scope
Local persistence for the whole app: two Room databases plus the on‑device blocking state. **Owns:** the SQLite schema (entities, PKs, DAOs, migrations), the typed key‑value preference store, and the **blocking‑config enforcement state machine** (the algorithm that decides "allowed / cooldown / hard‑block / paused"). **Does NOT own:** network sync (see [module-10-networking-sync.md](module-10-networking-sync.md)), the accessibility detection that produces scroll events (see [module-01-reels-detection-core.md](module-01-reels-detection-core.md)), or background scheduling (see [module-11-workers-background.md](module-11-workers-background.md)).

## 2. Migration verdict
**PURE‑DART.** This is conventional local persistence + business rules; no OS integration. Replace Room with **`drift`** (type‑safe DAOs, composite PKs, migrations). The enforcement state machine becomes pure Dart use‑cases — fully unit‑testable and shared by Android and iOS. Identical on both platforms.

## 3. Business logic & algorithms (load‑bearing)

### 3.1 Two databases
| DB | Version | Schema identity hash | Tables |
|---|---|---|---|
| `BrainRotRoomDatabase` | 1 | `5155f408ed131dc24809c68983195e33` | `user_blocking_config`, `daily_reels_app_split`, `reels_events` |
| `UserPrefDatabase` | 1 | `907e7765e4bd8c9b7f05925ea0bfc038` | `user_pref_boolean`, `user_pref_long`, `user_pref_string`, `migration_status`, `app_installation_history`, `permission_logs` |

No v2 schemas exist in the decompile → freeze v1 exactly; any change starts at drift schemaVersion 2 with an upgrade path.

### 3.2 Blocking enforcement state machine (the key algorithm)
Driven by `user_blocking_config` (one row, PK `br_user_id`). Evaluate on every detected reel:

```
allowReel(now, cfg, reelsThisWindow):
  1. if !cfg.isBlockEnabled            -> ALLOW            // blocking off
  2. if cfg.blockPauseExpiryTime != null && now < blockPauseExpiryTime
                                       -> ALLOW (PAUSED)   // user snoozed
  3. if cfg.hardBlockValidTill != null && now < hardBlockValidTill
                                       -> BLOCK (HARD)     // unbypassable window
  4. if reelsThisWindow < cfg.reelsAllowedCount
                                       -> ALLOW            // within allowance
  5. else  // allowance exhausted -> cooldown
       blockEnds = cfg.blockStartTimestamp + cfg.cooldownTimeInMillis
       if now < blockEnds             -> BLOCK (COOLDOWN)
       else  reset: blockStartTimestamp=now, blockStartReelCount=currentCount
                                       -> ALLOW (new window)
```
- `reelsAllowedValidForMillis` is a **secondary rolling‑window throttle** (e.g. N reels per 24h) evaluated independently of the cooldown cycle.
- Remote‑config bounds (Firebase RC, `res/xml/rc_defaults.xml`): allowed **1–50** (default 20); cooldown **30–300 min** (default 120); window **5–240 min** (default 30).

> **OPEN QUESTION (must validate):** the exact **precedence** of `blockPauseExpiryTime` vs `hardBlockValidTill` vs allowance/cooldown. The order above is inferred (pause → hard → allowance → cooldown); confirm against instrumented APK behavior before shipping — wrong order blocks/unblocks users incorrectly.

### 3.3 Scroll event → daily split rollup
1. Each detected reel writes one `reels_events` row (raw log).
2. Periodically (`ReelsSyncWorker` / migration), `GROUP BY stats_date, app_id` and write/replace into `daily_reels_app_split`.
3. Raw events pruned after **10 days** (`ReelsEventsPruneWorker`, see [module-11](module-11-workers-background.md)).
4. Delta sync sends only rows where `updated_at > lastSynced*` (`lastSyncedReelCount` / `lastSyncedUpdatedAt`).

### 3.4 One‑time migrations (`migration_status`)
- `reels_events_to_app_split_v1` (`REELS_EVENTS_TO_APP_SPLIT`): on first launch of the split‑capable version, aggregate legacy `reels_events` into `daily_reels_app_split`.
- `re_register_for_app_split_v1` (`RE_REGISTER_FOR_APP_SPLIT`): re‑sync/repair split data (orphans, display names).
- Pattern: check `is_done`; if false, run; set `is_done=1`. **Do not hardcode true.**

## 4. Data models

### 4.1 Room tables (columns · type · PK)
```
user_blocking_config        PK = br_user_id
  br_user_id TEXT PK · pinnedFriendBrUserId TEXT? · isBlockEnabled INT(bool)
  cooldownTimeInMillis INT(long) · hardBlockValidTill INT(long)?
  reelsAllowedCount INT · reelsAllowedValidForMillis INT(long)
  blockPauseExpiryTime INT(long)? · blockStartTimestamp INT(long)?
  blockStartReelCount INT? · updatedAt INT(long) · lastSyncedUpdatedAt INT(long)

daily_reels_app_split       PK = (androidDeviceId, statsDate, appId)   // composite
  androidDeviceId TEXT · statsDate TEXT · appId TEXT · displayName TEXT
  reelCount INT · viewDurationMs INT(long) · updatedAt INT(long) · lastSyncedReelCount INT

reels_events                PK = id AUTOINCREMENT
  id INT PK · androidDeviceId TEXT · brUserId TEXT? · eventTimestamp INT(long)
  appId TEXT · viewDurationMillis INT(long)

user_pref_boolean   user_pref_key TEXT PK · value INT(0/1)
user_pref_long      user_pref_key TEXT PK · value INT(long)?    // nullable
user_pref_string    user_pref_key TEXT PK · value TEXT?
migration_status    migration_key TEXT PK · is_done INT(bool)
app_installation_history  install_time INT(long) PK · created_at INT(long) · modified_at INT(long)
permission_logs     id INT PK AUTOINCREMENT · permission_type TEXT · asked_at INT(long)
```
No foreign keys; no indexes on core tables. Known typed‑pref keys seen elsewhere: `COUNTER_SIZE` (string), `CREATOR_LARGE_BUBBLE_ENABLED` (bool), `fresh_start_last_shown_day` (long), `last_celebrated_milestone` / `last_celebrated_milestone_day` (long).

### 4.2 Dart (drift) target shape
```dart
class UserBlockingConfigs extends Table {
  TextColumn get brUserId => text()();
  TextColumn get pinnedFriendBrUserId => text().nullable()();
  BoolColumn get isBlockEnabled => boolean()();
  IntColumn  get cooldownTimeInMillis => integer()();           // ms
  IntColumn  get hardBlockValidTill => integer().nullable()();  // epoch ms
  IntColumn  get reelsAllowedCount => integer()();
  IntColumn  get reelsAllowedValidForMillis => integer()();
  IntColumn  get blockPauseExpiryTime => integer().nullable()();
  IntColumn  get blockStartTimestamp => integer().nullable()();
  IntColumn  get blockStartReelCount => integer().nullable()();
  IntColumn  get updatedAt => integer()();
  IntColumn  get lastSyncedUpdatedAt => integer()();
  @override Set<Column> get primaryKey => {brUserId};
}

class DailyReelsAppSplits extends Table {
  TextColumn get androidDeviceId => text()();
  TextColumn get statsDate => text()();          // yyyy-MM-dd
  TextColumn get appId => text()();
  TextColumn get displayName => text()();
  IntColumn  get reelCount => integer()();
  IntColumn  get viewDurationMs => integer()();
  IntColumn  get updatedAt => integer()();
  IntColumn  get lastSyncedReelCount => integer()();
  @override Set<Column> get primaryKey => {androidDeviceId, statsDate, appId};
}
// reels_events, user_pref_*, migration_status, app_installation_history, permission_logs analogous.
```
Typed prefs: keep three drift tables (matches Java type‑safety) **or** collapse into one table with a `type` discriminator. Recommendation: keep three for 1:1 parity, expose a `UserPrefRepository` facade with typed getters/setters (upsert = `insertOnConflictUpdate`).

## 5. Android deps → Flutter map
| Android API | Verdict | Flutter | Notes |
|---|---|---|---|
| Room (runtime/ktx) | PKG | `drift` | composite PKs, migrations, DAOs |
| SQLite | PKG | `drift` (sqlite3 native) / `sqflite` | |
| Suspend DAOs (Flow/LiveData) | PKG | drift `Stream`/`Future` | reactive queries → Riverpod `StreamProvider` |
| SharedPreferences (`language_code`) | PKG | `shared_preferences` | simple scalar prefs only |
| Sync creds (username/password/sync_url) | PKG | `flutter_secure_storage` | **never log** |

## 6. iOS strategy
Identical. `drift` is cross‑platform (uses `sqlite3_flutter_libs` on iOS); `shared_preferences` and `flutter_secure_storage` (Keychain) both support iOS. The enforcement state machine is pure Dart and shared. The only platform difference is *where the reel events originate* (Android accessibility vs iOS DeviceActivity) — the storage layer is agnostic.

## 7. Platform‑channel surface
**None.** This module is pure Dart. It is *fed* by `brainpal/detection` events (persisted by the detection repository) but does not own a channel. See [01-platform-channel-contracts.md](01-platform-channel-contracts.md).

## 8. State management & DI
- `get_it` singletons: `AppDatabase` (drift), `UserPrefRepository`, `BlockingConfigRepository`, `StatsRepository`.
- Riverpod: `blockingConfigProvider` (`StreamProvider<UserBlockingConfig>` over a drift watch query), `todayStatsProvider` (`StreamProvider<List<DailyReelsAppSplit>>`), `allowReelUseCaseProvider`.
- Each Kotlin DAO `Flow` maps to a drift `.watch()` stream.

## 9. User flows
1. **App first launch** `[dart]`: if `app_installation_history` empty, insert `install_time = now`. Register sync user → store `br_user_id` in `user_blocking_config`.
2. **Reel detected** `[channel→dart]`: detection event arrives → insert `reels_events` row → run `allowReel()` → emit allow/block decision back to native overlay.
3. **Config pulled from server** `[dart]`: `GET /user/config` → upsert `user_blocking_config` (server `updated_at` wins).
4. **Daily rollup** `[dart]`: aggregate events → `daily_reels_app_split`; advance `lastSyncedReelCount` after push.
5. **Migration check** `[dart]`: on launch, for each `migration_status` key not done → run → mark done.

## 10. Parity risks & validation
- **Enforcement precedence (existential):** enumerate all flag combinations (pause/hard/allowance/cooldown × null/non‑null timestamps) as Dart unit tests and diff against instrumented APK behavior.
- **Composite‑PK upsert semantics:** `daily_reels_app_split` uses `INSERT OR REPLACE` → **overwrites** `reelCount`. Confirm overwrite (not SUM) is intended (OPEN QUESTION). Mirror with drift `insertOnConflictUpdate`.
- **Nullable longs:** `hardBlockValidTill`, `blockPauseExpiryTime`, `user_pref_long.value` are nullable — guard every comparison.
- **Migration idempotency:** run the migration twice in tests; assert no double‑aggregation.
- **Schema fidelity:** golden test comparing generated drift schema column names/types to the Room table list above.

## 11. Open questions
- `statsDate` exact format (`yyyy-MM-dd` assumed; sent as‑is to backend).
- `reels_events` prune trigger detail (timestamp‑based, cutoff 10d — confirm query).
- Why `reels_events.brUserId` is nullable (set only after register?).
- `INSERT OR REPLACE` overwrite vs SUM for `daily_reels_app_split`.
- How `app_installation_history.install_time` is consumed (trial/tenure logic in subscription/duel).

## 12. Migration checklist (Phase 2)
- [ ] Define drift tables for all 9 entities with exact names/types/PKs.
- [ ] Implement `UserPrefRepository` (3 typed tables) with upsert.
- [ ] Implement `BlockingConfigRepository` + `AllowReelUseCase` (state machine) with full unit tests.
- [ ] Implement `StatsRepository` (event insert, daily rollup, prune query, lastSynced bookkeeping).
- [ ] Implement migration runner over `migration_status` (both keys).
- [ ] Store sync creds in `flutter_secure_storage`; `br_user_id` in config table.
- [ ] Parity harness: enforcement truth‑table vs APK; schema golden test.
