# PIN Lock, Biometrics & Recovery

The **access_protection** feature is Detoxo's app-level lock: a PIN that gates
opening the app and changing protected settings, an escalating retry-lockout
ladder, optional biometric unlock (`local_auth`), and a "Forgot PIN" recovery
flow. It is a self-contained Clean-Architecture feature — `data / domain /
presentation` under `lib/features/access_protection/` — and the rest of the app
touches it only through `PinCubit`, the public barrel
(`access_protection.dart`), and the `requirePin` / `PinGuard` helpers.

> Scope note: this is a *soft* lock enforced in the Flutter UI. It guards Detoxo's
> own screens; it is not the same thing as the native accessibility/Device-Admin
> enforcement described in [03-detection-engine.md](03-detection-engine.md) and
> [13-onboarding-permissions.md](13-onboarding-permissions.md). The `LOCK_APP`
> block mode *reuses* this PIN screen conceptually, but native enforcement of it
> is a follow-up (the engine currently degrades `LOCK_APP` to a back press).

---

## 1. Layer map

| Layer | File | Responsibility |
|-------|------|----------------|
| domain / entity | `domain/entities/pin_config.dart` | `PinConfig` (persisted state) + `PinLockoutPolicy` (the ladder) |
| domain / hashing | `domain/pin_hasher.dart` | `PinHasher` — salted SHA-256 for custom PINs |
| domain / contract | `domain/repositories/pin_repository.dart` | `PinRepository` interface (load/save + OTP) |
| data | `data/repositories/pin_repository_impl.dart` | secure-storage persistence, legacy migration, dev-OTP stub |
| presentation / state | `presentation/pin_cubit.dart` | `PinCubit` — setup, verify, lockout, biometrics, recovery glue |
| presentation / gate | `presentation/pin_gate.dart` | `requirePin()` + `PinGuard` — how other features demand the PIN |
| presentation / UI | `presentation/pin_lock_screen.dart` | the full-screen keypad lock |
| presentation / UI | `presentation/pin_setup_screen.dart` | configure / disable the lock |
| presentation / UI | `presentation/pin_recovery_sheet.dart` | 3-step email-OTP reset |
| barrel | `access_protection.dart` | exports **only** `PinConfig` + `PinRepository` |

`PinType` and `PinScope` live in the shared blocking enums file
(`lib/features/blocking/shared/domain/entities/enums.dart`) because they carry
wire tokens used in persisted JSON.

---

## 2. `PinConfig` — the persisted state

`PinConfig` (an `Equatable`) is the single object `PinCubit` emits and the
repository round-trips to secure storage. Fields:

| Field | Type | Notes |
|-------|------|-------|
| `type` | `PinType` | `none` (default), `custom`, `date`, `time` (also `otp` / `deviceDefault`, modeled but not offered — see §3) |
| `secretHash` | `String` | salted SHA-256 of a **custom** PIN; empty for date/time/none |
| `salt` | `String` | random salt behind `secretHash`; empty otherwise |
| `secretLength` | `int` | digit count of a custom PIN — stored so the lock screen can draw the right number of dots and auto-submit **without ever holding the secret** |
| `scopes` | `Set<PinScope>` | which sections the PIN guards |
| `verifiedEmail` | `String` | recovery email |
| `retryCount` | `int` | cumulative failed attempts (persisted, drives the ladder) |
| `lockedUntil` | `DateTime?` | end of the current cooldown window (null = not locked) |
| `biometricEnabled` | `bool` | whether fingerprint/face unlock is allowed |

Derived getters:

- `isConfigured` → `type != PinType.none`.
- `isLockedOut` → `lockedUntil != null && lockedUntil.isAfter(now)`.
- `guards(scope)` → `scopes.contains(scope)`.

`copyWith` has one non-obvious parameter: **`clearLockout`**. Because `lockedUntil`
is nullable, an ordinary `copyWith(lockedUntil: null)` can't distinguish "leave
it" from "clear it", so passing `clearLockout: true` forces `lockedUntil = null`.
This is how a successful verify / recovery wipes the cooldown.

**JSON:** `toJson`/`fromJson` use each enum's `wire` token (`type` and each
`scope`), and `lockedUntil` is stored as `millisecondsSinceEpoch`. This is the
exact shape written under the secure key `pin_config`.

---

## 3. PIN types

`PinType` (enum, with wire tokens):

| Value | Wire | Offered in UI | Behaviour |
|-------|------|---------------|-----------|
| `none` | `NONE` | yes (= "no lock", the default) | lock disabled |
| `custom` | `CUSTOM` | yes | user-chosen 4–10 digits; stored as salted hash |
| `date` | `DATE` | yes | derived from the clock: `ddMMyyyy` (8 digits), **changes daily** |
| `time` | `TIME` | yes | derived from the clock: `HHmm` (4 digits), **changes each minute** |
| `otp` | `OTP` | no | modeled for wire compat; not selectable |
| `deviceDefault` | `DEVICE_DEFAULT` | no | modeled for wire compat; not selectable |

**Derived PINs (date/time) store no secret at all** — no salt, no hash,
`secretLength = 0`. `PinCubit._matches` computes the expected value live from
`DateTime.now()`:

```dart
PinType.date => entry == '${_two(now.day)}${_two(now.month)}${now.year}', // ddMMyyyy
PinType.time => entry == '${_two(now.hour)}${_two(now.minute)}',          // HHmm
```

They are convenience / "obscurity" locks (anyone who knows the trick can unlock),
which is why the setup screen surfaces a live preview ("Right now that is …") and
a hint that the value rotates. Custom PINs are the only credential that is a real
secret.

`PinCubit.expectedLength` tells the lock screen when an entry is complete so it can
auto-submit: `custom → secretLength`, `date → 8`, `time → 4`, else `4`.

---

## 4. PIN scopes

`PinScope` (enum, wire tokens) — the sections a PIN can guard:

| Value | Wire | Status |
|-------|------|--------|
| `app` | `DETOXO_APP` | **live** — ask for the PIN at launch |
| `settings` | `SETTINGS_APP` | **live** — ask before disabling blocking / resetting data / changing the PIN |
| `planSwitch` | `PLAN_SWITCH` | retired — pruned on setup; lock-screen copy still handled |
| `detoxoSettings` | `DETOXO_SETTINGS` | retained for wire compat; lock-screen copy handled |
| `appLocker` | `APP_LOCKER` | retired — pruned on setup; lock-screen copy still handled |

The setup screen exposes only `app` and `settings` (`_supportedScopes`). Any other
scope persisted by an older build is **filtered out on load and never re-saved**,
so the enum can keep the retired tokens for backward-compatible deserialization
without resurrecting dead toggles.

---

## 5. Hashing — `PinHasher`

`PinHasher` (an `abstract final class`, static-only) keeps custom PINs out of
plaintext storage:

- `newSalt()` — 16 cryptographically-random bytes from `Random.secure()`,
  `base64Url`-encoded for JSON-safe storage.
- `hash(salt, secret)` — `sha256(utf8('$salt:$secret'))` as a hex string.
- `verify(salt, expectedHash, entry)` — returns `false` if either `salt` or
  `expectedHash` is empty (so a misconfigured custom PIN can *never* unlock),
  otherwise `hash(salt, entry) == expectedHash`.

Date/Time PINs never pass through the hasher — there is nothing to hash.

> Note: this is a single unsalted-iteration SHA-256 (no PBKDF2/Argon key
> stretching). It is adequate against casual inspection of on-device storage for a
> 4–10 digit PIN, not against a determined offline brute-force. Hardening the KDF
> is a reasonable follow-up.

---

## 6. `PinCubit` — behaviour

`PinCubit extends Cubit<PinConfig>`; the emitted state *is* the `PinConfig`. It is
constructed with a `PinRepository` and an optional `LocalAuthentication` (defaults
to a fresh `LocalAuthentication()`, injectable for tests). Registered app-wide (see
§10).

### Setup / teardown

- `load()` — emits `repo.load()`.
- `setup({type, secret, scopes, verifiedEmail, biometricEnabled})` — for `custom`,
  mints a salt and hashes the secret and records `secretLength`; for date/time it
  stores empty salt/hash and `secretLength = 0`. Saves and emits.
- `disable()` — saves and emits `const PinConfig()` (i.e. `type = none`), removing
  the lock entirely.
- `resetSecretAfterRecovery(newSecret)` — used by the "Forgot PIN" flow. Sets a
  fresh custom hash/salt/length while **keeping** the guarded scopes, recovery
  email and biometric preference, and **clears** the retry ladder
  (`retryCount: 0, clearLockout: true`). Recovery resets the PIN; it never
  silently disables the lock.

### Verification and the lockout ladder

`verify(entry)` is the core:

```
if (isLockedOut) return false;               // keypad is disabled anyway
if (_matches) { retryCount=0, clearLockout; save+emit; return true; }
retries    = retryCount + 1;
lockout    = PinLockoutPolicy.lockoutFor(retries);
lockedUntil = lockout == null ? null : now + lockout;
save+emit(retryCount: retries, lockedUntil);
return false;
```

`retryCount` is **cumulative and persisted** — it is only ever reset by a correct
PIN or a completed recovery. Because both `retryCount` and `lockedUntil` live in
secure storage, the escalation and any active cooldown **survive an app restart**;
force-quitting during a lockout does not clear it.

**`PinLockoutPolicy.lockoutFor(retryCount)`** (in `pin_config.dart`) maps the
post-increment attempt count to a cooldown:

| Cumulative failed attempts | Lockout |
|----------------------------|---------|
| 1–5 | none |
| 6–8 | 30 seconds |
| 9–10 | 5 minutes |
| 11–15 | 1 hour |
| 16–20 | 4 hours |
| 21+ | 24 hours |

### Biometrics (`local_auth`)

- `canUseBiometrics()` — `isDeviceSupported() && canCheckBiometrics`; any
  `Exception` → `false`. Used to hide the biometric toggle where unsupported.
- `authenticateBiometric()` — guards on `canCheckBiometrics || isDeviceSupported`,
  then `authenticate(localizedReason: 'Unlock Detoxo', persistAcrossBackgrounding:
  true)`; any `Exception` → `false`.

> Behaviour to note: the biometric path does **not** consult `isLockedOut`. A
> successful fingerprint/face unlock succeeds regardless of an active retry
> cooldown — the ladder only gates the numeric keypad. Biometrics are gated only
> by `biometricEnabled` being set at setup.

### Recovery glue

- `sendRecoveryOtp(email)` → `repo.sendRecoveryOtp(email).isOk`.
- `validateRecoveryOtp(email, otp)` → `repo.validateOtp(...).fold((_) => false,
  (valid) => valid)`.

---

## 7. Persistence & the recovery backend — `PinRepositoryImpl`

`PinRepositoryImpl` implements `PinRepository` over `LocalStore`'s **secure**
key-value API (`readSecret` / `writeSecret`, backed by `flutter_secure_storage`).
The whole `PinConfig` JSON is stored under `StoreKeys.pinConfig` (`'pin_config'`,
flagged `// secret`).

**Legacy migration.** `load()` handles installs that predate hashing and stored a
plaintext custom PIN under a `secret` key: if the config is `custom`, has no
`secretHash`, and a non-empty legacy `secret` is present, it hashes that secret
with a fresh salt, persists the migrated config, and returns it — so the plaintext
is never re-saved and never sits unhashed again.

**Recovery is a documented stub (offline-first).** With no backend wired, the two
OTP methods are local:

```dart
static const String _devOtp = '000000';

sendRecoveryOtp(email) => _isValidEmail(email)
    ? Ok(null)                                  // "sends" nothing; format-checks only
    : Err(ValidationFailure('Enter a valid email address.'));

validateOtp(email, otp) => Ok(otp.trim() == _devOtp);   // dev code 000000
```

Both carry code comments naming the intended real endpoints — a live impl would
`POST /communication/sendOtp` and `POST /communication/validateOtp`. **These are
the documented swap-in targets; do not treat them as live URLs.** `Result<T>` is
the app's tiny `Ok`/`Err` sum type (`lib/core/utils/result.dart`).

The dev OTP `000000` is surfaced to the user in the recovery sheet itself ("Dev
build: use 000000."), so QA can complete a reset without a mail server.

---

## 8. UI

### `PinLockScreen` (`pin_lock_screen.dart`)

The full-screen keypad. One widget, three roles, selected by its callbacks:

| Role | Trigger | `onUnlocked` | `onCancel` |
|------|---------|--------------|-----------|
| **Launch gate** | routed to `/pin/lock` from splash | `null` → screen calls `context.go(Routes.home)` itself | absent (forced) |
| **Inline guard** | `PinGuard` wraps a screen | reveals the child | `maybePop()` |
| **Action gate** | `requirePin()` pushes it | pops `true` | pops `false` |

Key behaviours:

- `PopScope(canPop: false)` — the system back gesture **never** dismisses it. A
  close (✕) affordance appears **only** when `onCancel` is provided (i.e. an
  optional in-app gate, never the launch gate).
- On mount, if `biometricEnabled`, it fires `authenticateBiometric()` via a
  post-frame callback (prompts immediately).
- `_onKey` appends a digit, ignores input past `expectedLength`, and auto-submits
  (`_attempt`) once the buffer is full. If locked, a keypress instead re-shows the
  lockout dialog.
- `_attempt` → `cubit.verify`; on success `_succeed` (success haptic + the role's
  unlock action); on failure it plays an error haptic + shake, shows "Incorrect
  PIN", clears the entry, and — reading the freshly-emitted state — pops the
  lockout dialog if a new cooldown just started.
- **Lockout UX is dual:** an inline `_LockoutText` ticks a live countdown
  (`formatCountdown`) driven by a 1 Hz timer (`_syncLockTimer`) that runs *only*
  while locked and re-enables the keypad the instant the window ends; plus a glass
  dialog ("Too many attempts. Please wait …") shown **once per distinct lockout
  window** (guarded by `_shownFor`) so repeated pokes and the 1 Hz rebuild can't
  spam it.
- Scope-specific copy (title/subtitle/icon) is provided for `app`, `settings`,
  `appLocker`, and `planSwitch`/`detoxoSettings`.
- The keypad is 1–9 then `[biometric] 0 [backspace]`: the bottom-left key is the
  fingerprint shortcut when `biometricEnabled`, otherwise empty. `_Dots` renders
  `expectedLength` progress dots (clamped 1–10).
- "Forgot PIN?" opens `PinRecoverySheet` with `onRecovered: _succeed` — a
  successful reset unlocks the current gate directly.

### `PinSetupScreen` (`pin_setup_screen.dart`)

Configure or turn off the lock. Loads the current `PinConfig` on init (filtering
scopes to `_supportedScopes = {app, settings}`) and probes `canUseBiometrics()` to
decide whether to show the biometric toggle.

Save validation (`_save`):

1. `type == none` → routes to `_turnOff` (confirm dialog then `disable()`; no-op if
   nothing was configured).
2. custom: PIN ≥ 4 digits, and PIN == confirm (both toast on failure).
3. at least one scope selected.
4. recovery email must be valid *if provided*; and for a **custom** PIN an email is
   effectively required (warns and aborts if empty) — so a forgotten custom PIN is
   always recoverable.
5. `setup(..., biometricEnabled: _biometric && _biometricAvailable)`, toast, pop.

The custom-PIN fields are digits-only, obscured, `maxLength: 10` (hint "Enter 4–10
digits"). Date/Time selections show a live derived-value preview instead of an
entry field. A bottom-sheet radio picker chooses among none / custom / date / time.

### `PinRecoverySheet` (`pin_recovery_sheet.dart`)

A glass bottom sheet with three steps (`_Step.email → code → newPin`):

1. **email** — if a `verifiedEmail` is already on file it is shown read-only and
   **masked** (`maskEmail`: `john.doe@example.com → j•••@e•••.com`); otherwise the
   user types one. "Send code" calls `sendRecoveryOtp` and, on success, advances
   and starts a 30-second resend cooldown. The dev-code hint ("use 000000") is
   toasted here.
2. **code** — a 6-digit field; "Verify" calls `validateRecoveryOtp`. A "Resend in
   Ns" button is disabled during the cooldown.
3. **newPin** — new PIN (≥ 4 digits) + confirm; on submit
   `resetSecretAfterRecovery(pin)` writes a fresh custom PIN (keeping scopes/email/
   biometrics, clearing the ladder) and pops `true`, which fires the caller's
   `onRecovered`.

---

## 9. Demanding the PIN — `requirePin` & `PinGuard`

`pin_gate.dart` is the boundary other features use; they never construct
`PinLockScreen` directly.

```dart
// Action gate — await it at the trigger of a protected action.
if (await requirePin(context, PinScope.settings)) {
  // proceed; false means the user cancelled or failed
}
```

- **`requirePin(context, scope)`** reads `PinCubit.state`; if the lock isn't
  configured *or* doesn't guard `scope`, it returns `true` immediately (no
  prompt). Otherwise it pushes a full-screen `PinLockScreen` on the **root**
  navigator and resolves to whether the user unlocked.
- **`PinGuard(scope:, child:)`** wraps a whole screen: it shows `child` immediately
  when the scope isn't guarded, otherwise renders the lock inline and pops back out
  on cancel.

Because both consult `isConfigured` + `guards(scope)` first, adding a `requirePin`
call is safe even when no PIN is set — it's a pass-through until the user opts in.

---

## 10. Wiring & integration

- **DI** (`lib/core/di/injector.dart`): `registerLazySingleton<PinRepository>(() =>
  PinRepositoryImpl(sl()))` (the `sl()` resolves `LocalStore`).
- **Provider** (`lib/main.dart`): `BlocProvider(create: (_) =>
  PinCubit(sl<PinRepository>()))` — one app-wide cubit.
- **Routes** (`lib/core/navigation/routes.dart` + `app_router.dart`):
  `pinSetup = '/pin/setup'` → `PinSetupScreen`, `pinLock = '/pin/lock'` →
  `PinLockScreen` (launch-gate form).
- **Splash gating** (`lib/app/splash_screen.dart`): `pin.load()` runs in the boot
  `Future.wait`; routing order is **onboarding → PIN lock → permissions → home** —
  if `pin.isConfigured && pin.guards(PinScope.app)`, splash sends the user to
  `/pin/lock` before anything else.
- **Settings** (`lib/features/settings/presentation/settings_screen.dart`): the PIN
  toggle pushes `/pin/setup`; every protected mutation (disabling blocking,
  resetting data, editing the PIN) is fenced behind `requirePin(context,
  PinScope.settings)`. The `LOCK_APP` block mode requires a configured PIN, so
  choosing it without one routes the user to PIN setup rather than selecting a mode
  that can't enforce anything.

---

## 11. Status / follow-ups

| Item | State |
|------|-------|
| Custom PIN storage | live — salted SHA-256, plaintext never persisted; legacy plaintext auto-migrated |
| Date/Time PINs | live — clock-derived convenience locks, no stored secret |
| Retry-lockout ladder | live — cumulative, persisted, survives restart |
| Biometric unlock | live via `local_auth` (Android); bypasses the keypad lockout by design |
| Email-OTP recovery | **stub** — dev code `000000`, offline "send"; real `/communication/sendOtp` + `/communication/validateOtp` are documented swap-ins |
| Hash KDF hardening | follow-up — single-round SHA-256 today |
| `LOCK_APP` native enforcement | follow-up — engine degrades to a back press (see [03-detection-engine.md](03-detection-engine.md)) |
| `otp` / `deviceDefault` PIN types, `planSwitch` / `appLocker` scopes | modeled for wire compatibility; not offered / pruned in the UI |
| iOS | unsupported (the whole app is Android-only) |

---

## Source files

- `lib/features/access_protection/access_protection.dart`
- `lib/features/access_protection/domain/entities/pin_config.dart`
- `lib/features/access_protection/domain/pin_hasher.dart`
- `lib/features/access_protection/domain/repositories/pin_repository.dart`
- `lib/features/access_protection/data/repositories/pin_repository_impl.dart`
- `lib/features/access_protection/presentation/pin_cubit.dart`
- `lib/features/access_protection/presentation/pin_gate.dart`
- `lib/features/access_protection/presentation/pin_lock_screen.dart`
- `lib/features/access_protection/presentation/pin_setup_screen.dart`
- `lib/features/access_protection/presentation/pin_recovery_sheet.dart`
- `lib/features/blocking/shared/domain/entities/enums.dart` (`PinType`, `PinScope`)
- `lib/core/storage/local_store.dart` (`StoreKeys.pinConfig`)
- `lib/core/utils/result.dart` (`Result` / `Ok` / `Err`)
- `lib/core/widgets/common_widgets.dart` (`formatCountdown`)
- `lib/core/di/injector.dart` (`PinRepository` registration)
- `lib/main.dart` (`PinCubit` provider)
- `lib/core/navigation/routes.dart`, `lib/core/navigation/app_router.dart` (`/pin/setup`, `/pin/lock`)
- `lib/app/splash_screen.dart` (launch gating)
- `lib/features/settings/presentation/settings_screen.dart` (`requirePin` call sites)
