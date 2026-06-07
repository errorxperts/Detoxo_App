# 09 · Persistence & Data Model

This document specifies the complete persistence layer for the Flutter re-build of the short-form content blocker. The original native app uses **three** storage mechanisms: (1) a **Jetpack DataStore (preferences)** holding ~40 settings/config/session keys, encrypted on disk; (2) a **Room SQLite database** with four analytics entities; and (3) a **ContentProvider** (`com.newswarajya.noswipe.provider`) that lets the isolated accessibility service process (`:as_process`) read/write the same DataStore as the UI process. We map each store to clean Flutter equivalents (`flutter_secure_storage` for secrets, `hive` for structured JSON config, `drift` for the analytics DB, `shared_preferences` for trivial flags) and address the cross-process problem head-on, because in Flutter the accessibility service typically runs as a separate native process and **cannot** see Dart-side in-memory state.

---

## 1. Storage taxonomy at a glance

| # | Original store | Holds | Cross-process? | Flutter target | Legend |
|---|----------------|-------|----------------|----------------|--------|
| 1 | Jetpack DataStore (encrypted Preferences) | All settings, configs, sessions, plan, PIN, email, GDPR, flags | Yes (via ContentProvider) | `flutter_secure_storage` (secrets) + `hive` (JSON objects) + `shared_preferences` (flags) + native bridge for shared state | ✅ / ⚠️ |
| 2 | Room SQLite DB | Analytics events (blocks, device unlocks, focus unlocks, app access) | No (UI-process only) | `drift` | ✅ |
| 3 | ContentProvider `…provider` | Bridges DataStore between UI process and `:as_process` | Yes (the whole point) | Native `SharedPreferences`/`DataStore` read from Kotlin + `MethodChannel`/`EventChannel` | ⚠️ |

> **iOS:** There is no `:as_process` accessibility service and no ContentProvider. Persistence collapses to a single process. Use the **App Group shared container** (`UserDefaults(suiteName:)` / a shared SQLite file) to share config between the main app and any `DeviceActivityMonitor` extension — that is the closest analogue to the cross-process problem on Apple. The blocking itself is `FamilyControls`/`ManagedSettings`, not data we own.

**Source evidence (this section):** `data/database/datasource/DataStoreBase.java`, `data/database/datasource/DataStoreProvider.java`, `data/database/contentprovider/NoScrollContentProvider.java`, `analytics/db/AnalyticsDatabase.java`.

---

## 2. Store 1 — Settings & config (DataStore → secure storage + Hive)

### 2.1 What the original does

`DataStoreProvider` manages **two** DataStore instances (verified in `DataStoreProvider.java`):

- `commonInstance` — encrypted user prefs, with a one-time migration from legacy `EncryptedSharedPreferences` (AES-256-GCM via `MasterKeys`).
- `appInstance` — app-level config (initial config, fetched server responses, OTP, email cooldowns, GDPR), managed by `DataStoreUtils` which extends `DataStoreBase`.

Complex objects (`PinConfig`, `DailyAppBlocker`, `BlockedSite`, `ActivePlanDetails`, platform configs) are **Gson-serialized to a JSON string** and stored under a single preference key. Reads are exposed as Kotlin `Flow<T>` wrapped in `distinctUntilChanged()`. (Verified: serialization path `writeObject$app` → `Gson.toJson()` → `DataStore.updateData()` in `DataStoreBase.java`.)

### 2.2 Key registry (full inventory)

All keys below are defined in `DataStoreBase.PrefKeys` / `DataStoreUtils` (verified — the enumerated key set is listed in `persistence.json` and confirmed against `DataStoreBase.java`). **Owner** = which process writes it primarily: `UI` (Flutter app process), `SVC` (accessibility/monitor process), `BOTH`.

| Key (clean name) | Original key | Dart type | Owner | Flutter store | Purpose |
|---|---|---|---|---|---|
| `appTheme` | `APP_THEME` | `enum AppTheme` | UI | shared_preferences | Light/dark/system theme. |
| `defaultBlockingMode` | `DEFAULT_BLOCKING_MODE` | `enum BlockingMode` | UI | shared_preferences ⚠️ also native | Default block action (PRESS_BACK/KILL_APP/LOCK_SCREEN/NONE). Read by service. |
| `maxPauseDuration` | `MAX_PAUSE_DURATION` | `int` (ms) | UI | shared_preferences | UI cap on pause length (15 min default). |
| `isUserOnboarded` | `IS_USER_ONBOARDED` | `bool` (default `false`) | UI | shared_preferences | Onboarding completed flag. |
| `isPremiumWelcomeShown` | `IS_PREMIUM_WELCOME_SHOWN` | `bool` | UI | shared_preferences | Premium welcome dialog seen. |
| `pauseSession` | `PAUSE_SESSION` | `PauseSession` (JSON) | BOTH ⚠️ | hive + native | Global pause state machine (see §4). Service reads it every event. |
| `currentPlan` | `CURRENT_PLAN` | `enum BlockerPlan` | BOTH ⚠️ | shared_preferences + native | Active plan: BLOCK_ALL / CURIOUS / ONE_REEL / PAUSED. |
| `serviceFlowRequest` | `SERVICE_FLOW_REQUEST` | `bool` | BOTH ⚠️ | native | Command/handshake flag toward the service. |
| `webBlockList` | `WEB_BLOCK_LIST` | `Map<String, BlockedSite>` (JSON) | BOTH ⚠️ | hive + native | Blocked websites map keyed by URL. |
| `planConfig` | `PLAN_CONFIG` | `PlanConfig` (JSON) | UI | hive | Per-plan settings (curious/one-reel params). |
| `platformsConfig` | `PLATFORMS_CONFIG` | `PlatformsConfig` (JSON) | BOTH ⚠️ | hive + native | Server-fetched detector config; fallback = bundled `res/raw/platforms_config.json`. |
| `calibrationConfig` | `CALIBRATION_CONFIG` | `CalibrationConfig` (JSON) | BOTH ⚠️ | hive + native | Per-platform overlay positions/calibration. |
| `consumedNotifications` | `CONSUMED_NOTIFICATIONS` | `Set<String>` | UI | shared_preferences | IDs of already-shown server notifications. |
| `verifiedEmail` | `VERIFIED_EMAIL` | `String` (secret) | UI | **flutter_secure_storage** | Recovery/verified email. |
| `pinConfig` | `PIN_CONFIG` | `PinConfig` (JSON, secret) | BOTH ⚠️ | **flutter_secure_storage** + native | PIN/password config (see §3). |
| `localOtp` | `LOCAL_OTP` | `String` (secret) | UI | **flutter_secure_storage** | Locally generated OTP for email verification. |
| `dailyAppBlockerSession` | `DAILY_APP_BLOCKER_SESSION` | `DailyAppBlocker` (JSON) | BOTH ⚠️ | hive + native | Daily focus/limit session (see §5). |
| `platformRestrictions` | `PLATFORM_RESTRICTIONS` | `Map<String, bool>` (JSON) | BOTH ⚠️ | hive + native | Per-platform override of global blocking. |
| `appSessions` | `APP_SESSIONS` | `Map<String, AppSession>` (JSON) | BOTH ⚠️ | hive + native | Per-app PIN-unlock sessions (see §6). |
| `curiousData` | `CURIOUS_DATA` | `CuriousSession` (JSON) | BOTH ⚠️ | hive + native | Curious (Pomodoro) timer state (see §4). |
| `initialConfig` | `INITIAL_CONFIG` | `InitialConfig` (JSON) | UI | hive | First-fetch bootstrap config. |
| `fetchContentResponse` | `FETCH_CONTENT_RESPONSE` | `FetchContentResponse` (JSON) | UI | hive | Cached server content payload. |
| `emailCooldownExpiries` | `EMAIL_COOLDOWN_EXPIRIES` | `Map<String, int>` (JSON, ms) | UI | shared_preferences | Per-email-type cooldown expiry, keyed by `EmailType.name`. |
| `hapticFeedback` | `HAPTIC_FEEDBACK` | `bool` | BOTH ⚠️ | shared_preferences + native | Vibration-on-block toggle. Read by service. |
| `askedForReview` | `ASKED_FOR_REVIEW` | `bool` | UI | shared_preferences | In-app review prompt shown. |
| `lastReviewRequestTimestamp` | `LAST_REVIEW_REQUEST_TIMESTAMP` | `int` (ms) | UI | shared_preferences | Throttle for review prompts. |
| `sessionId` | `SESSION_ID` | `String` (UUID, default random) | BOTH ⚠️ | shared_preferences + native | Correlation ID for analytics; regenerated per service session. |
| `gdprConsent` | `GDPR_CONSENT` | `bool` | UI | shared_preferences | GDPR data-collection consent. |
| `gdprCountry` | `GDPR_COUNTRY` | `String` | UI | shared_preferences | Detected/declared country for GDPR. |
| `notifDeclined` | `NOTIF_DECLINED` | `bool` | UI | shared_preferences | User declined notification permission. |
| `notifPermissionPrompted` | `NOTIF_PERMISSION_PROMPTED` | `bool` | UI | shared_preferences | Notification permission already requested. |
| `blocklistMigrationBannerAcknowledged` | `BLOCKLIST_MIGRATION_BANNER_ACKNOWLEDGED` | `bool` | UI | shared_preferences | Dismissed blocklist-migration banner. |
| `autoShowAdIntroSeen` | `AUTO_SHOW_AD_INTRO_SEEN` | `bool` | UI | shared_preferences | Ad intro shown flag. |
| *(deeplink)* | *deeplink payload* | `String`/JSON | UI | shared_preferences | Pending deeplink to consume after launch. *(inferred — referenced in flows; exact key not enumerated in `DataStoreBase.PrefKeys` dump.)* |

> **Routing rule used above:** secrets (PIN, email, OTP, tokens) → `flutter_secure_storage`; structured JSON objects/maps → `hive`; scalar flags/enums/timestamps → `shared_preferences`. Any key marked **⚠️ + native** is also read by the accessibility service process — see §7.

### 2.3 Dart sketch — config models (Hive + freezed)

```dart
// domain/entities/pin_config.dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'pin_config.freezed.dart';
part 'pin_config.g.dart';

enum PinOption { none, pinCode, pattern, password }      // PinOptionsEnum
enum PinTimeFormat { hhmm12, hhmm24 }                     // PINTimeFormatEnum
enum PinDateFormat { ddmm, mmdd }                         // PINDateFormatEnum
enum PinRestrictedSection { noscrollApp }                // PINRestrictedSectionsEnum

@freezed
class PinConfig with _$PinConfig {
  const factory PinConfig({
    @Default(PinOption.none) PinOption activePinOption,
    @Default(PinTimeFormat.hhmm12) PinTimeFormat timeFormat,
    @Default(PinDateFormat.ddmm) PinDateFormat dateFormat,
    @Default('') String customPin,                       // secret → secure storage
    @Default({PinRestrictedSection.noscrollApp}) Set<PinRestrictedSection> restrictions,
    @Default(0) int pinRetryCount,
    @Default(0) int lastPinAttempted,                    // epoch ms
    @Default(0) int lastSuccessfulLogin,                 // epoch ms
    @Default(0) int restrictionDuration,                 // ms
  }) = _PinConfig;

  factory PinConfig.fromJson(Map<String, dynamic> j) => _$PinConfigFromJson(j);
}
```

```dart
// domain/entities/blocked_site.dart
@freezed
class BlockedSite with _$BlockedSite {
  const factory BlockedSite({
    required String site,
    @Default(true) bool isBlocked,
    @Default(false) bool exactMatch,
    @Default(0) int blockedTimestamp,   // epoch ms
  }) = _BlockedSite;
  factory BlockedSite.fromJson(Map<String, dynamic> j) => _$BlockedSiteFromJson(j);
}
// webBlockList persisted as Map<String /*url*/, BlockedSite> JSON, mirroring WEB_BLOCK_LIST.
```

### 2.4 Dart sketch — a clean settings data source

```dart
// data/datasources/settings_local_data_source.dart
abstract class SettingsLocalDataSource {
  Future<T?> readObject<T>(String key, T Function(Map<String, dynamic>) fromJson);
  Future<void> writeObject(String key, Map<String, dynamic> json);
  Stream<T?> watchObject<T>(String key, T Function(Map<String, dynamic>) fromJson);
}

class HiveSettingsDataSource implements SettingsLocalDataSource {
  HiveSettingsDataSource(this._box);
  final Box _box; // Hive box, opened with AES encryption key from flutter_secure_storage

  @override
  Future<T?> readObject<T>(String key, T Function(Map<String, dynamic>) fromJson) async {
    final raw = _box.get(key) as String?;
    if (raw == null) return null;
    return fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> writeObject(String key, Map<String, dynamic> json) =>
      _box.put(key, jsonEncode(json));

  @override
  Stream<T?> watchObject<T>(String key, T Function(Map<String, dynamic>) fromJson) =>
      _box.watch(key: key).map((_) => /* re-read */ null).asyncMap(
            (_) => readObject<T>(key, fromJson),
          ); // BLoC subscribes; mirrors Flow + distinctUntilChanged().
}
```

**Hive encryption:** open the box with `HiveAesCipher`, storing the 256-bit key itself in `flutter_secure_storage`. This reproduces the AES-256-GCM-at-rest property of the original encrypted DataStore. ✅

### 2.5 Migration (parity note)

The original runs a **one-time `DataMigration`** from legacy `EncryptedSharedPreferences` keys (`ONBOARDED`, `CUSTOM_PIN`, `RECOVERY_EMAIL`, `BLOCKED_SITES`, `PIN_RESTRICTIONS`, `blocked_apps`, `PLAN_CONFIG`, `CURRENT_PLAN`, `FRIENDS_REELS_STATUS`) into the new DataStore, then `cleanUp()` deletes the old keys (verified in `persistence.json` algorithm "DataStore Encrypted SharedPreferences Migration"). A green-field Flutter app has **no legacy store** and can skip this. Keep a one-shot guarded `migrate()` hook anyway for future schema bumps; Hive box version + `shared_preferences` `_schemaVersion` flag is sufficient. ✅

---

## 3. PIN store (secrets → flutter_secure_storage)

`PinConfig.customPin`, `verifiedEmail`, and `localOtp` are sensitive. In the original they live inside the **encrypted** DataStore; in Flutter they must go to `flutter_secure_storage` (Keychain on iOS, EncryptedSharedPreferences/Keystore on Android). Store the **non-secret** parts of `PinConfig` (format enums, retry count, timestamps) in Hive and only the `customPin` string in secure storage, or serialize the whole `PinConfig` JSON into secure storage if you prefer one object.

Default values (verified, `persistence.json` notes): `activePinOption = none`, `timeFormat = hhmm12`, `dateFormat = ddmm`, `customPin = ''`, `restrictions = {noscrollApp}`, `pinRetryCount = 0`, all expiry timestamps `0`.

```dart
// data/datasources/secure_local_data_source.dart
class SecureLocalDataSource {
  static const _pin = 'pin_config.custom_pin';
  static const _email = 'verified_email';
  final _storage = const FlutterSecureStorage();

  Future<void> writePin(String pin) => _storage.write(key: _pin, value: pin);
  Future<String?> readPin() => _storage.read(key: _pin);
  Future<void> writeVerifiedEmail(String e) => _storage.write(key: _email, value: e);
}
```

> **iOS:** secure values map cleanly to Keychain via the same `flutter_secure_storage` package. ✅

---

## 4. Pause & Curious session models (JSON config with derived phases)

These two objects encode the runtime state machines the service reads on every event (verified in `service/accessibility/data/PauseSessionData.java` and `CuriousSessionData.java`). They are pure data + computed phase, so they are **pure Dart** ✅ — only the *reading-from-the-service-process* part is ⚠️.

### 4.1 PauseSession

Fields (verified): `pausedOn` (epoch ms), `pauseDuration` (default 60000 ms), `lockDownDuration` (default ∞), `planToResume` (BLOCK_ALL/CURIOUS/ONE_REEL), `allowInLockDown` (bool), `maxPauseDuration` (15 min UI cap). Phase algorithm (verified `getCurrentPhase()`):

```dart
enum PausePhase { paused, pausedCooldown, idle }

class PauseSession {
  final int pausedOn, pauseDuration, lockDownDuration;
  final BlockerPlan planToResume;
  final bool allowInLockDown;
  const PauseSession({/* ... */});

  PausePhase phaseAt(int now) {
    if (now < pausedOn + pauseDuration) return PausePhase.paused;
    if (now < pausedOn + pauseDuration + lockDownDuration) return PausePhase.pausedCooldown;
    return PausePhase.idle; // resume planToResume
  }
}
```

### 4.2 CuriousSession (Pomodoro)

Fields (verified): `sessionDuration` (minutes), `cooldownDuration` (minutes), `lastWatchedInCurious`, `shortVideoSessionStartTime`, `isVideoAllowedInCooldown`, `disablePlanSwitchInCooldown`. Phase algorithm (verified `getCurrentPhase()`):

```dart
enum CuriousPhase { session, cooldown, idle }

class CuriousSession {
  final int sessionDuration, cooldownDuration;     // minutes
  final int shortVideoSessionStartTime;            // epoch ms
  final bool isVideoAllowedInCooldown, disablePlanSwitchInCooldown;
  const CuriousSession({/* ... */});

  CuriousPhase phaseAt(int now) {
    final start = shortVideoSessionStartTime;
    final sessionEnd  = start + sessionDuration * 60000;
    final cooldownEnd = start + (sessionDuration + cooldownDuration) * 60000;
    if (now >= start && now <= sessionEnd) return CuriousPhase.session;   // videos allowed
    if (now > sessionEnd && now <= cooldownEnd) return CuriousPhase.cooldown; // blocked unless isVideoAllowedInCooldown
    return CuriousPhase.idle;
  }
}
```

These are persisted as JSON under `pauseSession` / `curiousData` (Hive) and **mirrored to native** so the service can call `phaseAt(now)` (see §7).

---

## 5. DailyAppBlocker (daily focus/limit session)

Fields (verified, `persistence.json`): `dateSignature` (`dd-MM-yyyy`), `lastUpdate`, `dailyLimitDuration` (default `9000000` ms ≈ 2.5 h), `consumedDuration`, `sessionExpiry`, `currentFocusUnlockId`, `lastBlockSessionId`, `isActive` (default true), `isPaused`, `pauseExpiry`, `cooldownExpiry`, `pauseDurationMillis`, `cooldownDurationMillis`.

Two verified algorithms — port them verbatim to Dart instance methods:

```dart
enum FocusState { active, paused, cooldown }

class DailyAppBlocker {
  final String dateSignature;      // 'dd-MM-yyyy'
  final int dailyLimitDuration, consumedDuration;
  final bool isActive, isPaused;
  final int pauseExpiry, cooldownExpiry;
  const DailyAppBlocker({/* ... */});

  // isInCooldownWindow(currentTime) — verified
  bool isInCooldownWindow(int now) {
    if (isPaused && pauseExpiry > 0 && now <= pauseExpiry) return false; // pause active
    if (cooldownExpiry > 0 && cooldownExpiry > now) return true;          // cooldown active
    return false;
  }

  // refreshSignature(currentTime) — verified: reset on date rollover
  DailyAppBlocker refreshSignature(int now, String todaySig) {
    if (todaySig == dateSignature) return this;
    return copyWith(
      dateSignature: todaySig,
      consumedDuration: 0,
      cooldownExpiry: 0,
      lastUpdate: now,
    );
  }
}
```

> Use the `intl` package's `DateFormat('dd-MM-yyyy')` to compute `todaySig`. Daily rollover ("reset at midnight") is purely date-string comparison — no scheduled job required, though a `workmanager` midnight tick can pre-warm the reset. ✅

---

## 6. AppSession (per-app PIN unlock)

Verified `service/accessibility/data/AppSessionDetails.java`: `packageName`, `pinUnlockedOn` (ms), `pinExpiry` (ms deadline), `unlockedBlockActionMode` (`AppLockAction.closeApp | lockScreen`). Persisted as `Map<String /*pkg*/, AppSession>` under `appSessions`. The monitor process reads it to decide if a foreground app is currently unlocked.

```dart
enum AppLockAction { closeApp, lockScreen }

@freezed
class AppSession with _$AppSession {
  const factory AppSession({
    required String packageName,
    @Default(0) int pinUnlockedOn,
    @Default(0) int pinExpiry,
    @Default(AppLockAction.closeApp) AppLockAction unlockedBlockActionMode,
  }) = _AppSession;
  factory AppSession.fromJson(Map<String, dynamic> j) => _$AppSessionFromJson(j);

  bool isUnlockedAt(int now) => pinExpiry > now;
}
```

---

## 7. Store 3 — Cross-process sharing (the hard part) ⚠️

### 7.1 The problem

In the original, the UI process and the accessibility service in `:as_process` both read/write the **same** DataStore. They do not call each other; they coordinate purely through shared persistence plus the `NoScrollContentProvider` (authority `com.newswarajya.noswipe.provider`). Verified URI shape (`NoScrollContentProvider.java`): `content://com.newswarajya.noswipe.provider/{type}/{key}` where `type ∈ {string, int, long, boolean}`. `query()` does `runBlocking` on IO to read a `Preferences.Key(key)` and returns a one-column `MatrixCursor` (`VALUE`); `update()` writes on an IO coroutine then calls `contentResolver.notifyChange(uri)`.

**In Flutter this is the central architectural risk.** Hive and `flutter_secure_storage` boxes opened in the Dart UI isolate are **invisible** to a native accessibility service running in another process. Any state the service needs to make a block decision (`pinConfig`, `pauseSession`, `currentPlan`, `platformsConfig`, `platformRestrictions`, `appSessions`, `curiousData`, `dailyAppBlockerSession`, `hapticFeedback`, `defaultBlockingMode`, `sessionId`, `webBlockList` — all rows marked **⚠️ + native** in §2.2) must live somewhere **both processes can read natively**.

### 7.2 Recommended design

Use a **native-readable shared store as the source of truth for service-needed state**, and treat Dart Hive/secure-storage as a UI-side cache that writes through to it.

| Concern | Mechanism | Legend |
|---|---|---|
| Service-needed config (the ⚠️ rows) | Native Android `SharedPreferences` (or DataStore) written from Kotlin; UI pushes updates via `MethodChannel` → Kotlin → SharedPreferences | ⚠️ MethodChannel |
| Notify the service of a config change | `EventChannel` (service → Dart) and a Kotlin-side `SharedPreferences.OnSharedPreferenceChangeListener` (Dart → service) | ⚠️ EventChannel |
| Multi-process safety | Open native `SharedPreferences` with `MODE_MULTI_PROCESS` *(legacy, fragile)* **or** keep config in a single ContentProvider-backed store and read with `runBlocking`, exactly as the original; `flutter_overlay_window` already proves a second engine can be driven from native | ⚠️ |
| UI-only data (themes, flags, onboarding) | Pure Dart `shared_preferences`/Hive — never read by service | ✅ |
| Analytics DB | Pure Dart `drift` in UI process; service emits block events to Dart via `EventChannel`, Dart writes the row | ✅ + ⚠️ for the bridge |

**Concrete recommendation:** define a thin Kotlin `SharedConfigStore` wrapping `SharedPreferences` (same key names as §2.2 "original key" column for clarity). Expose it over:

```dart
// data/datasources/shared_config_channel.dart  (UI side)
class SharedConfigChannel {
  static const _m = MethodChannel('noscroll/shared_config');
  static const _e = EventChannel('noscroll/shared_config/events');

  Future<void> putString(String key, String value) =>
      _m.invokeMethod('put', {'key': key, 'type': 'string', 'value': value});

  Future<String?> getString(String key) =>
      _m.invokeMethod<String>('get', {'key': key, 'type': 'string'});

  // Service-process writes (e.g. new SESSION_ID, lastBlock) surface here.
  Stream<ConfigChange> changes() =>
      _e.receiveBroadcastStream().map((e) => ConfigChange.fromMap(e));
}
```

The Kotlin side mirrors the original `getKeyFromUri()` type switch and (optionally) keeps the `ContentProvider` so a genuinely separate `:as_process` service can `query()`/`update()` it the same way the original did. Mark the whole boundary ⚠️.

> **iOS:** No accessibility service, no second process for *our* logic — but the `DeviceActivityMonitor`/`ManagedSettings` extension is a separate process. Share config via an **App Group** (`UserDefaults(suiteName: "group.com.yourapp")`) instead of a ContentProvider. ✅ within the App-Group model, ❌ for replicating accessibility-style blocking.

---

## 8. Store 2 — Analytics DB (Room → drift)

### 8.1 Original schema

`AnalyticsDatabase` (verified `analytics/db/AnalyticsDatabase.java`) defines four tables / DAOs and a `MIGRATION_2_3`; `createAutoMigrations()` returns empty (no Room auto-migrations). InvalidationTracker tables: `device_unlock_sessions`, `shorts_block_history`, `focus_unlock_sessions`, `unlocked_app_access`. Entities are **insert-only / select-only** — no `UPDATE`/`DELETE` DAOs exist (verified note); deletions would need raw SQL.

| Table | Original entity | Primary key | Notable columns |
|---|---|---|---|
| `shorts_block_history` | `ShortsBlockHistoryEntity` | `id` autoincrement | `timestamp`, `packageName`, `blockMode`, `planWhenBlocked`, `platformId`, `sessionId` |
| `device_unlock_sessions` | `DeviceUnlockSessionEntity` | `sessionId` (String) | `unlockedOn`, `lockedOn` |
| `focus_unlock_sessions` | `FocusUnlockSessionEntity` | `unlockId` (String) | `sessionId`, `unlockedOn`, `unlockedDurationMillis`, `unlockedAppPackage` |
| `unlocked_app_access` | `UnlockedAppAccessEntity` | `id` autoincrement | `unlockId`, `packageName`, `usedOn` |

### 8.2 Drift schema (port)

```dart
// data/db/analytics_db.dart
import 'package:drift/drift.dart';
part 'analytics_db.g.dart';

@DataClassName('ShortsBlockRow')
class ShortsBlockHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get timestamp => integer()();          // epoch ms
  TextColumn get packageName => text()();
  TextColumn get blockMode => text()();            // PRESS_BACK | KILL_APP | LOCK_SCREEN | NONE
  TextColumn get planWhenBlocked => text()();      // BLOCK_ALL | CURIOUS | ONE_REEL | PAUSED
  TextColumn get platformId => text()();
  TextColumn get sessionId => text()();
  @override String get tableName => 'shorts_block_history';
}

@DataClassName('DeviceUnlockRow')
class DeviceUnlockSessions extends Table {
  TextColumn get sessionId => text()();
  IntColumn get unlockedOn => integer()();
  IntColumn get lockedOn => integer().nullable()();
  @override Set<Column> get primaryKey => {sessionId};
  @override String get tableName => 'device_unlock_sessions';
}

@DataClassName('FocusUnlockRow')
class FocusUnlockSessions extends Table {
  TextColumn get unlockId => text()();
  TextColumn get sessionId => text()();
  IntColumn get unlockedOn => integer()();
  IntColumn get unlockedDurationMillis => integer()();
  TextColumn get unlockedAppPackage => text()();
  @override Set<Column> get primaryKey => {unlockId};
  @override String get tableName => 'focus_unlock_sessions';
}

@DataClassName('UnlockedAppAccessRow')
class UnlockedAppAccess extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get unlockId => text()();
  TextColumn get packageName => text()();
  IntColumn get usedOn => integer()();
  @override String get tableName => 'unlocked_app_access';
}

@DriftDatabase(tables: [
  ShortsBlockHistory, DeviceUnlockSessions, FocusUnlockSessions, UnlockedAppAccess,
])
class AnalyticsDb extends _$AnalyticsDb {
  AnalyticsDb(super.e);
  @override int get schemaVersion => 3; // matches Room version after MIGRATION_2_3

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // Port MIGRATION_2_3 here when bumping 2→3 (e.g. added column).
        },
      );
}
```

### 8.3 Stats aggregation (ScrollingSessionStats)

Verified semantics (`AnalyticsRepository` + `persistence.json` notes): from `shorts_block_history`, group blocks by time gaps; a session is valid when the gap is `>= 30000 ms` (30 s `SESSION_MIN_GAP`), a **long** session when its duration `> 240000 ms` (240 s `LONG_SESSION_THRESHOLD`); `totalScrollingDuration` = sum of session durations. Output model: `sessionId`, `totalScrollingDuration`, `scrollingSessionCount`, `longScrollingSessionCount`, `recordedAt`.

```dart
// domain/usecases/compute_scrolling_stats.dart
class ScrollingSessionStats {
  final String sessionId;
  final int totalScrollingDuration;   // ms
  final int scrollingSessionCount;
  final int longScrollingSessionCount;
  final int recordedAt;
  const ScrollingSessionStats({/* ... */});
}

ScrollingSessionStats computeStats(List<ShortsBlockRow> blocks, {required int since}) {
  const minGap = 30000, longThreshold = 240000;
  final rows = blocks.where((b) => b.timestamp >= since).toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  // Walk rows; split into sessions whenever gap >= minGap; sum durations;
  // count sessions and those whose duration > longThreshold. (inferred grouping —
  // exact DAO SQL body was obfuscated, but thresholds are verified.)
  return ScrollingSessionStats(/* aggregated */);
}
```

### 8.4 Repository sketch

```dart
// data/repositories/analytics_repository_impl.dart
class AnalyticsRepositoryImpl implements AnalyticsRepository {
  AnalyticsRepositoryImpl(this._db);
  final AnalyticsDb _db;

  @override
  Future<void> recordBlock({
    required String packageName, required String blockMode,
    required String planWhenBlocked, required String platformId,
    required String sessionId,
  }) => _db.into(_db.shortsBlockHistory).insert(ShortsBlockHistoryCompanion.insert(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        packageName: packageName, blockMode: blockMode,
        planWhenBlocked: planWhenBlocked, platformId: platformId, sessionId: sessionId,
      ));

  @override
  Future<void> ensureSession(String sessionId) async {
    final existing = await (_db.select(_db.deviceUnlockSessions)
          ..where((t) => t.sessionId.equals(sessionId)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.deviceUnlockSessions).insert(DeviceUnlockSessionsCompanion.insert(
        sessionId: sessionId, unlockedOn: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  @override
  Stream<ScrollingSessionStats> watchStatsSince(int since) =>
      (_db.select(_db.shortsBlockHistory)..where((t) => t.timestamp.isBiggerOrEqualValue(since)))
          .watch().map((rows) => computeStats(rows, since: since));
}
```

> **Cross-process write path:** the accessibility service (native) detects a block and **cannot** write drift directly. It emits a `blockRecorded` event over an `EventChannel`; the Dart `AnalyticsRepositoryImpl` consumes it and inserts the row. ⚠️ for the bridge, ✅ for the DB itself. If you need the service to persist even when the Dart engine is dead, buffer events in the native `SharedConfigStore` (§7) and drain into drift on next app launch.

---

## 9. BLoC wiring (presentation ↔ persistence)

```dart
// presentation/bloc/settings/settings_bloc.dart
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc(this._watchPin, this._setBlockingMode) : super(const SettingsState.initial()) {
    on<SettingsStarted>((e, emit) async {
      await emit.forEach<PinConfig?>(
        _watchPin(), // wraps Hive box.watch + secure read; mirrors Flow distinctUntilChanged
        onData: (pin) => state.copyWith(pinConfig: pin),
      );
    });
    on<BlockingModeChanged>((e, emit) async {
      await _setBlockingMode(e.mode);            // writes Hive AND pushes to native via SharedConfigChannel
    });
  }
  final WatchPinConfig _watchPin;
  final SetDefaultBlockingMode _setBlockingMode;
}
```

The use case for any **⚠️ + native** key must write **both** the Dart store (for UI reactivity) and the native shared store (for the service), in that order, then optionally trigger `contentResolver.notifyChange`/`SharedPreferences` listener on the native side.

---

## 10. Package legend summary

| Need | Package | Legend |
|---|---|---|
| Encrypted secrets (PIN, email, OTP, Hive key) | `flutter_secure_storage` | ✅ |
| Structured JSON config/maps (configs, sessions, blocklists) | `hive` (+ `hive_flutter`, AES cipher) | ✅ |
| Trivial flags/enums/timestamps | `shared_preferences` | ✅ |
| Analytics SQLite DB + migrations + reactive queries | `drift` | ✅ |
| Immutable models + JSON codecs | `freezed`, `json_serializable` | ✅ |
| Date signature (`dd-MM-yyyy`) for daily rollover | `intl` | ✅ |
| Session/unlock IDs | `uuid` | ✅ |
| Cross-process config (UI ↔ accessibility service) | native `SharedPreferences`/DataStore + `MethodChannel`/`EventChannel` (or keep a Kotlin `ContentProvider`) | ⚠️ |
| Reading any of the above on iOS across the extension boundary | App Group `UserDefaults(suiteName:)` / shared SQLite | ⚠️ (and ❌ for accessibility-style blocking) |

---

## Source evidence

This document is based on direct reads of the decompiled sources and cached analysis:
- `sources/com/newswarajya/noswipe/reelshortblocker/data/database/datasource/DataStoreBase.java` (PrefKeys inventory, write/serialize path)
- `sources/.../data/database/datasource/DataStoreUtils.java` (app-level keys, email cooldowns, GDPR)
- `sources/.../data/database/datasource/DataStoreProvider.java` (two DataStore instances, encrypted-prefs migration)
- `sources/.../data/database/contentprovider/NoScrollContentProvider.java` (authority `com.newswarajya.noswipe.provider`, URI `{type}/{key}`, `query`/`update`)
- `sources/.../analytics/db/AnalyticsDatabase.java` (4 DAOs, `MIGRATION_2_3`, InvalidationTracker tables)
- `sources/.../analytics/db/entity/{ShortsBlockHistoryEntity, DeviceUnlockSessionEntity, FocusUnlockSessionEntity, UnlockedAppAccessEntity}.java`
- `sources/.../analytics/AnalyticsRepository.java` (recordBlock/recordFocusUnlock/ensureSession, ScrollingSessionStats thresholds 30 s / 240 s)
- `sources/.../service/accessibility/data/{PauseSessionData, CuriousSessionData, AppSessionDetails, DailyAppBlocker via persistence.json}.java` (phase algorithms, defaults)
- Cached analyses: `/tmp/ns_analysis/persistence.json`, `/tmp/ns_analysis/service-state-and-session.json`
- Parts labeled **(inferred)** (e.g. exact stats grouping SQL, deeplink key) had obfuscated/absent method bodies.

## Related docs
- `01-architecture-overview.md`
- `04-accessibility-service.md`
- `05-detection-engine.md`
- `06-blocking-modes-and-sessions.md`
- `07-plans-and-gating.md`
- `08-overlay-and-pin.md`
- `10-analytics-and-telemetry.md`
- `11-cross-process-and-channels.md`
