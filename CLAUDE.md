# Detoxo — project rules

**Detoxo** is an Android-first short-form-content (Reels / Shorts / infinite-feed) **blocker +
on-device reel counter**, built in Flutter with a native Kotlin AccessibilityService engine.

## Identity & stack
- App name **Detoxo**; package / applicationId **`com.errorxperts.detoxo`**; vendor namespace
  **errorxperts** (support: `errorxperts@gmail.com`).
- **flutter_bloc (Cubit) + get_it (`sl`) + go_router**. No Riverpod, no BLoC-with-events mega-blocs.
- **Feature-first Clean Architecture**: each feature under `lib/features/<x>` has
  `data / domain / presentation`; a feature is reached only through its public barrel
  (`features/<x>/<x>.dart`) or another feature's `domain/` contracts — never its internals.
  Enforced by `tool/check_boundaries.sh` (run in CI).
- The **hot detection/block path is native** (`android/app/src/main/kotlin/com/errorxperts/detoxo/`).
  Dart owns config, settings and UI. Native ↔ Dart over **one** MethodChannel
  `com.errorxperts.detoxo/commands` + **one** EventChannel `com.errorxperts.detoxo/events`.

## Naming invariants (never break)
- Never write `noscroll`, `curizic`, `brainpal`, `newswarajya`, `no_scroll`, or `:as_process` —
  those are a prior app / an outdated blueprint. Use **Detoxo** / **errorxperts**.
- The blocking-plan token **`curious` / `"CURIOUS"`** is real (native
  `PLAN_CONSCIOUS = "CURIOUS"`); keep it verbatim in code/wire. Its **UI label is "Conscious"** —
  use "Conscious" in user-facing text.

## Documentation rule
Docs live in `docs/code_docs/` (engineering) and `docs/info_docs/` (end-user / marketing).
**When you change a feature under `lib/features/**` or its native code under
`android/app/src/main/kotlin/com/errorxperts/detoxo/**` (or `pubspec.yaml`, `assets/config`,
`assets/content`, the manifest / `res/xml`), update the mapped doc in `docs/code_docs/` — and
the relevant `docs/info_docs/` section if the change is user-facing.** The feature→doc mapping
and the update checklist live in `.claude/skills/docs-sync/SKILL.md` (run **`/docs-sync`**).

## Build / test
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # freezed / json models
flutter analyze
flutter test
bash tool/check_boundaries.sh                               # architecture boundaries
```
This build is **offline-first**: no backend, premium is a local dev-unlock, analytics is local,
AdMob uses Google test ids, iOS shows an "unsupported" screen. See `docs/code_docs/16-implementation-roadmap.md`.
