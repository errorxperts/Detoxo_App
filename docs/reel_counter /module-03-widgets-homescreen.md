# Module: Home-Screen Widgets

> APP: BrainPal, package `com.brainrot.android`, v7.1.340.
> Decompiled sources: `/Users/shahbazqureshi/Documents/Decompile/sources` (JADX). Resources: `/Users/shahbazqureshi/Documents/Decompile/resources`.
> Canonical channel contract is [01-platform-channel-contracts.md](01-platform-channel-contracts.md). Backend stat shape is [02-backend-api-contract.md](02-backend-api-contract.md). Stats/leaderboard domain is owned by the reels-counter module; see [module-04-reels-counter-stats.md](module-01-reels-detection-core.md). Duels/leaderboard backend in [module-09-duels-leaderboard.md](module-05-duel-friends-stats.md). Deep-link routing in [module-12-deeplinks-routing.md](module-12-messaging-app-shell.md). Onboarding "Add widget" step in [module-10-onboarding.md](module-04-permissions-onboarding.md).

---

## 1. Purpose & scope

Two Android home-screen AppWidgets that surface the user's **today reel/short scroll count** directly on the launcher, plus a duel-leaderboard variant:

| Widget | Provider class | `res/xml` config | Cells | Min size | Preview | Content |
|---|---|---|---|---|---|---|
| **Compact** | `ReelsCounterWidgetReceiver` | `reels_counter_widget_info.xml` | 2x2 (`targetCellWidth=2`, `targetCellHeight=2`) | `120dp x 120dp` | `@drawable/widget_preview_no_friends` | Big number `totalCountToday` + label "Reels Today" |
| **Expanded** | `ReelsCounterWidgetExpandedReceiver` | `reels_counter_widget_expanded_info.xml` | 4x2 (`targetCellWidth=4`, `targetCellHeight=2`) | `250dp x 120dp` | `@drawable/widget_preview_leaderboard` | Duel leaderboard (friend rows) OR "Reels Today" count OR single-friend duel card OR "Invite a friend / to battle" CTA |

Both widgets are built with **Jetpack Glance** (`androidx.glance.appwidget`) which composes `@Composable` content into `RemoteViews` at update time. The same Glance render (`sh.c0.c`) is shared by both; the layout it produces is chosen at runtime from the widget's measured width (>= 250dp -> expanded) and from whether the provider class is the expanded one.

In-scope code (all under `com/brainrot/android/feature_widget/presentation/widget/`):
- `ReelsCounterWidgetReceiver` — compact Glance provider (Vivo guard on `onReceive`).
- `ReelsCounterWidgetExpandedReceiver` — expanded Glance provider (Vivo guard on `onReceive`).
- `WidgetPinResultReceiver` — receives the `requestPinAppWidget` success callback, logs analytics.
- `AppUpdateReceiver` — `MY_PACKAGE_REPLACED` handler; re-enables widgets and force-refreshes after app update.
- `WidgetVisibilityProvider` — `ContentProvider` whose `onCreate()` runs at process start to **disable widgets on Vivo SDK 31–33**.

Supporting (obfuscated) classes verified: pin trigger `qh.a.a`; widget enable/disable `sh.c.b`; Glance base `z5.o0`; Glance updater `sh.x`; render `sh.c0`; leaderboard render `sh.n`; leaderboard row model `sh.o`; analytics enum `mc.a`; analytics logger `nh.a`; widget content provider `be.m1` (case 4).

Out of scope (owned elsewhere): the actual stats stream and DB (module-04), duel/leaderboard backend & friend model (module-09), deep-link routing once `brainrot://...` reaches `MainActivity` (module-12).

---

## 2. Migration verdict

**Verdict: HYBRID (KEEP-NATIVE layout/render + DART data conduit) on Android. NOT POSSIBLE on iOS as a counter widget driven by live accessibility data; use WidgetKit + App Group with a degraded data source.**

| Platform | Verdict | Rationale |
|---|---|---|
| **Android** | **KEEP-NATIVE render + DART feeds data** | Glance/`RemoteViews` have **no Dart equivalent**. Flutter cannot render into an AppWidget host process; only `RemoteViews` may run there. The Glance composition (`sh.c0`, `sh.n`), the two providers, the pin flow, the Vivo guard, and `AppUpdateReceiver` are **ported near-verbatim to Kotlin** and stay in the retained native core. Flutter owns the **data**: it pushes the latest `ReelsStats`/leaderboard snapshot to native via `home_widget` (the `brainpal/widgets` MethodChannel), and native re-renders. The original app is *reactive* (Glance subscribes to Kotlin `Flow`s); the Flutter port is *push* (Dart writes a snapshot, then calls `refresh`). See §3 and §8. |
| **iOS** | **NOT POSSIBLE as-is; use WidgetKit + App Group** | iOS has no AppWidget/RemoteViews, no Glance, no launcher pin API, and—critically—no AccessibilityService, so the **live reel count that feeds the widget does not exist on iOS** (detection is Screen Time `DeviceActivity`, which reports thresholds, not per-scroll counts). A WidgetKit widget can be built reading a shared snapshot from an **App Group** container that the Flutter app (and the `DeviceActivityMonitor` extension) writes to, but its data fidelity is coarse. Pin-to-home-screen is user-driven only (no programmatic `requestPinAppWidget`). Deep-link taps work via `widgetURL`. See §6. |

> **Load-bearing architecture note.** This module is a textbook case of the BrainPal "~70% OS-integration" reality: the widget *render* is pure OS integration with zero Dart surface, while the *data* it shows is plain domain state. The clean cut is: **native renders, Dart supplies**. `home_widget` is used **strictly as a data conduit + refresh trigger**, never to define layout. Do not attempt `flutter_overlay_window` or any Flutter-drawn widget here — it is architecturally impossible on the AppWidget host.

---

## 3. Business logic & algorithms

All constants below were re-read from source/resources and are quoted **verbatim**.

### 3.1 Widget metadata (verbatim from `res/xml/`)

`reels_counter_widget_info.xml` (compact):
```xml
android:minWidth="120dp"  android:minHeight="120dp"
android:updatePeriodMillis="0"
android:initialLayout="@layout/glance_default_loading_layout"
android:previewImage="@drawable/widget_preview_no_friends"
android:resizeMode="vertical|horizontal"
android:minResizeWidth="120dp"  android:minResizeHeight="120dp"
android:widgetCategory="home_screen"
android:targetCellWidth="2"  android:targetCellHeight="2"
```

`reels_counter_widget_expanded_info.xml` (expanded):
```xml
android:minWidth="250dp"  android:minHeight="120dp"
android:updatePeriodMillis="0"
android:initialLayout="@layout/glance_default_loading_layout"
android:previewImage="@drawable/widget_preview_leaderboard"
android:resizeMode="vertical|horizontal"
android:minResizeWidth="120dp"  android:minResizeHeight="120dp"
android:widgetCategory="home_screen"
android:targetCellWidth="4"  android:targetCellHeight="2"
```

- **`updatePeriodMillis="0"`** → the OS never auto-refreshes. All updates are on-demand (Glance flow emission in native; push-from-Dart in the port). **Do not** set a non-zero period in the port.
- Both share `@layout/glance_default_loading_layout` as the initial placeholder (Glance built-in).

### 3.2 Expanded-vs-compact decision (verbatim from `be.m1` case 4 and `sh.c0.c`)

The widget content function (`be.m1.invoke`, `case 4`) decides "is expanded" by **provider class identity OR measured width**:

```text
appWidgetInfo = AppWidgetManager.getInstance(ctx).getAppWidgetInfo(glanceId.appWidgetId)
isExpandedProvider = (appWidgetInfo?.provider?.className == ReelsCounterWidgetExpandedReceiver.class.name)
isExpanded = isExpandedProvider OR (Float.compare(size.width, 250f) >= 0)   // c0.f23082a = 250
```
`c0.f23082a = 250` (dp) is the **breakpoint constant**. (`sh.c0` line: `public static final float f23082a = 250;`.)

### 3.3 Font/size scaling algorithm (verbatim from `sh.c0.c` and `sh.c0` field block)

Constants in `sh.c0` (dp / sp as `a4.f`):
```text
f23082a = 250    // breakpoint width
f23083b = 200    // scale divisor
f23084c = 10     // horizontal inset (each side)
f23085e = 20     // (corner radius / clickable bg radius)  [d = 14]
f23086f = 50     // content-width clamp MIN
f23087g = 150    // content-width clamp MAX
f23088h = 30     // title base size
f23089i = 20     // title clamp MIN
f23090j = 30     // title clamp MAX
f23091k = 14     // subtitle base size
f23092l = 12     // subtitle clamp MIN
f23093m = 14     // subtitle clamp MAX
f23094n = 4      // spacing
f23095o = 2      // spacing
p        = 16    // spacing
f23096q  = 24    // battle icon size
d        = 14    // (clickable inset baseline)
```
Pseudocode (matches `c0.c`):
```text
fA = width - (f23084c * 2)          // = width - 20
f3 = fA / f23083b                    // = fA / 200
if (f3 < 0) f3 = 0
titleSize    = clamp(f23088h * f3, f23089i, f23090j)   // clamp(30*f3, 20, 30)
subtitleSize = clamp(f23091k * f3, f23092l, f23093m)   // clamp(14*f3, 12, 14)
contentWidth = clamp(
    fA - ((1.2*subtitleSize) + (titleSize*1.2) + f23094n + f23095o + p),  // ... + 4 + 2 + 16
    f23086f, f23087g)                                                      // clamp(.., 50, 150)
d0 = WidgetTextStyles(
        contentWidth,
        title    = Font(R.font.cabinet_grotesk_black, titleSize),
        subtitle = Font(R.font.cabinet_grotesk_bold,  subtitleSize))
```
`clamp(x, lo, hi)` here is `y3.y(x, lo, hi)` = `coerceIn`.

### 3.4 Layout selection inside the render (verbatim from `sh.c0.c`)

```text
isExpanded = z12 = Float.compare(width, 250) >= 0      // recomputed in c0.c
deepLinkUri = isExpanded ? d("brainrot://duel","duel_widget","open")
                         : d("brainrot://home","home_widget","open")

hasLeaderboardList = (isExpanded && list != null && list.isNotEmpty())
if (hasLeaderboardList) {
    // any friend entry whose isCurrentUser == true  -> "leaderboard self present"
    showLeaderboard = list.any { it.entry.isCurrentUser == true }     // o.f23173a.f15786e
} else {
    showLeaderboard = false
}

render:
  if (showLeaderboard)            -> n.c(list)              // full leaderboard rows
  else if (isExpanded)            -> c0.b(count, firstName, hasFriend, friendCount, ..., d0)
                                       // single-friend duel card OR "Invite a friend to battle"
  else                           -> c0.a(count, d0)        // compact: number + "Reels Today"
```
- The whole widget is wrapped in a clickable that opens `deepLinkUri` **only when** `showLeaderboard == false`. When the leaderboard is shown, each row carries its own click target (`n.c` builds a `brainrot://duel?widget_source=duel_widget&widget_action=open` intent).

### 3.5 Single-friend duel card vs Invite CTA (verbatim from `sh.c0.b`)

`c0.b(count, friendFirstName, hasFriend (z10), friendReelCount (Integer num), friendName (str2), styles)`:
```text
draws the today count box (b0 composable) + R.drawable.br_ic_battle_content_low icon
if (hasFriend)  -> draw friend row (count num, name str2)  [clickable -> duel open]
else            -> "Invite a friend to battle" CTA:
        Intent(MainActivity) | FLAG_ACTIVITY_NEW_TASK(268435456)
        data = brainrot://duel?widget_source=duel_widget&widget_action=invite_friend&open_invite=true
```

### 3.6 Leaderboard rows (verbatim from `sh.n.c`)

```text
MAX_VISIBLE = 5
emptySlots = max(0, 5 - list.size())                 // "5 - list.size()" clamped >= 0
// "all uninstalled" check (controls a dimmed/placeholder style):
allUninstalled = list.isNotEmpty() && list.all { it.entry.isCurrentUser == true }   // n.c uses f15786e
// placeholder/teaser names (shuffled once):  pe.d.f20026a
placeholderNames = shuffle(["crush","bestie","rival","sibling",
                            "reel_addict","night_owl","roommate","doomscroller"])
row click target = brainrot://duel?widget_source=duel_widget&widget_action=open
container click   = brainrot://duel?widget_source=duel_widget&widget_action=open
```
- Ordinal-rank suffix helper `sh.n.h(int)` (verbatim):
```text
i11 = n % 100
suffix = "th"
if !(11 <= i11 < 14):
    switch (n % 10): 1->"st", 2->"nd", 3->"rd", else "th"
return n + suffix         // 1->"1st", 2->"2nd", 3->"3rd", 11->"11th", 21->"21st"
```
- Avatars: `sh.n.f`/`n.g` load each friend's `displayPhotoUrl` via Coil into a `Bitmap` (128x128, `n.f` uses size const `128`); on failure fall back to `R.drawable...` (uninstalled vs normal placeholder drawable). The avatar bitmap is carried in `sh.o.f23174b`.

### 3.7 Leaderboard gating by remote config (verbatim from `be.m1` case 4)

The leaderboard data flow is only built when expanded **and** the remote flag is read:
```text
leaderboardFlow = yyy.g().a(uc.h.LEADERBOARD_ENABLED_OVERRIDE)   // remote-config key
```
Remote-config key (verbatim from `uc/h.java`):
```text
LEADERBOARD_ENABLED_OVERRIDE("leaderboard_enabled_override_v1")
```
→ Port via `firebase_remote_config`, key **`leaderboard_enabled_override_v1`**. See [module-14-remote-config-flags.md](module-12-messaging-app-shell.md).

### 3.8 Vivo guard (verbatim, three independent sites)

The exact predicate, identical in `ReelsCounterWidgetReceiver.onReceive`, `ReelsCounterWidgetExpandedReceiver.onReceive`, `AppUpdateReceiver.onReceive`, and `WidgetVisibilityProvider.onCreate`:
```java
int i10 = Build.VERSION.SDK_INT;
if ((i10 == 31 || i10 == 32 || i10 == 33) && r.J(Build.MANUFACTURER, "vivo")) { /* disable / skip */ }
```
- `r.J(s, prefix)` = `String.startsWith(prefix, ignoreCase=true)` → manufacturer **starts with "vivo"** (case-insensitive).
- SDK **31, 32, 33** = Android **12, 12L, 13**. (NB: SDK 34 = Android 14 is **NOT** in the guard, despite the cache note "12–14". Verified: only 31/32/33.)
- In the two providers: guard returns early from `onReceive` (widget never updates).
- In `WidgetVisibilityProvider.onCreate` and `AppUpdateReceiver`: guard calls `sh.c.b(context, false)` to **disable** both receiver components.

### 3.9 Component enable/disable (verbatim from `sh.c.b`)

```java
static void b(Context context, boolean z10) {
  PackageManager pm = context.getPackageManager();
  ComponentName[] arr = {
     new ComponentName(context, ReelsCounterWidgetReceiver.class),
     new ComponentName(context, ReelsCounterWidgetExpandedReceiver.class) };
  int state = z10 ? COMPONENT_ENABLED_STATE_ENABLED(1) : COMPONENT_ENABLED_STATE_DISABLED(2);
  for (ComponentName cn : arr)
     pm.setComponentEnabledSetting(cn, state, DONT_KILL_APP(1));
  // on exception: log "Error enabling/disabling widgets" to "WidgetConfiguration"
}
```
Magic ints: `1` = `COMPONENT_ENABLED_STATE_ENABLED`, `2` = `COMPONENT_ENABLED_STATE_DISABLED`, third arg `1` = `DONT_KILL_APP`.

### 3.10 Pin-widget trigger (verbatim from `qh.a.a`)

```java
ph.d a(String widgetSource, boolean isExpanded) {
  if (Build.VERSION.SDK_INT < 26) return Result.UNSUPPORTED_OLD_OS;          // ph.a.f20090e
  AppWidgetManager mgr = AppWidgetManager.getInstance(ctx);
  if (!mgr.isRequestPinAppWidgetSupported()) return Result.UNSUPPORTED;      // ph.a.f20091n
  Class cls = isExpanded ? ReelsCounterWidgetExpandedReceiver.class : ReelsCounterWidgetReceiver.class;
  // resolve provider ComponentName from installed providers, else new ComponentName(ctx, cls)
  Intent cb = new Intent(ctx, WidgetPinResultReceiver.class);
  cb.setAction("com.brainrot.android.widget.ACTION_WIDGET_PINNED");
  cb.putExtra("widget_source", widgetSource);
  PendingIntent pi = PendingIntent.getBroadcast(ctx, widgetSource.hashCode(), cb,
        Build.VERSION.SDK_INT >= 31 ? 201326592 : 134217728);
  boolean ok = mgr.requestPinAppWidget(componentName, /*extras*/ null, pi);
  return ok ? Result.SUCCESS : Result.UNSUPPORTED;
}
```
- PendingIntent flags: `201326592` = `FLAG_IMMUTABLE | FLAG_UPDATE_CURRENT` (SDK >= 31); `134217728` = `FLAG_UPDATE_CURRENT` (SDK < 31).
- Request code = **`widgetSource.hashCode()`** (NOT a random/sequential code).
- Callback action = **`com.brainrot.android.widget.ACTION_WIDGET_PINNED`**, source extra key = **`widget_source`**.

### 3.11 Pin callback (verbatim from `WidgetPinResultReceiver`)

```java
if (action == "com.brainrot.android.widget.ACTION_WIDGET_PINNED"
      && intent.getIntExtra("appWidgetId", 0) != 0) {
   String source = intent.getStringExtra("widget_source") ?: "unknown";
   logger.log(mc.a.WIDGET_PIN_CALLBACK_SUCCESS, source);   // event 149, JSON {"source": source}
}
```

### 3.12 App-update refresh (verbatim from `AppUpdateReceiver`)

```java
if (action == "android.intent.action.MY_PACKAGE_REPLACED") {
   if (vivoGuard(SDK 31|32|33, "vivo")) { sh.c.b(ctx, false); return; }   // disable on Vivo
   sh.c.b(ctx, true);                                                     // re-enable both
   PendingResult pr = goAsync();
   // coroutine sg.h(case 1): refresh all widget instances, then pr.finish()
}
```

### 3.13 Deep-link URI builder (verbatim from `sh.c0.d`)

```java
static Uri d(String base, String widgetSource, String widgetAction) {
  return Uri.parse(base).buildUpon()
     .appendQueryParameter("widget_source", widgetSource)
     .appendQueryParameter("widget_action", widgetAction)
     .build();
}
```
Resulting URIs (verbatim):
| Surface | URI |
|---|---|
| Compact tap | `brainrot://home?widget_source=home_widget&widget_action=open` |
| Expanded tap / leaderboard row / container | `brainrot://duel?widget_source=duel_widget&widget_action=open` |
| Invite-friend CTA | `brainrot://duel?widget_source=duel_widget&widget_action=invite_friend&open_invite=true` |

All open `MainActivity` with `addFlags(268435456)` = `FLAG_ACTIVITY_NEW_TASK`. Routing of these query params (and firing of `HOME_WIDGET_CLICKED`/`DUEL_WIDGET_CLICKED`) happens at app entry — see §11 OPEN QUESTION and [module-12-deeplinks-routing.md](module-12-messaging-app-shell.md).

### 3.14 Strings (verbatim from `res/values/strings.xml`)

```xml
<string name="widget_reels_today">Reels Today</string>
<string name="widget_bottom_sheet_title">Add widget</string>
<string name="widget_invite_friend_line1">Invite a friend</string>
<string name="widget_invite_friend_line2">to battle</string>
<string name="widget_pin_success">Widget added to home screen.</string>
<string name="widget_pin_not_added">Couldn\'t confirm widget was added. Long-press home screen, open Widgets, then add BrainPal.</string>
<string name="widget_pin_not_supported">Couldn\'t open add-widget prompt. Long-press home screen, open Widgets, then add BrainPal.</string>
```
Placeholder battle names → `R.string.battle_invite_{crush,bestie,rival,sibling,reel_addict,night_owl,roommate,doomscroller}`.

### 3.15 Colors (verbatim ARGB longs, `l0.e(...)` = sRGB)

From `sh.c0`: `f23097r = 0xFF22_22_20` (`4280887072`), `f23098s = 0xA6_FB_xx` (`2801598458`, ~65% alpha grey — subtitle), `f23099t = 0xFF_FA_F8_FA` (`4294770682`, near-white bg).
From `sh.n`: `f23162n = 4279505679`, `f23163o = l0.c(452788218)` (leaderboard bg), `f23164q = 4283778349`, `f23165r = 4294770682`, `f23166s = 4287268476`, `f23168u = 4294947687`, `f23169v = 4285610496`. Fonts: `cabinet_grotesk_{black,bold,extrabold,medium,regular}`.

---

## 4. Data models

The widget is a **read-only projection** of three domain streams. No widget-specific persistence — Glance keeps its own state; the port keeps a JSON snapshot in the App Group / `home_widget` shared prefs. Source models (verbatim) and the freezed/drift targets below.

### 4.1 `ReelsStats` (verbatim — `feature_reels_counter/domain/model/ReelsStats.java`)

| Field | Type | Null | Default | Notes |
|---|---|---|---|---|
| `totalCountToday` | `int` | no | `0` | shown as the big number |
| `totalTimeMillisToday` | `long` | no | `0L` | not shown on widget; kept for parity |
| `lastUpdateTime` | `long` | no | `System.currentTimeMillis()` | staleness marker |
| `appWiseSplit` | `List<AppReelsStats>` | no | `[]` (`ep.q`) | not shown on widget |

> No `@SerializedName` annotations on these domain models (they are domain, not DTO). The widget snapshot is serialized by the port (suggested keys in code block).

### 4.2 `AppReelsStats` (verbatim)

| Field | Type | Null | Notes |
|---|---|---|---|
| `appId` | `String` | no | e.g. `com.instagram.android` |
| `displayName` | `String` | no | |
| `count` | `int` | no | |
| `totalTimeMillis` | `long` | no | |

### 4.3 `OneFriend` (verbatim) — drives the single-friend duel card

| Field | Type | Null | Notes |
|---|---|---|---|
| `brUserId` | `String` | **yes** | nullable |
| `status` | `lg.b` (enum) | no | friendship status |
| `friendShipStartDateInMillis` | `long` | no | |
| `isPinned` | `boolean` | no | |
| `profileInfo` | `ProfileInfo` | no | |
| `shouldShowInviteAccepted` | `boolean` | no | default `false` |

`hasFriend` on the widget = `OneFriend != null`; friend display name = `profileInfo.getFirstName()`.

### 4.4 `ProfileInfo` (verbatim) — `getFirstName()` is load-bearing

| Field | Type | Null |
|---|---|---|
| `displayName` | `String` | no |
| `emailId` | `String` | no |
| `displayPhotoUrl` | `String` | **yes** |

`getFirstName()` = trim `displayName`, split on regex **`\s+`**, take first token; empty-string fallback. (Port this verbatim — it is what the widget shows next to the friend.)

### 4.5 `CounterLeaderboardEntry` (verbatim — `lg/a.java`, `toString` = `CounterLeaderboardEntry`) — leaderboard row source

| Field (obf) | Name | Type | Null | Notes |
|---|---|---|---|---|
| `f15783a` | `id` | `String` | no | |
| `f15784b` | `displayName` | `String` | no | |
| `f15785c` | `displayPhotoUrl` | `String` | **yes** | Coil avatar source |
| `d` | `reelCount` | `Integer` | **yes** | |
| `f15786e` | `isCurrentUser` | `boolean` | no | gates "showLeaderboard" |
| `f15787f` | `rank` | `int` | no | default `1` |
| `f15788g` | `isUninstalled` | `boolean` | no | default `false` |

### 4.6 Widget render row (`sh.o` = `LeaderboardWidgetRow`)
| Field | Type | Notes |
|---|---|---|
| `f23173a` | `entry: CounterLeaderboardEntry` | |
| `f23174b` | `avatar: Bitmap?` | resolved via Coil, nullable |

### 4.7 Dart target shapes (freezed; widget snapshot DTO)

```dart
// domain (pure Dart) — mirrors module-04 models; reused, not redefined here.
@freezed
class ReelsStats with _$ReelsStats {
  const factory ReelsStats({
    @Default(0) int totalCountToday,
    @Default(0) int totalTimeMillisToday,   // long -> int (Dart int = 64-bit)
    @Default(0) int lastUpdateTime,
    @Default(<AppReelsStats>[]) List<AppReelsStats> appWiseSplit,
  }) = _ReelsStats;
}

@freezed
class CounterLeaderboardEntry with _$CounterLeaderboardEntry {
  const factory CounterLeaderboardEntry({
    required String id,
    required String displayName,
    String? displayPhotoUrl,
    int? reelCount,
    @Default(false) bool isCurrentUser,
    @Default(1) int rank,
    @Default(false) bool isUninstalled,
  }) = _CounterLeaderboardEntry;
}

// ---- The ONLY widget-specific model: the snapshot pushed to native via home_widget ----
@freezed
class WidgetSnapshot with _$WidgetSnapshot {
  const factory WidgetSnapshot({
    @JsonKey(name: 'reelsToday')        required int reelsToday,            // ReelsStats.totalCountToday
    @JsonKey(name: 'lastUpdateMs')      required int lastUpdateMs,
    @JsonKey(name: 'leaderboardEnabled')@Default(false) bool leaderboardEnabled, // remote flag
    @JsonKey(name: 'hasFriend')         @Default(false) bool hasFriend,
    @JsonKey(name: 'friendFirstName')   String? friendFirstName,
    @JsonKey(name: 'friendReelCount')   int? friendReelCount,
    @JsonKey(name: 'leaderboard')       @Default(<CounterLeaderboardEntry>[]) List<CounterLeaderboardEntry> leaderboard,
  }) = _WidgetSnapshot;
  factory WidgetSnapshot.fromJson(Map<String,Object?> j) => _$WidgetSnapshotFromJson(j);
}
```
> **No drift table for the widget.** The snapshot lives in `home_widget`'s shared prefs (Android) / App Group `UserDefaults` (iOS) as a single JSON blob keyed e.g. `widget_snapshot`. Underlying `ReelsStats` & leaderboard persistence belong to module-04 / module-09 (drift). Avatars: on Android keep Coil-in-native; in the port pre-resolve avatar PNGs to files referenced by path in the snapshot (RemoteViews `ImageView` reads a `Uri`/`Bitmap`, not a network URL).

---

## 5. Android deps → Flutter map

| Android API | Verdict | Flutter pkg / channel | Notes |
|---|---|---|---|
| `androidx.glance.appwidget.GlanceAppWidget` (`z5.o0`) | KEEP-NATIVE | — (retained Kotlin) | No Dart equivalent. Composition `sh.c0`/`sh.n` stays. |
| `android.appwidget.AppWidgetProvider` (compact/expanded receivers) | KEEP-NATIVE | — | Keep both provider classes + their `res/xml`. |
| `AppWidgetManager.updateAppWidget` (Glance reactive update) | KEEP-NATIVE, **driven by** DART | `home_widget` `updateWidget()` → native re-render; `brainpal/widgets`.`refresh` | Push model replaces Flow subscription. |
| `AppWidgetManager.requestPinAppWidget` (`qh.a.a`) | DART+CHANNEL | `home_widget` `requestPinWidget()` **or** `brainpal/widgets`.`requestPinWidget` | Wraps native pin; SDK>=26 + `isRequestPinAppWidgetSupported()` checks kept native. |
| `WidgetPinResultReceiver` (pin success cb) | KEEP-NATIVE → DART event | `brainpal/widgets` callback / FlutterFire | Native receiver fires; bridge result to Dart to log analytics + toast. |
| `AppUpdateReceiver` (`MY_PACKAGE_REPLACED`) | KEEP-NATIVE | — | Re-enable + refresh after update; no Dart equivalent for the broadcast. |
| `WidgetVisibilityProvider` (`ContentProvider`, init-order Vivo guard) | KEEP-NATIVE | — | Must run at **process start** before any widget update; cannot move to Dart (Flutter engine not up yet). |
| `PackageManager.setComponentEnabledSetting` (`sh.c.b`) | KEEP-NATIVE | — | Toggle widget components (Vivo / post-update). |
| `Build.MANUFACTURER` / `Build.VERSION.SDK_INT` (Vivo) | DART can read, but KEEP-NATIVE | `device_info_plus` (read) | The *guard itself* stays native (timing); `device_info_plus` only for in-app diagnostics. |
| Glance trampolines (`ActionTrampolineActivity`, `InvisibleActionTrampolineActivity`, `ActionCallbackBroadcastReceiver`, `MyPackageReplacedReceiver`, `GlanceRemoteViewsService`) | KEEP-NATIVE | — | Declared by Glance; keep manifest entries verbatim. |
| Coil avatar loading (`sh.n.f`/`n.g`) | KEEP-NATIVE | (port: pre-resolve to file path) | RemoteViews can't fetch URLs; native loads bitmap. |
| `firebase remote config` flag `leaderboard_enabled_override_v1` | DART | `firebase_remote_config` | Dart reads, includes in snapshot. |
| Deep links `brainrot://home`/`brainrot://duel` | DART | `app_links` + `go_router` | Routing in module-12. **Not** Firebase Dynamic Links. |
| Analytics events 147–151, 326–328, 356–358 | DART | `firebase_analytics` (+ `nh.a` parity) | See §8 / §10. |
| `PendingIntent` flags 201326592 / 134217728 | KEEP-NATIVE | — | Inside native pin wrapper. |

---

## 6. iOS strategy

**There is no AppWidget on iOS and no live per-scroll counter from the OS.** Re-implement as a degraded WidgetKit widget over an App Group; everything else is "not possible; use <X>".

| Android capability | iOS reality | iOS replacement |
|---|---|---|
| AppWidget / Glance / RemoteViews | none | **WidgetKit** (`WidgetCenter`, `TimelineProvider`, SwiftUI). Build compact + medium families. |
| Reactive `Flow<ReelsStats>` → widget | none | Flutter writes `WidgetSnapshot` JSON to **App Group** `UserDefaults`; call `WidgetCenter.shared.reloadAllTimelines()` from the bridge. |
| Live reel **count** source (AccessibilityService) | **does not exist** | Screen Time `DeviceActivityMonitor` reports **threshold events**, not counts. Widget shows derived/coarse data (e.g. "blocked N times today", time-in-app buckets), **not** a true per-scroll count. This is a known fidelity gap — see [module-01-detection-core.md](module-01-reels-detection-core.md) and §11. |
| `requestPinAppWidget` (programmatic pin) | none | User adds widget manually from the widget gallery. The "Add widget" onboarding step becomes an **instructional** screen (no programmatic trigger). |
| Pin success callback / `ACTION_WIDGET_PINNED` | none | No callback exists; cannot detect that the user added the widget. Analytics events 149/356–358 have **no iOS analogue**. |
| Tap deep-link | supported | SwiftUI `.widgetURL(URL("brainpal://home" | "brainpal://duel"))`; `app_links` handles it in Flutter. (Scheme on iOS should be the app's registered scheme; see module-12.) |
| Leaderboard / duel data | available (network) | Same Dart domain layer; widget reads it from the App Group snapshot. Avatars must be written as image files into the App Group container. |
| Vivo guard | N/A | No equivalent; iOS has no manufacturer fragmentation here. |
| `MY_PACKAGE_REPLACED` refresh | none | Not needed; WidgetKit reloads on app launch / timeline policy. |

> **Behind the same Dart domain layer.** Both platforms share the `WidgetSnapshot` producer (a Riverpod provider). Android consumes it via `home_widget` shared-prefs; iOS consumes it via App Group `UserDefaults`. The *render* diverges (Glance vs SwiftUI) but the *data contract is identical*.

---

## 7. Platform-channel surface

Channels used (names verbatim from the canonical namespace; source of truth: [01-platform-channel-contracts.md](01-platform-channel-contracts.md)):

### 7.1 `MethodChannel "brainpal/widgets"` (Dart → native) — primary

| Method | Args | Returns | Direction | Maps to native |
|---|---|---|---|---|
| `pushWidgetData` | `WidgetSnapshot` JSON (see §4.7) | `void`/`bool` | Dart→native | writes snapshot to `home_widget` prefs / App Group |
| `refresh` | `{ "which": "compact"\|"expanded"\|"all" }` | `void` | Dart→native | triggers Glance update (Android: `sh.x` per-instance update; iOS: `reloadAllTimelines`) |
| `requestPinWidget` | `{ "widgetSource": String, "isExpanded": bool }` | `WidgetPinResult` (`success`\|`unsupported`\|`unsupported_old_os`) | Dart→native | wraps `qh.a.a`; logs event 147 attempt |
| `areWidgetsEnabled` | `{}` | `bool` | Dart→native | reflects Vivo guard state (`sh.c.b` component state) |

> `home_widget` provides `saveWidgetData`/`updateWidget`/`requestPinWidget` directly; the `brainpal/widgets` MethodChannel is the **canonical wrapper** so the pin-result/Vivo semantics and event logging stay in one place. Use `home_widget` under the hood, expose `brainpal/widgets` to Dart.

### 7.2 Pin-result delivery (native → Dart)

The native `WidgetPinResultReceiver` (kept) receives `com.brainrot.android.widget.ACTION_WIDGET_PINNED`. Bridge the result to Dart so the port can log `WIDGET_PIN_CALLBACK_SUCCESS` and show the success toast. Recommended payload (over `home_widget`'s background callback or a dedicated `brainpal/widgets` reply):
```json
{ "type": "widget_pinned", "widgetSource": "<string>", "appWidgetId": <int> }
```

### 7.3 Data dependency (not owned here)
- The `WidgetSnapshot` is built in Dart from the reels-counter stats stream that originates natively on `EventChannel "brainpal/detection"` (reel events) and is aggregated in module-04. This module only **consumes** that aggregated state. No direct subscription to `brainpal/detection` here.

### 7.4 Kotlin Flow → channel mapping
| Original Kotlin stream | Original consumer | Port path |
|---|---|---|
| `ng.d.a()` → `Flow<ReelsStats>` | `be.m1` case 4 (Glance) | module-04 aggregates → Dart `widgetSnapshotProvider` → `pushWidgetData` |
| `AuthLibrary.getUserProfileFlow()` → `Flow<OneFriend>` | `be.m1` case 4 | module-09 friend state → snapshot.`hasFriend/friendFirstName/friendReelCount` |
| leaderboard `Flow<List<CounterLeaderboardEntry>>` (`...g().a(LEADERBOARD_ENABLED_OVERRIDE)`) | `be.m1` case 4 | module-09 leaderboard + `firebase_remote_config` → snapshot.`leaderboard` |

---

## 8. State management & DI

```text
core/platform/widget_channel.dart
  WidgetChannel (MethodChannel "brainpal/widgets")          // get_it singleton (@injectable)

presentation/widget/
  @riverpod WidgetSnapshot widgetSnapshot(ref) {            // riverpod_generator
     final stats   = ref.watch(reelsStatsProvider);         // module-04
     final friend  = ref.watch(oneFriendProvider);          // module-09
     final board   = ref.watch(leaderboardProvider);        // module-09
     final lbEnabled= ref.watch(remoteFlagProvider('leaderboard_enabled_override_v1')); // module-14
     return WidgetSnapshot(
        reelsToday: stats.totalCountToday,
        lastUpdateMs: stats.lastUpdateTime,
        leaderboardEnabled: lbEnabled,
        hasFriend: friend != null,
        friendFirstName: friend?.profileInfo.firstName,
        friendReelCount: friend?.reelCount,
        leaderboard: lbEnabled ? board : const [],
     );
  }

  // listener: push to native whenever snapshot changes (replaces Glance Flow subscription)
  @riverpod
  class WidgetSyncController extends _$WidgetSyncController {
     build() {
        ref.listen(widgetSnapshotProvider, (prev, next) async {
           if (prev == next) return;                          // dedupe; Glance recomposes on change
           await ref.read(widgetChannelProvider).pushWidgetData(next);
           await ref.read(widgetChannelProvider).refresh('all');
        });
     }
  }
```
- **DI:** `WidgetChannel`, analytics logger, remote-config reader → `get_it` + `injectable` singletons. UI/snapshot providers → Riverpod.
- **Refresh cadence parity:** original = reactive (Glance recomposes on any Flow emission); port = `ref.listen` push on snapshot equality change. Also push on `AppLifecycleState.resumed` and on a `workmanager` periodic task (e.g. every 15 min, the WorkManager minimum) so the widget doesn't go stale while the app is killed. **Do not** add `updatePeriodMillis`; keep it `0`.

---

## 9. User flows

### 9.1 Add-widget (pin) flow
1. [dart] User taps "Add widget" (onboarding `ONBOARDING_ADD_WIDGET_CLICKED` 103, or settings `WIDGET_ADD_CTA_CLICKED` 146). Bottom sheet `WIDGET_BOTTOM_SHEET_SHOWN` 145.
2. [dart] Log `WIDGET_PIN_REQUEST_ATTEMPTED` (147); call `brainpal/widgets`.`requestPinWidget {widgetSource, isExpanded}`.
3. [channel→native] Wrapper runs `qh.a.a`: SDK>=26? `isRequestPinAppWidgetSupported()`? If no → return `unsupported`/`unsupported_old_os`.
4. [native] On unsupported: [dart] log `WIDGET_PIN_UNSUPPORTED` (148) + toast `widget_pin_not_supported` (event 356 / onboarding 326).
5. [native] On supported: `requestPinAppWidget(component, null, PendingIntent(req=source.hashCode, ACTION_WIDGET_PINNED, IMMUTABLE|UPDATE_CURRENT))` → OS shows system pin dialog.
6. [native] User confirms → OS delivers `ACTION_WIDGET_PINNED` (with `appWidgetId`) to `WidgetPinResultReceiver`.
7. [native→channel→dart] Receiver logs `WIDGET_PIN_CALLBACK_SUCCESS` (149) `{source}`; bridge to Dart → toast `widget_pin_success` (event 357 / onboarding 327). If never confirmed: toast `widget_pin_not_added` (358 / onboarding 328).

### 9.2 Display / refresh flow (steady state)
1. [native] OS sends `APPWIDGET_UPDATE` / `LOCALE_CHANGED` to provider → `z5.o0.onReceive` → `onUpdate`.
2. [native] Vivo guard checked first (early-return on Vivo 31/32/33).
3. [native] `sh.x` launches coroutine → `be.m1` case 4 composes content from current snapshot.
4. [native] `sh.c0.c` measures width, builds `d0` styles, picks layout (compact / count / single-friend / invite / leaderboard).
5. [native] Glance converts composition → `RemoteViews` → `updateAppWidget`.
6. [dart→channel→native] In the port: whenever `widgetSnapshotProvider` changes, Dart calls `pushWidgetData` + `refresh` → native re-runs steps 3–5 reading the new snapshot.

### 9.3 Tap flow
1. [native] User taps widget area / leaderboard row / invite CTA → Glance trampoline fires the `PendingIntent`.
2. [native] Intent opens `MainActivity` (`FLAG_ACTIVITY_NEW_TASK`) with `brainrot://home?...` or `brainrot://duel?...`.
3. [dart] `app_links` delivers URI; `go_router` parses `widget_source`/`widget_action`(/`open_invite`) and routes to Home or Duel (open-invite sheet). Logs `HOME_WIDGET_CLICKED` (150) / `DUEL_WIDGET_CLICKED` (151). (Routing + event firing: module-12.)

### 9.4 App-update flow
1. [native] OS broadcasts `MY_PACKAGE_REPLACED` → `AppUpdateReceiver`.
2. [native] If Vivo 31/32/33 → `sh.c.b(false)` (disable) and return.
3. [native] Else `sh.c.b(true)` (re-enable both) → `goAsync()` coroutine refreshes all widget instances → `finish()`.

### 9.5 Vivo-disable flow
1. [native] Process start → `WidgetVisibilityProvider.onCreate()` (init-order 100, before Flutter engine).
2. [native] If Vivo 31/32/33 → `sh.c.b(false)` disables both receiver components → widgets stay installed but inert.

---

## 10. Parity risks & validation

| # | Risk | Mitigation / test |
|---|---|---|
| R1 | **Flutter cannot draw the widget.** Naive devs reach for `flutter_overlay_window` / a Flutter view in the widget. | Hard rule: native render only. Code review gate. Test: widget shows on a stock launcher with the app **process killed**. |
| R2 | **Push vs reactive drift.** Original recomposes on every Flow tick; port only refreshes when Dart pushes. Stale counter if a refresh is missed. | Push on snapshot-change + `resumed` + WorkManager periodic. Harness: scroll a reel, kill app, observe widget updates within one WorkManager cycle. |
| R3 | **Vivo guard regression** (SDK exactly 31/32/33, manufacturer prefix "vivo", case-insensitive; **NOT** 34). | Port guard verbatim in native, keep in `WidgetVisibilityProvider.onCreate` + both providers + `AppUpdateReceiver`. Test matrix: Vivo API 31/32/33 (disabled) vs Vivo API 30/34 + non-Vivo API 31 (enabled). |
| R4 | **Pin request-code = `widgetSource.hashCode()`** (not random). Two pins with same source collide intentionally; with `FLAG_UPDATE_CURRENT` that's by design. | Keep `source.hashCode()`. Test: pin compact then expanded with distinct sources → both callbacks distinct. |
| R5 | **PendingIntent flags** must be `IMMUTABLE|UPDATE_CURRENT` (>=31) / `UPDATE_CURRENT` (<31). Wrong mutability crashes on API 31+. | Keep flags `201326592`/`134217728`. Test on API 31+ that pin dialog appears. |
| R6 | **Leaderboard gating** by `leaderboard_enabled_override_v1`. If the flag isn't wired, the leaderboard variant silently never shows. | Wire `firebase_remote_config`; default off. Test flag on/off toggles leaderboard rows. |
| R7 | **`showLeaderboard` requires a self-entry** (`isCurrentUser==true` present). Off-by-one if backend omits the current user. | Replicate `list.any{isCurrentUser}`; ensure module-09 includes self. Test: list without self → falls back to count/invite, not leaderboard. |
| R8 | **Max 5 rows + ordinal suffix** (`5 - size`, `h(int)` → 1st/2nd/3rd/11th). | Port `n.h` verbatim incl. 11–13 special-case. Unit-test ranks 1,2,3,4,11,12,13,21,22,23,101,111. |
| R9 | **Avatars in RemoteViews** can't fetch URLs. | Pre-resolve to `Bitmap`/file (native Coil kept, or port pre-downloads). Test offline + broken-URL fallback drawable. |
| R10 | **iOS data fidelity** — no real per-scroll count. | Document the gap; widget shows derived metric. Acceptance with product. |
| R11 | **`updatePeriodMillis` must stay 0.** A non-zero value drains battery and is non-parity. | Keep both `res/xml` at `0`. Lint the xml. |
| R12 | **Deep-link param parity** (`widget_source`,`widget_action`,`open_invite`) and events 150/151 fire location. | Test each tap path delivers exact query string and fires correct event (module-12). |

**Event-id reference (verbatim from `mc/a.java`)** — port all with identical names so analytics dashboards survive:

| id | enum name | analytics label | dVar group |
|---|---|---|---|
| 145 | `WIDGET_BOTTOM_SHEET_SHOWN` | "Widget: Bottom Sheet Shown" | dVar2 |
| 146 | `WIDGET_ADD_CTA_CLICKED` | "Widget: Add CTA Clicked" | dVar2 |
| 147 | `WIDGET_PIN_REQUEST_ATTEMPTED` | "Widget: Pin Request Attempted" | dVar2 |
| 148 | `WIDGET_PIN_UNSUPPORTED` | "Widget: Pin Unsupported" | dVar2 |
| 149 | `WIDGET_PIN_CALLBACK_SUCCESS` | "Widget: Pin Callback Success" | dVar2 |
| 150 | `HOME_WIDGET_CLICKED` | "Home Widget: Clicked" | dVar |
| 151 | `DUEL_WIDGET_CLICKED` | "Duel Widget: Clicked" | dVar |
| 88 | `ONBOARDING_ADD_WIDGET_SHOWN` | "Onboarding Add Widget: Shown" | dVar |
| 103 | `ONBOARDING_ADD_WIDGET_CLICKED` | "Onboarding: Add Widget Clicked" | dVar |
| 104 | `ONBOARDING_ADD_WIDGET_NOT_NOW_CLICKED` | "Onboarding Add Widget: Not Now Clicked" | dVar |
| 326 | `ONBOARDING_WIDGET_PIN_UNSUPPORTED_TOAST` | "Onboarding: Widget Pin Unsupported Toast" | dVar3 |
| 327 | `ONBOARDING_WIDGET_PIN_SUCCESS_TOAST` | "Onboarding: Widget Pin Success Toast" | dVar3 |
| 328 | `ONBOARDING_WIDGET_PIN_NOT_ADDED_TOAST` | "Onboarding: Widget Pin Not Added Toast" | dVar3 |
| 356 | `WIDGET_PIN_UNSUPPORTED_TOAST` | "Widget: Pin Unsupported Toast" | dVar3 |
| 357 | `WIDGET_PIN_SUCCESS_TOAST` | "Widget: Pin Success Toast" | dVar3 |
| 358 | `WIDGET_PIN_NOT_ADDED_TOAST` | "Widget: Pin Not Added Toast" | dVar3 |

The `nh.a` logger writes JSON `{"source": <widget_source>}` for event 149 (`nh.a.a(aVar, mc.a.f16506l2, source)`); for the `b(source, reason)` variant it writes `{"source":..., "reason":...}` under event `WIDGET_PIN_UNSUPPORTED` (148). Port this exact JSON.

---

## 11. Open questions

1. **OPEN QUESTION — where are `HOME_WIDGET_CLICKED` (150) / `DUEL_WIDGET_CLICKED` (151) fired?** They are defined in `mc/a.java` but the firing site is the deep-link entry handler in `MainActivity`, which is obfuscated; not confirmed in this module. Resolve in [module-12-deeplinks-routing.md](module-12-messaging-app-shell.md) — confirm `widget_action=open` on `home`/`duel` triggers exactly one of these.
2. **OPEN QUESTION — leaderboard list emission cadence & source.** `be.m1` reads it from `...g().a(LEADERBOARD_ENABLED_OVERRIDE)` plus a friend/profile flow; whether it's backend-synced live or a local snapshot is owned by module-09. Confirm refresh frequency for the widget.
3. **OPEN QUESTION — single-friend `friendReelCount` source.** `c0.b` takes `Integer num` for the friend's count; where it originates (today's duel count vs cached) is not in this module. Confirm in module-09.
4. **OPEN QUESTION — exact "all uninstalled" / dimmed styling semantics** in `sh.n.c`/`sh.n.d` (method bodies decompiled to dumps). The `isUninstalled` flag and the `f15786e`-based `z10` branch select alternate drawables/colors; pixel parity needs the original `n.d` body or a screenshot reference.
5. **OPEN QUESTION — placeholder battle-name strings.** `pe.d.f20026a` references `R.string.battle_invite_{crush,bestie,...}` for teaser rows; the displayed copy must be pulled from `strings.xml` (only the keys are confirmed here).
6. **OPEN QUESTION — iOS data source.** Final decision on what metric the iOS widget shows given no per-scroll count (see module-01). Product sign-off needed.
7. **OPEN QUESTION — `goAsync()` coroutine body in `AppUpdateReceiver`** (`sg.h` case 1) is a dump; confirm it iterates **all** instances of both providers when refreshing.
8. **OPEN QUESTION — does `home_widget` support two distinct provider classes** (compact + expanded) cleanly, or must the port register a custom Android plugin? Validate early; if not, keep a thin custom MethodChannel rather than relying on `home_widget`'s single-provider assumption.

---

## 12. Migration checklist

**Phase A — native core (Kotlin, ported near-verbatim)**
- [ ] Keep `ReelsCounterWidgetReceiver` + `ReelsCounterWidgetExpandedReceiver` (Glance providers) and both `res/xml/reels_counter_widget_*_info.xml` **unchanged** (`updatePeriodMillis=0`, cell sizes, previews).
- [ ] Keep Glance composition `sh.c0` (render + scaling constants) and `sh.n`/`sh.o` (leaderboard + ordinal `h(int)`); verify constants §3.3/§3.6 byte-for-byte.
- [ ] Keep `WidgetVisibilityProvider` (`authorities=com.brainrot.android.widget.provider`, `initOrder=100`) and the Vivo guard (SDK 31/32/33 + "vivo" prefix) in all four sites.
- [ ] Keep `sh.c.b` component enable/disable; `AppUpdateReceiver` (`MY_PACKAGE_REPLACED`) + its refresh coroutine.
- [ ] Keep `qh.a.a` pin wrapper (SDK>=26, `isRequestPinAppWidgetSupported`, request-code `source.hashCode()`, flags 201326592/134217728, action `com.brainrot.android.widget.ACTION_WIDGET_PINNED`, extra `widget_source`) and `WidgetPinResultReceiver`.
- [ ] Keep all Glance manifest entries (trampolines, `GlanceRemoteViewsService`, `MyPackageReplacedReceiver`, `RemoteViewsCompatService`).

**Phase B — channel bridge**
- [ ] Implement `MethodChannel "brainpal/widgets"` with `pushWidgetData` / `refresh` / `requestPinWidget` / `areWidgetsEnabled` (wrap `home_widget` + native pin/Vivo logic).
- [ ] Bridge `WidgetPinResultReceiver` success → Dart (`widget_pinned` payload) for event 149 + toast.
- [ ] Wire snapshot writer: `home_widget` shared prefs (Android) / App Group `UserDefaults` (iOS).
- [ ] Verify against [01-platform-channel-contracts.md](01-platform-channel-contracts.md) (frozen names).

**Phase C — Dart domain/data**
- [ ] Add `WidgetSnapshot` freezed model (§4.7) + json_serializable.
- [ ] `widgetSnapshotProvider` (Riverpod) composing reels stats (module-04) + friend/leaderboard (module-09) + remote flag `leaderboard_enabled_override_v1` (module-14).
- [ ] `WidgetSyncController` — push on snapshot change + `AppLifecycleState.resumed` + `workmanager` periodic (>=15 min). Keep `updatePeriodMillis=0`.
- [ ] Pre-resolve avatar images to file paths in the snapshot (no network URLs into RemoteViews).
- [ ] Port analytics events 145–151, 326–328, 356–358 with identical names + JSON shapes via `firebase_analytics`.

**Phase D — iOS**
- [ ] WidgetKit extension (compact + medium families) reading App Group snapshot; `WidgetCenter.reloadAllTimelines()` from bridge.
- [ ] `.widgetURL` deep links (`brainpal://home` / `brainpal://duel`); route via `app_links` + `go_router`.
- [ ] Make "Add widget" onboarding step instructional on iOS (no programmatic pin); suppress events 149/356–358 (no analogue).
- [ ] Resolve §11 #6 data-source decision.

**Phase E — validation**
- [ ] Vivo matrix (R3), pin flags/request-code (R4/R5), leaderboard gating + self-entry + max-5/ordinals (R6/R7/R8), avatar fallback (R9), `updatePeriodMillis=0` lint (R11), deep-link param + event parity (R12).
- [ ] Kill-process widget-refresh harness (R2); stock-launcher render with app dead (R1).
