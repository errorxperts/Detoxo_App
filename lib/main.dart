import 'dart:async';

import 'package:detoxo/app/app_resume_sync.dart';
import 'package:detoxo/app/engine_sync.dart';
import 'package:detoxo/app/starter_rule_sync.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/app_gate.dart';
import 'package:detoxo/core/navigation/app_router.dart';
import 'package:detoxo/core/services/firebase/firebase.dart';
import 'package:detoxo/features/access_protection/domain/repositories/pin_repository.dart';
import 'package:detoxo/features/access_protection/presentation/pin_auto_relock.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:detoxo/features/additional_feature/app_feedback/app_feedback.dart';
import 'package:detoxo/features/analytics/analytics.dart';
import 'package:detoxo/features/blocking/block_screen/domain/repositories/block_screen_repository.dart';
import 'package:detoxo/features/blocking/block_screen/presentation/block_screen_style_cubit.dart';
import 'package:detoxo/features/blocking/blocklist/presentation/targets_cubit.dart';
import 'package:detoxo/features/blocking/engine/presentation/service_cubit.dart';
import 'package:detoxo/features/blocking/plans/presentation/conscious_cubit.dart';
import 'package:detoxo/features/blocking/plans/presentation/reel_session_cubit.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:detoxo/features/limits/daily_limit/domain/entities/daily_limit.dart';
import 'package:detoxo/features/limits/daily_limit/domain/repositories/daily_limit_repository.dart';
import 'package:detoxo/features/limits/daily_limit/presentation/daily_limit_cubit.dart';
import 'package:detoxo/features/limits/rules/domain/repositories/rule_repository.dart';
import 'package:detoxo/features/limits/rules/presentation/rules_cubit.dart';
import 'package:detoxo/features/limits/streak/domain/repositories/streak_repository.dart';
import 'package:detoxo/features/limits/streak/presentation/streak_cubit.dart';
import 'package:detoxo/features/limits/unblock/domain/repositories/unblock_repositories.dart';
import 'package:detoxo/features/limits/unblock/presentation/unblock_cubit.dart';
import 'package:detoxo/features/limits/unblock/presentation/widgets/pending_unblock_listener.dart';
import 'package:detoxo/features/permissions/permissions.dart';
import 'package:detoxo/features/permissions/presentation/permissions_cubit.dart';
import 'package:detoxo/features/usage/usage.dart';
import 'package:detoxo/firebase_options.dart';
import 'package:feedback/feedback.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The home-widget previews' font, Manrope, ships under the OFL, which asks
  // for its licence to travel with it. Registered once: the bootstrap re-runs.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Manrope',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  // Telemetry init is best-effort: no offline-first app should fail to launch
  // because a Firebase handshake did not come back. DI is NOT in that bucket —
  // without it there is no app to show, so it stays outside the guard.
  await guardedSync(
    'firebase',
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
  );
  // Route uncaught framework and async errors to Crashlytics as early as
  // possible (before DI), so init-time crashes are captured.
  FirebaseCrashReportingService.installGlobalHandlers();
  // Transparent bars only; each theme sets its own icon brightness through
  // the AnnotatedRegion in the app builder.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  await configureDependencies();
  // Telemetry: capture cubit events/errors globally, then switch on collection,
  // the anonymous install id and the native-event reporter.
  Bloc.observer = FirebaseBlocObserver(
    sl<AnalyticsService>(),
    sl<CrashReportingService>(),
  );
  await guardedSync('firebaseServices', FirebaseServices.start(sl));
  GlassAppBar.globalActionsBuilder = (_) => const [FeedbackActionButton()];
  runApp(const DetoxoApp());
}

class DetoxoApp extends StatelessWidget {
  const DetoxoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ServiceCubit(sl<EngineRepository>())),
        BlocProvider(create: (_) => ConsciousCubit(sl<EngineRepository>())),
        BlocProvider(create: (_) => ReelSessionCubit(sl<EngineRepository>())),
        BlocProvider(
          create: (_) =>
              SettingsCubit(sl<SettingsRepository>(), sl<EngineRepository>()),
        ),
        BlocProvider(
          create: (_) => TargetsCubit(
            sl<ConfigRepository>(),
            sl<EngineRepository>(),
            performance: sl<PerformanceService>(),
          ),
        ),
        BlocProvider(
          create: (_) => PermissionsCubit(sl<PermissionRepository>()),
        ),
        BlocProvider(create: (_) => PinCubit(sl<PinRepository>())),
        // Live reel-counter stream (today count + today usage time) and the
        // daily limit — both feed the dashboard screen-time ring.
        BlocProvider(
          create: (_) => ContentCounterCubit(
            sl<ContentCounterRepository>(),
            sl<BubbleRepository>(),
          ),
        ),
        // Bubble + widget styling, shared by the Appearance hub and both
        // editors. Lazy: hydrated from native on the first screen that reads it.
        BlocProvider(
          create: (_) =>
              CounterAppearanceCubit(sl<CounterAppearanceRepository>()),
        ),
        // Block-screen style + its on/off switch, shared by the Appearance
        // hub's card and the editor. Lazy: hydrated from native on first read.
        BlocProvider(
          create: (_) => BlockScreenStyleCubit(sl<BlockScreenRepository>()),
        ),
        BlocProvider(
          create: (_) => DailyLimitCubit(sl<DailyLimitRepository>()),
        ),
        // "Days under your daily limit" streak — fed by the dashboard hero and
        // read back into its stat pill.
        BlocProvider(create: (_) => StreakCubit(sl<StreakRepository>())),
        // EVO-058: the Activity tab's screen-time rollups. Lazy, so nothing
        // is computed at boot — the first Activity open constructs it — and
        // app-wide so the tab (rebuilt on every switch) and the drawer route
        // share one instance: a later open paints the last numbers at once
        // and refreshes in place instead of flashing a spinner and running
        // two channel queries per mount. Not `..load()`ed: the view refreshes
        // on mount.
        BlocProvider(
          create: (_) =>
              InsightsCubit(sl<InsightsRepository>(), sl<EngineRepository>()),
        ),
        // Blocking rules (schedules / limits) + THE Dart push path for the
        // native rules snapshot: cold start via `runBootstrap`, resume via
        // AppResumeSync, every edit, and native `ruleBoundary` events.
        // Deliberately NOT `..load()`ed here: bootstrap owns the initial load
        // for this cubit, `DailyLimitCubit` and `StreakCubit`, because it also
        // has to re-run them after an in-process "Reset app data" wipe. Loading
        // in both places ran every one of them twice on every cold start.
        BlocProvider(
          create: (_) => RulesCubit(
            sl<RuleRepository>(),
            sl<DailyLimitRepository>(),
            sl<UsageRepository>(),
            sl<EngineRepository>(),
            ledger: sl<BypassLedgerRepository>(),
          ),
        ),
        // M8: app-wide because four surfaces reach it — the App Blocker and
        // Website blocker rows, the rules screen's override, and the sheet the
        // native wall's "Allow for a while" opens on the next resume.
        BlocProvider(
          create: (_) => UnblockCubit(
            sl<TemporaryUnblockRepository>(),
            sl<BypassLedgerRepository>(),
            sl<EngineRepository>(),
          ),
        ),
      ],
      // The router's gate is fed from here rather than read inside the redirect:
      // cubits are Streams and `refreshListenable` wants a Listenable, and this
      // keeps core/navigation free of feature imports.
      child: MultiBlocListener(
        listeners: [
          BlocListener<SettingsCubit, AppSettings>(
            listenWhen: (a, b) => a.onboarded != b.onboarded,
            listener: (_, s) => sl<AppGate>().update(onboarded: s.onboarded),
          ),
          BlocListener<PermissionsCubit, List<PermissionStatus>>(
            listener: (context, _) => sl<AppGate>().update(
              permissionsOk: context
                  .read<PermissionsCubit>()
                  .allRequiredGranted,
            ),
          ),
        ],
        child: BlocListener<SettingsCubit, AppSettings>(
          listenWhen: (a, b) => a.vibrationEnabled != b.vibrationEnabled,
          listener: (_, state) => AppHaptics.enabled = state.vibrationEnabled,
          // The Daily Limit is enforced through the rules snapshot (its native
          // reel-time meter), so a saved limit re-pushes it.
          child: BlocListener<DailyLimitCubit, DailyLimit>(
            listenWhen: (a, b) => a.limit != b.limit,
            listener: (context, _) =>
                unawaited(context.read<RulesCubit>().resync()),
            child: BlocSelector<SettingsCubit, AppSettings, AppThemeMode>(
              selector: (s) => s.themeMode,
              builder: (_, mode) => _Router(themeMode: _flutterThemeMode(mode)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether [mode] shows the Dark theme right now.
bool _darkFor(ThemeMode mode) => switch (mode) {
  ThemeMode.dark => true,
  ThemeMode.light => false,
  ThemeMode.system =>
    WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark,
};

/// Maps the domain appearance preference to a Flutter [ThemeMode].
ThemeMode _flutterThemeMode(AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => ThemeMode.system,
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.dark => ThemeMode.dark,
};

class _Router extends StatefulWidget {
  const _Router({required this.themeMode});

  final ThemeMode themeMode;

  @override
  State<_Router> createState() => _RouterState();
}

class _RouterState extends State<_Router> {
  final _router = buildRouter();

  @override
  void initState() {
    super.initState();
    // The bubble and the home widgets paint the static spec brand of their
    // own brightness; one push at start keeps native in step with it.
    unawaited(
      sl<CounterAppearanceRepository>().setBrands(
        light: AppTokens.light.brand.main.toARGB32(),
        dark: AppTokens.dark.brand.main.toARGB32(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BetterFeedback(
      themeMode: widget.themeMode,
      theme: glassFeedbackTheme(Brightness.light),
      darkTheme: glassFeedbackTheme(Brightness.dark),
      // The form sits above MaterialApp, so it gets the app theme here.
      feedbackBuilder: (context, onSubmit, scrollController) => Theme(
        data: _darkFor(widget.themeMode) ? AppTheme.dark() : AppTheme.light(),
        child: GlassFeedbackForm(
          onSubmit: onSubmit,
          scrollController: scrollController,
        ),
      ),
      child: AppResumeSync(
        // Arms the first run's starter rule on the accessibility-grant edge.
        // App-wide so a grant made from anywhere counts, not just from the
        // permission screen.
        child: StarterRuleSync(
          child: PinAutoRelock(
            router: _router,
            gate: sl<AppGate>(),
            child: MaterialApp.router(
              title: 'Detoxo',
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: widget.themeMode,
              // Snap a theme change, as `context.tokens` does.
              themeAnimationDuration: Duration.zero,
              routerConfig: _router,
              debugShowCheckedModeBanner: false,
              // M8: the sheet a wall's "Allow for a while" opens. Mounted
              // here, INSIDE the router, so it can never float over the PIN
              // lock or the splash.
              // A home-widget tap's screen (IM-08), mounted the same way.
              builder: (context, child) =>
                  AnnotatedRegion<SystemUiOverlayStyle>(
                    value: AppTheme.overlay(Theme.of(context).brightness),
                    child: PendingUnblockListener(
                      child: WidgetTapListener(
                        child: child ?? const SizedBox(),
                      ),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
