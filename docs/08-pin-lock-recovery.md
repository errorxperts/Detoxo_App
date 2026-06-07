# PIN Lock, Biometrics & Email-OTP Recovery

This document is the blueprint for the **access-control layer** of the Flutter rebuild: the PIN/biometric gate that protects the app itself and its sensitive sections, the escalating retry-lockout ladder that defeats brute-force, and the email-OTP recovery path that lets a locked-out user regain control. It maps each behavior in the decompiled native app to a clean Flutter + flutter_bloc + Clean-Architecture design, naming the exact pub.dev package per mechanism and flagging the small native surface (the full-screen blocker overlay) that still needs a MethodChannel. All enum values, lengths, thresholds and JSON keys below were read directly from the decompiled source (cited inline); anything whose method body was obfuscated is labelled **(inferred)**.

---

## 1. Legend

| Symbol | Meaning |
|---|---|
| ✅ | A pub.dev package fully handles this in Dart |
| ⚠️ | Needs a native MethodChannel/EventChannel (or a native-wrapping plugin) |
| ❌ | Not possible on iOS (no API equivalent) |

---

## 2. Subsystem map (what we are rebuilding)

| Concern | Native evidence | Flutter target |
|---|---|---|
| PIN type model | `activities/home/data/PinOptionsEnum.java` | `PinType` enum + `PinConfig` entity |
| DATE/TIME derivation | `PINTimeFormatEnum.java`, `PINDateFormatEnum.java` | `PinDeriver` (pure Dart, `intl`) ✅ |
| Restriction scopes | `activities/home/data/PINRestrictedSectionsEnum.java` | `PinRestrictionScope` enum |
| PIN setup + email verify | `activities/home/viewmodel/settings/PinLockViewModel.java` | `PinSettingsBloc` |
| PIN verification gate | `activities/pinblockoverlay/viewmodel/PinBlockOverlayViewmodel.java` | `PinBloc` (lockout state machine) |
| Biometric unlock | `activities/pinblockoverlay/common/BiometricHelper.java` | `local_auth` ✅ |
| Retry-lockout ladder | `PinBlockOverlayViewmodel.allowPinEntry()` (VERIFIED) | `LockoutPolicy` (pure Dart) ✅ |
| OTP / recovery API | `network/data/otp/*`, `network/data/pinrecovery/*` | `RecoveryRepository` + `dio` ✅ |
| Secure PIN storage | `androidx.datastore.preferences` | `flutter_secure_storage` ✅ |
| Full-screen blocker overlay | `activities/pinblockoverlay/PinBlockOverlayActivity.java` | ⚠️ native Activity / `flutter_overlay_window` |

---

## 3. PIN types — `PinOptionsEnum`

**Source evidence:** `activities/home/data/PinOptionsEnum.java` (read directly). Each entry carries an `optionName` (display string) and a `length` (expected digit count).

| Native ordinal | Name | `optionName` | `length` | Meaning |
|---|---|---|---|---|
| 0 | `NONE` | "None" | 0 | No PIN; gate disabled |
| 1 | `CUSTOM` | "Custom" | **10** | User-chosen PIN. UI accepts ≥4 on entry; field max length is 10. |
| 2 | `DATE` | "Date" | **10** | PIN derived from the current **date** per `PINDateFormatEnum` |
| 3 | `TIME` | "Time" | **10** | PIN derived from the current **time** per `PINTimeFormatEnum` |
| 4 | `OTP` | "OTP" | **6** | One-time code emailed to the verified address |
| 5 | `DEVICE_DEFAULT` | "Device PIN/Pattern" | 0 | Delegates to the OS credential / biometric prompt |

> Note: the `length` field on `CUSTOM/DATE/TIME` is `10` in the enum (the max input buffer), **not** the natural length of a derived value. The DATE/TIME *derived* code is shorter (e.g. 4 digits for `HHMM`); the enum length is just the input-pad cap. `DEVICE_DEFAULT` is disabled below API 28 in the native app (no biometric/credential prompt) — mirror this in Flutter by hiding it when `local_auth.isDeviceSupported()` is false.

### Dart enum

```dart
/// What a correct PIN looks like / how it is produced.
/// Mirrors native PinOptionsEnum (PinOptionsEnum.java).
enum PinType {
  none(displayName: 'None', maxLength: 0),
  custom(displayName: 'Custom', maxLength: 10),
  date(displayName: 'Date', maxLength: 10),
  time(displayName: 'Time', maxLength: 10),
  otp(displayName: 'OTP', maxLength: 6),
  deviceDefault(displayName: 'Device PIN/Pattern', maxLength: 0);

  const PinType({required this.displayName, required this.maxLength});
  final String displayName;
  final int maxLength;
}
```

---

## 4. DATE / TIME derivation — clock-as-password

DATE and TIME PINs have **no stored secret**: the correct value is computed from the device clock at verification time, so it changes automatically (daily for DATE, by-minute for TIME). The native app stores only the *format* preference.

**Source evidence:** `PINTimeFormatEnum.java`, `PINDateFormatEnum.java` (read directly), plus `overlay-and-pinblock.json` algorithm "DATE/TIME modes compute PIN dynamically from system time using DateTimeFormatter.ofPattern".

### `PINTimeFormatEnum`

| Name | `formatName` (display) | Pattern | Example |
|---|---|---|---|
| `HHMM_24` | "24 Hrs (HH:MM)" | `HHmm` | 14:07 → `1407` |
| `HHMM_12` | "12 Hrs (HH:MM)" | `hhmm` | 02:07 PM → `0207` |

### `PINDateFormatEnum`

| Name | `formatName` (display) | Pattern | Example (07 Jun 2026) |
|---|---|---|---|
| `DDMM` | "DD-MM" | `ddMM` | `0706` |
| `DDMMYYYY` | "DD-MM-YYYY" | `ddMMyyyy` | `07062026` |
| `DDMMYY` | "DD-MM-YY" | `ddMMyy` | `070626` |

> The native enums only define `formatName`; the *digit* string is produced at runtime by formatting the clock with the corresponding pattern (the `getViewIdResourceName`-style separators are stripped — only digits remain). The mapping above is **(inferred)** from those format names and the documented "ofPattern" usage; verify against the actual UI strings when implementing.

### Dart deriver (✅ pure Dart, package `intl`)

```dart
enum PinTimeFormat { hhmm24('HHmm'), hhmm12('hhmm'); // see PINTimeFormatEnum
  const PinTimeFormat(this.pattern); final String pattern; }

enum PinDateFormat { ddmm('ddMM'), ddmmyyyy('ddMMyyyy'), ddmmyy('ddMMyy'); // PINDateFormatEnum
  const PinDateFormat(this.pattern); final String pattern; }

class PinDeriver {
  /// Returns the digits-only PIN that is currently valid for a derived PIN type.
  /// `now` is injected so the bloc and tests use the same clock.
  String derive(PinConfig cfg, DateTime now) {
    switch (cfg.pinType) {
      case PinType.time:
        return DateFormat(cfg.timeFormat.pattern).format(now);
      case PinType.date:
        return DateFormat(cfg.dateFormat.pattern).format(now);
      default:
        throw StateError('derive() only valid for DATE/TIME');
    }
  }
}
```

> Edge case to replicate: TIME PINs change every minute, so the verify path should accept the value computed at the *moment of submission*, and re-derive (not cache from screen open). DATE PINs should tolerate a midnight boundary by deriving at submission time too.

---

## 5. Restriction scopes — `PINRestrictedSectionsEnum`

Which parts of the app are gated by the PIN. **Source evidence:** `activities/home/data/PINRestrictedSectionsEnum.java` (read directly). Each entry has `sectionName` (display) and `isEnforcing` (whether the PIN is *mandatory* when the feature is on).

| Native ordinal | Name | `sectionName` | `isEnforcing` |
|---|---|---|---|
| 0 | `NOSCROLL_APP` | "NoScroll App" | `false` |
| 1 | `SETTINGS_APP` | "Settings & App Info" | **`true`** |
| 2 | `PLAN_SWITCH` | "Plan Switcher" | `false` |
| 3 | `NOSCROLL_SETTINGS` | "NoScroll Settings" | `false` |
| 4 | `APP_LOCKER` | "App locker" | `false` |

> `SETTINGS_APP` is the only enforcing scope. It guards the OS **Settings / App-info** screen (where a user would try to disable the accessibility service or uninstall the app), so the native app forces a PIN there even if other scopes are optional. The biometric error path also special-cases this scope (see §7). The `(i2 & 2) != 0 ? false : z` default-constructor pattern confirms `isEnforcing` defaults to `false` for all entries except the explicit `SETTINGS_APP` (`true`).

### Dart enum

```dart
/// Where the PIN gate applies. Mirrors PINRestrictedSectionsEnum.
enum PinRestrictionScope {
  noscrollApp('NoScroll App', false),
  settingsApp('Settings & App Info', true), // only enforcing scope
  planSwitch('Plan Switcher', false),
  noscrollSettings('NoScroll Settings', false),
  appLocker('App locker', false);

  const PinRestrictionScope(this.displayName, this.isEnforcing);
  final String displayName;
  final bool isEnforcing;
}
```

In Flutter, enforce scopes with **`go_router` route guards** (✅): each protected route declares the scope it needs; a `redirect` checks `PinBloc.state.isUnlockedFor(scope)` and pushes the PIN route otherwise. The native intent extra `RESTRICTION_SOURCE` (the enum name string) becomes a route argument / query param.

---

## 6. Core entity — `PinConfig`

**Source evidence:** `activities/home/compose/pin/data/PinConfig.java`. Persisted in native under the DataStore key `PIN_CONFIG`; a change broadcasts `REFRESH_DATA` (action `com.noscroll.action.APP_COMMAND`) to the accessibility service.

| Native field | Type | Purpose |
|---|---|---|
| `activePinOption` | `PinOptionsEnum` | Which PIN type is active |
| `customPin` | `String` | The custom secret (only used for `CUSTOM`) |
| `timeFormat` | `PINTimeFormatEnum` | Format for `TIME` derivation |
| `dateFormat` | `PINDateFormatEnum` | Format for `DATE` derivation |
| `restrictions` | `Set<PINRestrictedSectionsEnum>` | Active scopes |
| `pinRetryCount` | `int` | Consecutive failed attempts (drives lockout ladder) |
| `lastPinAttempted` | `long` (ms) | Timestamp of last attempt (lockout window start) |
| `lastSuccesfulLogin` | `long` (ms) | Last successful unlock |
| `restrictionDuration` | `long` (ms) | Current lockout duration (written by `allowPinEntry`, see §8) |

### Dart entity (domain)

```dart
class PinConfig extends Equatable {
  const PinConfig({
    this.pinType = PinType.none,
    this.customPin = '',            // store via flutter_secure_storage, never plaintext prefs
    this.timeFormat = PinTimeFormat.hhmm24,
    this.dateFormat = PinDateFormat.ddmmyyyy,
    this.restrictions = const {},
    this.retryCount = 0,
    this.lastAttemptAtMs = 0,
    this.lastSuccessAtMs = 0,
    this.lockoutDurationMs = 0,
  });

  final PinType pinType;
  final String customPin;
  final PinTimeFormat timeFormat;
  final PinDateFormat dateFormat;
  final Set<PinRestrictionScope> restrictions;
  final int retryCount;
  final int lastAttemptAtMs;
  final int lastSuccessAtMs;
  final int lockoutDurationMs;

  PinConfig copyWith({ /* ... all fields ... */ });

  @override
  List<Object?> get props => [pinType, customPin, timeFormat, dateFormat,
      restrictions, retryCount, lastAttemptAtMs, lastSuccessAtMs, lockoutDurationMs];
}
```

**Storage mapping:** persist `customPin` and `verifiedEmail` in **`flutter_secure_storage`** ✅ (Android Keystore / iOS Keychain). The rest of `PinConfig` (enums, counters, timestamps) can live in `flutter_secure_storage` too (single JSON blob) or in `hive`/`isar` — but the secret must not land in `shared_preferences`. The native `REFRESH_DATA` broadcast becomes a MethodChannel call `pinChannel.invokeMethod('refreshPinConfig')` ⚠️ so the native accessibility service reloads its copy.

---

## 7. Biometric unlock — `BiometricHelper`

**Source evidence:** `activities/pinblockoverlay/common/BiometricHelper.java` + `overlay-and-pinblock.json` "BiometricPrompt Error Handling". Native wraps `androidx.biometric.BiometricPrompt` (requires a `FragmentActivity`), lazy-initialized, with callbacks.

Verified error-code handling:

| `BiometricPrompt` error code | Native constant | Action |
|---|---|---|
| `10` | `BIOMETRIC_ERROR_USER_CANCELED` | call `onCancel` (return to PIN pad) |
| `13` | `BIOMETRIC_ERROR_NEGATIVE_BUTTON` | call `onCancel` |
| any other | — | if `source == SETTINGS_APP` launch `Intent("android.settings.SETTINGS", flags=872415232)`; then call `onCloseOrBlock` |
| success | `onAuthenticationSucceeded` | call `onUnlockSuccess` → close overlay with unlock result |

### Flutter — `local_auth` ✅ (⚠️ only `deviceDefault`/escalation needs platform credential)

```dart
class BiometricGate {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isAvailable() async =>
      await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;

  /// Returns one of: unlocked / cancelled / unavailable-or-error.
  Future<BiometricResult> authenticate() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock NoScroll',
        options: const AuthenticationOptions(
          biometricOnly: false, // false => allow device credential, mirrors DEVICE_DEFAULT
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return ok ? BiometricResult.unlocked : BiometricResult.cancelled;
    } on PlatformException catch (e) {
      // local_auth surfaces error codes via e.code: notAvailable / notEnrolled / lockedOut ...
      return BiometricResult.error;
    }
  }
}

enum BiometricResult { unlocked, cancelled, error }
```

> `local_auth` collapses the native codes 10/13 into a single `false`/cancel return, so we treat `cancelled` like the native `onCancel` (stay on PIN pad). The `SETTINGS_APP`-launch-on-error behavior is app-specific UX — keep it for parity: on `BiometricResult.error` when the active scope is `settingsApp`, route the user to a "use your PIN instead" fallback.
>
> **iOS:** ✅ `local_auth` works (Face ID / Touch ID). But the *system-level gating* of OS Settings (`android.settings.SETTINGS`) has **no iOS equivalent** ❌ — iOS apps cannot block the user from opening Settings.app. On iOS the PIN/biometric gate only protects in-app sections.

---

## 8. Retry-lockout ladder — `LockoutPolicy`

**Source evidence (VERIFIED, read directly):** `PinBlockOverlayViewmodel.allowPinEntry()` lines 333–351. Exact logic:

```java
if (pinConfig == null || (pinRetryCount = pinConfig.getPinRetryCount()) <= 5) return true;   // <=5: no lock
long elapsed = System.currentTimeMillis() - pinConfig.getLastPinAttempted();
long lockMs  = pinRetryCount <= 8  ? 30000L          // 6–8   -> 30 s
             : pinRetryCount <= 10 ? 300000L         // 9–10  -> 5 m
             : pinRetryCount <= 15 ? 3600000L        // 11–15 -> 1 h
             : pinRetryCount <= 20 ? 14400000L       // 16–20 -> 4 h
             :                       86400000L;       // >20   -> 24 h
long remaining = lockMs - elapsed;                    // clamped to >= 0
// writes lockMs into PinConfig.restrictionDuration, starts a "Try again in: " countdown if remaining>0
```

### Verified ladder

| `retryCount` | Lockout | Constant (ms) |
|---|---|---|
| ≤ 5 | none (entry allowed) | — |
| 6 – 8 | 30 seconds | `30000` |
| 9 – 10 | 5 minutes | `300000` |
| 11 – 15 | 1 hour | `3600000` |
| 16 – 20 | 4 hours | `14400000` |
| > 20 | 24 hours | `86400000` |

Notes verified from the method body:
- The **window start** is `lastPinAttempted`; `remaining = lockoutMs - (now - lastPinAttempted)`, clamped to 0.
- When still locked (`remaining > 0`) it starts a countdown labelled **`"Try again in: "`** and, for `OTP` type, sets `autoResend=true` so a fresh code is auto-requested when the window ends.
- The chosen `lockoutMs` is written back into `PinConfig.restrictionDuration` (field index confirmed via the `copy$default(..., 0L, 0L, j, 255, null)` call where `j` is `lockMs`).
- Increment/persistence of `retryCount` happens on each failed unlock (`onPinUnlock`); reset to 0 on success (`lastSuccesfulLogin` updated).

### Dart policy (✅ pure Dart, fully testable)

```dart
class LockoutPolicy {
  static const _ladder = <int, int>{ // upper-bound retryCount -> lockout ms
    8: 30 * 1000,
    10: 5 * 60 * 1000,
    15: 60 * 60 * 1000,
    20: 4 * 60 * 60 * 1000,
  };
  static const _maxLockoutMs = 24 * 60 * 60 * 1000; // >20

  /// null => entry allowed; otherwise the lockout window for this retryCount.
  int? lockoutMsFor(int retryCount) {
    if (retryCount <= 5) return null;
    for (final entry in _ladder.entries) {
      if (retryCount <= entry.key) return entry.value;
    }
    return _maxLockoutMs;
  }

  /// Remaining ms before entry is allowed again (0 if free).
  int remainingMs({required int retryCount, required int lastAttemptAtMs, required int nowMs}) {
    final lock = lockoutMsFor(retryCount);
    if (lock == null) return 0;
    final remaining = lock - (nowMs - lastAttemptAtMs);
    return remaining < 0 ? 0 : remaining;
  }
}
```

---

## 9. Email-OTP & PIN-recovery API

**Source evidence:** `network/data/otp/request/OTPRequest.java`, `.../OTPResponse.java`, `network/data/otp/validate/ValidateOTPRequest.java`, `.../ValidateOTPResponse.java`, `network/data/pinrecovery/PINRecoveryRequest.java`, `.../PinRecoveryResponse.java`, plus `EmailTypeEnum.java`.

### `EmailTypeEnum` (verified, ordinals 0–3)

| Ordinal | Name | Used for |
|---|---|---|
| 0 | `VERIFY_EMAIL` | Confirm ownership during PIN setup |
| 1 | `UNLOCK_APP` | Temporary unlock after too many failures |
| 2 | `CHANGE_EMAIL` | Change the verified recovery address |
| 3 | `RECOVERY` | "Forgot PIN" → reset the PIN |

### Request/response JSON keys (exact field names)

`OTPRequest`: `email`, `emailType`, `lockedAppName`
`OTPResponse`: `email`, `expiry` (ms), `lastSent` (ms), `message`, `otp` (masked), `purchaseReset` (bool), `success`, `waitingTime` (ms — resend cooldown)
`ValidateOTPRequest`: `email`, `emailType`, `otp`
`ValidateOTPResponse`: `email`, `message`, `emailType`, `result` (bool — true = match), `retryCount`
`PINRecoveryRequest`: `deviceTime` (ms), `email`, `pinFormat` (enum value), `timeOffset` (int — tz offset)
`PinRecoveryResponse`: `message`, `success` (bool), `waitingExpiry` (ms — re-request gate)

### Email validation regex (VERIFIED)

`PinLockViewModel.java` (line 353) defines:
```
^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[a-zA-Z]{2,}$
```
Reuse verbatim with Dart `RegExp` (✅) or `email_validator`.

### Flows

**Email verification (setup)** — `sendOtp(email, VERIFY_EMAIL)` → user types code → `validateOtp(email, VERIFY_EMAIL, otp)` → on `result=true` persist `verifiedEmail`, advance to PIN selection.

**PIN recovery ("Forgot PIN")** — verified at `PinBlockOverlayViewmodel.forgotPin()`/`sendOTP()`: `sendOtp(verifiedEmail, RECOVERY, lockedAppName)` → countdown driven by `OTPResponse.waitingTime` → `validateOtp(verifiedEmail, RECOVERY, otp)` → on `result=true` allow setting a new PIN (resets `customPin`, clears `retryCount`). The dedicated `PINRecoveryRequest` endpoint (carrying `deviceTime`/`timeOffset`/`pinFormat`) supports server-side reset and is rate-limited via `PinRecoveryResponse.waitingExpiry`.

**Unlock-after-failures** — `sendOtp(verifiedEmail, UNLOCK_APP, appName)` issues a temporary unlock code; on validation the lockout/cooldown is cleared for the session.

**Resend cooldown (verified):** after any send, a countdown of `waitingTime` ms blocks the resend button (`isResendEnabled=false`, button shows remaining time); for OTP-type PINs the lockout ladder can auto-resend when the window ends.

### Dart models (✅ `json_serializable` + `dio`)

```dart
enum EmailOtpType { verifyEmail, unlockApp, changeEmail, recovery }
// serialize to the native SCREAMING_SNAKE names: VERIFY_EMAIL / UNLOCK_APP / CHANGE_EMAIL / RECOVERY

@JsonSerializable()
class OtpRequest {
  OtpRequest({required this.email, required this.emailType, this.lockedAppName});
  final String email;
  @JsonKey(name: 'emailType') final EmailOtpType emailType;
  final String? lockedAppName;
  factory OtpRequest.fromJson(Map<String, dynamic> j) => _$OtpRequestFromJson(j);
  Map<String, dynamic> toJson() => _$OtpRequestToJson(this);
}

@JsonSerializable()
class OtpResponse {
  OtpResponse({required this.success, required this.expiry, required this.lastSent,
      required this.waitingTime, this.message, this.otp, this.purchaseReset = false, this.email});
  final bool success;
  final int expiry;        // ms epoch
  final int lastSent;      // ms epoch
  final int waitingTime;   // ms resend cooldown
  final String? message;
  final String? otp;       // masked
  final bool purchaseReset;
  final String? email;
  factory OtpResponse.fromJson(Map<String, dynamic> j) => _$OtpResponseFromJson(j);
}

@JsonSerializable()
class ValidateOtpRequest {
  ValidateOtpRequest({required this.email, required this.emailType, required this.otp});
  final String email;
  @JsonKey(name: 'emailType') final EmailOtpType emailType;
  final String otp;
  Map<String, dynamic> toJson() => _$ValidateOtpRequestToJson(this);
}

@JsonSerializable()
class ValidateOtpResponse {
  ValidateOtpResponse({required this.result, required this.retryCount, this.email, this.message, this.emailType});
  final bool result;       // true => OTP matched
  final int retryCount;
  final String? email;
  final String? message;
  final String? emailType;
  factory ValidateOtpResponse.fromJson(Map<String, dynamic> j) => _$ValidateOtpResponseFromJson(j);
}

@JsonSerializable()
class PinRecoveryRequest {
  PinRecoveryRequest({required this.deviceTime, required this.email,
      required this.pinFormat, required this.timeOffset});
  final int deviceTime;    // System.currentTimeMillis()
  final String email;
  final String pinFormat;  // enum value
  final int timeOffset;    // tz offset
  Map<String, dynamic> toJson() => _$PinRecoveryRequestToJson(this);
}

@JsonSerializable()
class PinRecoveryResponse {
  PinRecoveryResponse({required this.success, required this.waitingExpiry, this.message});
  final bool success;
  final int waitingExpiry; // ms re-request gate
  final String? message;
  factory PinRecoveryResponse.fromJson(Map<String, dynamic> j) => _$PinRecoveryResponseFromJson(j);
}
```

### Repository contract (domain)

```dart
abstract class RecoveryRepository {
  Future<OtpResponse> sendOtp({required String email, required EmailOtpType type, String? lockedAppName});
  Future<ValidateOtpResponse> validateOtp({required String email, required EmailOtpType type, required String otp});
  Future<PinRecoveryResponse> requestPinReset({required String email, required String pinFormat});
}
```

> **iOS:** the OTP/recovery HTTP layer is platform-neutral ✅ — the entire email-OTP recovery story works identically on iOS.

---

## 10. PIN verification gate — `PinBloc` (with lockout state machine)

The verification gate is what runs when a protected scope is accessed. It resolves the expected PIN (stored for `CUSTOM`, derived for `DATE`/`TIME`, server-checked for `OTP`, OS prompt for `DEVICE_DEFAULT`), enforces the lockout ladder, and offers biometric + "Forgot PIN".

### Events / States

```dart
sealed class PinEvent {}
class PinDigitPressed extends PinEvent { PinDigitPressed(this.digit); final String digit; }
class PinDeletePressed extends PinEvent {}
class PinSubmitted extends PinEvent {}
class BiometricRequested extends PinEvent {}
class ForgotPinRequested extends PinEvent {}
class OtpEntered extends PinEvent { OtpEntered(this.otp); final String otp; }
class LockoutTicked extends PinEvent {}     // 1 Hz timer

enum PinPhase { entering, verifying, locked, unlocked, denied }

class PinState extends Equatable {
  const PinState({
    required this.config,
    required this.scope,
    this.entered = '',
    this.phase = PinPhase.entering,
    this.message,
    this.isError = false,
    this.lockoutRemainingMs = 0,
    this.showForgotPin = false,
    this.otpResendRemainingMs = 0,
  });
  final PinConfig config;
  final PinRestrictionScope scope;
  final String entered;
  final PinPhase phase;
  final String? message;
  final bool isError;
  final int lockoutRemainingMs;
  final bool showForgotPin;
  final int otpResendRemainingMs;
  /* copyWith + props */
  @override
  List<Object?> get props => [config, scope, entered, phase, message, isError,
      lockoutRemainingMs, showForgotPin, otpResendRemainingMs];
}
```

### Verify / derive logic in the bloc

```dart
class PinBloc extends Bloc<PinEvent, PinState> {
  PinBloc(this._repo, this._deriver, this._policy, this._biometric, this._recovery,
          this._clock) : super(/* initial from config */) {
    on<PinDigitPressed>(_onDigit);
    on<PinDeletePressed>(_onDelete);
    on<PinSubmitted>(_onSubmit);
    on<BiometricRequested>(_onBiometric);
    on<LockoutTicked>(_onTick);
    on<ForgotPinRequested>(_onForgot);
    on<OtpEntered>(_onOtp);
  }

  Future<void> _onSubmit(PinSubmitted e, Emitter<PinState> emit) async {
    // 1. lockout gate (mirrors allowPinEntry)
    final remaining = _policy.remainingMs(
      retryCount: state.config.retryCount,
      lastAttemptAtMs: state.config.lastAttemptAtMs,
      nowMs: _clock.nowMs);
    if (remaining > 0) {
      emit(state.copyWith(phase: PinPhase.locked, lockoutRemainingMs: remaining,
          message: 'Try again in: ', isError: true));
      return;
    }
    // 2. resolve expected value
    final expected = switch (state.config.pinType) {
      PinType.custom => state.config.customPin,
      PinType.date || PinType.time => _deriver.derive(state.config, _clock.now),
      _ => null, // OTP handled by _onOtp; DEVICE_DEFAULT handled by _onBiometric
    };
    // 3. compare (constant-time compare for the stored secret)
    final ok = expected != null && _constantTimeEquals(state.entered, expected);
    if (ok) {
      await _repo.onUnlockSuccess(state.scope, _clock.nowMs); // retryCount=0, lastSuccess=now
      emit(state.copyWith(phase: PinPhase.unlocked));
    } else {
      final newCount = state.config.retryCount + 1;
      await _repo.onUnlockFailure(newCount, _clock.nowMs);    // persists count + lastAttempt
      final newRemaining = _policy.remainingMs(
        retryCount: newCount, lastAttemptAtMs: _clock.nowMs, nowMs: _clock.nowMs);
      emit(state.copyWith(
        entered: '', isError: true,
        config: state.config.copyWith(retryCount: newCount, lastAttemptAtMs: _clock.nowMs),
        phase: newRemaining > 0 ? PinPhase.locked : PinPhase.entering,
        lockoutRemainingMs: newRemaining,
        showForgotPin: true,
      ));
    }
  }
}
```

> `OTP` verification routes to `_onOtp`, which calls `RecoveryRepository.validateOtp(..., type: EmailOtpType.unlockApp)` and unlocks on `result == true`. `DEVICE_DEFAULT` routes straight to `_onBiometric`. A 1 Hz `LockoutTicked` event decrements `lockoutRemainingMs` and flips `phase` back to `entering` at zero — mirroring the native `"Try again in: "` countdown. Use a constant-time compare for the custom PIN to avoid timing leaks (the native code does a plain equality; this is a safe improvement).

---

## 11. The blocker overlay — `PinBlockOverlayActivity`

**Source evidence:** `activities/pinblockoverlay/PinBlockOverlayActivity.java`, `compose/data/NSBlockScreens.java`, and `overlay-and-pinblock.json`.

Verified manifest/behavior facts:
- Declared with **`taskAffinity=""`** + **`excludeFromRecents=true`** so it appears as a modal over the blocked app and never clutters the recents list.
- Launched by the accessibility service / `AppLockerProcessor.restrictApp()` via `startActivity`, **not** `WindowManager.addView` (per `overlay-and-pinblock.json` note: it is a full-screen Activity, not a true system overlay).
- Intent extras: `APP_PIN_LOCKED` (bool), `APP_BLOCKED` (bool), `IS_IN_COOLDOWN` (bool), `PACKAGE_NAME` (String), `RESTRICTION_SOURCE` (enum name String).
- Returns result via `setResult`: `PIN_STATUS=true` (`RESULT_OK = -1`) on unlock, else `RESULT_CANCELED = 0`; on failed PIN with `APP_BLOCKED`, fires a `MAIN|HOME` intent to eject the user to the launcher.
- `AppLockerProcessor` de-duplicates repeated launches within **2000 ms** (4-element ring of `(packageName, timestamp)`).

### Screens — `NSBlockScreens` enum (verified)

| Ordinal | Name | Shown when |
|---|---|---|
| 0 | `PIN_LOCK_SCREEN` | A protected app/section needs PIN/biometric/OTP |
| 1 | `BLOCKER_LOCK_SCREEN` | App over daily limit → Focus-Mode duration picker |
| 2 | `COOLDOWN_SCREEN` | Inside a cooldown window; entry is blocked |

### Flutter strategy ⚠️ (the only non-pure-Dart piece)

Drawing a PIN screen **on top of another app's window** is not pure Dart. Two routes:

1. **In-app gate (easy, ✅):** for scopes that live *inside our own app* (`NOSCROLL_APP`, `NOSCROLL_SETTINGS`, `PLAN_SWITCH`, `APP_LOCKER` settings) use a normal full-screen route: `Navigator.push(MaterialPageRoute(fullscreenDialog: true))` wrapped in `PopScope(canPop: false)` to block the back gesture. This covers everything reachable while our app is foreground.

2. **System overlay over *other* apps (⚠️ native):** when the accessibility service catches a foreground blocked app, render the PIN screen via **`flutter_overlay_window`** (wraps `WindowManager TYPE_APPLICATION_OVERLAY`, type `2032`) **or** a dedicated native blocker `Activity` launched over a MethodChannel — replicating `taskAffinity=""`/`excludeFromRecents`. The native side passes the equivalent of `RESTRICTION_SOURCE`/`PACKAGE_NAME` back into the Flutter overlay engine.

```dart
// In-app route guard (option 1)
PopScope(
  canPop: false, // back is disabled until unlocked, mirrors onKeyEvent BACK handling
  child: BlocProvider(
    create: (_) => sl<PinBloc>()..add(GateOpened(scope: scope)),
    child: const PinLockScreen(),
  ),
);
```

> **iOS:** the system-overlay-over-other-apps behavior (option 2) is **❌ not possible** — iOS has no AccessibilityService and no draw-over-other-apps window. The closest parental-control analog is **FamilyControls / ManagedSettings / DeviceActivity**, which can *shield* apps with Apple's own screen, but you cannot render a custom Flutter PIN pad over a third-party app. The in-app gate (option 1) works on iOS ✅.

---

## 12. PIN-setup bloc — `PinSettingsBloc`

Drives the settings screen (`PinLockViewModel` + `PinConfigActionsImpl` + `EmailOtpImpl`): email input + regex validation, email verification via OTP, PIN-type selection, custom-PIN entry (enabled at length ≥ 4), restriction-scope toggles, and the resend countdown.

```dart
sealed class PinSettingsEvent {}
class EmailChanged extends PinSettingsEvent { EmailChanged(this.email); final String email; }
class VerifyEmailRequested extends PinSettingsEvent {}
class SetupOtpEntered extends PinSettingsEvent { SetupOtpEntered(this.otp); final String otp; }
class PinTypeSelected extends PinSettingsEvent { PinTypeSelected(this.type); final PinType type; }
class CustomPinChanged extends PinSettingsEvent { CustomPinChanged(this.pin); final String pin; }
class RestrictionToggled extends PinSettingsEvent { RestrictionToggled(this.scope); final PinRestrictionScope scope; }
class PinConfigSaved extends PinSettingsEvent {}
class ResendOtpTicked extends PinSettingsEvent {}

// Validation reuses the VERIFIED native regex:
final _emailRegex = RegExp(r'^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[a-zA-Z]{2,}$');

// On save: write PinConfig to flutter_secure_storage, then notify the native service
//   await sl<PinRefreshChannel>().refresh(); // ⚠️ MethodChannel -> service reload (REFRESH_DATA)
```

> Enforce per-type input caps from `PinType.maxLength`; the custom-PIN submit button enables at length ≥ 4 (native `isCustomPinSubmitEnabled`). The resend button stays disabled for `OtpResponse.waitingTime` ms via a 1 Hz `ResendOtpTicked` countdown. `DEVICE_DEFAULT` is hidden when `BiometricGate.isAvailable()` is false (native disables it below API 28).

---

## 13. Package summary

| Mechanism | Package / approach | Flag |
|---|---|---|
| Biometric / device-credential unlock | `local_auth` | ✅ (iOS ✅) |
| Secure PIN & email storage | `flutter_secure_storage` | ✅ |
| Structured config (optional) | `hive` or `isar` | ✅ |
| OTP / recovery HTTP | `dio` + `json_serializable` | ✅ |
| Email regex / validation | Dart `RegExp` or `email_validator` | ✅ |
| DATE/TIME PIN derivation | `intl` (`DateFormat`) | ✅ |
| State management | `flutter_bloc` | ✅ |
| Route guards for scopes | `go_router` redirect | ✅ |
| DI | `get_it` (+ `injectable`) | ✅ |
| Countdown timers | `dart:async` `Timer.periodic` | ✅ |
| In-app full-screen gate | `Navigator` + `PopScope` | ✅ |
| Overlay over *other* apps | `flutter_overlay_window` / native Activity via MethodChannel | ⚠️ (iOS ❌) |
| Service config refresh | MethodChannel `refreshPinConfig` | ⚠️ |
| Gating OS Settings.app | native `android.settings.SETTINGS` intent | ⚠️ (iOS ❌) |

---

## 14. Source evidence

Built from: `activities/home/data/PinOptionsEnum.java`, `EmailTypeEnum.java`, `PINRestrictedSectionsEnum.java`, `PINTimeFormatEnum.java`, `PINDateFormatEnum.java`; `activities/home/compose/pin/data/PinConfig.java`; `activities/home/viewmodel/settings/PinLockViewModel.java` (email regex line 353); `activities/pinblockoverlay/viewmodel/PinBlockOverlayViewmodel.java` (`allowPinEntry()` lines 333–351, VERIFIED lockout ladder; `startForgotPinCountdown`); `activities/pinblockoverlay/common/BiometricHelper.java`; `activities/pinblockoverlay/PinBlockOverlayActivity.java`; `activities/pinblockoverlay/compose/data/NSBlockScreens.java` and `PinScreenState.java`; `network/data/otp/request/OTPRequest.java` & `OTPResponse.java`; `network/data/otp/validate/ValidateOTPRequest.java` & `ValidateOTPResponse.java`; `network/data/pinrecovery/PINRecoveryRequest.java` & `PinRecoveryResponse.java`. Cached analyses: `/tmp/ns_analysis/pin-lock-and-recovery.json`, `/tmp/ns_analysis/overlay-and-pinblock.json`.

---

## Related docs

- `01-architecture-overview.md`
- `02-accessibility-detection-engine.md`
- `03-blocking-modes-and-overlays.md`
- `04-platforms-config-schema.md`
- `05-foreground-service-and-lifecycle.md`
- `06-plans-and-quota-gating.md`
- `07-app-locker-and-focus-mode.md`
- `09-uninstall-protection-device-admin.md`
- `10-networking-and-backend-sync.md`
