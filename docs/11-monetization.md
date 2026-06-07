# Monetization: Subscriptions, Premium Gating & Ads

This document is the rebuild blueprint for the app's money layer: Google Play subscriptions/IAP, the premium entitlement model that drives feature gating (premium-exclusive platforms/apps, AI features, parental features, ad removal), and the AdMob ad stack (banner / native / interstitial / rewarded). It maps every mechanism to a real Flutter/pub.dev package, gives clean Dart models + a `PremiumBloc` + an entitlement repository + a feature-gate helper, and flags the one server-side gap (purchase-token → backend entitlement sync) that the decompiled sources do not expose. The native app uses Google Play Billing + Google Mobile Ads behind Kotlin; in Flutter both are pure-package (`in_app_purchase`, `google_mobile_ads`), so monetization is one of the few subsystems that needs **no** custom `MethodChannel`.

> **Legend:** ✅ a pub.dev package fully handles it · ⚠️ needs a native MethodChannel/EventChannel or platform glue · ❌ not possible on that platform.

---

## 1. Subsystem map (verified)

| Concern | Original (decompiled) | Flutter target | Legend |
| --- | --- | --- | --- |
| Subscription purchase flow | `monetization/purchases/NoScrollBillingService.java` (`BillingClient`, `PurchasesUpdatedListener`) | `in_app_purchase` | ✅ |
| Pending purchases / reconnect | `enablePendingPurchases(...enableOneTimeProducts())`, `enableAutoServiceReconnection()` | `in_app_purchase` (handled internally) | ✅ |
| Active-purchase restore | `NoScrollBillingService.refreshActivePurchases()` (queries Play, body obfuscated) | `InAppPurchase.restorePurchases()` | ✅ |
| Plan catalog / display | `network/.../premium_upgrade/response/Plan.java`, `Category.java` | `PremiumPlan`, `PremiumCategory` entities + repo | ✅ |
| Entitlement / feature flags | `ActivePlanDetails.java`, `ActiveClientPlan.java`, `PlanFeatureSetTable.java` | `Entitlement` entity + `PremiumBloc` | ✅ |
| Full-screen ads | `monetization/advertising/FullScreenAdManager.java` | `google_mobile_ads` (`InterstitialAd`, `RewardedAd`, `RewardedInterstitialAd`) | ✅ |
| Banner / native ads | `advertising/ui/AdmobComposablesKt.java`, `BannerNativeAdHandler.java` | `google_mobile_ads` (`BannerAd`, `NativeAd`) | ✅ |
| Ad config source | `network/.../initialconfig/response/AdmobAdLoader.java`, `AdFormatEnum.java` (from `initial_config`) | `AdSlotConfig` model from remote config | ✅ |
| UMP / GDPR consent | (not present in decompiled sources — see §8) | `google_mobile_ads` `ConsentInformation`/`ConsentForm` | ✅ |
| Purchase analytics | Firebase events in `NoScrollBillingService` | `firebase_analytics` | ✅ |
| Reactive product/purchase state | Kotlin `StateFlow`/`SharedFlow` | Dart `Stream` + bloc | ✅ |
| Purchase-token → backend entitlement sync | **NOT found in decompiled sources** | server call in repository | ⚠️ inferred / TODO (§9) |

---

## 2. Data models (verified field names → clean Dart)

The original models live under `network/data/premium_upgrade/response/`. Field names below are quoted directly from the decompiled `data class` constructors; the Dart names are our own clean equivalents.

### 2.1 `Plan` — catalog entry (server-defined)
Verified fields (`Plan.java`): `planId`, `basePlanId`, `offerId`, `offerTags:List<String>`, `planName`, `planDescription`, `categoryId`, `chips:List<String>`, `planTypeEnum:PlanTypeEnum`, `params:String`, `priority:Int`, `budgetFriendlyTag:Boolean`, `popularTag:Boolean`, `recommendedTag:Boolean`, `value:Boolean`, `planTier:Int`, `featureSetId:String`.

- `basePlanId` + `offerId` are the **Google Play subscription identifiers** passed into the billing flow.
- `featureSetId` is the foreign key into a `PlanFeatureSetTable` row (what the plan unlocks).
- `priority` ascending = display order.

### 2.2 `Category` — plan grouping for the paywall UI
Verified fields (`Category.java`): `categoryId`, `categoryName`, `categoryDescription`, `priority:Int`, `plansType:PlanTypeEnum`.

### 2.3 `PlanFeatureSetTable` — the feature capability matrix (VERIFIED)
Verified fields (`PlanFeatureSetTable.java`): `planId:String`, `blockAds:Boolean`, `onlyPremiumFeatures:Boolean`, `onlyParental:Boolean`, `topTierPlan:Boolean`, `allowAiFeatures:Boolean`. All default to `false`; `planId` defaults to `""`.

`getFeaturesList()` (verified, exact strings) builds UI labels in this order:

| Flag true | Label appended |
| --- | --- |
| `blockAds` | `"Ads Free"` |
| `onlyPremiumFeatures` | `"All Premium Features"` |
| `onlyParental` | `"Parental Features"` |
| `allowAiFeatures` | `"AI Features"` |
| _(list empty)_ | `"Basic Features"` |

### 2.4 `ActiveClientPlan` — one active subscription instance
Verified defaults (`ActiveClientPlan.java`): `planId` default `"ns_basic"`, `planType:PlanTypeEnum` default `FREE`, `expiry:Long` default `-1L` (ms epoch; `-1` = no expiry / free), `purchaseToken:String`, `features:PlanFeatureSetTable`, `isCanceled:Boolean`, `planTier:Int` default `10`, `planName` default `"NoScroll Basic"`, `desc`, `price`, `autoRenewing:Boolean`.

### 2.5 `ActivePlanDetails` — aggregated live entitlement (VERIFIED, mutable)
Verified (`ActivePlanDetails.java`): all flags are mutable `var`s synced at runtime. Constructor order + defaults:

| Field | Default | Drives |
| --- | --- | --- |
| `aiFeatures` | `false` | AI detection / calibration features |
| `blockAds` | `false` | **gates every ad** (banner + full-screen) |
| `premiumFeatures` | `false` | premium-exclusive platforms/apps |
| `parentalFeatures` | `false` | parental-control features |
| `topTierPlan` | `false` | highest-tier (e.g. unlimited rules) |
| `promptUpgrades` | **`true`** | whether to show upsell prompts |
| `plans` | `[ActiveClientPlan(ns_basic, FREE, …)]` | list of active subscriptions |

This is the single object passed to `FullScreenAdManager`, every ad composable, and every feature guard. In Flutter it becomes our immutable `Entitlement` entity, rebuilt (not mutated) whenever the server/billing state changes.

### 2.6 Clean Dart entities

```dart
// domain/entities/premium_plan.dart
enum PlanType { free, monthly, yearly, lifetime } // maps PlanTypeEnum

class PlanFeatureSet {
  final bool blockAds;
  final bool onlyPremiumFeatures;
  final bool onlyParental;
  final bool topTierPlan;
  final bool allowAiFeatures;
  const PlanFeatureSet({
    this.blockAds = false,
    this.onlyPremiumFeatures = false,
    this.onlyParental = false,
    this.topTierPlan = false,
    this.allowAiFeatures = false,
  });

  /// Mirrors PlanFeatureSetTable.getFeaturesList() exact strings.
  List<String> get displayLabels {
    final out = <String>[];
    if (blockAds) out.add('Ads Free');
    if (onlyPremiumFeatures) out.add('All Premium Features');
    if (onlyParental) out.add('Parental Features');
    if (allowAiFeatures) out.add('AI Features');
    if (out.isEmpty) out.add('Basic Features');
    return out;
  }
}

class PremiumPlan {
  final String planId;        // our internal id
  final String basePlanId;    // Google Play base plan id
  final String offerId;       // Google Play offer id
  final List<String> offerTags;
  final String name;
  final String description;
  final String categoryId;
  final List<String> chips;
  final PlanType type;
  final int priority;         // ascending = display order
  final bool budgetFriendly;
  final bool popular;
  final bool recommended;
  final bool highlightValue;  // original "value" flag
  final int tier;
  final String featureSetId;
  const PremiumPlan({
    required this.planId,
    required this.basePlanId,
    required this.offerId,
    this.offerTags = const [],
    required this.name,
    this.description = '',
    required this.categoryId,
    this.chips = const [],
    this.type = PlanType.free,
    this.priority = 0,
    this.budgetFriendly = false,
    this.popular = false,
    this.recommended = false,
    this.highlightValue = false,
    this.tier = 10,
    required this.featureSetId,
  });
}
```

```dart
// domain/entities/entitlement.dart
class ActivePlan {
  final String planId;          // default 'ns_basic'
  final PlanType type;          // default free
  final int expiryEpochMs;      // -1 = none
  final String purchaseToken;
  final PlanFeatureSet features;
  final bool isCanceled;
  final int tier;               // default 10
  final String name;            // default 'NoScroll Basic'
  final String description;
  final String price;
  final bool autoRenewing;
  const ActivePlan({
    this.planId = 'ns_basic',
    this.type = PlanType.free,
    this.expiryEpochMs = -1,
    this.purchaseToken = '',
    this.features = const PlanFeatureSet(),
    this.isCanceled = false,
    this.tier = 10,
    this.name = 'NoScroll Basic',
    this.description = '',
    this.price = '',
    this.autoRenewing = false,
  });
  bool get isActive =>
      expiryEpochMs == -1 || expiryEpochMs > DateTime.now().millisecondsSinceEpoch;
}

/// Immutable equivalent of ActivePlanDetails (we never mutate; we copyWith).
class Entitlement {
  final bool aiFeatures;
  final bool blockAds;
  final bool premiumFeatures;
  final bool parentalFeatures;
  final bool topTierPlan;
  final bool promptUpgrades;   // default true
  final List<ActivePlan> plans;
  const Entitlement({
    this.aiFeatures = false,
    this.blockAds = false,
    this.premiumFeatures = false,
    this.parentalFeatures = false,
    this.topTierPlan = false,
    this.promptUpgrades = true,
    this.plans = const [ActivePlan()],
  });

  /// The free default — matches ActivePlanDetails() no-arg constructor.
  static const free = Entitlement();
  bool get isPremium => plans.any((p) => p.type != PlanType.free && p.isActive);

  Entitlement copyWith({...}) => Entitlement(/* ... */);
}
```

---

## 3. Subscription purchase flow

### 3.1 Original flow (verified from `NoScrollBillingService.java`)
- Client built with `BillingClient.newBuilder(context).setListener(this).enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build()).enableAutoServiceReconnection().build()`.
- Reactive state holders: `_productDetailsMap : StateFlow<Map>` (product cache) and `_activePurchases : SharedFlow<List<Purchase>>` (replay = 1) with read-only wrappers `productDetailsMap` / `activePurchases`.
- `onPurchasesUpdated(BillingResult, List<Purchase>)` is the verified `PurchasesUpdatedListener` callback. Logic (exact):
  1. `responseCode == 0` and list non-null → success path.
  2. `responseCode == 1` → user cancelled → `FirebaseAnalytics.logEvent("premium_purchase_cancelled")`; return.
  3. any other code → log `"premium_purchase_failed"` with bundle `{response_code, debug_message}`; return.
  4. Success: for each `Purchase`, log `"premium_purchase_success"` with `{order_id (or ""), products (comma-joined), state (purchaseState)}`.
  5. Invoke `onPurchasesDetected.invoke(list)` (notifies the view model to sync).
  6. Merge new purchases with the cached replay list, **dedupe by `getPurchaseToken()` via `HashSet`**, then `tryEmit(uniqueList)` on `_activePurchases`.
- `refreshActivePurchases()` launches a coroutine that calls `queryPurchasesAsync` (body obfuscated → inferred) to repopulate `_activePurchases` on app start = the **restore** path.

> Firebase event names are lower-cased via `Locale.ROOT`. The `mFirebaseAnalytics` reference is null-checked before each `logEvent`, so analytics-disabled builds don't crash.

### 3.2 Flutter purchase flow (`in_app_purchase` ✅, iOS ✅)

`in_app_purchase` exposes the same Play Billing primitives cross-platform; on iOS it bridges to StoreKit. Mapping:

| Original | `in_app_purchase` |
| --- | --- |
| `BillingClient` + `PurchasesUpdatedListener` | `InAppPurchase.instance` + `purchaseStream` |
| product cache (`productDetailsMap`) | `queryProductDetails(ids)` → `ProductDetailsResponse` |
| `launchBillingFlow(basePlanId/offerId)` | `buyNonConsumable(PurchaseParam)` (subs are non-consumable) |
| `enablePendingPurchases` | handled internally; emits `PurchaseStatus.pending` |
| `refreshActivePurchases()` | `restorePurchases()` |
| dedupe by purchase token | dedupe by `PurchaseDetails.purchaseID` / verification token |

```dart
// data/datasources/billing_datasource.dart
class BillingDataSource {
  final InAppPurchase _iap = InAppPurchase.instance;
  final _purchaseController = StreamController<List<PurchaseDetails>>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _sub;

  Stream<List<PurchaseDetails>> get purchases => _purchaseController.stream;

  Future<void> init() async {
    if (!await _iap.isAvailable()) return;
    _sub = _iap.purchaseStream.listen(_onPurchaseUpdated, onDone: () => _sub?.cancel());
  }

  Future<List<ProductDetails>> loadProducts(Set<String> productIds) async {
    final resp = await _iap.queryProductDetails(productIds);
    return resp.productDetails;
  }

  Future<void> buy(ProductDetails details) =>
      _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: details));

  Future<void> restore() => _iap.restorePurchases();

  void _onPurchaseUpdated(List<PurchaseDetails> list) {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.canceled:
          // analytics: 'premium_purchase_cancelled'
          break;
        case PurchaseStatus.error:
          // analytics: 'premium_purchase_failed' {response_code, debug_message}
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // analytics: 'premium_purchase_success' {order_id, products, state}
          break;
        case PurchaseStatus.pending:
          break;
      }
      if (p.pendingCompletePurchase) _iap.completePurchase(p); // ack
    }
    final unique = {for (final p in list) p.purchaseID ?? p.verificationData.serverVerificationData: p}
        .values.toList(); // dedupe (mirrors HashSet<purchaseToken>)
    _purchaseController.add(unique);
  }
}
```

> **iOS:** `in_app_purchase` works (StoreKit). There is no notion of `basePlanId`/`offerId`; iOS subscription groups/offers are configured in App Store Connect and selected by product id. Keep the abstraction at "product id" in the repository.

### 3.3 Billing-period parsing (verified helpers)

`PremiumPurchaseHelperKt` parses `ProductDetails.PricingPhase.billingPeriod` (ISO-8601). Re-implement cleanly in Dart:

```dart
// domain/usecases/format_billing_period.dart
/// getPlanFrequency() equivalent — substring match on ISO-8601 period.
String planFrequencySuffix(String period, {bool short = true}) {
  if (period.contains('P1M')) return short ? '/mo' : '/month';
  if (period.contains('P1Y')) return short ? '/yr' : '/year';
  if (period.contains('P1W')) return short ? '/wk' : '/week';
  if (period.contains('P1D')) return '/day';
  return '';
}

/// humanizeBillingPeriod() equivalent — regex extract count*cycles.
String humanizeBillingPeriod(String period, int cycleCount) {
  if (period.isEmpty || cycleCount <= 0) return '';
  final m = RegExp(r'P(\d+)([DWMY])').firstMatch(period);
  if (m == null) return '';
  final value = int.parse(m.group(1)!) * cycleCount;
  const units = {'D': 'day', 'W': 'week', 'M': 'month', 'Y': 'year'};
  final unit = units[m.group(2)]!;
  return '$value $unit${value == 1 ? '' : 's'}';
}

/// isFreeTrialOffer() — first phase priced 0 AND >1 phase.
bool isFreeTrialOffer(List<PricingPhase> phases) =>
    phases.length > 1 && phases.first.priceAmountMicros == 0;
```

---

## 4. Premium gating & the feature matrix

### 4.1 Verified gating semantics
- The native app gates by reading the live `ActivePlanDetails` flags (verified workflow in `monetization.json`, step group "System checks if feature is premium-gated"):
  - `parentalFeatures` / `premiumFeatures` / `aiFeatures` → if `false`, render an **Upgrade** overlay or disable the UI element.
  - `blockAds` → **orthogonal**: independently gates ad rendering, not other features.
  - `topTierPlan` → gates highest-tier features (e.g. unlimited parental rules).
- Per-platform / per-app premium exclusivity (`premiumExclusive` in the detection config) is checked against `premiumFeatures`. See `08-detection-config.md` for where `premiumExclusive` lives in `platforms_config.json`.

### 4.2 Feature matrix (Plan → capability)

| Capability | Source flag | Gate input | Effect when locked |
| --- | --- | --- | --- |
| Remove all ads | `PlanFeatureSetTable.blockAds` → `Entitlement.blockAds` | every ad widget/manager | show ad / show paywall slot |
| Premium platforms & apps | `onlyPremiumFeatures` → `premiumFeatures` | platform/app `premiumExclusive` | overlay "Upgrade to unlock" |
| Parental controls | `onlyParental` → `parentalFeatures` | parental screens | disabled + upsell |
| AI detection/calibration | `allowAiFeatures` → `aiFeatures` | AI feature toggles | disabled + upsell |
| Top-tier (unlimited rules) | `topTierPlan` → `topTierPlan` | quota-limited features | cap at free limit |
| Show upgrade prompts | n/a | `promptUpgrades` | suppress upsell UI if `false` |

### 4.3 Gating helper (clean Dart)

```dart
// domain/entities/premium_feature.dart
enum PremiumFeature { adsFree, premiumContent, parental, ai, topTier }

// presentation/utils/entitlement_gate.dart
extension EntitlementGate on Entitlement {
  bool can(PremiumFeature f) => switch (f) {
        PremiumFeature.adsFree        => blockAds,
        PremiumFeature.premiumContent => premiumFeatures,
        PremiumFeature.parental       => parentalFeatures,
        PremiumFeature.ai             => aiFeatures,
        PremiumFeature.topTier        => topTierPlan,
      };

  /// Should this platform/app (premiumExclusive) be usable?
  bool canUsePremiumContent(bool premiumExclusive) =>
      !premiumExclusive || premiumFeatures;
}

// presentation/widgets/feature_gate.dart
class FeatureGate extends StatelessWidget {
  final PremiumFeature feature;
  final Widget child;
  final Widget Function(BuildContext)? lockedBuilder;
  const FeatureGate({super.key, required this.feature, required this.child, this.lockedBuilder});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PremiumBloc, PremiumState, bool>(
      selector: (s) => s.entitlement.can(feature),
      builder: (ctx, unlocked) => unlocked
          ? child
          : (lockedBuilder?.call(ctx) ?? const UpgradeOverlay()),
    );
  }
}
```

---

## 5. PremiumBloc + entitlement repository

```dart
// domain/repositories/premium_repository.dart
abstract class PremiumRepository {
  Future<List<PremiumCategory>> loadCatalog();   // Plan + Category from server/cache
  Future<List<PremiumPlan>> loadPlans();
  Future<void> purchase(PremiumPlan plan);       // -> billing flow
  Future<void> restore();
  Stream<Entitlement> watchEntitlement();        // resolved live state
}
```

```dart
// presentation/bloc/premium_event.dart
sealed class PremiumEvent {}
class PremiumStarted extends PremiumEvent {}
class PremiumCatalogRequested extends PremiumEvent {}
class PremiumPurchaseRequested extends PremiumEvent { final PremiumPlan plan; PremiumPurchaseRequested(this.plan); }
class PremiumRestoreRequested extends PremiumEvent {}
class _EntitlementChanged extends PremiumEvent { final Entitlement e; _EntitlementChanged(this.e); }

// presentation/bloc/premium_state.dart
class PremiumState {
  final Entitlement entitlement;       // defaults to Entitlement.free
  final List<PremiumCategory> catalog;
  final bool purchasing;
  final String? error;
  const PremiumState({
    this.entitlement = Entitlement.free,
    this.catalog = const [],
    this.purchasing = false,
    this.error,
  });
  bool get isPremium => entitlement.isPremium;
  PremiumState copyWith({...}) => PremiumState(/* ... */);
}
```

```dart
// presentation/bloc/premium_bloc.dart
class PremiumBloc extends Bloc<PremiumEvent, PremiumState> {
  final PremiumRepository repo;
  StreamSubscription<Entitlement>? _entSub;

  PremiumBloc(this.repo) : super(const PremiumState()) {
    on<PremiumStarted>((e, emit) {
      _entSub = repo.watchEntitlement().listen((ent) => add(_EntitlementChanged(ent)));
    });
    on<_EntitlementChanged>((e, emit) => emit(state.copyWith(entitlement: e.e)));

    on<PremiumCatalogRequested>((e, emit) async {
      emit(state.copyWith(error: null));
      try {
        emit(state.copyWith(catalog: await repo.loadCatalog()));
      } catch (err) {
        emit(state.copyWith(error: '$err'));
      }
    });

    on<PremiumPurchaseRequested>((e, emit) async {
      emit(state.copyWith(purchasing: true, error: null));
      try {
        await repo.purchase(e.plan); // entitlement update arrives via stream
      } catch (err) {
        emit(state.copyWith(error: '$err'));
      } finally {
        emit(state.copyWith(purchasing: false));
      }
    });

    on<PremiumRestoreRequested>((e, emit) => repo.restore());
  }

  @override
  Future<void> close() { _entSub?.cancel(); return super.close(); }
}
```

The repository resolves `Entitlement` by merging (a) the active purchases stream from `BillingDataSource` with (b) the server's plan/feature-set tables (matching `purchaseToken`/product id → `PlanFeatureSetTable`). The free default is `Entitlement.free`, mirroring the no-arg `ActivePlanDetails()`.

---

## 6. Ads: AdMob stack

### 6.1 Ad config (verified)
- `AdmobAdLoader.java` (from `initial_config`): `adTag:String` (the AdMob unit id) + `adType:AdFormatEnum`. **Verified default unit id:** `ca-app-pub-1071824559641088/8442330639`; default `adType` = `LARGE_BANNER`.
- `AdFormatEnum.java` (VERIFIED). Note the constructor quirk: the first five use the default-flag form so `isBannerAd` resolves to **`true`**; the last four pass explicit `false`:

| Ordinal | Value | `isBannerAd` | Renders as |
| --- | --- | --- | --- |
| 0 | `LARGE_BANNER` | true | `BannerAd` @ `AdSize.largeBanner` |
| 1 | `BANNER` | true | `BannerAd` @ `AdSize.banner` |
| 2 | `RECTANGLE` | true | `BannerAd` @ `AdSize.mediumRectangle` |
| 3 | `NATIVE_SMALL` | true* | `NativeAd` (small variant) |
| 4 | `NATIVE_NORMAL` | true* | `NativeAd` (normal variant) |
| 5 | `INTERSTITIAL` | false | full-screen |
| 6 | `REWARDED` | false | full-screen |
| 7 | `REWARDED_INTERSTITIAL` | false | full-screen |
| 8 | `APP_OPEN` | false | app-open |

\* Native entries technically carry `isBannerAd=true` from the default-flag constructor, but the routing in `NSBanner` switches on the **enum value** (not the flag) to send `NATIVE_*` to the native renderer. Treat `isBannerAd` as "renders inline" and switch on the explicit enum for the exact widget.

```dart
// domain/entities/ad_slot.dart
enum AdFormat { largeBanner, banner, rectangle, nativeSmall, nativeNormal,
                interstitial, rewarded, rewardedInterstitial, appOpen }

extension AdFormatX on AdFormat {
  bool get isInline => switch (this) {
        AdFormat.interstitial || AdFormat.rewarded ||
        AdFormat.rewardedInterstitial || AdFormat.appOpen => false,
        _ => true,
      };
}

class AdSlotConfig {
  final String adTag;     // AdMob unit id; default below
  final AdFormat format;  // default largeBanner
  const AdSlotConfig({
    this.adTag = 'ca-app-pub-1071824559641088/8442330639',
    this.format = AdFormat.largeBanner,
  });
}
```

### 6.2 Full-screen ads — `FullScreenAdManager` (verified lifecycle)

`FullScreenAdManager.java` load/show, with `ActivePlanDetails.blockAds` as the master gate.

**Load (verified steps):**
1. If `blockAds == true` → skip, return.
2. If `adTag` already in `loadingStates` set → skip (dedupe concurrent loads).
3. Add `adTag` to `loadingStates`; build `AdRequest`.
4. Switch on format: `INTERSTITIAL → InterstitialAd.load`, `REWARDED → RewardedAd.load`, `REWARDED_INTERSTITIAL → RewardedInterstitialAd.load`.
5. `onAdLoaded` → store in `loadedAds[adTag]` (a `LinkedHashMap`), remove from `loadingStates`, fire `callback.onAdLoaded(showLambda)`.
6. `onAdFailedToLoad` → remove from `loadingStates`, fire `callback.onAdFailedToLoad(message)`.

**Show (verified steps):**
1. If `blockAds == true` → skip.
2. Look up `loadedAds[adTag]`; if null → log warning, `callback.onAdFailedToShow("No ad ready")`, return.
3. Attach `FullScreenContentCallback`:
   - `onAdDismissedFullScreenContent` → remove from cache; if `INTERSTITIAL` → `onAdCompleted()` **and** `onAdDismissed()`; else → `onAdDismissed()`.
   - `onAdFailedToShowFullScreenContent` → remove ad, `onAdFailedToShow(adError.message)`.
4. For `REWARDED` / `REWARDED_INTERSTITIAL` attach `OnUserEarnedRewardListener`; on reward → `onAdCompleted()`.
5. `ad.show(activity)` (or `ad.show(activity, rewardListener)`).

Flutter equivalent with `google_mobile_ads` ✅:

```dart
// data/datasources/full_screen_ad_manager.dart
class FullScreenAdManager {
  final _loaded = <String, Object>{};      // LinkedHashMap -> insertion order
  final _loading = <String>{};

  Future<void> load(AdSlotConfig slot, Entitlement ent,
      {required void Function() onLoaded, required void Function(String) onFailed}) async {
    if (ent.blockAds) return;               // step 1
    if (!_loading.add(slot.adTag)) return;  // step 2/3 (Set.add false = present)
    final req = const AdRequest();
    switch (slot.format) {
      case AdFormat.interstitial:
        InterstitialAd.load(adUnitId: slot.adTag, request: req,
          adLoadCallback: InterstitialAdLoadCallback(
            onAdLoaded: (ad) { _loaded[slot.adTag] = ad; _loading.remove(slot.adTag); onLoaded(); },
            onAdFailedToLoad: (e) { _loading.remove(slot.adTag); onFailed(e.message); }));
      case AdFormat.rewarded:
        RewardedAd.load(adUnitId: slot.adTag, request: req,
          rewardedAdLoadCallback: RewardedAdLoadCallback(
            onAdLoaded: (ad) { _loaded[slot.adTag] = ad; _loading.remove(slot.adTag); onLoaded(); },
            onAdFailedToLoad: (e) { _loading.remove(slot.adTag); onFailed(e.message); }));
      case AdFormat.rewardedInterstitial:
        RewardedInterstitialAd.load(adUnitId: slot.adTag, request: req,
          rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
            onAdLoaded: (ad) { _loaded[slot.adTag] = ad; _loading.remove(slot.adTag); onLoaded(); },
            onAdFailedToLoad: (e) { _loading.remove(slot.adTag); onFailed(e.message); }));
      default: _loading.remove(slot.adTag);
    }
  }

  void show(String adTag, AdFormat format, Entitlement ent,
      {void Function()? onCompleted, void Function()? onDismissed,
       void Function(String)? onFailedToShow}) {
    if (ent.blockAds) return;
    final ad = _loaded.remove(adTag);
    if (ad == null) { onFailedToShow?.call('No ad ready'); return; }

    void wireFullScreen(dynamic a) {
      a.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (a2) {
          a2.dispose();
          if (format == AdFormat.interstitial) onCompleted?.call();
          onDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (a2, e) { a2.dispose(); onFailedToShow?.call(e.message); },
      );
    }

    if (ad is InterstitialAd) { wireFullScreen(ad); ad.show(); }
    else if (ad is RewardedAd) { wireFullScreen(ad); ad.show(onUserEarnedReward: (_, __) => onCompleted?.call()); }
    else if (ad is RewardedInterstitialAd) { wireFullScreen(ad); ad.show(onUserEarnedReward: (_, __) => onCompleted?.call()); }
  }
}
```

### 6.3 Banner & native ads (verified routing)

`AdmobComposablesKt.NSBanner()` (verified):
1. If `blockAds == true` → render empty; return.
2. If `format.isBannerAd == false` (full-screen) → render empty; return.
3. Switch on enum → `LARGE_BANNER`/`BANNER`/`RECTANGLE` → `AdmobBanner(adTag, AdSize)`, `NATIVE_SMALL`/`NATIVE_NORMAL` → `AdmobNativeAd(adTag, variant)`.

`NativeAdVariant` (verified): `SMALL` (compact), `NORMAL` (full).

Native-ad **fallback placeholder** (verified): when icon/headline/body/CTA are null, defaults are `'Ad Icon'`, `'Ad Headline'`, `'This is a sample ad description body text.'`, `'Learn More'`; an offline placeholder renders the `ic_noscroll` logo + the text `"NoScroll"` in a dimmed ~20sp font on a semi-transparent surface, 24dp rounded corners.

`BannerNativeAdHandler.bannerCache` (verified): a static `LinkedHashMap` keyed per slot holding a `CachedBannerAd { AdView, FrameLayout }` so banners survive recomposition.

```dart
// presentation/widgets/ns_banner.dart
class NSBanner extends StatelessWidget {
  final AdSlotConfig slot;
  const NSBanner({super.key, required this.slot});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PremiumBloc, PremiumState, bool>(
      selector: (s) => s.entitlement.blockAds,
      builder: (ctx, blockAds) {
        if (blockAds || !slot.format.isInline) return const SizedBox.shrink(); // steps 1-2
        return switch (slot.format) {                                          // step 3
          AdFormat.largeBanner => _BannerSlot(slot.adTag, AdSize.largeBanner),
          AdFormat.banner      => _BannerSlot(slot.adTag, AdSize.banner),
          AdFormat.rectangle   => _BannerSlot(slot.adTag, AdSize.mediumRectangle),
          AdFormat.nativeSmall => _NativeSlot(slot.adTag, NativeTemplateType.small),
          AdFormat.nativeNormal=> _NativeSlot(slot.adTag, NativeTemplateType.medium),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}
```

> **Caching:** `google_mobile_ads` `BannerAd`/`NativeAd` are stateful objects you must `load()` once and `dispose()` when done. Hold them in a `StatefulWidget`'s state (or a small cache keyed by `adTag`) to mirror `bannerCache` — never rebuild the ad on every `build()`.

---

## 7. Rewarded-unlock pattern

Verified intent: rewarded / rewarded-interstitial ads exist (`AdFormatEnum.REWARDED`, `REWARDED_INTERSTITIAL`) and `FullScreenAdManager` fires `onAdCompleted()` on `OnUserEarnedRewardListener`. The reward is routed back to the view model (interaction: `FullScreenAdManager -> HomeViewModel callback: onAdCompleted()`), which then grants a temporary feature unlock.

```dart
// domain/usecases/unlock_with_rewarded_ad.dart
class UnlockWithRewardedAd {
  final FullScreenAdManager ads;
  final PremiumRepository repo;
  UnlockWithRewardedAd(this.ads, this.repo);

  Future<bool> call(AdSlotConfig rewardedSlot, Entitlement ent) async {
    final completer = Completer<bool>();
    ads.show(rewardedSlot.adTag, AdFormat.rewarded, ent,
      onCompleted: () => completer.complete(true),    // user earned reward
      onDismissed: () { if (!completer.isCompleted) completer.complete(false); },
      onFailedToShow: (_) => completer.complete(false));
    final earned = await completer.future;
    if (earned) {
      // grant temporary unlock locally; (inferred) sync to backend if a token exists
    }
    return earned;
  }
}
```

> **(inferred / TODO):** The decompiled sources **do not** show where a rewarded unlock or a subscription purchase token is POSTed to the backend to mint server-side entitlement. Plan a `repo.syncPurchaseToken(token)` call (§9) and decide whether rewarded unlocks are local-only or server-tracked.

---

## 8. UMP / GDPR consent

No UMP/consent code was found in the decompiled monetization sources (likely initialized elsewhere or absent). For a compliant rebuild, gather consent **before** `MobileAds.initialize()` using `google_mobile_ads`' bundled UMP SDK ✅:

```dart
// data/datasources/ad_consent.dart
Future<void> ensureConsentThenInitAds() async {
  final params = ConsentRequestParameters();
  final done = Completer<void>();
  ConsentInformation.instance.requestConsentInfoUpdate(params, () async {
    if (await ConsentInformation.instance.isConsentFormAvailable()) {
      ConsentForm.loadAndShowConsentFormIfRequired((_) => done.complete());
    } else { done.complete(); }
  }, (_) => done.complete());
  await done.future;
  await MobileAds.instance.initialize();
}
```

> **iOS:** also call App Tracking Transparency before ads. UMP handles GDPR; ATT (via `app_tracking_transparency`) handles iOS tracking consent. Both are required for compliant iOS ads.

---

## 9. Backend purchase-token sync (inferred / TODO)

The `onPurchasesDetected` callback hands the `Purchase` list to the view model, and `monetization.json`'s success workflow asserts step 8 = "HomeViewModel syncs purchase token to backend, receives updated `ActivePlanDetails`". However, **the actual network call is not present in the decompiled monetization classes** — it lives in the (obfuscated) view model / network layer. For the rebuild:

```dart
// in PremiumRepositoryImpl.purchase / _onPurchaseUpdated
Future<Entitlement> _resolveEntitlement(PurchaseDetails p) async {
  // 1. (TODO) verify token server-side: POST {productId, purchaseToken, platform}
  //    -> server validates with Google Play Developer API / App Store Server API
  // 2. server returns the PlanFeatureSetTable for that plan
  // 3. build immutable Entitlement from returned flags
  // Until the backend contract is known, fall back to local feature-set lookup
  // keyed by productId. (inferred)
}
```

**Security note:** never trust client-side `blockAds`/`premiumFeatures` flags alone for paid content — validate the purchase token on the server. The decompiled app resolves features client-side from `ActivePlanDetails`; treat that as a UX hint, gate value server-side.

---

## 10. Cross-platform summary

| Feature | Android | iOS |
| --- | --- | --- |
| Subscriptions / IAP | ✅ `in_app_purchase` (Play Billing) | ✅ `in_app_purchase` (StoreKit) |
| Restore purchases | ✅ `restorePurchases()` | ✅ `restorePurchases()` |
| Banner / native ads | ✅ `google_mobile_ads` | ✅ `google_mobile_ads` |
| Interstitial / rewarded | ✅ `google_mobile_ads` | ✅ `google_mobile_ads` |
| UMP / GDPR consent | ✅ UMP | ✅ UMP + ATT (`app_tracking_transparency`) |
| Purchase analytics | ✅ `firebase_analytics` | ✅ `firebase_analytics` |
| Feature gating | ✅ pure Dart (`Entitlement`) | ✅ pure Dart (`Entitlement`) |

Monetization needs **no** `MethodChannel` — unlike the detection/blocking subsystems, both billing and ads are fully covered by pub packages on both platforms.

---

## Source evidence

This document is based on direct reads of:
- `sources/com/newswarajya/noswipe/reelshortblocker/monetization/purchases/NoScrollBillingService.java` (verified: `onPurchasesUpdated`, Firebase events, token dedupe, `enablePendingPurchases`/`enableAutoServiceReconnection`)
- `sources/com/newswarajya/noswipe/reelshortblocker/monetization/advertising/FullScreenAdManager.java` (load/show lifecycle, `blockAds` gate)
- `sources/com/newswarajya/noswipe/reelshortblocker/monetization/advertising/ui/AdmobComposablesKt.java` (`NSBanner` routing, native fallback)
- `sources/com/newswarajya/noswipe/reelshortblocker/monetization/advertising/BannerNativeAdHandler.java` (banner cache)
- `sources/com/newswarajya/noswipe/reelshortblocker/monetization/advertising/ui/NativeAdVariant.java`
- `sources/com/newswarajya/noswipe/reelshortblocker/network/data/initialconfig/response/AdmobAdLoader.java` (verified default unit id `ca-app-pub-1071824559641088/8442330639`)
- `sources/com/newswarajya/noswipe/reelshortblocker/network/data/initialconfig/response/AdFormatEnum.java` (verified enum + `isBannerAd`)
- `sources/com/newswarajya/noswipe/reelshortblocker/network/data/premium_upgrade/response/{Plan,Category,PlanFeatureSetTable,ActiveClientPlan,ActivePlanDetails}.java` (verified field names/defaults; `getFeaturesList()` strings)
- `sources/com/newswarajya/noswipe/reelshortblocker/activities/home/compose/premium/helpers/PremiumPurchaseHelperKt.java` (billing-period parsing, free-trial detection)
- Cached analysis: `/tmp/ns_analysis/monetization.json`

Obfuscated/skipped bodies (`refreshActivePurchases` coroutine, `onPremiumGateRendered`, backend token sync) are labeled **(inferred)**.

## Related docs
- `08-detection-config.md` — where `premiumExclusive` lives in `platforms_config.json` (premium content gating input)
- `09-remote-config.md` — `initial_config` delivery of `AdmobAdLoader` ad slots and plan catalog
- `10-analytics-logging.md` — Firebase event taxonomy (`premium_purchase_*`)
- `12-app-architecture.md` — where `PremiumBloc` and the entitlement repository sit in Clean Architecture
- `02-native-boundary.md` — why monetization is the rare subsystem needing no MethodChannel
