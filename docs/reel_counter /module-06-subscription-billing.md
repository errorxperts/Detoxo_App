# Module: Subscription, Paywall & Billing

> Source of truth for channel names: [01-platform-channel-contracts.md](01-platform-channel-contracts.md).
> Sibling docs: [02-backend-api-contract.md](02-backend-api-contract.md), [module-05-auth-identity.md](module-08-account-feedback.md), [module-07-premium-gating.md](module-06-subscription-billing.md), [module-09-challenges-unlock.md](module-02-overlays-floating-bubble.md).
> App: **BrainPal** `com.brainrot.android` v**7.1.340**.

---

## 1. Purpose & scope

This module owns everything that turns a free user into a paying "Plus" user and keeps that entitlement in sync:

- **Paywall** product display (monthly / yearly / yearly-offer) and A/B `paywall_variant` plumbing.
- **Checkout** via **Razorpay** (PRIMARY, live key, native `CheckoutActivity` UPI-intent flow) with a **Play Billing / RevenueCat** path (fallback / state source of truth).
- **Subscription state** derived from the **RevenueCat SDK** entitlement `plus` -> `isPlusUser` (the binary premium gate consumed by [module-07-premium-gating.md](module-06-subscription-billing.md)).
- **Custom payments backend** ("Regain Payments Service", `ai.regainapp.payments`) for order setup, **order-status polling**, cancel + refund.
- **Free-trial** tracking (`created_from_free_trial`).
- **Back-press yearly offer**: a scratch-card discount shown on app exit, with an `AlarmManager`-scheduled **offer-expiry countdown notification** (`BackPressOfferExpiryNotificationReceiver`).
- **Post-setup offer**, **welcome-expiry** window, **restore-on-reinstall**.

**Out of scope (cross-linked):** the actual feature gating decisions (07), the NFC/physical unlock challenges shown on the subscription-success page (09), auth/`brUserId` identity that seeds the RevenueCat app-user-id (05).

> **THE LOAD-BEARING ARCHITECTURE NOTE.** Unlike the detection/overlay/widget modules, billing is **mostly portable**. The one hard native dependency is the Razorpay **UPI-intent** checkout (`CheckoutActivity` calls `BaseRazorpay.getAppsWhichSupportUpi` / `getAppsWhichSupportAutoPayIntent` and drives an in-process WebView), which `razorpay_flutter` reimplements. The back-press **offer-expiry alarm + notification** is Android-only OS integration but has clean Flutter equivalents (`flutter_local_notifications` zoned schedule). On **iOS** there is **no Razorpay-native-UPI and no AccessibilityService-gated success page**; iOS billing must run through StoreKit2 / `in_app_purchase` (App Store rules forbid Razorpay for digital goods), and the iOS premium gate is a StoreKit entitlement, not a RevenueCat-on-Play entitlement. See §6.

---

## 2. Migration verdict

**Overall: DART+CHANNEL** (business/data/state in Dart; checkout SDK + offer alarm behind plugins/channel).

| Concern | Android verdict | iOS verdict |
|---|---|---|
| Subscription state model + gating (`isPlusUser`) | **PURE-DART** domain; data layer fed by RevenueCat/StoreKit + backend | **PURE-DART** domain (same), fed by StoreKit2 entitlement |
| Razorpay checkout (UPI intent, WebView) | **DART+PLUGIN** `razorpay_flutter` (reimplements `CheckoutActivity`) | **NOT POSSIBLE** — App Store bans Razorpay for digital subs; use `in_app_purchase` (StoreKit2) |
| Regain Payments backend (`/payments/*`) | **PURE-DART** dio+retrofit | **PURE-DART** (same endpoints; provider differs) |
| RevenueCat entitlement read | **DART+PLUGIN** (`purchases_flutter`) OR keep custom backend status as truth (see §11 OQ-1) | **DART+PLUGIN** (`purchases_flutter`) |
| Order-status polling (`300000ms`) | **PURE-DART** timer/loop | **PURE-DART** (or StoreKit transaction listener instead) |
| Back-press offer eligibility + cooldown math | **PURE-DART** | **PURE-DART** |
| Back-press **offer-expiry notification alarm** | **DART+PLUGIN** `flutter_local_notifications` zonedSchedule (replaces `AlarmManager` + `BackPressOfferExpiryNotificationReceiver`) | **DART+PLUGIN** `flutter_local_notifications` (UNUserNotificationCenter) |
| Subscription-success NFC/physical-challenge page | **KEEP-NATIVE** (challenge core, see [module-09-challenges-unlock.md](module-02-overlays-floating-bubble.md)) | challenge UI re-implemented; no AccessibilityService gate |

**Rationale.** Nothing in this module needs a multi-window overlay or AccessibilityService except the success-page challenge hand-off (which belongs to module 09). The Razorpay UPI flow is the only piece that genuinely requires a native SDK on Android, and `razorpay_flutter` wraps the same `com.razorpay:checkout` library this app already ships. The alarm is trivially replaced by zoned local notifications. RevenueCat (`purchases_flutter`) is a drop-in.

---

## 3. Business logic & algorithms

### 3.1 VERBATIM config constants — `res/xml/rc_defaults.xml` (Firebase Remote Config defaults)

These are read at runtime via the obfuscated accessor `on.b.e().f("KEY")` / `.g("KEY")` (Firebase Remote Config; rc_defaults are the *fallback* values). Re-confirmed verbatim:

| Remote-Config key | Default value | Meaning |
|---|---|---|
| `RC_PUBLIC_SDK_KEY` | *(empty)* | RC SDK key NOT supplied via RC; hardcoded in code instead (see 3.2) |
| `RC_ENTITLEMENT_ID` | `plus` | entitlement whose `isActive()` == `isPlusUser` |
| `RC_MONTHLY_PRODUCT_ID` | `monthly` | monthly product identifier |
| `RC_YEARLY_PRODUCT_ID` | `yearly` | yearly product identifier |
| `RC_YEARLY_OFFER_PRODUCT_ID` | `yearly_offer` | discounted yearly product for back-press offer |
| `PLUS_SUBSCRIPTION_WELCOME_EXPIRY_MINUTES` | `180` | welcome/"just subscribed" window (minutes) |
| `SHOULD_SHOW_BACK_PRESS_YEARLY_OFFER` | `true` | master switch for the back-press scratch offer |
| `BACK_PRESS_YEARLY_OFFER_EXPIRY_MINUTES` | `60` | how long a shown offer stays valid |
| `BACK_PRESS_YEARLY_OFFER_BUFFER_MINUTES` | `60` | grace buffer added before scheduling/expiry math |
| `BACK_PRESS_YEARLY_OFFER_COOLDOWN_MINUTES` | `4320` | min gap between offers (4320 min = 3 days) |
| `CHECKOUT_OPTIMIZATION_TTL_IN_MILLIS` | `600000` | checkout-optimization cache TTL (10 min) |
| `REMOTE_CONFIG_FETCH_INTERVAL_IN_SECS` | `3600` | RC fetch interval |
| `PRIVACY_POLICY_URL` | `https://brainpalapp.ai/legal/privacy-policy` | |
| `TERMS_OF_SERVICE_URL` | `https://brainpalapp.ai/legal/terms-of-use` | |
| `PART_OF_GATEWAY_EXPERIMENT` | `DEFAULT_LOCAL` | payment-gateway A/B bucket |

> **VERBATIM accessor proof** (`sources/kc/a.java`): the buffer constant resolves to **minutes -> ms** as `(value)*60*1000`, defaulting to **60** when unset/<0:
> ```java
> long jF = bVarE.f("BACK_PRESS_YEARLY_OFFER_BUFFER_MINUTES");
> Long lValueOf = (jF < 0) ? null : jF;
> return (lValueOf != null ? lValueOf : 60L) * 60 * 1000;   // minutes -> millis
> ```
> and the offer product id defaults to `"yearly_offer"`:
> ```java
> String strG = bVarE.g("RC_YEARLY_OFFER_PRODUCT_ID");
> return aq.j.b0(strG) ? "yearly_offer" : strG;
> ```

### 3.2 VERBATIM payment keys

- **Razorpay LIVE key** (`sources/lc/a.java` line 42, set in `onCreate` before constructing `Razorpay`):
  ```java
  this.f1193l0 = "rzp_live_SxX4XCM7fABMgJ";
  this.T = new Razorpay(this, this.f1193l0);
  ```
  > **SECURITY OPEN QUESTION (OQ-9):** a *live* publishable Razorpay key is hardcoded in the binary. Keep it client-side (publishable keys are designed to be public) but verify the *secret* never ships; orders are created server-side via `/payments/subscriptions/setup`. Do not regress this to embedding a secret.
- **RevenueCat Google SDK key** (`sources/zg/i.java` line 247, the ACTUAL configure call — note `RC_PUBLIC_SDK_KEY` is empty, the key is hardcoded):
  ```java
  Purchases.Companion.configure(
      new PurchasesConfiguration.Builder(context, "goog_UIUiLbfHWbfqpKdefquYdBHGDTS")
          .diagnosticsEnabled(true).build());
  ```

### 3.3 RevenueCat IS wired — it is the subscription-state source of truth (resolves the cached OPEN QUESTION)

`sources/zg/i.java` ("SubscriptionStateManager") confirms RevenueCat is **fully integrated**, not merely evaluated:

- `Purchases.configure(...)` is called with key `goog_UIUiLbfHWbfqpKdefquYdBHGDTS` (3.2).
- An `UpdatedCustomerInfoListener` is registered; every `CustomerInfo` update calls `j(CustomerInfo)`.
- On auth login it calls `Purchases.awaitLogIn(brUserId)` (the RC app-user-id == auth `brUserId` from [module-05-auth-identity.md](module-08-account-feedback.md)); on logout `awaitLogOut`; refresh via `awaitCustomerInfo(CacheFetchPolicy)`.
- RC custom attributes are set: `$displayName`, `$email`, `brUserId`, `$deviceVersion` = `"<MANUFACTURER> <MODEL> (API <SDK_INT>)"`, `$mixpanelDistinctId`, `appVersion` = `"7.1.340"` (VERBATIM).

**The gating algorithm** (`j(CustomerInfo)`, VERBATIM pseudocode from `sources/zg/i.java` lines 619–704):

```text
fun onCustomerInfo(ci):
    activeEntitlements = ci.entitlements.active            # Map<String, EntitlementInfo>
    entId = RemoteConfig.get("RC_ENTITLEMENT_ID")
    if entId.isBlank(): entId = "plus"
    ent = activeEntitlements[entId]                         # may be null

    isPlusUser  = ent != null && ent.isActive()
    appUserId   = ci.originalAppUserId
    productId   = ent?.productIdentifier
    willRenew   = ent != null && ent.willRenew
    expiration  = ent?.expirationDate
    mgmtUrl     = ci.managementURL
    origPurchase= ent?.originalPurchaseDate

    # subscriptionType label derived from product PLAN identifier:
    plan = ent?.productPlanIdentifier
    subscriptionType =
        if plan contains "yearly"/"annual" (ci) -> "Yearly"
        elif plan contains "monthly" (ci)       -> "Monthly"
        else plan

    state = SubscriptionState(isPlusUser, appUserId, productId, willRenew,
                              lastUpdatedAtMs = now(), expiration,
                              subscriptionType, mgmtUrl, origPurchase)
    publish(state)

    # analytics props mirrored to nb.a (mixpanel/firebase keys mc.a.*):
    set("is_plus_user" = isPlusUser)
    set("...flag" = false)
    set("subscription_type" = subscriptionType ?: "none")
    set("...value" = isPlusUser ? (subscriptionType ?: "unknown") : "0")

    # transition side-effects:
    if (wasPlus && !isPlusUser): launch downgrade-side-effect coroutine
    if (!wasPlus && isPlusUser):  launch upgrade-side-effect coroutine
```

> **So the dual-stack split is:** **RevenueCat** owns *entitlement truth* (`isPlusUser`, expiration, willRenew, managementURL); the **Regain backend + Razorpay** own *checkout / order lifecycle / cancel+refund*. They are joined by the same `rc_app_user_id` (== `brUserId`). The custom backend's `RegainSubscriptionStatus` is a parallel/redundant view (some screens use it for currency/maxAmount display) but the **gate** is RevenueCat's `plus` entitlement.

### 3.4 Razorpay checkout algorithm — `CheckoutActivity` (`ai/regainapp/payments/ui/CheckoutActivity.java`)

VERBATIM facts:
- Order-status poll timeout default: `this.f1192k0 = 300000L;` (**300000 ms = 5 min**), overridable by the `u(...)` launcher's `j10` arg.
- Implements `PaymentResultWithDataListener`; routes `onActivityResult` back to `razorpay.onActivityResult(...)`.
- `onActivityResult` special-cases UPI: if extras `"Status" == "SUCCESS"` and `f1190i0` flag set -> `onPaymentSuccess(null,null)`; `"fail"` lower-cased; `responseCode` `"U16"`/`"U01"` -> launch a coroutine (retry/cleanup).
- Checkout JSON built in `u(...)` (VERBATIM keys):
  ```java
  jSONObject.put(intentType==SUBSCRIPTION ? "subscription_id" : "order_id", checkoutId);
  jSONObject.put("currency", "INR");          // hardcoded INR
  jSONObject.put("amount", amountInPaisa);    // long, paisa (minor units)
  jSONObject.put("method", "upi");
  jSONObject.put("_[flow]", "intent");
  if (topPaymentApp != null) jSONObject.put("upi_app_package_name", topPaymentApp);
  jSONObject.put("contact", "8888888888");    // placeholder contact (VERBATIM)
  jSONObject.put("email", userEmail);
  if (intentType == SUBSCRIPTION) jSONObject.put("recurring", "preferred");
  ```
- Supported UPI apps discovered via `BaseRazorpay.getAppsWhichSupportUpi(...)` and `getAppsWhichSupportAutoPayIntent(...)`, then filtered against an allowlist `m.h.f15966a` (the set of known UPI app packages).

Checkout flow pseudocode:
```text
setup:
  resp = POST /payments/subscriptions/setup(productId, basePlanId, rcAppUserId,
            provider="razorpay", paywallVariant, subscriptionSource, body=metadataMap)
  # resp: { regain_subscription_id, regain_order_id, provider, provider_subscription_id,
  #         provider_order_id, provider_redirect_url, checkout_token }
  launch CheckoutActivity.u(intentType, checkoutId=provider_subscription_id|provider_order_id,
                            regainOrderId, regainSubscriptionId, userEmail, topUpiApp,
                            amountInPaisa, ..., timeoutMs=300000, recurring)

onPaymentSuccess(razorpayPaymentId, paymentData):
  poll:
    loop until COMPLETED | FAILED | CANCELLED | elapsed > timeoutMs(=300000):
      OrderStatusResponse s = GET /payments/orders/status(
          provider="razorpay", regain_order_id, regain_subscription_id, rc_app_user_id,
          provider_payment_id=razorpayPaymentId, provider_signature=razorpaySignature,
          delay=<backoff ms>)
      if s.state == COMPLETED: break
  refresh RevenueCat customerInfo -> j(CustomerInfo) -> isPlusUser=true
  navigate to subscription-success (then NFC/physical-challenge page, module 09)

onPaymentError(code, response, data): log "PaymentsFlow", surface error, allow retry
```

### 3.5 Back-press yearly offer + expiry notification

- **Eligibility / scheduling math** (constants from 3.1): when the user back-presses out of the app and `SHOULD_SHOW_BACK_PRESS_YEARLY_OFFER` is true and the per-user cooldown (`BACK_PRESS_YEARLY_OFFER_COOLDOWN_MINUTES` = 4320) has elapsed since the last shown offer, show the scratch card for `yearly_offer`. The offer is valid for `BACK_PRESS_YEARLY_OFFER_EXPIRY_MINUTES` (60) with a `BACK_PRESS_YEARLY_OFFER_BUFFER_MINUTES` (60) grace buffer.
- **Alarm scheduling / cancel** (`sources/a0/w.java`, method `o(String)` — the *cancel* path, VERBATIM):
  ```java
  new h4.w(context).f11596b.cancel(null, 9005);                 // cancel notification id 9005
  PendingIntent broadcast = PendingIntent.getBroadcast(context, 9005,
      new Intent(context, BackPressOfferExpiryNotificationReceiver.class), 603979776);
  ((AlarmManager) context.getSystemService("alarm")).cancel(broadcast);
  // analytics: offer_source="BACK_PRESS_OFFER", action="notification_cancelled", reason=<str>
  ```
  - **Notification & request code: `9005`** (VERBATIM). PendingIntent flags `603979776` = `FLAG_NO_CREATE | FLAG_IMMUTABLE | FLAG_UPDATE_CURRENT`-class bits (immutable, no-create on cancel).
  - The matching *set* path schedules the same `getBroadcast(...,9005,...)` PendingIntent on `AlarmManager` at `offerShownAt + EXPIRY_MINUTES`.
- **Receiver** (`feature_subscription/domain/receiver/BackPressOfferExpiryNotificationReceiver.java`): Hilt-injected `BroadcastReceiver`, **non-exported**. `onReceive` calls `goAsync()` (skipped on the Android 12/12L/13 + `Build.MANUFACTURER == "vivo"` combo — VERBATIM `(i10==31||i10==32||i10==33) && "vivo"`), then runs a coroutine that posts the expiry-countdown notification via injected helper `b1`.
- **Notification channel** (`res/values/strings.xml`):
  - `notification_channel_offer_countdown` = `"Limited Time Offers"`
  - `notification_channel_offer_countdown_description` = `"Countdown reminders for limited time subscription offers"`

### 3.6 VERBATIM user-facing strings (`res/values/strings.xml`)

Paywall / offer:
```
back_press_offer_cta = "Invest %1$s in Yourself"
back_press_offer_per_year = "per year"
back_press_offer_scratch_card_description = "Scratch to reveal your offer"
back_press_offer_scratch_here = "Scratch Here"
back_press_offer_tagline_prefix = "For just"
back_press_offer_tagline_suffix = "/day, win your day"
back_press_offer_timer_prefix = "Ends in"
back_press_offer_title_discount = "%1$d%% discount"
back_press_offer_title_prefix = "One-time"
back_press_offer_title_suffix = "just for you!"
offer_countdown_back_press_title = "%1$d%% offer"
offer_countdown_time_left = "left to avail %1$s"
paywall_offer_discount_ticket_label = "Discount"
post_setup_offer_continue = "Continue"
post_setup_offer_discount = "%1$d%% OFF"
post_setup_offer_discount_subtitle = "on yearly plan"
post_setup_offer_title = "You unlocked limited time offer!"
account_settings_reset_back_press_offer = "Reset back offer"     # debug/dev reset
account_settings_back_press_offer_reset_done = "Back offer reset"
```
Subscription status / cancel survey:
```
subscription_status_benefits_title = "Benefits Of Pro!"
subscription_status_cancel = "Cancel Subscription"
subscription_status_cancel_failed = "Unable to cancel subscription. Please try again."
subscription_status_cancel_reason_accident = "I don't want Autopay"
subscription_status_cancel_reason_dont_use = "I don't use BrainPal anymore"
subscription_status_cancel_reason_expensive = "It's out of my price range"
subscription_status_cancel_reason_others = "Others"
subscription_status_cancel_reason_placeholder = "Please specify your reason"
subscription_status_cancel_reason_technical = "Technical issues"
subscription_status_cancel_success = "Subscription cancelled successfully"
subscription_status_cancel_survey_title = "Sad to see you go! Can you tell us why you're cancelling?"
subscription_status_member_summary = "Premium membership active"
subscription_status_member_till = "Member till"
subscription_status_plan_type = "Plan Type"
subscription_status_plus_badge = "Pro"
subscription_status_refund_and_revoke = "Refund payment and remove Plus access"
subscription_status_support_message = "Thanks for helping BrainPal's mission to help everyone reduce doomscrolling."
payments_subscription_link_razorpay = "Razorpay"
```
Subscription-success (hands off to NFC/physical challenge, module 09):
```
subscription_success_nfc_continue = "Continue"
subscription_success_nfc_page_1_title = "You took back control\nfrom Reels"
subscription_success_nfc_page_2_title = "To open Reels, you must\ndo a physical challenge"
subscription_success_nfc_see_action = "See it in action"
```

### 3.7 VERBATIM enums

```
BrainPalPaymentMethod         : PLAY_STORE, RAZORPAY
Providers (provider_name)     : RAZORPAY("razorpay"), PHONEPE("phonepe")
RegainSubscriptionState (status): PENDING, ACTIVATION_IN_PROGRESS, ACTIVE, ACTIVATION_FAILED,
                                  CANCELLED, HALTED, NONE
OrderState (status)           : PENDING, COMPLETED, FAILED, CANCELLED
```
> Note: backend `provider` query param uses lowercase string values (`"razorpay"`, `"phonepe"`). `PHONEPE` is defined but `CheckoutActivity` hardwires `"razorpay"`.

---

## 4. Data models

### 4.1 `SubscriptionState` (domain — RevenueCat-derived, the gate) — `feature_subscription/domain/model/SubscriptionState.java`

| Field | Type | Nullable | Source (RC) |
|---|---|---|---|
| `isPlusUser` | bool | no (default false) | `entitlement.isActive()` |
| `appUserId` | String | yes | `customerInfo.originalAppUserId` |
| `productIdentifier` | String | yes | `entitlement.productIdentifier` |
| `willRenew` | bool | no (default false) | `entitlement.willRenew` |
| `lastUpdatedAtMs` | long | no (default `System.currentTimeMillis()`) | now |
| `expirationDate` | Date | yes | `entitlement.expirationDate` |
| `subscriptionType` | String | yes | derived "Yearly"/"Monthly"/raw |
| `managementUrl` | Uri | yes | `customerInfo.managementURL` |
| `originalPurchaseDate` | Date | yes | `entitlement.originalPurchaseDate` |

### 4.2 `RegainSubscriptionStatus` (backend DTO, GSON) — `ai/regainapp/payments/domain/models/RegainSubscriptionStatus.java`

| @SerializedName | Field | Type | Nullable |
|---|---|---|---|
| `regain_subscription_id` | regainSubscriptionId | String | no |
| `google_id` | googleId | String | no |
| `app_user_id` | appUserId | String | no |
| `revenuecat_product_id` | revenuecatProductId | String | yes |
| `payment_provider` | paymentProvider | String | no |
| `entitlement_type` | entitlementType | String | yes |
| `currency` | currency | String | yes |
| `provider_subscription_id` | providerSubscriptionId | String | yes |
| `subscription_state` | subscriptionState | String | yes |
| `max_amount` | maxAmount | Integer | yes |
| `frequency` | frequency | String | yes |
| `setup_regain_order_id` | setupRegainOrderId | String | yes |
| `activated_at` | activatedAt | String (ISO ts) | yes |
| `expires_at` | expiresAt | String (ISO ts) | yes |
| `current_period_start` | currentPeriodStart | String | yes |
| `current_period_end` | currentPeriodEnd | String | yes |
| `next_charge_at` | nextChargeAt | String | yes |
| `paid_count` | paidCount | Integer | yes |
| `created_from_free_trial` | createdFromFreeTrial | Boolean | yes |
| `cancelled_at` | cancelledAt | String | yes |
| `created_at` | createdAt | String | yes |
| `updated_at` | updatedAt | String | yes |

### 4.3 `SetupSubscriptionResponse` — `ai/regainapp/payments/domain/models/SetupSubscriptionResponse.java`

| @SerializedName | Field | Type | Nullable |
|---|---|---|---|
| `regain_subscription_id` | regainSubscriptionId | String | no |
| `regain_order_id` | regainOrderId | String | no |
| `provider` | provider | String | no |
| `provider_subscription_id` | providerSubscriptionId | String | yes |
| `provider_order_id` | providerOrderId | String | yes |
| `provider_redirect_url` | providerRedirectUrl | String | yes |
| `checkout_token` | checkoutToken | String | yes |

### 4.4 `SubscriptionStatusResponse` — `ai/regainapp/payments/domain/models/SubscriptionStatusResponse.java`

| @SerializedName | Field | Type | Nullable |
|---|---|---|---|
| `regain_subscription_id` | regainSubscriptionId | String | no |
| `state` | state | String | no |
| `provider_subscription_id` | providerSubscriptionId | String | yes |
| `entitlement_type` | entitlementType | String | no |
| `max_amount` | maxAmount | Integer | yes |
| `frequency` | frequency | String | yes |
| `activated_at` | activatedAt | String | yes |
| `expires_at` | expiresAt | String | yes |
| `next_billing_date` | nextBillingDate | String | yes |
| `cancelled_at` | cancelledAt | String | yes |

> `OrderStatusResponse`, `OrderSetupResponse`, `LatestOneTimeOrderResponse` mirror the same conventions (state machine + provider ids); see [02-backend-api-contract.md](02-backend-api-contract.md).

### 4.5 Dart target shapes (freezed + drift)

```dart
// ---- domain enums ----
enum BrainPalPaymentMethod { playStore, razorpay }
enum PaymentProvider { razorpay, phonepe }
enum RegainSubscriptionState {
  pending, activationInProgress, active, activationFailed, cancelled, halted, none
}
enum OrderState { pending, completed, failed, cancelled }

// ---- gate state (RevenueCat-derived) ----
@freezed
class SubscriptionState with _$SubscriptionState {
  const factory SubscriptionState({
    @Default(false) bool isPlusUser,
    String? appUserId,
    String? productIdentifier,
    @Default(false) bool willRenew,
    required int lastUpdatedAtMs,        // epoch millis
    DateTime? expirationDate,
    String? subscriptionType,            // "Yearly" | "Monthly" | raw
    String? managementUrl,               // Uri.toString()
    DateTime? originalPurchaseDate,
  }) = _SubscriptionState;
}

// ---- backend status DTO ----
@freezed
class RegainSubscriptionStatusDto with _$RegainSubscriptionStatusDto {
  const factory RegainSubscriptionStatusDto({
    @JsonKey(name: 'regain_subscription_id') required String regainSubscriptionId,
    @JsonKey(name: 'google_id') required String googleId,
    @JsonKey(name: 'app_user_id') required String appUserId,
    @JsonKey(name: 'revenuecat_product_id') String? revenuecatProductId,
    @JsonKey(name: 'payment_provider') required String paymentProvider,
    @JsonKey(name: 'entitlement_type') String? entitlementType,
    String? currency,
    @JsonKey(name: 'provider_subscription_id') String? providerSubscriptionId,
    @JsonKey(name: 'subscription_state') String? subscriptionState,
    @JsonKey(name: 'max_amount') int? maxAmount,
    String? frequency,
    @JsonKey(name: 'setup_regain_order_id') String? setupRegainOrderId,
    @JsonKey(name: 'activated_at') String? activatedAt,
    @JsonKey(name: 'expires_at') String? expiresAt,
    @JsonKey(name: 'current_period_start') String? currentPeriodStart,
    @JsonKey(name: 'current_period_end') String? currentPeriodEnd,
    @JsonKey(name: 'next_charge_at') String? nextChargeAt,
    @JsonKey(name: 'paid_count') int? paidCount,
    @JsonKey(name: 'created_from_free_trial') bool? createdFromFreeTrial,
    @JsonKey(name: 'cancelled_at') String? cancelledAt,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
  }) = _RegainSubscriptionStatusDto;
  factory RegainSubscriptionStatusDto.fromJson(Map<String, dynamic> j) =>
      _$RegainSubscriptionStatusDtoFromJson(j);
}

@freezed
class SetupSubscriptionResponse with _$SetupSubscriptionResponse {
  const factory SetupSubscriptionResponse({
    @JsonKey(name: 'regain_subscription_id') required String regainSubscriptionId,
    @JsonKey(name: 'regain_order_id') required String regainOrderId,
    required String provider,
    @JsonKey(name: 'provider_subscription_id') String? providerSubscriptionId,
    @JsonKey(name: 'provider_order_id') String? providerOrderId,
    @JsonKey(name: 'provider_redirect_url') String? providerRedirectUrl,
    @JsonKey(name: 'checkout_token') String? checkoutToken,
  }) = _SetupSubscriptionResponse;
  factory SetupSubscriptionResponse.fromJson(Map<String, dynamic> j) =>
      _$SetupSubscriptionResponseFromJson(j);
}
```

```dart
// ---- drift: persist last-known gate + offer bookkeeping for offline gating ----
class SubscriptionCache extends Table {
  IntColumn  get id                  => integer().withDefault(const Constant(1))(); // singleton row
  BoolColumn get isPlusUser          => boolean().withDefault(const Constant(false))();
  TextColumn get appUserId           => text().nullable()();
  TextColumn get productIdentifier   => text().nullable()();
  BoolColumn get willRenew           => boolean().withDefault(const Constant(false))();
  IntColumn  get lastUpdatedAtMs     => integer()();
  DateTimeColumn get expirationDate  => dateTime().nullable()();
  TextColumn get subscriptionType    => text().nullable()();
  TextColumn get managementUrl       => text().nullable()();
  @override Set<Column> get primaryKey => {id};
}

class BackPressOfferState extends Table {
  IntColumn  get id              => integer().withDefault(const Constant(1))();
  DateTimeColumn get lastShownAt => dateTime().nullable()(); // cooldown anchor (4320 min)
  DateTimeColumn get currentOfferExpiresAt => dateTime().nullable()();
  IntColumn  get discountPercent => integer().nullable()();  // backend-supplied %
  @override Set<Column> get primaryKey => {id};
}
```

---

## 5. Android deps -> Flutter map

| Android API / lib | Verdict | Flutter pkg or channel | Notes |
|---|---|---|---|
| `com.razorpay:checkout` (`Razorpay`, `CheckoutActivity`, `PaymentResultWithDataListener`) | DART+PLUGIN | `razorpay_flutter` | Re-implements UPI-intent checkout; pass `key=rzp_live_SxX4XCM7fABMgJ`, order/subscription id, `amount` (paisa), `currency="INR"`, `recurring="preferred"` for subs |
| `BaseRazorpay.getAppsWhichSupportUpi` / `getAppsWhichSupportAutoPayIntent` | DART+PLUGIN | `razorpay_flutter` (internal) | UPI app discovery + intent flow handled inside plugin; no manual list needed |
| `com.revenuecat.purchases.Purchases` (configure / awaitLogIn / awaitCustomerInfo / setAttributes / UpdatedCustomerInfoListener) | DART+PLUGIN | `purchases_flutter` (RevenueCat) | `configure(googleApiKey:"goog_UIUiLbfHWbfqpKdefquYdBHGDTS")`; `logIn(brUserId)`; listen `addCustomerInfoUpdateListener` -> map `entitlements.active["plus"]` |
| Google Play Billing (via RC) | DART+PLUGIN | `in_app_purchase` (fallback) **or** `purchases_flutter` | Razorpay is PRIMARY on Android; Play path is fallback per `BrainPalPaymentMethod.PLAY_STORE` |
| Retrofit `PaymentsApi` (`/payments/*`) | DART | `dio` + `retrofit` (+ `dio_cache_interceptor`) | Same endpoints/query params; see §7 and [02-backend-api-contract.md](02-backend-api-contract.md) |
| `AlarmManager.set/cancel` (offer expiry, req code 9005) | DART+PLUGIN | `flutter_local_notifications` `zonedSchedule` / `cancel(9005)` | Replaces alarm + receiver; exact-alarm permission via `permission_handler` only if exact timing required |
| `BackPressOfferExpiryNotificationReceiver` (BroadcastReceiver) | DART | (none) — folded into notification schedule | No channel needed; the notification *is* the side effect |
| `NotificationChannel notification_channel_offer_countdown` | DART+PLUGIN | `flutter_local_notifications` channel | id `"notification_channel_offer_countdown"`, name `"Limited Time Offers"`, desc `"Countdown reminders for limited time subscription offers"` |
| Firebase Remote Config (`on.b.e()`) for offer/RC constants | DART+PLUGIN | `firebase_remote_config` | Seed defaults from `rc_defaults.xml` (§3.1) |
| `PaymentsFileProvider` (FileProvider for receipts/share) | DART+PLUGIN | `share_plus` + `path_provider` | Receipt sharing; authority `com.brainrot.android.payments.fileprovider` |
| GSON DTOs | DART | `freezed` + `json_serializable` | Preserve `@SerializedName` -> `@JsonKey(name:)` exactly (§4) |
| `mc.a.*` analytics props on plus transitions | DART | `firebase_analytics` + Mixpanel | Mirror `is_plus_user`, `subscription_type`; tokens in §3.1 (Mixpanel debug/prod) |

---

## 6. iOS strategy

| Capability | iOS reality | Implementation |
|---|---|---|
| Razorpay digital-subscription checkout | **NOT POSSIBLE** — App Store §3.1.1 requires in-app purchase for digital content; Razorpay/UPI is **rejectable** for subscriptions | Use **StoreKit2** via `in_app_purchase` **or** `purchases_flutter` (RevenueCat) with App Store products. The Razorpay path is Android-only |
| Entitlement / `isPlusUser` | StoreKit2 `Transaction.currentEntitlements` (or RevenueCat `appl_...` key) | Same Dart `SubscriptionState`; data layer fed by StoreKit instead of RC-on-Play. The `plus` entitlement id can be reused as the RC entitlement identifier across stores |
| Regain backend `/payments/*` setup/poll/cancel | Backend is provider-agnostic but `provider="razorpay"` is meaningless on iOS | Either (a) route iOS purchases entirely through StoreKit + RevenueCat (skip Razorpay setup), reconciling via RC server-side, or (b) add a `provider="app_store"` server path (backend change). See OQ-7 |
| Back-press offer + scratch card | Allowed (UI only) | Re-implement scratch UI in Flutter; the discount becomes a StoreKit **promotional offer** / introductory offer on the `yearly_offer` product, NOT a Razorpay discount |
| Offer-expiry countdown notification | `UNUserNotificationCenter` | `flutter_local_notifications` `zonedSchedule` works on iOS; request notification permission via `permission_handler` |
| Subscription-success NFC/physical challenge page | No AccessibilityService; blocking is via Screen Time (FamilyControls/DeviceActivity/ManagedSettings/Shield) | The success page UI ports; the *gating* it advertises is implemented on Apple Screen Time — see [module-09-challenges-unlock.md](module-02-overlays-floating-bubble.md) and the detection module |
| `managementURL` / cancel | StoreKit `showManageSubscriptions` | Use `in_app_purchase` / native sheet; backend cancel+refund is N/A for App Store (refunds go through Apple) |

> **iOS billing is a re-platform, not a port.** Same Dart domain (`SubscriptionState`, `isPlusUser`), same paywall product ids (`monthly`/`yearly`/`yearly_offer`), but the purchase + restore + refund mechanics are StoreKit. RevenueCat (`purchases_flutter`) is the cleanest way to keep one entitlement abstraction (`plus`) across both stores.

---

## 7. Platform-channel surface

This module is **almost entirely Dart + plugins** (`razorpay_flutter`, `purchases_flutter`, `flutter_local_notifications`, `firebase_remote_config`, `dio`). It touches the **frozen channel contract** only at the edges:

| Channel (verbatim) | Dir | Method/Event | Payload | Why this module cares |
|---|---|---|---|---|
| `brainpal/permissions` (MethodChannel) | Dart->native | `check`/`request` (`notifications`) | `{type:"notifications"}` -> `{granted:bool}` | Needed to post the offer-countdown notification (Android 13+) before scheduling |
| `brainpal/permission_status` (EventChannel) | native->Dart | grant/revoke transitions | `{type, granted, ts}` | React if user revokes notification permission while an offer alarm is pending |
| `brainpal/system_events` (EventChannel) | native->Dart | `DATE_CHANGED`/`TIME_SET`/`TIMEZONE_CHANGED` | `{event, ts}` | Recompute offer-expiry / welcome-expiry windows when clock changes (anti-cheat: offer "Ends in" timer) |
| `brainpal/challenges` (MethodChannel) | Dart->native | `start` (`nfc`/`walk_steps`/...) | per [01-platform-channel-contracts.md](01-platform-channel-contracts.md) | Subscription-success page launches the physical-challenge demo (module 09) |
| `brainpal/challenge_events` (EventChannel) | native->Dart | `progress`/`completed`/`failed` | per 01 | success-page demo completion |

> **No new channel needed for checkout or RevenueCat** — those are plugin method channels owned by `razorpay_flutter` / `purchases_flutter`, not the BrainPal `brainpal/*` namespace. Local-notification scheduling for the offer countdown is `flutter_local_notifications`, not `brainpal/*`. Do **not** invent a `brainpal/billing` channel; keep billing in pure Dart + vendor plugins.

---

## 8. State management & DI

```text
get_it/injectable singletons (core, non-UI):
  PaymentsApi              (retrofit on dio)              -> /payments/*
  RevenueCatGateway        (purchases_flutter wrapper)    -> configure/logIn/customerInfo stream
  SubscriptionRepository   (merges RC entitlement + backend status)
  OfferScheduler           (flutter_local_notifications; replaces AlarmManager+receiver)
  BackPressOfferRepository (drift BackPressOfferState; cooldown math)
  RemoteConfigService      (firebase_remote_config; §3.1 keys)

Riverpod v2 (riverpod_generator):
  @riverpod subscriptionState        -> StreamNotifier<SubscriptionState>
        # maps RevenueCat addCustomerInfoUpdateListener (== Kotlin UpdatedCustomerInfoListener
        #  -> zg.i.j(CustomerInfo)) into the same gate logic of §3.3.
  @riverpod isPlusUser               -> bool   (select subscriptionState.isPlusUser) [consumed by module 07]
  @riverpod paywallProducts          -> FutureProvider (monthly/yearly/yearly_offer + prices)
  @riverpod checkoutController       -> Notifier (setup -> razorpay_flutter -> poll -> refresh RC)
  @riverpod orderStatusPoller        -> StreamNotifier (300000ms timeout; OrderState machine)
  @riverpod backPressOfferController -> Notifier (eligibility, scratch reveal, schedule expiry notif)
  @riverpod cancelSubscription       -> Notifier (survey reason + refund_money)
```

**Kotlin Flow/Channel -> Dart stream mapping**

| Kotlin source | Dart stream |
|---|---|
| `zg.i.f29309j : StateFlow<SubscriptionState>` (`o0` over `d1`) | `subscriptionStateProvider` (StreamNotifier) |
| `UpdatedCustomerInfoListener.onReceived` -> `j(CustomerInfo)` | `RevenueCatGateway.customerInfoStream` -> mapped to `SubscriptionState` |
| `CheckoutActivity.b0/f1184c0 : SharedFlow` (checkout UI events) | `checkoutController` state (loading/success/error) |
| `CheckoutActivity` order-status coroutine loop | `orderStatusPoller` (Dart `Stream.periodic` w/ 300000ms cap) |
| `AlarmManager` 9005 broadcast -> `BackPressOfferExpiryNotificationReceiver` | `OfferScheduler.zonedSchedule(id:9005)` (no stream; fire-and-forget notif) |

---

## 9. User flows

### 9.1 Paywall trigger (gate fail)
1. `[dart]` Premium feature requested (module 07) while `isPlusUser == false`.
2. `[dart]` `subscriptionStateProvider` confirms gate false -> `go_router` push `/paywall?variant=<paywall_variant>`.
3. `[dart]` Load products (`monthly`/`yearly`/`yearly_offer`) + prices (RevenueCat offerings or backend `RegainSubscriptionStatus.maxAmount`/`currency`).

### 9.2 Razorpay purchase (Android, PRIMARY)
1. `[dart]` Tap "Subscribe" -> `POST /payments/subscriptions/setup(product_id, base_plan_id, rc_app_user_id, provider="razorpay", paywall_variant, subscription_source, body=metadata)`.
2. `[dart]` Receive `SetupSubscriptionResponse{regain_subscription_id, regain_order_id, provider_subscription_id|provider_order_id, checkout_token}`.
3. `[plugin]` `razorpay_flutter` opens checkout: `currency="INR"`, `amount=<paisa>`, `recurring="preferred"` (subscription), UPI-intent.
4. `[plugin]` `onPaymentSuccess(razorpay_payment_id, signature)`.
5. `[dart]` Poll `GET /payments/orders/status(provider="razorpay", regain_order_id, regain_subscription_id, rc_app_user_id, provider_payment_id, provider_signature, delay)` until `COMPLETED` or **300000 ms** timeout.
6. `[plugin]` `purchases_flutter.getCustomerInfo()` refresh -> entitlement `plus` active.
7. `[dart]` `subscriptionStateProvider` flips `isPlusUser=true`; analytics; pop paywall.
8. `[dart]`+`[channel]` Navigate to subscription-success; optionally launch physical-challenge demo via `brainpal/challenges` (module 09).

### 9.3 Play / RevenueCat purchase (fallback)
1. `[dart]` If `BrainPalPaymentMethod.PLAY_STORE` selected (regional/experiment, `PART_OF_GATEWAY_EXPERIMENT`).
2. `[plugin]` `purchases_flutter.purchaseStoreProduct(...)` (or `in_app_purchase`).
3. `[plugin]` Entitlement update -> gate flips. No Razorpay/Regain poll needed.

### 9.4 Free trial
1. `[dart]` Backend/RC marks subscription `created_from_free_trial=true`, `willRenew` possibly true, `expires_at` future.
2. `[dart]` Gate `isPlusUser=true` for trial window; show "Trial" affordance (`subscription_status_*`).
3. `[dart]` On `expirationDate < now` and `willRenew=false` -> next `CustomerInfo` shows entitlement inactive -> `isPlusUser=false` -> paywall.

### 9.5 Back-press yearly offer
1. `[dart]` User back-presses to exit; `backPressOfferController` checks `SHOULD_SHOW_BACK_PRESS_YEARLY_OFFER` AND cooldown (`now - lastShownAt >= 4320 min`) AND `!isPlusUser`.
2. `[dart]` Show scratch card (`back_press_offer_*` strings); set `lastShownAt=now`, `currentOfferExpiresAt = now + 60 min` (+60 min buffer per §3.1).
3. `[plugin]` `OfferScheduler.zonedSchedule(id:9005, at: currentOfferExpiresAt, channel: notification_channel_offer_countdown)` (replaces `AlarmManager`+receiver).
4. `[dart]` Scratch reveal -> `back_press_offer_cta "Invest %1$s in Yourself"` -> paywall with `yearly_offer` preselected (`paywall_offer_discount_ticket_label "Discount"`).
5. `[dart]` Purchase via 9.2 with `yearly_offer` product; on success `OfferScheduler.cancel(9005)`.
6. `[plugin]` If unclaimed, notification fires at expiry: `offer_countdown_back_press_title "%1$d%% offer"`, `offer_countdown_time_left "left to avail %1$s"`.

### 9.6 Cancel + refund
1. `[dart]` Settings -> "Cancel Subscription" -> survey (`subscription_status_cancel_survey_title`) with reasons (`dont_use`/`expensive`/`technical`/`accident`/`others`).
2. `[dart]` Optional checkbox `subscription_status_refund_and_revoke "Refund payment and remove Plus access"`.
3. `[dart]` `POST /payments/subscriptions/cancel(rc_app_user_id, refund_money=<bool>)` -> `RegainSubscriptionStatus`.
4. `[plugin]` RC `CustomerInfo` update -> entitlement inactive -> `isPlusUser=false`. Success toast `subscription_status_cancel_success`.

### 9.7 Restore on reinstall
1. `[dart]` On first launch post-reinstall, auth restores `brUserId` (module 05).
2. `[plugin]` `purchases_flutter.logIn(brUserId)` (== Kotlin `awaitLogIn`) -> `CustomerInfo` -> if `plus` active, `isPlusUser=true` automatically (no re-purchase). Optionally call `restorePurchases()` for store-side receipts.
3. `[dart]` Backend `GET /payments/subscriptions(rc_app_user_id)` reconciles currency/plan display.

### 9.8 Post-setup offer & welcome window
1. `[dart]` After `COMPLETED`, within `PLUS_SUBSCRIPTION_WELCOME_EXPIRY_MINUTES` (180) show welcome state.
2. `[dart]` If backend/variant flags it, show post-setup upsell: `post_setup_offer_title`, `post_setup_offer_discount "%1$d%% OFF"`, `post_setup_offer_discount_subtitle "on yearly plan"`, `post_setup_offer_continue`.

---

## 10. Parity risks & validation

| Risk | Detail | Validation / harness |
|---|---|---|
| **Wrong gate source** | If Dart reads backend `RegainSubscriptionStatus.subscription_state` instead of the RC `plus` entitlement, gate can diverge (backend may lag RC webhook). Native truth = RC entitlement (§3.3). | Unit-test `SubscriptionState` mapper against RC `CustomerInfo` fixtures: entitlement active/inactive, willRenew true/false, expired. Assert `isPlusUser == entitlement.isActive()`. |
| **Razorpay key / amount units** | `amount` is **paisa (minor units)**, `currency` hardcoded `"INR"`, key `rzp_live_SxX4XCM7fABMgJ`. Off-by-100 = 100x charge. | Golden test: `maxAmount` (paisa) flows to plugin unchanged; assert no `/100` before Razorpay. Sandbox a ₹1 order. |
| **Order-status timeout** | Must cap polling at **300000 ms (5 min)**; UPI can resolve slowly. Premature give-up shows false failure though payment succeeds. | Integration test: simulate `PENDING`*N then `COMPLETED` at t=4:50; assert success. At t=5:01 assert timeout state + recovery path. |
| **Cooldown math** | Back-press offer cooldown `4320 min` (3 days); buffer `60 min`; expiry `60 min`. Wrong unit (min vs ms) breaks `*60*1000`. | Unit-test eligibility: lastShown at now-4319m -> ineligible; now-4321m -> eligible. Verify `zonedSchedule` time == shown + 60m. |
| **Clock change cheat** | "Ends in" timer + welcome window keyed to wall clock; users may change date to dodge/extend offers. Native listens `DATE_CHANGED`/`TIMEZONE_CHANGED`. | Subscribe to `brainpal/system_events`; test recompute on TZ/date jump. Prefer server `expires_at` over device clock where possible. |
| **Notification id collision** | Offer notification + alarm request code = **9005**; reusing it elsewhere mis-cancels. | Reserve 9005 for offer-expiry only; assert `OfferScheduler.cancel(9005)` on claim/purchase. |
| **iOS store-policy reject** | Shipping Razorpay on iOS for subs = App Store rejection. | CI guard: assert `razorpay_flutter` purchase path is unreachable on `Platform.isIOS`; iOS uses StoreKit. |
| **RC config key leak/rotation** | `goog_UIUiLbfHWbfqpKdefquYdBHGDTS` is a public RC SDK key (fine to ship) but must match RC dashboard project. | Smoke test `Purchases.isConfigured == true` post-`configure`; verify entitlement id `plus` exists in RC dashboard. |
| **Restore identity drift** | RC app-user-id MUST equal auth `brUserId`; if Dart logs in RC with device-anonymous id, restore fails. | Test reinstall flow: `logIn(brUserId)` then assert entitlement restored without purchase. |
| **Vivo goAsync skip** | Native skips `goAsync()` on Android 12/12L/13 + vivo (§3.5). Flutter notif scheduling differs but verify offer notif still fires on those devices. | Manual QA on a vivo Android 13 device: schedule + fire offer notification. |

---

## 11. Open questions

- **OQ-1 (RESOLVED — gate source):** RevenueCat **is** wired and is the entitlement source of truth (`zg.i` calls `Purchases.configure`, `awaitLogIn`, `UpdatedCustomerInfoListener`; gate = entitlement `plus` `isActive()`). The Regain backend + Razorpay are the *checkout/order* layer. The cached "RevenueCat vs custom backend" question is answered: **both, with distinct roles.** Remaining sub-question: does the backend *also* independently flip access (server webhook -> push) or only RC? Assume RC is canonical for the gate.
- **OQ-2 (product ids / prices):** Product identifiers are the literals `monthly` / `yearly` / `yearly_offer` (rc_defaults), but the concrete Play/RC product SKUs and **prices** are not in the binary — they come from RC offerings / backend `max_amount`+`currency`. Confirm exact SKUs + price tiers (INR vs USD) from the RC dashboard / backend.
- **OQ-3 (discount %):** Back-press / post-setup discount percentage is a runtime template `%1$d%%`; no constant in code. Source per-user/per-region from backend. Confirm where the `discount` is applied (Razorpay order amount vs RC promotional offer).
- **OQ-4 (trial duration):** `created_from_free_trial` is server-set; trial length (days) not in binary. Confirm `trial_duration_days`.
- **OQ-5 (PLAY_STORE selection):** `BrainPalPaymentMethod.PLAY_STORE` exists and RC-on-Play is configured, but `CheckoutActivity` hardwires `"razorpay"`. When is the Play path chosen — regional (non-IN), `PART_OF_GATEWAY_EXPERIMENT` bucket, or fallback on Razorpay failure? Confirm routing rule.
- **OQ-6 (PHONEPE provider):** `Providers.PHONEPE("phonepe")` is defined but unused in checkout. Is a PhonePe gateway planned? Affects `provider` enum handling.
- **OQ-7 (iOS backend path):** Backend `provider` param has no App Store value. Decide: route iOS purchases purely through RC/StoreKit (RC server reconciles) or add a backend `provider="app_store"`. Backend-team decision.
- **OQ-8 (one-time orders):** `setupOneTimeOrder` / `/payments/one_time_orders/*` + `LatestOneTimeOrderResponse` exist but no UI flow in the decompile. Lifetime/VIP purchase planned? If so it's a separate paywall.
- **OQ-9 (live key handling):** `rzp_live_SxX4XCM7fABMgJ` is a publishable live key in the binary (acceptable) — confirm the Razorpay **secret** is server-only and orders are server-created (they are: `/payments/subscriptions/setup`). Re-verify before shipping.
- **OQ-10 (offer-scheduling exactness):** Native uses `AlarmManager` (likely `setExactAndAllowWhileIdle` for the "Ends in" precision). Does the offer countdown need exact-alarm precision (-> `SCHEDULE_EXACT_ALARM` permission) or is `flutter_local_notifications` inexact zoned schedule acceptable? Product decision.
- **OQ-11 (checkout-optimization TTL):** `CHECKOUT_OPTIMIZATION_TTL_IN_MILLIS=600000` — what is cached for 10 min (pre-fetched UPI app list? setup response?)? Confirm so Flutter caches the same thing with `dio_cache_interceptor`.

---

## 12. Migration checklist

**Phase A — domain + data (pure Dart, no UI)**
- [ ] Define `SubscriptionState`, enums (`BrainPalPaymentMethod`, `PaymentProvider`, `RegainSubscriptionState`, `OrderState`) as freezed (§4.5).
- [ ] Define backend DTOs with exact `@JsonKey` names (§4.2–4.4); generate `json_serializable`.
- [ ] Build `PaymentsApi` retrofit interface mirroring §7 endpoints + query params verbatim (see [02-backend-api-contract.md](02-backend-api-contract.md)).
- [ ] Add drift `SubscriptionCache` + `BackPressOfferState` tables.
- [ ] Seed `firebase_remote_config` defaults from `rc_defaults.xml` (§3.1) verbatim.

**Phase B — entitlement gate (RevenueCat)**
- [ ] Add `purchases_flutter`; `configure(googleApiKey: "goog_UIUiLbfHWbfqpKdefquYdBHGDTS", diagnostics: true)`.
- [ ] On auth login/logout, `logIn(brUserId)` / `logOut()` (module 05).
- [ ] Set RC attributes: `$displayName`, `$email`, `brUserId`, `$deviceVersion`, `$mixpanelDistinctId`, `appVersion="7.1.340"`.
- [ ] Implement `customerInfo -> SubscriptionState` mapper per §3.3 (entitlement id from RC key `RC_ENTITLEMENT_ID`, default `plus`; "Yearly"/"Monthly" label rule).
- [ ] Expose `subscriptionStateProvider` + `isPlusUserProvider` (consumed by [module-07-premium-gating.md](module-06-subscription-billing.md)).
- [ ] Implement restore-on-reinstall (logIn + `restorePurchases`).

**Phase C — checkout (Razorpay, Android primary)**
- [ ] Add `razorpay_flutter`; wire `setup -> checkout -> success/error` (§9.2).
- [ ] Build order-status poller capped at **300000 ms**, `OrderState` machine.
- [ ] Pass `amount` as **paisa**, `currency="INR"`, `recurring="preferred"` for subs; key `rzp_live_SxX4XCM7fABMgJ`.
- [ ] Implement Play/RC fallback path (`BrainPalPaymentMethod.PLAY_STORE`) per OQ-5 routing.

**Phase D — offers + notifications**
- [ ] Implement back-press eligibility (cooldown 4320m, expiry 60m, buffer 60m; `SHOULD_SHOW_BACK_PRESS_YEARLY_OFFER`).
- [ ] Scratch-card paywall with `yearly_offer`; strings §3.6.
- [ ] `flutter_local_notifications` channel `notification_channel_offer_countdown` ("Limited Time Offers"); `zonedSchedule(id:9005)`; `cancel(9005)` on claim/purchase.
- [ ] Subscribe to `brainpal/system_events` to recompute timers on clock/TZ change.
- [ ] Welcome window (180m) + post-setup upsell.

**Phase E — cancel + parity**
- [ ] Cancel survey UI + `cancelSubscription(refund_money)` (§9.6).
- [ ] All §10 tests green (gate mapping, amount units, 300000 timeout, cooldown math, restore identity).

**Phase F — iOS**
- [ ] StoreKit2 via `in_app_purchase`/`purchases_flutter` for `monthly`/`yearly`/`yearly_offer`; **no Razorpay** on iOS.
- [ ] iOS gate from StoreKit entitlement; `flutter_local_notifications` for offer countdown.
- [ ] Resolve OQ-7 backend provider path for App Store; `showManageSubscriptions` for cancel.
