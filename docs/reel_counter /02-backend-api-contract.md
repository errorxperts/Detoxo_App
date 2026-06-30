# 02 · Backend API Contract

> Canonical reference for every BrainPal backend endpoint, DTO, header and the delta‑sync protocol. Module docs link here instead of duplicating endpoint detail. Cross‑refs: [module-10-networking-sync.md](module-10-networking-sync.md), [module-05-duel-friends-stats.md](module-05-duel-friends-stats.md), [module-07-invite-referral.md](module-07-invite-referral.md), [module-08-account-feedback.md](module-08-account-feedback.md).

## 1. Hosts, transport & security

| Item | Value | Source |
|---|---|---|
| API base URL | `https://api.brainpalapp.ai` | `sources/kc/x.java:80` (AuthConfig) |
| Web / legal / referral hosts | `brainpalapp.ai`, `brainrotapp.ai`, `join.brainpalapp.ai`, `join.brainrotapp.ai` | AndroidManifest, `network_security_config.xml` |
| Cleartext | **Disabled** (`cleartextTrafficPermitted="false"`) | `res/xml/network_security_config.xml` |
| TLS trust anchors | `system` + `@raw/lets_encrypt_roots` + `user` for the two app domains | same |
| HTTP stack | Retrofit2 + OkHttp3 + Gson (`@SerializedName`) | `core/data/remote/*`, `network/*` |

**Flutter target:** `dio` + `retrofit` (codegen) + `json_serializable`. Pin Let's Encrypt roots via a custom `SecurityContext` / `badCertificateCallback` only if you must match the `@raw/lets_encrypt_roots` anchor (most devices already trust LE). See [module-10-networking-sync.md](module-10-networking-sync.md) for the client/interceptor design.

## 2. Authentication model

- **No Firebase/OAuth sign‑in.** Identity is **device‑scoped**: a `br_user_id` is assigned by the backend on first `POST /stats/register_sync_user` and persisted locally in `user_blocking_config.br_user_id`.
- An `android_device_id` (stable per device) is sent in request bodies/queries.
- An OkHttp interceptor (`f.b`) injects the credential from `AuthLibrary.getBrUserId()` (package `ai.regainapp.auth`). Replicate as a `dio` interceptor that adds the same header/param.
- `register_sync_user` returns `username` / `password` / `sync_url` (Couchbase) — **store with `flutter_secure_storage`, never log.**

> **OPEN QUESTION:** exact header name/placement for `br_user_id` (header vs query vs body) and whether `delete_user_data` is truly parameterless (backend likely derives identity from the auth interceptor/device id).

## 3. Endpoint catalog

Base = `https://api.brainpalapp.ai`. Cache column: SWR = stale‑while‑revalidate disk cache (see §5).

### 3.1 Auth / token
| Method | Path | Params | Response | Purpose | Cache |
|---|---|---|---|---|---|
| POST | `/auth/save_fcm_token` | `?fcm_token={t}&firebase_app_instance_id={id}` | `ResponseBody` (200) | Save FCM token after refresh | none |

### 3.2 User config & stats (`BrainRotStatsApiService`)
| Method | Path | Params / Body | Response | Purpose | Cache |
|---|---|---|---|---|---|
| POST | `/stats/register_sync_user` | (auth only) | `SyncUserResponse{username,password,sync_url}` | Register device, get Couchbase creds + `br_user_id` | none |
| GET | `/stats/api/v1/user/restore` | (auth) | `UserRestoreResponse{config: BlockReelsState, splitsHistory: List<RestoreSplitItem>}` | Restore config + history on reinstall | none |
| GET | `/stats/api/v1/user/config` | (auth) | `BlockReelsState` | Pull remote blocking config | SWR? |
| POST | `/stats/api/v1/user/config/update` | `?device_id={id}` + body `BlockReelsState` | `ConfigUpdateResponse{status, updated_at}` | Push local config change | none |
| POST | `/stats/api/v1/user/scroll/update` | body `ScrollUpdateRequest` | `ScrollUpdateResponse{status, server_time_ms, other_device_splits}` | Push daily per‑app scroll splits | none |

### 3.3 Duel / leaderboard
| Method | Path | Params | Response | Cache |
|---|---|---|---|---|
| GET | `/stats/api/v1/duel/count` | `?friend_br_user_id={id}&stats_date={yyyy-MM-dd}` | `DuelCountResponse` | — |
| GET | `/stats/api/v1/duel/friends` | `?stats_date={date}` + header `X-Skip-SWR` | `List<DuelCountResponse>` | **SWR, TTL 10s** |
| GET | `/stats/api/v1/duel/friends_history` | `?stats_date={date}` | `List<DuelCountResponse>` | **standard, TTL 86400s** |

### 3.4 Invite / friends (`InviteApi`)
| Method | Path | Params | Response | Cache |
|---|---|---|---|---|
| POST | `/invite/create_link` | (auth) | `CreateInviteLinkResponse{shortLink, brUserId}` | — |
| POST | `/invite/accept` | `?invited_by_br_user_id={id}` | `AcceptInviteResponse{message}` | — |
| GET | `/invite/friends` | header `skip_swr` | `GetFriendsResponse{friends: List<FriendInfo>}` | **SWR, TTL 30s** |
| POST | `/invite/remove_friend` | `?friend_br_user_id={id}` | `RemoveFriendResponse{message}` | — |
| GET | `/invite/get_invite_details` | `?invited_by_br_user_id={id}` | `InviteDetailsResponse{displayName, displayPhotoUrl}` | — |

### 3.5 Account / feedback (`AccountApi`, `FeedbackUploadApi`)
| Method | Path | Params | Response | Notes |
|---|---|---|---|---|
| POST | `/invite/delete_user_data` | (none visible) | `DeleteUserDataResponse{message}` | GDPR wipe; **one‑way** |
| GET | `/invite/get_vote_summary` | `?br_user_id={id}` | `VoteSummaryResponse` | per‑app vote tallies |
| POST | `/send_feedback/logs` | `?user_id&feedback_id` + multipart `file` Part | callback | `@Multipart`; screenshot/log upload |

### 3.6 File download (`FileDownloadApi`)
| Method | Path | Notes |
|---|---|---|
| GET (`@Streaming`) | `@Url` (arbitrary) | streaming download to app files dir; used by `FileDownloadWorker` |

## 4. DTOs (field → type → JSON key)

> JSON keys below are snake_case as observed in payloads; confirm exact `@SerializedName` per class when porting. Dart targets use `freezed` + `json_serializable`.

### 4.1 `BlockReelsState` (remote mirror of `UserBlockingConfig`)
```
br_user_id              String
is_block_enabled        bool
cooldown_time_in_millis long
hard_block_valid_till   long?     (epoch ms; null = no hard block)
reels_allowed_count     int
reels_allowed_valid_for_millis long
block_pause_expiry_time long?     (epoch ms; null = not paused)
block_start_timestamp   long?
block_start_reel_count  int?
pinned_friend_br_user_id String?
updated_at              long      (server authoritative)
```
See the full local schema + enforcement algorithm in [module-09-core-data-storage.md](module-09-core-data-storage.md).

### 4.2 Scroll sync
```
ScrollUpdateRequest {
  android_device_id String
  stats_date        String   // "yyyy-MM-dd"
  splits            List<AppSplitItem>
}
AppSplitItem {
  app_package      String     // e.g. com.instagram.android
  display_name     String     // e.g. "Instagram"
  reel_count       int
  view_duration_ms long
}
ScrollUpdateResponse {
  status            String
  server_time_ms    long       // USE THIS for day-boundary math, not device clock
  other_device_splits  Map<String /*android_device_id*/, List<OtherDeviceSplitItem>>
}
OtherDeviceSplitItem { android_device_id, app_package, display_name, reel_count, view_duration_ms, updated_at }
RestoreSplitItem     { android_device_id, stats_date, app_package, display_name, reel_count, view_duration_ms }
ConfigUpdateResponse { status:String, updated_at:long }
SyncUserResponse     { username:String, password:String, sync_url:String }
UserRestoreResponse  { config: BlockReelsState, splitsHistory: List<RestoreSplitItem> }
```

### 4.3 Duel / friends
```
DuelCountResponse { br_user_id, count:int, rot_score:int, is_pinned:bool, stats_date:String, is_uninstalled:bool }
FriendInfo        { br_user_id, display_name, display_photo_url, is_uninstalled:bool=false, friend_since_ms:long? }
GetFriendsResponse{ friends: List<FriendInfo> }
CreateInviteLinkResponse { short_link:String, br_user_id:String }
AcceptInviteResponse     { message:String }
RemoveFriendResponse     { message:String }
InviteDetailsResponse    { display_name:String, display_photo_url:String }
DeleteUserDataResponse   { message:String }
VoteSummaryResponse      { total_votes:int, correct_votes:int,
                           instagram_votes, tiktok_votes, youtube_votes, snapchat_votes, facebook_votes:int }
```

## 5. SWR disk cache protocol

Implemented by OkHttp interceptor `yc.b`; replicate with a custom `dio` interceptor (or `dio_cache_interceptor`).

- Request/response carry headers: `X-Cache: true`, `X-Cache-TTL: {10|30|86400}` (seconds), `X-Cache-Type: {swr|standard}`.
- Cache key = **MD5 of the request URL**; entries stored on disk in the app cache dir.
- `X-Skip-SWR` request header **forces a fresh network fetch** (used by pull‑to‑refresh on the duel screen).
- `swr` type: serve cached immediately, revalidate in background. `standard` type: serve cached until TTL expiry, then network.

## 6. Delta‑sync protocol

The client keeps `since*` watermarks and the server returns only rows changed after them; **server timestamp wins** on conflict.

```
SyncRequest {
  since_friends_stats : long   // ms
  since_my_splits     : long
  since_friends_list  : long
  since_config        : long
}
```
- **Pull:** server returns deltas (`FriendStatsDelta`, `MySplitDelta`, `FriendListDelta`, config) each carrying `updated_at`; client advances its `since*`/`lastSynced*` watermarks.
- **Push:** `scroll/update` (daily aggregates, batched per day — never partial‑day) and `config/update` (with `device_id`).
- **Multi‑device:** `other_device_splits` is **informational only** (drive a "syncing across devices" UI state); do **not** auto‑merge into local stats without confirmation.
- **Boundaries:** use `server_time_ms` from `ScrollUpdateResponse` for day rollovers to avoid client clock skew.
- **Offline queue:** failed `scroll/update`/`config/update` should be queued and retried by the sync workers (see [module-11-workers-background.md](module-11-workers-background.md)); `updateScrollStats` must not silently discard.

## 7. Couchbase vs REST — architectural fork (OPEN QUESTION)

`register_sync_user` hands back Couchbase Sync Gateway creds (`username`/`password`/`sync_url`), implying **optional Couchbase Lite bidirectional replication** for cross‑device stats. But the REST `scroll/update` + `restore` + delta endpoints can fully cover sync on their own.

**Decision needed in Phase 0** (changes the storage/sync architecture):
- **If Couchbase is live:** keep it as a **native module** behind a channel (`cbl_dart`/`cbl_flutter` are heavy) — see [99-native-retained-modules.md](99-native-retained-modules.md).
- **If REST is the real path:** ignore `sync_url`, drive everything through the REST delta endpoints above (recommended default unless proven otherwise).

*Validation:* instrument the running APK / proxy traffic to see whether the `sync_url` Couchbase endpoint is ever contacted after `register_sync_user`.

## 8. Open questions
- Exact `@SerializedName` casing per field (snake vs kebab) — confirm against each `network/*` class.
- `ConfigUpdateResponse.status` valid values (`success`/`error`?).
- Is `pinned_friend_br_user_id` single‑valued or a list (multi‑friend duels)?
- `delete_user_data` authorization model (parameterless?).
- `get_vote_summary`: are tallies *my* votes about friends or friends' votes about *me*?
- Timezone of `block_start_timestamp` / `hard_block_valid_till` (UTC vs device).
- `stats_date` format confirmation (`yyyy-MM-dd` assumed).
