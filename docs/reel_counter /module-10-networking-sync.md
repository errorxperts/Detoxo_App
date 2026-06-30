# Module: Networking & Sync Engine

## 1. Purpose & scope
The Dart‑side HTTP client, interceptors, and the **sync orchestration** that pushes/pulls blocking config, scroll stats, and duel data. **Owns:** the `dio`/`retrofit` client, auth + SWR‑cache interceptors, delta‑sync merge logic, and the offline retry queue. **Does NOT own:** the endpoint catalog and DTO field definitions (those live once in [02-backend-api-contract.md](02-backend-api-contract.md) — this doc references them), local schema (see [module-09-core-data-storage.md](module-09-core-data-storage.md)), or worker scheduling (see [module-11-workers-background.md](module-11-workers-background.md)).

## 2. Migration verdict
**PURE‑DART** (with a possible **DART+CHANNEL** fork for Couchbase). Retrofit/OkHttp → `dio` + `retrofit` codegen is a direct port. The only platform decision is the **Couchbase‑vs‑REST** fork (see §7 of [02-backend-api-contract.md](02-backend-api-contract.md)); if Couchbase Lite is kept it becomes a native module behind a channel. Recommended default: REST‑only, fully Dart.

## 3. Business logic & algorithms (load‑bearing)

### 3.1 Client stack
- Base URL `https://api.brainpalapp.ai` (`kc/x.java:80`).
- Interceptor chain (mirror OkHttp `f.b` + `yc.b`):
  1. **Auth interceptor** — injects `br_user_id` (from `AuthLibrary.getBrUserId()`); adds `android_device_id` where required.
  2. **SWR cache interceptor** — disk cache keyed by **MD5(request URL)**; honors `X-Cache-TTL` (10/30/86400s), `X-Cache-Type` (`swr`/`standard`), and `X-Skip-SWR` (force fresh). See §5 of the API contract.
  3. **Logging** (`pretty_dio_logger`) — **must redact** `register_sync_user` creds.

### 3.2 Delta‑sync algorithm
```
sync():
  req = SyncRequest(
    since_friends_stats = prefs.lastSync.friendsStats,
    since_my_splits     = prefs.lastSync.mySplits,
    since_friends_list  = prefs.lastSync.friendsList,
    since_config        = prefs.lastSync.config )
  resp = pull(req)                       // server returns only rows updated after each watermark
  for delta in resp:                     // FriendStatsDelta / MySplitDelta / FriendListDelta / config
      if delta.updated_at > local.updated_at: upsert(delta)   // SERVER WINS
      advance watermark = max(watermark, delta.updated_at)
  push():
    POST scroll/update (daily aggregates, batched per day)   // never partial-day
    POST config/update?device_id (if local config changed since lastSyncedUpdatedAt)
  use resp.server_time_ms for day-boundary math (not device clock)
```

### 3.3 Scroll‑update batching
- Aggregate `daily_reels_app_split` rows for the day into `ScrollUpdateRequest.splits: [AppSplitItem]`.
- Submit one batch per `stats_date`; do not submit partial‑day data mid‑day except on date rollover.
- Response `other_device_splits` is **display‑only** ("syncing across devices"); never auto‑merge.

### 3.4 Which workers drive which calls
| Worker | Endpoint(s) |
|---|---|
| `SaveFCMTokenWorker` | `POST /auth/save_fcm_token` |
| `BlockConfigSyncWorker` | `GET /user/config`, `POST /user/config/update` |
| `ReelsSyncWorker` | `POST /user/scroll/update`, restore |
| `FriendsUpdateWorker` | `GET /invite/friends`, duel endpoints |
| (restore on reinstall) | `GET /user/restore` |

## 4. Data models
All request/response DTOs are defined once in [02-backend-api-contract.md](02-backend-api-contract.md) §4. Dart targets use `freezed` + `json_serializable`. Local mirror entity = `UserBlockingConfig` ↔ remote `BlockReelsState` (see [module-09](module-09-core-data-storage.md)). Sync watermarks live in `shared_preferences`: `last_sync_config_ms`, `last_sync_my_splits_ms`, `last_sync_friends_stats_ms`, `last_sync_friends_list_ms`.

## 5. Android deps → Flutter map
| Android API | Verdict | Flutter | Notes |
|---|---|---|---|
| Retrofit2 + OkHttp3 + Gson | PKG | `dio` + `retrofit` + `json_serializable` | codegen interfaces mirror `BrainRotStatsApiService` |
| Auth interceptor `f.b` | PKG | custom `dio` `Interceptor` | inject `br_user_id` |
| SWR cache `yc.b` (MD5 disk cache) | PKG | `dio_cache_interceptor` (+ custom header handling) or hand‑rolled | honor `X-Cache-*`, `X-Skip-SWR` |
| TLS LE‑root pinning | PKG | `dio` `SecurityContext` | only if matching `@raw/lets_encrypt_roots` |
| Couchbase Lite (optional) | CHANNEL / KEEP‑NATIVE | `cbl_dart`/`cbl_flutter` or native channel | **only if sync_url is actually used** |
| `android_device_id` | PKG | `device_info_plus` | must be stable across restarts |

## 6. iOS strategy
HTTP layer is fully cross‑platform (`dio`). `device_info_plus` provides `identifierForVendor` on iOS — note it **resets on app uninstall**, unlike Android ID; persist a generated UUID in Keychain (`flutter_secure_storage`) as the stable device id so `br_user_id` survives reinstall. If Couchbase Lite is kept, it has an iOS SDK but still warrants a native module. REST delta‑sync works identically.

## 7. Platform‑channel surface
**None** unless the Couchbase fork is chosen → then a `brainpal/sync` method channel over the native Couchbase Lite replicator (start/stop/status). See [01-platform-channel-contracts.md](01-platform-channel-contracts.md) and [99-native-retained-modules.md](99-native-retained-modules.md).

## 8. State management & DI
- `get_it`: `Dio`, `BrainRotStatsApi`, `BrainRotApi`, `InviteApi`, `AccountApi`, `FeedbackUploadApi`, `SyncEngine`, `SecureCredStore`.
- Riverpod: `syncStateProvider` (idle/syncing/error), `duelFriendsProvider` (`FutureProvider.family` keyed by `stats_date`), `configSyncProvider`. `ref.invalidate` after a worker completes a sync to refresh dependent UI (mirrors the `h0.a()` callback pattern).

## 9. User flows
1. **App start** `[dart]`: ensure `br_user_id` (register if absent) → kick `BlockConfigSyncWorker` immediate + `ReelsSyncWorker` immediate.
2. **Reel persisted** `[dart]`: event stored locally; not pushed immediately — batched by `ReelsSyncWorker`.
3. **Pull‑to‑refresh duel** `[dart]`: `GET /duel/friends` with `X-Skip-SWR` to bypass the 10s cache.
4. **Config edit (e.g. set allowance)** `[dart]`: write local `user_blocking_config` (bump `updatedAt`) → `POST /config/update` → on success set `lastSyncedUpdatedAt`.
5. **Reinstall restore** `[dart]`: `GET /user/restore` → repopulate config + splits history.

## 10. Parity risks & validation
- **Delta correctness & clock skew:** two‑device + reinstall contract tests against staging; assert no double‑count, no lost splits; use `server_time_ms` for boundaries.
- **SWR semantics:** test that `X-Skip-SWR` forces network and TTLs (10/30/86400) behave; MD5 key collisions impossible but verify key derivation matches.
- **Offline queue:** kill network mid‑push; assert retry with backoff and no data loss/duplication.
- **Server‑wins merge:** craft conflicting local/remote `updated_at`; assert remote wins.
- **Credential redaction:** assert logs never contain `password`/`sync_url`.

## 11. Open questions
- `ConfigUpdateResponse.status` valid values; retry policy on failure.
- Is there an explicit `br_user_id` register/validate beyond `register_sync_user`?
- Couchbase actually exercised? (fork decision)
- `AppSplitRequest.date` always `yyyy-MM-dd`?
- `FileDownloadApi` range/resume support?

## 12. Migration checklist (Phase 2)
- [ ] Generate `dio`+`retrofit` API interfaces for stats/invite/account/feedback/file APIs.
- [ ] Implement auth interceptor (`br_user_id`) + SWR cache interceptor (`X-Cache-*`, `X-Skip-SWR`, MD5 key).
- [ ] Implement `SyncEngine` (delta pull/push, watermarks, server‑wins, offline queue).
- [ ] Wire sync triggers to the workmanager workers (see [module-11](module-11-workers-background.md)).
- [ ] Stable device id (Keychain‑backed UUID) + secure cred store.
- [ ] Resolve Couchbase‑vs‑REST fork (Phase 0) and implement accordingly.
- [ ] Contract tests vs staging (two‑device, reinstall, offline).
