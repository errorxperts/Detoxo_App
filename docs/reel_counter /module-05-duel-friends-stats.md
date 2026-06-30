# Module: Duels, Friends & Stats

> BrainPal package `com.brainrot.android` v7.1.340. This module covers the **"Scroll Battle"** (in-code: *duel*) social-competition feature: friend list, daily head-to-head + leaderboard ranking by reels scrolled, the `rot_score`, per-app reel **"split"** breakdown, the multi-device split aggregation, the delta-sync stats pipeline, and the **pinned friend**.
>
> Source of truth for channels: [01-platform-channel-contracts.md](01-platform-channel-contracts.md). Source of truth for endpoints: [02-backend-api-contract.md](02-backend-api-contract.md). Sibling data/sync concerns: [module-04-*](module-01-reels-detection-core.md) (reels counter), block config lives in [module-03-*](module-02-overlays-floating-bubble.md).

---

## 1. Purpose & scope

The **Scroll Battle** lets a user compete with friends to scroll the *fewest* short-form videos ("reels") per day. Scope of this module:

- **Friend list** management (add via invite link, accept, remove/delete, "uninstalled" state). Source: `InviteApi` (`/invite/*`).
- **Daily duel / leaderboard**: rank all friends + self for a `stats_date` by reels scrolled (fewest = winner). Source: `BrainRotStatsApiService.getDuelFriends` (`/stats/api/v1/duel/friends`).
- **Head-to-head (H2H)** single-friend daily comparison. DTO `getDuelCount` (`/stats/api/v1/duel/count`) exists but is **not wired** in the decompiled build (see §11 OQ-1).
- **`rot_score`**: server-computed secondary ranking score carried alongside reel count.
- **Per-app "split"**: each user's daily reel count broken down per target app (Instagram/YouTube/TikTok/Snapchat/Facebook), tracked per device.
- **Multi-device aggregation**: a user with multiple Android devices contributes `OtherDeviceSplitItem` rows merged into their own daily totals.
- **Pinned friend**: one friend pinned for prominence; stored in the global block config (`BlockReelsState.pinnedFriendBrUserId`).
- **Delta-sync**: timestamp-cursor sync of friend stats / friend list / my-splits / config.
- **Battle notifications**: daily H2H ("X beat you yesterday") and rank ("You came Nth of M") push messages.

**Out of scope** (documented elsewhere): the AccessibilityService reel detection that *produces* the counts (module-04), the block-overlay enforcement that consumes `BlockReelsState` (module-03), the invite deep-link / paywall (modules 02/06).

> **CRITICAL ARCHITECTURE NOTE.** This module is overwhelmingly **business/data/sync logic with NO OS-integration surface** — it is the part of BrainPal that ports most cleanly to pure Dart. It does **not** need the retained native detection/overlay core. Its only platform coupling is (a) the **`android_device_id`** identity it stamps on every split, and (b) it is *fed* by reel-count events that originate in the native detection core (via `EventChannel "brainpal/detection"`). On iOS the entire social/stats layer ports verbatim to Dart; only the upstream *source* of counts differs (Apple `DeviceActivity` instead of AccessibilityService — see §6 and module-03/04).

---

## 2. Migration verdict

**Verdict: PURE-DART** (the rare module with no required native code), with one DART+CHANNEL touchpoint for device identity.

| Concern | Android verdict | iOS verdict |
|---|---|---|
| Friend list / duel leaderboard / H2H REST reads | **PURE-DART** — `dio`+`retrofit`, `dio_cache_interceptor` for the SWR headers | **PURE-DART** — identical |
| Per-app split storage + delta computation | **PURE-DART** — `drift` table `daily_reels_app_split` | **PURE-DART** — identical |
| Delta-sync orchestration (cursors, merge) | **PURE-DART** — `workmanager` periodic trigger + Dart repo | **PURE-DART** — `workmanager` (BGTaskScheduler under the hood) |
| `android_device_id` stamping | **DART+CHANNEL** — read once via `brainpal/permissions`/device core, cache in `flutter_secure_storage` | **DART+CHANNEL** — use `identifierForVendor`; field name kept `android_device_id` on the wire for server compat |
| Reel counts that feed splits | consumed from native via `EventChannel "brainpal/detection"` (module-04) | consumed from `DeviceActivity` extension (module-03/04) |
| Couchbase Lite friend replication | see OQ-2 — **likely dead/legacy**; recommend **REST-only** in Flutter | n/a |

**Rationale.** Every class in this module (`DuelCountResponse`, `FriendStatsDelta`, `MySplitDelta`, `AppSplitItem`, `OtherDeviceSplitItem`, `DailyReelsAppSplit`, `Friends`/`OneFriend`, `DayStats`, `BlockReelsState`) is a plain Kotlin data class or Retrofit interface — pure JVM logic with Gson annotations and SQLite/Room persistence. There is no `Service`, `Window`, `Sensor`, NFC, or overlay touched here. The only reason it is not 100% PURE-DART is the `android_device_id` identity that the server uses to partition splits by device.

---

## 3. Business logic & algorithms

> All constants/keys below were re-read from the decompiled source and quoted verbatim. Cited file paths are under `/Users/shahbazqureshi/Documents/Decompile/sources/`.

### 3.1 Target apps & per-app "split"

A **split** = one app's contribution to a user's daily reel count. Each split carries `appPackage` (a.k.a. `app_id`), human `displayName`, `reelCount`, and `viewDurationMs`. The target app package set is the same across the app (Instagram, YouTube, TikTok, Snapchat, Facebook). Exact package strings are owned by the **detection module** — see [module-04](module-01-reels-detection-core.md) §3 for the canonical, verbatim list. **Do not hard-code a second copy here**; the duel module treats `appId`/`appPackage` + `displayName` as opaque server-provided strings (server is authoritative for `display_name`).

> **OPEN QUESTION OQ-3**: confirm the canonical package list & display names from module-04 rather than inventing them here.

### 3.2 Duel / leaderboard ranking (verbatim semantics)

The leaderboard endpoint returns `List<DuelCountResponse>`, one row per friend (+ self) for a `stats_date`. Ranking is **by reels scrolled, fewest = winner** ("crown"). Confirmed by UI strings (`/resources/res/values/strings.xml`):

```
battle_notif_rank_win_body  = "Fewest reels of everyone. Keep the crown."
battle_notif_h2h_win_body   = "Fewer reels than them. Keep it up."
battle_notif_h2h_lose_title = "%1$s beat you yesterday"
battle_notif_rank_lose_title= "You came %1$s of %2$d yesterday"
battle_title                = "Scroll Battle"
counter_leaderboard_rank/player/count = "Rank" / "Player" / "Reels"
```

So the primary sort key is `count` (reels) **ascending**. `rot_score` is a parallel server-computed score (see §3.3). `is_pinned` rows are surfaced prominently (pinned friend). `is_uninstalled` rows render as inactive (`battle_friend_uninstalled = "Uninstalled"`).

Pseudocode (display ranking):

```text
fun rankLeaderboard(rows: List<DuelCountResponse>, self: DuelCountResponse): List<Row> {
  all = rows + self
  // primary: fewest reels wins; uninstalled sink to bottom; pinned highlighted (not reordered to top necessarily)
  sorted = all.sortedWith(
      compareBy({ it.isUninstalled })            // active first
        .thenBy({ it.count ?: Int.MAX_VALUE })   // fewest reels = rank 1
        .thenBy({ it.rotScore ?: Int.MAX_VALUE })// tiebreak by rot_score
  )
  return sorted.mapIndexed { i, r -> Row(rank = i+1, r) }
}
```

> **OPEN QUESTION OQ-4**: exact tiebreak + whether pinned is pinned-to-top vs highlighted-in-place is a UI decision not fully recoverable from decompiled code (the duel Compose screens are obfuscated/stripped — only `DayStats.java` survives in `feature_duel`). Treat the above as the documented default; validate against server `rot_score` ordering.

### 3.3 `rot_score` (rot = "brain rot")

`rot_score` (`@SerializedName("rot_score")`, `Integer` in `DuelCountResponse`, primitive `int` in `FriendStatsDelta`/`DailyReelsStats`) is a **server-computed** engagement/penalty score. **The client never computes it** — there is no rot-score formula in the decompiled source; the client only reads/stores/ranks by it. Higher = "more brain rot" (worse). It is carried per friend per day. Client responsibilities: store it (`friend_stats.rot_score`), use it as a leaderboard tiebreak, and display it.

> **OPEN QUESTION OQ-5**: the exact server formula for `rot_score` (reels × weight, view-duration penalty, etc.) is backend-side and not in this APK. Capture from backend team; record in [02-backend-api-contract.md](02-backend-api-contract.md).

### 3.4 Per-app split DELTA computation (the load-bearing algorithm)

The client tracks per-app daily reel counts locally in Room table **`daily_reels_app_split`** (entity `DailyReelsAppSplit`, `TABLE_NAME = "daily_reels_app_split"`, `core/domain/model/DailyReelsAppSplit.java`). The critical field is:

```
private final int lastSyncedReelCount;   // high-water mark of what the server already has
```

The **scroll-update push** (`ig.s.a()`, `/sources/ig/s.java`, → `BrainRotStatsApiService.updateScrollStats`) sends only the *new* reels since last sync, then advances the water mark:

```text
// PUSH (ig.s.a → POST /stats/api/v1/user/scroll/update)
val today      = formatDate(now)                 // "yyyy-MM-dd", Locale.US  (qb.a.Y)
val splits     = dao.appSplitsForDate(today)
val payload    = splits
    // AppSplitItem carries the *absolute* reelCount + viewDurationMs per app_package
    .map { AppSplitItem(it.appId, it.displayName, it.reelCount, it.viewDurationMs) }
val req = ScrollUpdateRequest(androidDeviceId, today, payload)
val resp: ScrollUpdateResponse = api.updateScrollStats(req)

// RESPONSE → merge OTHER devices of the SAME user
// resp.otherDeviceSplits : Map<statsDate, List<OtherDeviceSplitItem>>
for ((statsDate, items) in resp.otherDeviceSplits) {
  val merged = items.map { o ->
    DailyReelsAppSplit(
      androidDeviceId = o.androidDeviceId,        // a DIFFERENT device id
      statsDate       = statsDate,                // map KEY is the date
      appId           = o.appPackage,
      displayName     = o.displayName,
      reelCount       = o.reelCount,
      viewDurationMs  = o.viewDurationMs,
      updatedAt       = o.updatedAt,
      lastSyncedReelCount = o.reelCount           // other-device rows are already "synced"
    )
  }
  dao.upsertAll(merged)
}
```

Verbatim facts confirmed:
- `ScrollUpdateRequest` JSON: `android_device_id`, `stats_date`, `splits: List<AppSplitItem>` (`network/ScrollUpdateRequest.java`).
- `AppSplitItem` JSON: `app_package`, `display_name`, `reel_count`, `view_duration_ms` (`network/AppSplitItem.java`).
- `ScrollUpdateResponse` JSON: `status`, `server_time_ms`, `other_device_splits: Map<String, List<OtherDeviceSplitItem>>` (`network/ScrollUpdateResponse.java`). **The map key is the `stats_date`** (used as `statsDate` in the merge — see `ig.s` decompiled block B:69).
- `OtherDeviceSplitItem` JSON: `android_device_id`, `app_package`, `display_name`, `reel_count`, `view_duration_ms`, `updated_at` (`network/OtherDeviceSplitItem.java`).

> The Flutter delta semantics: persist `lastSyncedReelCount` per (device, date, app). On push, the *delta to send* is `reelCount - lastSyncedReelCount`; after a 2xx, set `lastSyncedReelCount = reelCount`. Note: in the decompiled `AppSplitItem` the **absolute** `reel_count` is sent (server diffs), while `AppSplitRequest` (the `count` field) is the alternative delta-style DTO used only by the dormant `/sync` path (§3.6).

### 3.5 Friends-update worker (delta refresh cadence — verbatim)

`FriendsUpdateWorker` (`core/worker/FriendsUpdateWorker.java`) is a `CoroutineWorker` that:

```text
doWork():
  val ok = syncUseCase.run()        // qh.d.a(): see chain below
  if (ok) { uiRefreshCallback() ; return Result.success() }
  catch(e) -> log("doWork: Failed to refresh friends count","FriendsUpdateWorker"); return Result.retry()
```

The sync use-case **`qh.d.a()`** (`/sources/qh/d.java`) chains three suspend steps:

```text
1. oh.d.b()      // count friend docs in local store; returns Boolean (count > 0). If false → return false (skip).
2. ig.f.c()      // WARM the duel leaderboard cache: api.getDuelFriends(today, X-Skip-SWR="true")
3. qh.b.a()      // refresh widget/glance friend data (sh.x doc render)
   → return true
```

`ig.f.c()` (`/sources/ig/f.java`) verbatim:
```text
val today = qb.a.Y(System.currentTimeMillis())  // "yyyy-MM-dd"
api.getDuelFriends(stats_date = today, X-Skip-SWR = "true")
```

**Scheduling (verbatim, `/sources/wc/h0.java`):** `FriendsUpdateWorker` is enqueued as a **OneTimeWorkRequest** (NOT periodic):
- unique name: **`"friends_update_worker_onetime"`**, policy **KEEP** (`ka.l.f14429e`)
- `setInitialDelay(30, MINUTES)`
- `setBackoffCriteria(..., 5, MINUTES)` (backoff delay 5 min on retry)
- constraint: **NetworkType.CONNECTED** (`ka.w.f14451n`)
- re-enqueued on every app start (`BrainRotApplication.scheduleFriendsUpdateWorker` → `h0.a()`) and again from inside the worker's success path (self-chaining ≈ every ~30 min while app is alive + on cold start).

> **Flutter mapping**: a `workmanager` one-off task `friendsUpdateOneTime` with `initialDelay: 30 min`, `backoffPolicy` 5 min, `existingWorkPolicy: keep`, `constraints: NetworkType.connected`, re-registered on app launch and at the end of each successful run. See §8.

### 3.6 Dormant delta-sync REST path (`SyncRequest`/`SyncResponse`)

`SyncRequest` / `SyncResponse` (`network/SyncRequest.java`, `SyncResponse.java`) describe a *cursor-based* delta sync:

- `SyncRequest`: `device_id`, `since_friends_stats` (ms), `since_my_splits` (ms), `since_friends_list` (ms), `app_splits: List<AppSplitRequest>`, `since_config` (ms), `config: BlockReelsState`.
- `SyncResponse`: `server_time_ms`, `friends_stats_deltas: List<FriendStatsDelta>`, `friends_list_deltas: List<FriendListDelta>`, `my_splits_deltas: List<MySplitDelta>`, `config_delta: BlockReelsState`.

**However**: a full grep of the decompiled APK shows **`SyncRequest`/`SyncResponse` are referenced by NO caller** (only their own files). There is **no Retrofit method** in `BrainRotStatsApiService` that takes/returns them. The live data path is instead: `getDuelFriends` (read) + `updateScrollStats` (write) + Couchbase replication for friend docs.

> **DO NOT port the `/sync` REST path as live behavior.** Treat `SyncRequest`/`SyncResponse`/`AppSplitRequest`/`MySplitDelta`/`FriendStatsDelta`/`FriendListDelta` as **server-contract reference + likely-future/legacy schema**. Model them in Dart for completeness (they are the cleanest description of the delta-cursor design and are very likely how the Couchbase docs are shaped), but the active wire calls are the duel + scroll endpoints. See OQ-1/OQ-2.

### 3.7 Pinned friend

`BlockReelsState.pinnedFriendBrUserId` (`@SerializedName("pinned_friend_br_user_id")`, nullable `String`) holds the pinned friend's `br_user_id`. Pinning is **part of the global block config**, not a separate friends call. `ig.f.b(brUserId, ...)` (`/sources/ig/f.java`) shows the un-pin / config-rewrite path: it reads `UserBlockingConfig`, and **if `config.pinnedFriendBrUserId == brUserId`** it rewrites the config clearing the pin (via `UserBlockingConfig.copy$default(..., updatedAt = now, ...)`), then persists through `sc.i.b(config)`. I.e. **removing the friend who is pinned clears the pin.** Config changes propagate to the server via `updateReelsConfig` (`POST /stats/api/v1/user/config/update`) — see [module-03](module-02-overlays-floating-bubble.md) for the full block-config lifecycle.

### 3.8 Friend status & "invite accepted" celebration

`OneFriend.status` is enum **`lg.b`** with values (verbatim, `/sources/lg/b.java`):

```
PENDING(0), ACCEPTED(1), BLOCKED(2), UNINSTALLED(3), PERMISSION_MISSING(4)
```

`OneFriend.shouldShowInviteAccepted: Boolean` (defaults `false`) drives the "%1$s joined the battle" celebration (`friend_accepted_title`). The list source `FriendListDelta.status` is a raw `String` on the wire → mapped to `lg.b`.

### 3.9 Date / week formatting (verbatim)

`qb.a` (`/sources/qb/a.java`):
- `Y(ms)` → `new SimpleDateFormat("yyyy-MM-dd", Locale.US)` → the canonical `stats_date`.
- `Z(ms)` → week range label `"MMM d - d"` / `"MMM d - MMM d"` (Locale.US), spanning `+6` days (used by Battle weekly stats `battle_stats_title`).
- Day-of-midnight floor helper (sets HH/mm/ss/SSS to 0) used to bucket `DayStats`.

`DayStats` (`feature_duel/domain/use_case/DayStats.java`): `dayLabel: String`, `count: Int`, `timeMillis: Long` — the per-day bar in the weekly Battle chart.

---

## 4. Data models

> Field name · wire JSON `@SerializedName` (or "—" for non-Gson domain models) · type · nullability · DB column/PK. All re-read from source.

### 4.1 Network DTOs

**`DuelCountResponse`** (`network/DuelCountResponse.java`) — one leaderboard/H2H row.

| field | JSON | type | null | notes |
|---|---|---|---|---|
| brUserId | `br_user_id` | String | non-null | friend (or self) id |
| count | `count` | Integer | **nullable** | reels scrolled that day |
| rotScore | `rot_score` | Integer | **nullable** | server score |
| isPinned | `is_pinned` | boolean | non-null | |
| statsDate | `stats_date` | String | non-null | `yyyy-MM-dd` |
| isUninstalled | `is_uninstalled` | boolean | non-null | default `false` (ctor) |

**`FriendListDelta`** (`network/FriendListDelta.java`)

| field | JSON | type | null |
|---|---|---|---|
| friendId | `friend_id` | String | non-null |
| status | `status` | String | non-null (→ `lg.b`) |
| updatedAt | `updated_at` | long(ms) | non-null |

**`FriendStatsDelta`** (`network/FriendStatsDelta.java`)

| field | JSON | type | null |
|---|---|---|---|
| friendId | `friend_id` | String | non-null |
| date | `date` | String | non-null (`yyyy-MM-dd`) |
| reelCount | `reel_count` | int | non-null |
| rotScore | `rot_score` | int | non-null |
| updatedAt | `updated_at` | long(ms) | non-null |

**`MySplitDelta`** (`network/MySplitDelta.java`)

| field | JSON | type | null |
|---|---|---|---|
| androidDeviceId | `android_device_id` | String | non-null |
| statsDate | `stats_date` | String | non-null |
| appId | `app_id` | String | non-null |
| displayName | `display_name` | String | non-null |
| reelCount | `reel_count` | int | non-null |
| viewDurationMs | `view_duration_ms` | long(ms) | non-null |
| updatedAt | `updated_at` | long(ms) | non-null |

**`AppSplitItem`** (`network/AppSplitItem.java`) — push split (in `ScrollUpdateRequest.splits`)

| field | JSON | type | null |
|---|---|---|---|
| appPackage | `app_package` | String | non-null |
| displayName | `display_name` | String | non-null |
| reelCount | `reel_count` | int | non-null |
| viewDurationMs | `view_duration_ms` | long(ms) | non-null |

**`AppSplitRequest`** (`network/AppSplitRequest.java`) — delta-style split (dormant `/sync` only)

| field | JSON | type | null |
|---|---|---|---|
| date | `date` | String | non-null |
| appId | `app_id` | String | non-null |
| displayName | `display_name` | String | non-null |
| count | `count` | int | non-null |
| viewDurationMs | `view_duration_ms` | long(ms) | non-null |

**`OtherDeviceSplitItem`** (`network/OtherDeviceSplitItem.java`) — in `ScrollUpdateResponse.other_device_splits` map values

| field | JSON | type | null |
|---|---|---|---|
| androidDeviceId | `android_device_id` | String | non-null |
| appPackage | `app_package` | String | non-null |
| displayName | `display_name` | String | non-null |
| reelCount | `reel_count` | int | non-null |
| viewDurationMs | `view_duration_ms` | long(ms) | non-null |
| updatedAt | `updated_at` | long(ms) | non-null |

**`RestoreSplitItem`** (`network/RestoreSplitItem.java`) — in `UserRestoreResponse.splits_history`

| field | JSON | type | null |
|---|---|---|---|
| androidDeviceId | `android_device_id` | String | non-null |
| statsDate | `stats_date` | String | non-null |
| appPackage | `app_package` | String | non-null |
| displayName | `display_name` | String | non-null |
| reelCount | `reel_count` | int | non-null |
| viewDurationMs | `view_duration_ms` | long(ms) | non-null |

**`ScrollUpdateRequest`** (`network/ScrollUpdateRequest.java`): `android_device_id`, `stats_date`, `splits: List<AppSplitItem>`.
**`ScrollUpdateResponse`** (`network/ScrollUpdateResponse.java`): `status`, `server_time_ms`, `other_device_splits: Map<String(date), List<OtherDeviceSplitItem>>`.
**`SyncRequest` / `SyncResponse`** — §3.6 (dormant).
**`SyncUserResponse`** (`network/SyncUserResponse.java`): `username`, `password`, `sync_url` — **Couchbase Lite replication credentials** (returned by `POST /stats/register_sync_user`; `@SerializedName` keys are the Couchbase `C4Replicator` constants for user/password). See OQ-2.
**`UserRestoreResponse`** (`network/UserRestoreResponse.java`): `config: BlockReelsState?`, `splits_history: List<RestoreSplitItem>`.
**`ConfigUpdateResponse`** (`network/ConfigUpdateResponse.java`): `status: String`, `updated_at: long`.

**`BlockReelsState`** (`network/BlockReelsState.java`) — global block config; only `pinned_friend_br_user_id` is owned here, the rest belongs to [module-03](module-02-overlays-floating-bubble.md):

| field | JSON | type | null |
|---|---|---|---|
| pinnedFriendBrUserId | `pinned_friend_br_user_id` | String | **nullable** |
| isBlockEnabled | `is_block_enabled` | boolean | non-null |
| cooldownTimeInMillis | `cooldown_time_in_millis` | long | non-null |
| hardBlockValidTill | `hard_block_valid_till` | Long | nullable |
| reelsAllowedCount | `reels_allowed_count` | int | non-null |
| reelsAllowedValidForMillis | `reels_allowed_valid_for_millis` | long | non-null |
| blockPauseExpiryTime | `block_pause_expiry_time` | Long | nullable |
| blockStartTimestamp | `block_start_timestamp` | Long | nullable |
| blockStartReelCount | `block_start_reel_count` | Integer | nullable |
| updatedAt | `updated_at` | long(ms) | non-null |

### 4.2 Invite-feature DTOs (the LIVE friend list source)

**`GetFriendsResponse`** (`feature_invite/data/remote/GetFriendsResponse.java`): `friends: List<FriendInfo>` (no `@SerializedName` — field name `friends`).
**`FriendInfo`** (`feature_invite/data/remote/FriendInfo.java`)

| field | JSON | type | null |
|---|---|---|---|
| brUserId | `br_user_id` | String | non-null |
| displayName | `display_name` | String | nullable |
| displayPhotoUrl | `display_photo_url` | String | nullable |
| isUninstalled | `is_uninstalled` | Boolean | nullable (default `false`) |
| friendSinceMs | `friend_since_ms` | Long | nullable |

### 4.3 Domain models (non-Gson)

**`Friends`** (`feature_reels_counter/domain/model/Friends.java`): `brUserId: String?`, `myFriendsBRUserIds: List<OneFriend>`.
**`OneFriend`**: `brUserId: String?`, `status: lg.b`, `friendShipStartDateInMillis: long`, `isPinned: boolean`, `profileInfo: ProfileInfo`, `shouldShowInviteAccepted: boolean (=false)`.
**`ProfileInfo`**: `displayName: String`, `emailId: String`, `displayPhotoUrl: String?` + computed `firstName` (split `displayName` on `\s+`, take first token).
**`DailyReelsStats`** (`feature_reels_counter/domain/model/DailyReelsStats.java`): `brUserId: String?`, `statsDate: String`, `reelCount: int`, `rotScore: int`.
**`DayStats`** (`feature_duel/domain/use_case/DayStats.java`): `dayLabel: String`, `count: int`, `timeMillis: long`.
**`DailyReelsAppSplit`** (`core/domain/model/DailyReelsAppSplit.java`) — **Room entity** `daily_reels_app_split`: `androidDeviceId`, `statsDate`, `appId`, `displayName`, `reelCount: int`, `viewDurationMs: long`, `updatedAt: long`, `lastSyncedReelCount: int (=0)`.

### 4.4 Dart target shapes (freezed + drift)

```dart
// ---------- freezed DTOs (json_serializable) ----------
@freezed
class DuelCountResponse with _$DuelCountResponse {
  const factory DuelCountResponse({
    @JsonKey(name: 'br_user_id') required String brUserId,
    @JsonKey(name: 'count') int? count,
    @JsonKey(name: 'rot_score') int? rotScore,
    @JsonKey(name: 'is_pinned') @Default(false) bool isPinned,
    @JsonKey(name: 'stats_date') required String statsDate,
    @JsonKey(name: 'is_uninstalled') @Default(false) bool isUninstalled,
  }) = _DuelCountResponse;
  factory DuelCountResponse.fromJson(Map<String, dynamic> j) =>
      _$DuelCountResponseFromJson(j);
}

enum FriendStatus { pending, accepted, blocked, uninstalled, permissionMissing }
// wire <-> enum: "PENDING"|"ACCEPTED"|"BLOCKED"|"UNINSTALLED"|"PERMISSION_MISSING"

@freezed
class FriendInfo with _$FriendInfo {           // LIVE friend-list element (/invite/friends)
  const factory FriendInfo({
    @JsonKey(name: 'br_user_id') required String brUserId,
    @JsonKey(name: 'display_name') String? displayName,
    @JsonKey(name: 'display_photo_url') String? displayPhotoUrl,
    @JsonKey(name: 'is_uninstalled') @Default(false) bool isUninstalled,
    @JsonKey(name: 'friend_since_ms') int? friendSinceMs,
  }) = _FriendInfo;
  factory FriendInfo.fromJson(Map<String, dynamic> j) => _$FriendInfoFromJson(j);
}

@freezed
class AppSplitItem with _$AppSplitItem {        // push split
  const factory AppSplitItem({
    @JsonKey(name: 'app_package') required String appPackage,
    @JsonKey(name: 'display_name') required String displayName,
    @JsonKey(name: 'reel_count') required int reelCount,
    @JsonKey(name: 'view_duration_ms') required int viewDurationMs,
  }) = _AppSplitItem;
  factory AppSplitItem.fromJson(Map<String, dynamic> j) => _$AppSplitItemFromJson(j);
}

@freezed
class ScrollUpdateRequest with _$ScrollUpdateRequest {
  const factory ScrollUpdateRequest({
    @JsonKey(name: 'android_device_id') required String androidDeviceId,
    @JsonKey(name: 'stats_date') required String statsDate,
    @JsonKey(name: 'splits') required List<AppSplitItem> splits,
  }) = _ScrollUpdateRequest;
  factory ScrollUpdateRequest.fromJson(Map<String, dynamic> j) =>
      _$ScrollUpdateRequestFromJson(j);
}

@freezed
class ScrollUpdateResponse with _$ScrollUpdateResponse {
  const factory ScrollUpdateResponse({
    @JsonKey(name: 'status') required String status,
    @JsonKey(name: 'server_time_ms') required int serverTimeMs,
    // key = stats_date "yyyy-MM-dd"
    @JsonKey(name: 'other_device_splits')
        @Default({}) Map<String, List<OtherDeviceSplitItem>> otherDeviceSplits,
  }) = _ScrollUpdateResponse;
  factory ScrollUpdateResponse.fromJson(Map<String, dynamic> j) =>
      _$ScrollUpdateResponseFromJson(j);
}
// OtherDeviceSplitItem, RestoreSplitItem, UserRestoreResponse, FriendStatsDelta,
// FriendListDelta, MySplitDelta, AppSplitRequest, SyncRequest/Response,
// SyncUserResponse, ConfigUpdateResponse, BlockReelsState  -> 1:1 freezed (keys above).

// ---------- drift tables ----------
class DailyReelsAppSplits extends Table {
  TextColumn   get androidDeviceId    => text()();
  TextColumn   get statsDate          => text()();          // yyyy-MM-dd
  TextColumn   get appId              => text()();
  TextColumn   get displayName        => text()();
  IntColumn    get reelCount          => integer()();
  IntColumn    get viewDurationMs     => integer()();
  IntColumn    get updatedAt          => integer()();       // ms
  IntColumn    get lastSyncedReelCount=> integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {androidDeviceId, statsDate, appId};
}

class FriendStats extends Table {                 // one row per friend per day (leaderboard cache)
  TextColumn get friendId  => text()();
  TextColumn get statsDate => text()();
  IntColumn  get reelCount => integer()();
  IntColumn  get rotScore  => integer()();
  IntColumn  get updatedAt => integer()();
  IntColumn  get isPinned  => integer().withDefault(const Constant(0))();
  IntColumn  get isUninstalled => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {friendId, statsDate};
}

class FriendsListTable extends Table {            // friend roster (/invite/friends + status)
  TextColumn get friendId        => text()();
  TextColumn get status          => text()();     // FriendStatus.name
  TextColumn get displayName     => text().nullable()();
  TextColumn get displayPhotoUrl => text().nullable()();
  IntColumn  get friendSinceMs   => integer().nullable()();
  IntColumn  get isPinned        => integer().withDefault(const Constant(0))();
  IntColumn  get isUninstalled   => integer().withDefault(const Constant(0))();
  IntColumn  get updatedAt       => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {friendId};
}
```

---

## 5. Android deps → Flutter map

| Android API / class | Verdict | Flutter pkg or channel | Notes |
|---|---|---|---|
| `BrainRotStatsApiService` (Retrofit: `getDuelFriends`, `getDuelCount`, `getFriendsHistory`, `updateScrollStats`, `getReelsConfig`, `updateReelsConfig`, `restoreUserData`, `registerSyncUser`) | DART | `dio` + `retrofit` | endpoints in [02-backend-api-contract.md](02-backend-api-contract.md) |
| `InviteApi` (`/invite/friends`, `/invite/accept`, `/invite/create_link`, `/invite/remove_friend`, `/invite/get_invite_details`) | DART | `dio` + `retrofit` | LIVE friend-list source |
| OkHttp SWR cache via `X-Cache`/`X-Cache-TTL`/`X-Cache-Type` headers | DART | `dio_cache_interceptor` | replicate header-driven SWR (§7.2) |
| Gson `@SerializedName` | DART | `json_serializable` `@JsonKey` | keys preserved verbatim |
| Room entity `daily_reels_app_split` + DAOs | DART | `drift` | table name + PK preserved |
| Couchbase Lite (`z5.*`, `C4Replicator`, `SyncUserResponse`) friend replication | DART (recommend drop) | `dio` REST only | see OQ-2; do not embed Couchbase in Flutter |
| `WorkManager` `FriendsUpdateWorker` (one-time, 30-min delay, 5-min backoff, NetworkType.CONNECTED) | DART | `workmanager` | one-off self-rescheduling task; constraints mirrored |
| `SharedPreferences("friends_prefs")` (`first_seen_<friendId>`, sync cursors) | DART | `shared_preferences` | keep `first_seen_<id>` key shape |
| `android_device_id` (Settings.Secure / app-generated) | DART+CHANNEL | `brainpal/permissions` or device core + `flutter_secure_storage` | identity stamped on every split |
| Battle/leaderboard local notifications (`notification_channel_battle_result`) | DART | `flutter_local_notifications` + `firebase_messaging` | H2H/rank push (§9.7) |
| Firebase Analytics (duel/pin/invite events) | DART | `firebase_analytics` | event names in module-09 analytics doc |
| `SimpleDateFormat("yyyy-MM-dd", Locale.US)` (`qb.a.Y`) | DART | `intl` `DateFormat('yyyy-MM-dd')` (en_US) | MUST be Locale.US/UTC-stable |

---

## 6. iOS strategy

The **entire social/stats/duel layer ports verbatim to Dart on iOS** — it is REST + local DB + a background task. There is no Apple-specific reimplementation needed *for this module*; the only iOS deltas are upstream and at identity:

1. **Device identity.** Android sends `android_device_id`. On iOS use `UIDevice.identifierForVendor` (or an app-generated UUID in Keychain for stability across reinstalls). **Keep the wire key `android_device_id`** so the backend's split partitioning is unchanged; treat it as an opaque "device id". (Document this aliasing in [02-backend-api-contract.md](02-backend-api-contract.md).)
2. **Source of reel counts.** The per-app splits that this module pushes are *produced* by reel detection. On Android that is the AccessibilityService; on iOS it is the `DeviceActivityMonitor`/`DeviceActivity` extension feeding counts through an App Group + the same Dart domain layer (see [module-03](module-02-overlays-floating-bubble.md) / [module-04](module-01-reels-detection-core.md)). **What this module consumes is identical: a per-(date, appId) reel count.** The `appId` on iOS is a `FamilyControls` `ApplicationToken`-derived stable key, not a package name — the server `display_name` still drives UI.
3. **Background sync.** `workmanager` on iOS maps to `BGAppRefreshTask`/`BGProcessingTask`. iOS gives **no 30-min guarantee**; the friends/leaderboard refresh becomes best-effort + on-foreground refresh. Mark this in §10.
4. **Couchbase replication** (if kept) runs fine on iOS, but recommendation stands to drop it (OQ-2).
5. **Pinned friend / battle notifications**: pure Dart + APNs via `firebase_messaging`. No change.

**Not-possible items on iOS for this module: none.** (Unlike overlays/widgets in sibling modules, the duel/friends/stats layer has full iOS parity.)

---

## 7. Platform-channel surface

This module is almost entirely off-channel (REST + DB). It only *consumes* two channels owned by other modules; it defines no new channels. X-ref [01-platform-channel-contracts.md](01-platform-channel-contracts.md).

### 7.1 Channels consumed

| Channel | Dir | Used for | Owner module |
|---|---|---|---|
| `EventChannel "brainpal/detection"` | native→Dart | reel-detection events `{appId, videoId, isAd, isPanelOpen, viewDurationMs, ts}` → increment the per-app split (`daily_reels_app_split`) that this module later pushes | module-04 |
| `MethodChannel "brainpal/permissions"` | Dart→native | one-time fetch of the device identity used as `android_device_id` (or read from device core) | module-03/permissions |

No method/event in this module *originates* on a channel; all writes go to the network/DB layer.

### 7.2 SWR cache contract (HTTP, not platform-channel)

The duel/invite reads carry cache directives the native OkHttp layer honored; reproduce in `dio_cache_interceptor`:

| Endpoint | `X-Cache-TTL` | `X-Cache-Type` | Notes |
|---|---|---|---|
| `GET /stats/api/v1/duel/count` | 30 s | `swr` | H2H (dormant caller) |
| `GET /stats/api/v1/duel/friends` | 10 s | `swr` | leaderboard; warmed by worker with `X-Skip-SWR: "true"` (force-revalidate) |
| `GET /stats/api/v1/duel/friends_history` | 86400 s | `standard` | historical day (dormant caller) |
| `GET /invite/friends` | 30 s | `swr` | friend roster; `X-Skip-SWR` header to force fresh |

`X-Skip-SWR: "true"` (sent by the worker via `getDuelFriends(today, "true")`) means *bypass the stale-while-revalidate short-circuit and revalidate now*.

---

## 8. State management & DI

Riverpod v2 (codegen) for UI state; `get_it`+`injectable` for repos/services. Each Kotlin Flow/suspend maps to an async provider.

```dart
// --- DI singletons (get_it / injectable) ---
// StatsApi (dio+retrofit)          <- BrainRotStatsApiService
// InviteApi (dio+retrofit)         <- com...feature_invite...InviteApi
// AppDatabase (drift)              <- Room (daily_reels_app_split etc.)
// DeviceIdentity                   <- android_device_id provider (secure_storage cached)
// FriendsRepository                <- ig.f (warm duel cache + pin rewrite)
// SplitRepository                  <- ig.s (scroll push + other-device merge)
// SyncUseCase                      <- qh.d (oh.d.b -> ig.f.c -> qh.b.a)

// --- providers (riverpod_generator) ---
@riverpod
Future<List<DuelLeaderboardRow>> duelLeaderboard(Ref ref, String statsDate) async {
  // 1) local FriendStats for date (drift watch) ; 2) trigger getDuelFriends (SWR) ; 3) rank (§3.2)
}

@riverpod
Future<List<FriendInfo>> friendsList(Ref ref) async => ref.read(inviteApiProvider).getFriends();

@riverpod
class PinnedFriend extends _$PinnedFriend {        // reads BlockReelsState.pinnedFriendBrUserId
  @override String? build() => ref.watch(blockConfigProvider).value?.pinnedFriendBrUserId;
  Future<void> pin(String id)   { /* config/update */ }
  Future<void> unpin(String id) { /* ig.f.b parity: clear if matches */ }
}

@riverpod
Stream<List<DailyReelsAppSplit>> mySplits(Ref ref, String date) =>
    ref.watch(appDatabaseProvider).watchSplitsForDate(date);   // drift stream

@riverpod
class FriendsSync extends _$FriendsSync {           // qh.d.a() equivalent
  @override FutureOr<void> build() {}
  Future<bool> run() async {
    if (await ref.read(friendsRepoProvider).friendCount() == 0) return false; // oh.d.b
    await ref.read(friendsRepoProvider).warmDuelCache();                       // ig.f.c
    await ref.read(widgetSyncProvider).refreshFriends();                       // qh.b.a
    return true;
  }
}
```

| Kotlin source | Dart target |
|---|---|
| `qh.d.a()` (3-step suspend chain) | `FriendsSync.run()` |
| `oh.d.b()` (friend-count > 0) | `friendsRepoProvider.friendCount()` |
| `ig.f.c()` (`getDuelFriends(today,"true")`) | `friendsRepoProvider.warmDuelCache()` |
| `ig.f.b(id)` (pin clear) | `PinnedFriend.unpin(id)` |
| `ig.f.f12791e` (StateFlow<Long> refresh tick) | a `Stream`/`StateNotifier<int>` ticking `now` to invalidate leaderboard provider |
| `ig.s.a()` (scroll push + merge) | `SplitRepository.pushScrollUpdate()` |
| `FriendsUpdateWorker` | `workmanager` callback → `FriendsSync.run()` |
| `wc.h0.a()` (enqueue one-time worker) | `Workmanager().registerOneOffTask('friendsUpdateOneTime', initialDelay:30m, backoff:5m, constraints:connected, existingWorkPolicy:keep)` |

---

## 9. User flows

> `[native]` = retained Kotlin detection core; `[dart]` = Flutter; `[channel]` = platform channel; `[net]` = REST.

### 9.1 Open Battle / leaderboard
1. `[dart]` User opens Battle tab; `duelLeaderboard(today)` provider builds.
2. `[dart]` Emit cached `FriendStats` rows from drift immediately.
3. `[net]` `GET /stats/api/v1/duel/friends?stats_date=today` (SWR 10 s).
4. `[dart]` Upsert response into `FriendStats`; re-rank (§3.2: fewest reels = rank 1; uninstalled to bottom; pinned highlighted).
5. `[dart]` Render rows: avatar (`display_photo_url`), name (`ProfileInfo.firstName`), reels (`count`), rank, pin badge, "Uninstalled" if `is_uninstalled`.

### 9.2 View a friend's per-app split (H2H detail)
1. `[dart]` Tap a friend row.
2. `[dart]` Show that friend's per-app split for the date. **Note:** the live build has no friend-level split endpoint wired (`getDuelCount` is dormant, OQ-1); own-device splits come from `daily_reels_app_split`. Friend splits depend on backend (OQ-1).

### 9.3 Push my reels (scroll update)
1. `[native]`→`[channel]` Detection core emits reel events on `brainpal/detection`.
2. `[dart]` Increment `daily_reels_app_split(reelCount, viewDurationMs)` for `(deviceId, today, appId)`.
3. `[net]` On schedule/foreground: `POST /stats/api/v1/user/scroll/update` with `ScrollUpdateRequest{android_device_id, stats_date, splits=[AppSplitItem...]}`.
4. `[dart]` On 2xx: set `lastSyncedReelCount = reelCount`; merge `other_device_splits` (keyed by date) into `daily_reels_app_split` (other device rows).

### 9.4 Background friends refresh (worker)
1. `[dart]` `workmanager` fires `friendsUpdateOneTime` (≥30 min after enqueue, NetworkType.connected).
2. `[dart]` `FriendsSync.run()` → if friend count 0, success (no-op); else warm `getDuelFriends(today, X-Skip-SWR=true)` + refresh widget friend data.
3. `[dart]` Success → callback re-enqueues worker (self-chain) + refreshes UI; failure → `Result.retry()` (5-min backoff).

### 9.5 Pin / unpin a friend
1. `[dart]` Long-press → Pin.
2. `[net]` Read current `BlockReelsState`; set `pinned_friend_br_user_id = friendId`; `POST /stats/api/v1/user/config/update?android_device_id=…` (body `BlockReelsState`).
3. `[dart]` Persist returned config; `PinnedFriend` provider re-emits; pinned row highlighted.
4. `[dart]` **Unpin / remove pinned friend** (`ig.f.b` parity): if removed friend == pinned, clear pin in config and re-`config/update`.

### 9.6 Add / accept / remove friend
1. `[dart]` Create invite link `POST /invite/create_link` → share (`share_plus`) / deep-link (`app_links`+`go_router`).
2. `[dart]` Invitee accepts `POST /invite/accept?invited_by_br_user_id=…`.
3. `[net]` `GET /invite/friends` refreshes roster; new friend may carry `shouldShowInviteAccepted=true` → show `"%1$s joined the battle"` celebration once, then clear flag.
4. `[dart]` Remove: `POST /invite/remove_friend?friend_br_user_id=…`; if was pinned → clear pin (9.5.4).

### 9.7 Battle notifications (daily)
1. `[net/push]` FCM delivers H2H/rank result.
2. `[dart]` `flutter_local_notifications` channel **"Leaderboard"** (`notification_channel_battle_result`, desc "Daily leaderboard updates"). Bodies verbatim: win H2H "Fewer reels than them. Keep it up.", lose H2H "%1$s beat you yesterday", win rank "Fewest reels of everyone. Keep the crown.", lose rank "You came %1$s of %2$d yesterday".

### 9.8 Restore after reinstall
1. `[net]` `GET /stats/api/v1/user/restore` → `UserRestoreResponse{config, splits_history}`.
2. `[dart]` Bulk-upsert `splits_history` (`RestoreSplitItem`) into `daily_reels_app_split` (set `lastSyncedReelCount = reelCount`); apply `config` to block state.

---

## 10. Parity risks & validation

| # | Risk | Validation / harness |
|---|---|---|
| R1 | **Leaderboard sort wrong** (asc vs desc). Fewest reels MUST win. | Golden test: feed fixture `List<DuelCountResponse>` w/ known counts/rotScore/uninstalled/pinned; assert rank order == fixture-expected (§3.2). Cross-check vs server `rot_score` ordering. |
| R2 | **Split delta double-count / loss** if `lastSyncedReelCount` not advanced on exactly-2xx. | Property test: simulate N reel increments + flaky push (timeout, 500, 2xx); assert server-side cumulative == local `reelCount`, no resend after 2xx, full resend after failure. |
| R3 | **other_device map key misuse** — key is `stats_date`, NOT device id. | Unit test parsing `ScrollUpdateResponse` fixture w/ 2 dates × 2 devices; assert each `DailyReelsAppSplit.statsDate == map key` and `androidDeviceId == item.androidDeviceId`. |
| R4 | **Date drift** — `stats_date` must be `yyyy-MM-dd` Locale.US, stable across timezone/DST. | Test `DateFormat('yyyy-MM-dd', 'en_US')` at TZ boundaries; pin device clock to `2026-06-30T23:59` various zones; compare to `qb.a.Y` output. |
| R5 | **SWR semantics** — TTLs (30/10/86400 s) + `X-Skip-SWR` force-revalidate not honored → stale leaderboard or excess traffic. | Integration test against mock server: assert revalidation timing matches TTL and that worker call bypasses stale window. |
| R6 | **Friend status enum** mismatch (`PERMISSION_MISSING` often forgotten). | Round-trip all 5 strings `PENDING/ACCEPTED/BLOCKED/UNINSTALLED/PERMISSION_MISSING` enum↔wire; assert no `unknown`. |
| R7 | **Pin clear on remove** not mirrored (`ig.f.b`). | Test: pin friend X, remove X, assert `pinned_friend_br_user_id` cleared + `config/update` called. |
| R8 | **Worker cadence** — Flutter `workmanager` one-off self-chain must mirror 30-min delay/KEEP/5-min backoff/connected. | Verify registration params; on iOS document best-effort (R8-iOS). |
| R9 | **Dormant `/sync` revived accidentally** — porting `SyncRequest`/`SyncResponse` as live would double-write. | Lint/grep gate: no production code path calls a `/sync` endpoint; the freezed models exist for reference only. |
| R10 | **Device identity instability** (new `android_device_id` per reinstall fragments splits). | Persist id in `flutter_secure_storage`; test reinstall preserves id; iOS Keychain-backed `identifierForVendor` fallback. |

---

## 11. Open questions

- **OQ-1 (H2H / friend split endpoint live?)**: `getDuelCount` (`/stats/api/v1/duel/count`) and `getFriendsHistory` (`/stats/api/v1/duel/friends_history`) have **no caller** in the decompiled APK (only `getDuelFriends` is invoked, from `ig.f.c`). Are H2H + history live features in v7.1.340, or stripped/feature-flagged? Determines whether §9.2 friend-split detail is buildable. → confirm with backend + product.
- **OQ-2 (Couchbase replication vs REST)**: `register_sync_user` → `SyncUserResponse{username,password,sync_url}` are Couchbase Lite (`C4Replicator`) sync-gateway credentials, and `oh.d.a()` counts local Couchbase friend docs (`z5.m0`). Is friend-stats truth replicated via Couchbase, with REST `getDuelFriends` only a read cache? Or is Couchbase legacy/dead? Recommendation: **REST-only in Flutter** — needs confirmation that all friend data is reachable via `getDuelFriends` + `/invite/friends` (no Couchbase-only fields).
- **OQ-3 (target app package list)**: pull the canonical, verbatim package→display_name map from [module-04](module-01-reels-detection-core.md) rather than duplicating here.
- **OQ-4 (pinned & tiebreak UI rules)**: the duel Compose UI is obfuscated/stripped (only `DayStats.java` survives in `feature_duel`). Confirm: is pinned friend pinned-to-top or highlighted-in-place? Exact tiebreak when reel counts tie (rot_score? friend_since? name?).
- **OQ-5 (rot_score formula)**: server-side; not in APK. Capture in [02-backend-api-contract.md](02-backend-api-contract.md).
- **OQ-6 (`SyncRequest.config` direction)**: the dormant `/sync` pushes `config: BlockReelsState` and returns `config_delta`. If revived, who wins on conflict (client vs server `updated_at`)? Aligns with module-03 config lifecycle.
- **OQ-7 (iOS appId key)**: on iOS the per-app `appId` cannot be a package name (FamilyControls tokens are opaque/privacy-shielded). Define the stable `appId` aliasing scheme so leaderboard splits remain comparable cross-platform.

---

## 12. Migration checklist

**Phase A — data layer (pure Dart)**
- [ ] Generate freezed/json DTOs for all network models in §4 with verbatim `@JsonKey` names.
- [ ] Define `FriendStatus` enum + wire mapper (5 values incl. `permissionMissing`).
- [ ] Create drift tables `daily_reels_app_split` (PK device+date+app, `lastSyncedReelCount` default 0), `friend_stats`, `friends_list`.
- [ ] Implement `DateFormat('yyyy-MM-dd','en_US')` date helper + week-range label (parity `qb.a.Y`/`Z`).
- [ ] Device identity provider (`android_device_id` / iOS `identifierForVendor`) cached in `flutter_secure_storage`.

**Phase B — network + cache**
- [ ] Wire `dio`+`retrofit` `StatsApi` (`getDuelFriends`, `updateScrollStats`, `getReelsConfig`, `updateReelsConfig`, `restoreUserData`; include dormant `getDuelCount`/`getFriendsHistory`/`registerSyncUser` behind flags).
- [ ] Wire `InviteApi` (`/invite/friends|accept|create_link|remove_friend|get_invite_details`).
- [ ] Configure `dio_cache_interceptor` per §7.2 TTLs + honor `X-Skip-SWR`.

**Phase C — repositories + sync**
- [ ] `SplitRepository.pushScrollUpdate()` (parity `ig.s.a`): build `AppSplitItem` list, POST, merge `other_device_splits` by date key, advance `lastSyncedReelCount` on 2xx.
- [ ] `FriendsRepository.warmDuelCache()` (parity `ig.f.c`) + `friendCount()` (parity `oh.d.b`) + `unpinIfMatches()` (parity `ig.f.b`).
- [ ] `FriendsSync.run()` (parity `qh.d.a` 3-step chain).
- [ ] Register `workmanager` one-off `friendsUpdateOneTime` (30-min delay, 5-min backoff, connected, KEEP) on launch + on success self-chain; iOS → BGAppRefresh best-effort.

**Phase D — presentation (Riverpod)**
- [ ] `duelLeaderboard(date)` provider with §3.2 ranking + golden test (R1).
- [ ] `friendsList`, `mySplits(date)`, `PinnedFriend` providers.
- [ ] Battle screens: leaderboard (Rank/Player/Reels), friend actions (delete w/ confirm), invite CTAs, "joined the battle" celebration, weekly Battle stats chart (`DayStats`).
- [ ] Battle notifications: `flutter_local_notifications` channel "Leaderboard" + FCM handler (H2H/rank bodies verbatim).

**Phase E — restore + hardening**
- [ ] Restore flow `GET /user/restore` → bulk upsert `splits_history`.
- [ ] Implement validation harness R1–R10.
- [ ] Lint gate: no live caller of `/sync` (R9).
- [ ] Resolve OQ-1, OQ-2 with backend before shipping friend-split detail + dropping Couchbase.
