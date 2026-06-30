# Module: Invite & Referral

## 1. Purpose & scope
Referral links, accepting invites via deep links, friend‑list management, and wiring an accepted invite into the duel "pinned friend" relationship. **Owns:** invite link creation/storage, deep‑link parsing, accept flow, friend add/remove. **Does NOT own:** the duel scoring/leaderboard UI (see [module-05-duel-friends-stats.md](module-05-duel-friends-stats.md)) or the endpoint/DTO definitions (see [02-backend-api-contract.md](02-backend-api-contract.md)).

## 2. Migration verdict
**PURE‑DART** (with App Links handled by `app_links` + `go_router`). All logic — link creation, accept, friend management, local invite tables — is conventional Dart. The only platform touchpoint is deep‑link delivery, covered by packages on both platforms. Identical on Android + iOS (Universal Links on iOS).

## 3. Business logic & algorithms (load‑bearing)

### 3.1 Invite link creation
```
createInvite():
  resp = POST /invite/create_link            // CreateInviteLinkResponse{short_link, br_user_id}
  insert invite_links(inviteLink=short_link, createdAt=now)
  share via system chooser (share_plus)
```

### 3.2 Accept invite via deep link
- Deep‑link hosts (App Links, `autoVerify=true`): `https://join.brainpalapp.ai`, `https://join.brainrotapp.ai`; custom scheme `brainrot://`.
```
onDeepLink(uri):
  invitedBy = uri.queryParameter("invited_by_br_user_id")
  insert pending_invites(invited_by_br_user_id=invitedBy, is_processed=0, created_at=now,
                         utm_source=?, utm_campaign=?)
  POST /invite/accept?invited_by_br_user_id=invitedBy     // AcceptInviteResponse{message}
  UPDATE pending_invites SET is_processed=1, processed_at=now WHERE invited_by_br_user_id=invitedBy
  // set inviter as the accepter's pinned duel friend:
  UserBlockingConfig = cfg.copy(pinnedFriendBrUserId = invitedBy)
```

### 3.3 Friend list sync + first‑seen
```
getFriends():
  resp = GET /invite/friends (header skip_swr, SWR TTL 30s)   // GetFriendsResponse{friends:[FriendInfo]}
  for f in friends:
    friendSince = f.friend_since_ms ?? prefs['first_seen_'+f.br_user_id] ?? (now, then store)
  sort by friendSince
```
- Pending invite processing: `SELECT … WHERE is_processed=0 ORDER BY created_at DESC LIMIT 1` → show "X invited you" → confirm → mark processed; housekeeping `DELETE FROM invite_links`.
- Remove friend: `POST /invite/remove_friend?friend_br_user_id=…` → also breaks duel pairing.
- Invite details (for the inviter card): `GET /invite/get_invite_details?invited_by_br_user_id=…`.

## 4. Data models

### 4.1 Local Room tables (`Invite.db`)
```
invite_links     inviteLink TEXT PK · createdAt INT(long)
pending_invites  id INT PK AUTO · invited_by_br_user_id TEXT · utm_source TEXT? · utm_campaign TEXT?
                 created_at INT(long) · processed_at INT(long)? · is_processed INT(bool)
```
Prefs (`friends_prefs`): `first_seen_<br_user_id>` (long).

### 4.2 DTOs
`CreateInviteLinkResponse`, `AcceptInviteResponse`, `GetFriendsResponse`, `FriendInfo`, `RemoveFriendResponse`, `InviteDetailsResponse` — defined in [02-backend-api-contract.md](02-backend-api-contract.md) §4.3. Dart `freezed`.

### 4.3 Dart (drift) target
```dart
class InviteLinks extends Table { TextColumn get inviteLink => text()(); IntColumn get createdAt => integer()(); @override Set<Column> get primaryKey => {inviteLink}; }
class PendingInvites extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invitedByBrUserId => text()();
  TextColumn get utmSource => text().nullable()();
  TextColumn get utmCampaign => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get processedAt => integer().nullable()();
  BoolColumn get isProcessed => boolean().withDefault(const Constant(false))();
}
```

## 5. Android deps → Flutter map
| Android API | Verdict | Flutter | Notes |
|---|---|---|---|
| App Links (autoVerify, 2 hosts) + `brainrot://` | PKG | `app_links` + `go_router` | keep `/.well-known/assetlinks.json` on backend |
| Retrofit `InviteApi` | PKG | `dio`+`retrofit` | |
| Room (`Invite.db`) | PKG | `drift` | |
| `SharedPreferences` (`friends_prefs`) | PKG | `shared_preferences` | per‑friend first_seen |
| Share intent | PKG | `share_plus` | invite link share |
| (FDL — avoid) | — | **not** `firebase_dynamic_links` (sunset) | use App Links/Universal Links |

## 6. iOS strategy
Direct parity: App Links → **Universal Links** (Associated Domains entitlement + `apple-app-site-association` file on `join.brainpalapp.ai`); `app_links` handles both platforms. Custom scheme `brainrot://` works on iOS too. Sharing via `share_plus`. All other logic shared Dart. No reduction in capability.

## 7. Platform‑channel surface
**None** — deep links delivered through `app_links` (no custom channel). Accepted invite mutates `user_blocking_config` (pinned friend) via the data layer ([module-09](module-09-core-data-storage.md)).

## 8. State management & DI
- Riverpod: `friendsProvider` (`FutureProvider`/stream over `getFriends`), `pendingInviteProvider`, `inviteLinkProvider` (`FutureProvider` for `createInvite`).
- `get_it`: `InviteRepository` (InviteApi + invite DAOs + prefs), `DeepLinkHandler` (subscribes to `app_links` stream, routes via `go_router`).

## 9. User flows
1. **Share invite** `[dart]`: tap Invite → `create_link` → `share_plus`.
2. **Friend taps link** `[os→app_links→dart]`: cold/warm start → parse `invited_by_br_user_id` → `pending_invites` → `accept` → set pinned friend.
3. **View friends** `[dart]`: `getFriends` (SWR 30s) → resolve first‑seen → sorted list.
4. **Remove friend** `[dart]`: `remove_friend` → refresh; breaks duel.
5. **Show pending invite** `[dart]`: on launch, surface unprocessed invite → confirm.

## 10. Parity risks & validation
- **Deep‑link parity:** serve `assetlinks.json` + `apple-app-site-association`; test `adb shell am start -a android.intent.action.VIEW -d "https://join.brainpalapp.ai/?invited_by_br_user_id=abc"` and the iOS Universal Link.
- **Cold‑start link:** ensure first‑run links are captured (`app_links.getInitialLink`).
- **Pinned‑friend write:** assert accept updates `user_blocking_config.pinnedFriendBrUserId` and syncs.
- **first_seen fallback:** test all three branches (server / pref / new).
- **Subscription gating:** if invites are premium‑gated, check entitlement before showing create (cross‑ref [module-06](module-06-subscription-billing.md)).

## 11. Open questions
- Are invites subscription‑gated?
- `utm_source`/`utm_campaign` source (link params?) and usage.
- Is `pinned_friend` single or multi (multi‑friend duels)?
- Pending‑invite polling: background worker vs on‑launch fetch (on‑launch assumed).

## 12. Migration checklist (Phase 3)
- [ ] drift `invite_links` + `pending_invites`; `friends_prefs`.
- [ ] `InviteRepository` (create/accept/friends/remove/details).
- [ ] `app_links` + `go_router` deep‑link routing (both schemes/hosts).
- [ ] Accept flow writes pinned friend to config + sync.
- [ ] `share_plus` invite sharing.
- [ ] Backend: assetlinks.json + apple-app-site-association.
- [ ] iOS Associated Domains entitlement.
