# Module: Account & Feedback

## 1. Purpose & scope
User identity (device‑scoped), GDPR data deletion, feature‑request vote summary, and the feedback flow (categorized form + screenshot/log upload via a background worker). **Owns:** account settings screen, delete‑data flow, vote summary display, feedback form + upload. **Does NOT own:** the sync‑credential mechanics (see [module-10-networking-sync.md](module-10-networking-sync.md)) or the worker scheduling internals (see [module-11-workers-background.md](module-11-workers-background.md)).

## 2. Migration verdict
**PURE‑DART.** Identity is device‑scoped (no auth UI to rebuild); deletion, voting, and feedback are conventional HTTP + multipart + local cleanup. Feedback upload retry runs as a `workmanager` task. Identical on Android + iOS (with iOS device‑id caveat, see §6).

## 3. Business logic & algorithms (load‑bearing)

### 3.1 Identity model
- **No Firebase/OAuth.** `br_user_id` = server‑assigned via `POST /stats/register_sync_user`, persisted in `user_blocking_config.br_user_id`, correlated to a stable `android_device_id`. All API calls are device‑scoped.

### 3.2 Delete user data (GDPR, one‑way)
```
deleteAccount():
  confirm("Delete all data? This permanently deletes server data and clears the app")
  POST /invite/delete_user_data         // DeleteUserDataResponse{message}; no params visible
  on success: wipe local drift DBs + prefs + secure store
```
> **OPEN QUESTION:** the endpoint appears parameterless — backend likely derives identity from the auth interceptor / device id. Confirm before shipping.

### 3.3 Vote summary
```
GET /invite/get_vote_summary?br_user_id=<id>   // VoteSummaryResponse
display: "<friends_guessed> friends guessed (<correct> correct)"
```
Tracks `total_votes`, `correct_votes`, and per‑app counts (`instagram_votes`, `tiktok_votes`, `youtube_votes`, `snapchat_votes`, `facebook_votes`). Read‑only/backend‑aggregated.

### 3.4 Feedback flow
- Categories (verbatim from strings): *App crashing · Permission Issue · Block/Feature not working · Subscription Issue · Report an issue · Share an idea · Other · Appreciate the team · Leave us a review*.
- Text input limit **2000 chars** (`"%1$d/2000 characters"`); consent checkbox *"Share screenshot to help us debug the issue"* / *"Share logs…"*.
- Upload: `FeedbackUploadApi.uploadLogFile(@Query user_id, @Query feedback_id, @Part file)` → `@Multipart POST /send_feedback/logs`.
- `FeedbackUploadWorker` screenshot poll: **up to 20 iterations × 500ms = 10s** waiting for the screenshot file to exist; logs "Screenshot detected for upload: <name>" if found, else warns and returns **success anyway** (never fails the worker).
- Uninstall feedback: separate prompt *"Can you please share why you're uninstalling?"* with *Submit & Uninstall* / *Uninstall*.

## 4. Data models
- Reuses `user_blocking_config` (`br_user_id`) and prefs from [module-09](module-09-core-data-storage.md).
- DTOs: `DeleteUserDataResponse{message}`, `VoteSummaryResponse{…}` ([02-api](02-backend-api-contract.md) §4.3).
- Dart: `Feedback { category, text(≤2000), shareScreenshot:bool, feedbackId }`, `VoteSummary { totalVotes, correctVotes, perApp:Map<String,int> }`.

## 5. Android deps → Flutter map
| Android API | Verdict | Flutter | Notes |
|---|---|---|---|
| Device id (`ANDROID_ID`/serial) | PKG | `device_info_plus` (+ Keychain UUID on iOS) | stable across reinstall |
| Retrofit multipart upload | PKG | `dio` `MultipartFile` / `http.MultipartRequest` | match field names (`user_id`,`feedback_id`,`file`) |
| `FeedbackUploadWorker` (poll+upload) | PKG | `workmanager` + `retry` | replace 20×500ms loop with async delay |
| Screenshot file in app dir | PKG | `path_provider` | staging location (OPEN QUESTION) |
| Account settings UI (Compose) | PURE‑DART | Flutter widgets | |
| Couchbase creds (from register) | PKG | `flutter_secure_storage` | never log |

## 6. iOS strategy
Logic identical. **Device‑id caveat:** iOS `identifierForVendor` resets on uninstall of all vendor apps — to keep `br_user_id` stable across reinstall, persist a generated UUID in **Keychain** (`flutter_secure_storage`, which survives reinstall) and use it as the device id (see [module-10](module-10-networking-sync.md) §6). Multipart upload, deletion, voting, and feedback all work cross‑platform. Screenshot capture for debug feedback is more constrained on iOS (no silent screen grab) — rely on user‑attached images via `image_picker`.

## 7. Platform‑channel surface
**None.** Pure Dart + HTTP. (Feedback may consume `brainpal/system_events: SCREEN_CAPTURED` only for analytics, not required.)

## 8. State management & DI
- Riverpod: `voteSummaryProvider` (`FutureProvider`), `feedbackControllerProvider` (`StateNotifier` for form), `accountProvider` (identity/state).
- `get_it`: `AccountRepository` (AccountApi + cleanup), `FeedbackRepository` (FeedbackUploadApi + file staging).

## 9. User flows
1. **Open account settings** `[dart]`: show identity, manage subscription link, language, widgets toggle, vote summary, Send Feedback, Delete account.
2. **Submit feedback** `[dart]`: pick category → text (≤2000) → optional screenshot consent → enqueue `FeedbackUploadWorker` → poll (≤10s) → multipart upload.
3. **Delete account** `[dart]`: confirm → `delete_user_data` → wipe local stores → reset to onboarding.
4. **Uninstall feedback** `[dart]`: prompt reason → submit → proceed to uninstall.

## 10. Parity risks & validation
- **Multipart field names** must match backend exactly (`user_id`, `feedback_id`, `file`).
- **Delete completeness:** after server 200, assert *all* local drift tables + prefs + secure store cleared.
- **Device‑id stability:** test reinstall keeps `br_user_id` (Keychain‑backed UUID on iOS; ANDROID_ID on Android).
- **Worker non‑failure:** confirm feedback worker returns success even when screenshot absent (matches original).
- **Char limit:** enforce 2000 in UI.

## 11. Open questions
- Screenshot file format/location the worker polls (cache/temp/cloud URL?).
- `delete_user_data` authorization model (parameterless?).
- Does `br_user_id` rotate on factory reset / device‑id change? backend mapping?
- Vote summary: my votes about friends, or friends' votes about me?
- Is feedback submission authenticated or device‑id based?

## 12. Migration checklist (Phase 3)
- [ ] `AccountRepository` (delete‑data + local wipe) and `FeedbackRepository` (multipart upload).
- [ ] Account settings + feedback form screens (categories, 2000‑char limit, consent).
- [ ] `FeedbackUploadWorker` via `workmanager` (async poll, upload, success‑on‑miss).
- [ ] Stable device id (ANDROID_ID / Keychain UUID) shared with [module-10](module-10-networking-sync.md).
- [ ] Vote summary screen.
- [ ] iOS: `image_picker` attachments; Keychain device id.
