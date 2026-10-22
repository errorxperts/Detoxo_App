# 23 · Testing Runbook & IDE Run Configurations

How to actually run Detoxo's tests — from a terminal, from Android Studio, or from VS Code.

This is the **human** runbook. The agent-facing version, with the report format and the computed
quality score, is `.claude/skills/detoxo-auto-test/SKILL.md` (run **`/detoxo-auto-test`**). The
strategy and rationale behind the layers live in
[16 Status & Roadmap §5](16-implementation-roadmap.md).

Everything goes through **one driver**, `tool/qa.sh`. Nothing below duplicates a command — the
IDE configurations invoke the same script.

## Quick reference

```bash
bash tool/qa.sh [-d <serial>] [--reset] [--baseline] \
  {functional|e2e|perf|blocking|blockers|all|prep|restore|devices}
```

| Command | Device? | Time | What it does |
|---|---|---|---|
| `functional` | no | ~3m | format → token checks → analyze → ~1,380 unit/widget tests → native JVM tests → boundary check |
| `devices` | no | instant | list attached, authorised phones |
| `prep` | yes | ~10s–5m | grant accessibility + overlay, keep the screen awake |
| `e2e` | yes | ~4m | boot the real app, walk every gate, screenshot each step |
| `perf` | yes | ~12m | cold start + frame timeline + memory + APK size vs baseline |
| `blocking` | yes | ~90s | engine bound-check + 60s logcat watch while you scroll a reel |
| `blockers` | yes | — | App Blocker + Web Blocker walk (`blockers_e2e_test.dart`) with real block probes; needs YouTube + Chrome |
| `all` | yes | ~17m | `functional` → `e2e` → `perf`, in that order |
| `restore` | yes | ~5s | put the device back exactly as you found it |

`-d` is optional when exactly one phone is attached — the driver resolves it, and lists them if
there is more than one. Artifacts land in `build/qa/` (gitignored).

The Android-free engine logic has plain JVM tests too (`engine/ReelTracker`, the reel
counter's identity + dwell state machine; `engine/UsageQuery`, the usage-stats filters, local
midnight and the opens-today transition count; `overlay/BlockScreenGeometry`, the block screen's
flags, strip math, plan labels, payload sanitiser, style parsing (old keys ignored), the
`wallIsDark` table and the wall's and the nudge card's contrast in both themes for every accent,
read from the generated `DxTokens`; `overlay/FrozenGlass`, the native kit's pure helpers (CSS
gradient line, blur σ, hue-rotate / saturate, `clockLabel`, the hero icon per reason, `wallFit`,
the slide's 88 % threshold, the ambient falloff, the waiting knob); `overlay/WallPolicy`, which
block raises a wall and which skips the Appearance switch; `overlay/QuoteBook`, quote picking; `overlay/AccentResolver`, the live-accent mirror, on every
row of `test/fixtures/accent_cases.json`, which the Dart `accent_test` reads too). `dev.sh precommit` (and so
`qa.sh functional`) runs them through `native_tests()` when it can find a JDK 17+
(`$JAVA_HOME`, macOS `java_home -v 17+`, or the Homebrew `openjdk@17` keg) and
**warns and skips** otherwise — a host without a JDK never fails the gate, it just
doesn't cover the native rule. A checkout without `android/gradlew` (gitignored, so a fresh
clone or git worktree has none) **fails** with a pointer to `flutter build apk --config-only`,
which injects the wrapper. To run them alone:

```bash
cd android && JAVA_HOME=<jdk17> ./gradlew :app:testDebugUnitTest --tests '*ReelTrackerTest*'
# report: build/app/reports/tests/testDebugUnitTest/index.html
```

`all` runs cheapest-first so a red Layer 1 shows up in minutes instead of 17. Each device
layer is self-contained — `perf` installs its own profile APK and clears its own
onboarding/permission gates — so you can run them individually, in any order.

## Everyday loop

```bash
flutter test test/<feature>_test.dart   # while iterating on one feature — seconds, not minutes
bash tool/dev.sh precommit     # before every commit — format, token checks, analyze, test, native tests (JDK 17), boundaries
```

`precommit` checks both generated token sets before it analyzes anything:
`widget_tokens` (`tool/home_widget/gen_tokens.dart --check`) and `design_tokens`
(`tool/design/gen_design_tokens.dart --check`, which fails when `app_tokens.g.dart` or
`DxTokens.kt` no longer match `tool/design/{tokens,recipes}.json`). After editing either JSON,
run the generator without `--check` and commit its outputs.
`test/core/design_system/design_tokens_test.dart` runs the same check through `Process.run`, so
it needs `dart` on `PATH` (present under `dev.sh` and in the IDEs).

Theme a widget test with `AppTheme.dark()` / `AppTheme.light()` rather than a hand-built `ThemeData`:
`context.tokens` follows the theme's brightness and needs no registration, and the text slots and
the scheme then match the app.

`/detoxo-auto-test` scopes itself to the feature named in the chat (targeted tests first, the
full gate once at the end) and only runs the whole suite for "ready to ship" style asks — see
`.claude/skills/detoxo-auto-test/SKILL.md`.

`tool/qa.sh functional` delegates to exactly this, and additionally tees the output to
`build/qa/functional.log` and the exit code to `build/qa/functional.rc` so the report can score
it. Use `dev.sh precommit` when you just want the gate; use `qa.sh functional` when you are
producing a QA report.

## Android Studio

Thirteen shared run configurations live in `.idea/runConfigurations/` and appear in the run
dropdown as soon as the project is opened. They are checked in — `.gitignore` keeps the rest of
`.idea/` local:

```gitignore
.idea/*
!.idea/runConfigurations/
```

> `.idea/*`, **not** `.idea/`. A trailing slash makes git skip the directory entirely, so a
> negation underneath it can never re-include anything.

| Configuration | Runs |
|---|---|
| Detoxo (debug) / (profile) | `lib/main.dart` |
| Unit + widget tests | `test/` folder |
| Dev · precommit | `tool/dev.sh precommit` |
| QA · functional (no device) | `tool/qa.sh functional` |
| QA · devices / prep device / restore device | `tool/qa.sh devices｜prep｜restore` |
| QA · e2e walk + screenshots | `tool/qa.sh e2e` |
| QA · perf (gate vs baseline) / (adopt new baseline) | `tool/qa.sh perf` / `--baseline perf` |
| QA · blocking smoke | `tool/qa.sh blocking` |
| QA · all (functional-e2e-perf) | `tool/qa.sh all` |

The `QA ·` / `Dev ·` entries are **Shell Script** configurations (bundled plugin) with
*Execute in terminal* on, so the interactive prompts — the `--reset` confirmation, the "scroll a
reel now" window — work normally.

## VS Code

`.vscode/launch.json` (5 launch configs) and `.vscode/tasks.json` (11 tasks), both checked in.

- **Run and Debug** → app in debug / profile / release, plus the two real-boot integration tests.
- **Terminal ▸ Run Task…** → the whole `qa.sh` surface. `QA: functional (no device)` is the
  default test task, so <kbd>⌘⇧P</kbd> ▸ *Run Test Task* runs the gate.

Two deliberate details:

- **`E2E walk (device, needs prep)` carries `preLaunchTask: "QA: prep device"`.** The app cannot
  get past `/permissions` without the accessibility + overlay grants, and that screen has no skip
  — launching the test without prep just parks it at the wall until it times out.
- **There is no launch config for the frame timeline.** It needs
  `flutter drive --no-dds --keep-app-running`, and a launch config cannot pass those. Use the
  **QA: perf** task.

## First run on a new phone

1. Enable *Developer options ▸ USB debugging*, plug in, accept the RSA prompt.
2. `bash tool/qa.sh devices` — confirm it shows `device`, not `unauthorized`/`offline`.
3. `bash tool/qa.sh prep` — grants accessibility over adb and keeps the screen awake.
4. **On realme/ColorOS and MIUI/HyperOS, grant the overlay by hand when prompted.** There is no
   adb path: `appops set` fails with `uid 2000 does not have MANAGE_APP_OPS_MODES` and `pm grant`
   with `GRANT_RUNTIME_PERMISSIONS`. `prep` opens the settings page and waits up to 300s.
   The grant survives `adb install -r` but **not** an uninstall — and `flutter test -d`
   uninstalls the app when it finishes, so expect one manual grant per device-facing phase.
5. When you are done: **`bash tool/qa.sh restore`** — last, and after `blocking`, which needs the
   app installed.

`--reset` (`pm clear`) is opt-in and prompts for a typed `YES`, because it destroys real Hive,
secure-storage and engine data on that phone.

## Reading the artifacts

| File | What it holds |
|---|---|
| `build/qa/functional.log` / `.rc` | Layer 1 output and exit code |
| `build/qa/e2e.status` / `e2e.log` | `pass`/`fail` + the full walk log |
| `build/qa/shots/NN-<step>.png` | one screenshot per walk step, in order |
| `build/qa/metrics.json` | this run's numbers |
| `build/qa/baseline.json` | what they are compared against |
| `build/qa/blocking.status` | `blocked｜inconclusive｜skipped｜unbound｜notinstalled` |
| `build/qa/adb_state.env` | the device settings `restore` puts back |

Re-score a run without re-measuring anything (reads only files already on disk):

```bash
QA_APK_BYTES=$(stat -f%z build/app/outputs/flutter-apk/app-release.apk) python3 tool/qa_metrics.py
```

**Open the screenshots.** A green `e2e.status` with a blank PNG is not a pass.

## Troubleshooting

Symptom → cause → fix. Every one of these was hit on a real device.

| Symptom | Fix |
|---|---|
| `no adb device` but the phone is plugged in | Unlock it; accept the RSA prompt. `adb devices` showing `unauthorized` means the prompt was dismissed. |
| Walk parks on "Grant required permissions" | Accessibility was revoked by the reinstall. `qa.sh` re-asserts it on a 1s loop; if it persists, run `prep` again. |
| `A test overrode FlutterError.onError` | The test booted the app without `bootApp()` from `integration_test/qa_walk.dart`. Crashlytics replaces both error handlers. |
| Drive dies: `Failed to connect to VM Service … Connection refused` | Missing `--no-dds`. `traceAction` opens its own socket to the port DDS holds. |
| Phone soft-reboots mid-suite (`JNI FatalError … /data_mirror/…`) | Missing `--keep-app-running`; the exit-time uninstall raced a spawning process. |
| Memory gate fails but `apk_size_bytes` delta is 0 | The binary did not change, so this is measurement conditions. `dumpsys meminfo` is screen-dependent; re-adopt the baseline. |
| `flutter drive` fails inside `driver.requestData` | Look further down for `adb: device '<serial>' not found` — a dropped USB link reads exactly like a driver bug. Reseat the cable and re-run. |
| `blocking` reports `notinstalled` | `restore` uninstalls the app, so `blocking` must run **before** it. Re-run `e2e` or `perf` to reinstall, then `blocking`. |
| Phone locks mid-run and the overlay page is unreachable | `prep` sets `svc power stayon usb`; if the run started before that landed, unlock and re-run. |
| `dart format` crashes with `PathNotFoundException` | Never run `dart format .` — it walks `build/ios/SourcePackages/`. `tool/dev.sh` formats only `lib test integration_test test_driver`. |

## Writing a new on-device test

Put shared helpers in `integration_test/qa_walk.dart` and import it with the documented
`// ignore: always_use_package_imports` — `integration_test/` sits outside `lib/`, so `package:`
cannot reach it. Then:

- Boot with **`bootApp()`**, never a bare `app.main()`.
- Settle with `settle()` / `waitFor()`, not `pumpAndSettle`: the boot walk still meets the
  splash's indeterminate `LoadingState` spinner, which turns while animations are on. Nothing else
  in the app loops, so a widget test of one screen may `pumpAndSettle` — except while an
  indeterminate spinner is mounted without `disableAnimations`.
- **One** `app.main()` per file; `configureDependencies()` cannot be re-registered.
- `find.text` matches the *rendered* string: `SectionHeader` uppercases, the `AppTabBar`
  renders both tab names (so `'Insights'` matches the tab label as well as the tab's header —
  scope such finders to the `AppTabBar` / `TabHeader` / `GlassAppBar`), and widgets below a lazy
  sliver are never built at all.

## Source files

- `tool/qa.sh` · `tool/qa_metrics.py` · `tool/dev.sh` · `tool/check_boundaries.sh`
- `tool/design/gen_design_tokens.dart` · `tool/home_widget/gen_tokens.dart` · `test/core/design_system/design_tokens_test.dart`
- `integration_test/qa_walk.dart` · `app_e2e_test.dart` · `onboarding_e2e_test.dart` · `blockers_e2e_test.dart` · `app_perf_test.dart` · `pin_dialog_test.dart` · `pin_setup_flow_test.dart`
- `test_driver/perf_driver.dart`
- `.idea/runConfigurations/*.xml` · `.vscode/launch.json` · `.vscode/tasks.json`
- `.claude/skills/detoxo-auto-test/SKILL.md`
