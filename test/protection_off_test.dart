import 'package:bloc_test/bloc_test.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/app_gate.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/storage/local_store.dart';
import 'package:detoxo/features/access_protection/access_protection.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:detoxo/features/access_protection/presentation/pin_setup_screen.dart';
import 'package:detoxo/features/additional_feature/app_upgrader/app_upgrader.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/features/limits/app_blocker/domain/repositories/app_block_repository.dart';
import 'package:detoxo/features/limits/rules/domain/entities/rule.dart';
import 'package:detoxo/features/limits/rules/domain/entities/rule_editor_args.dart';
import 'package:detoxo/features/limits/rules/presentation/rule_editor_screen.dart';
import 'package:detoxo/features/limits/rules/presentation/rules_cubit.dart';
import 'package:detoxo/features/limits/unblock/presentation/unblock_cubit.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_stats.dart';
import 'package:detoxo/features/limits/web_blocker/domain/repositories/web_block_repository.dart';
import 'package:detoxo/features/limits/web_blocker/domain/repositories/web_block_stats_repository.dart';
import 'package:detoxo/features/limits/web_blocker/presentation/web_protection_screen.dart';
import 'package:detoxo/features/permissions/domain/entities/permission_status.dart';
import 'package:detoxo/features/permissions/domain/repositories/permission_repository.dart';
import 'package:detoxo/features/permissions/presentation/permissions_cubit.dart';
import 'package:detoxo/features/settings/presentation/settings_screen.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

// C9: every action that turns protection off is PIN first (where the PIN
// exists), then a critical ConfirmSheet. A cancel commits nothing, so the
// state-bound switch snaps back; turning anything on stays direct.

class _FakePinRepo implements PinRepository {
  PinConfig stored = const PinConfig();

  @override
  Future<PinConfig> load() async => stored;
  @override
  Future<void> save(PinConfig config) async => stored = config;
  @override
  Future<void> setSecureScreen({required bool enabled}) async {}
  @override
  Future<int> lastScreenOffMillis() async => 0;
  @override
  Future<({int elapsedMs, int bootCount})?> monotonicNow() async => null;
}

class _NoPermissions implements PermissionRepository {
  @override
  Future<List<PermissionStatus>> statuses() async => const [];
  @override
  Future<Set<AppPermission>> lastKnownGranted() async => const {};
  @override
  Future<bool> installedOutsidePlay() async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _NoUpgrade implements AppUpgradeService {
  @override
  Future<UpgradeStatus?> check({bool force = false}) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _Store implements LocalStore {
  bool cleared = false;
  @override
  Future<void> clearAll() async => cleared = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _MemSettings implements SettingsRepository {
  AppSettings value = const AppSettings();
  @override
  Future<AppSettings> load() async => value;
  @override
  Future<void> save(AppSettings settings) async => value = settings;
  @override
  Stream<AppSettings> watch() => const Stream.empty();
}

class _MockSettings extends MockCubit<AppSettings> implements SettingsCubit {}

class _MockUnblock extends MockCubit<UnblockState> implements UnblockCubit {}

class _MockRules extends MockCubit<RulesState> implements RulesCubit {}

/// Every engine call is a no-op that answers null.
class _Engine implements EngineRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<Null>.value();
}

class _MockWebRepo extends Mock implements WebBlockRepository {}

class _MockAppBlocks extends Mock implements AppBlockRepository {}

class _MockStats extends Mock implements WebBlockStatsRepository {}

/// Fixed frames: the GlassScaffold ambient never lets pumpAndSettle converge.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _toggle(WidgetTester tester, String title) async {
  final toggle = find.descendant(
    of: find.widgetWithText(AppToggleTile, title),
    matching: find.byType(AppToggle),
  );
  await tester.scrollUntilVisible(
    toggle,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(toggle);
  await _settle(tester);
}

bool _toggleValue(WidgetTester tester, String title) => tester
    .widget<AppToggle>(
      find.descendant(
        of: find.widgetWithText(AppToggleTile, title),
        matching: find.byType(AppToggle),
      ),
    )
    .value;

/// The sheet's copy, word for word, and its critical tone (the well's 6 px
/// halo is the tone's `b` at 18 %).
void _expectSheet(
  WidgetTester tester, {
  required String title,
  required String message,
  required String cancel,
}) {
  expect(find.text(title), findsOneWidget);
  expect(find.text(message), findsOneWidget);
  expect(find.text(cancel), findsOneWidget);
  final halo = ConfirmTone.critical.b.withValues(alpha: 0.18);
  expect(
    find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          ((w.decoration as BoxDecoration).boxShadow?.any(
                (s) => s.color == halo,
              ) ??
              false),
    ),
    findsOneWidget,
  );
}

Finder _icon3d(AssetGenImage asset, {bool tint = false}) =>
    find.byWidgetPredicate(
      (w) => w is Icon3d && w.asset.path == asset.path && w.accentTint == tint,
    );

/// Waits out the 5 s, then confirms with a semantic tap on the ready knob
/// (TalkBack's double-tap; [action] is its label) and lets the sheet close.
Future<void> _confirm(WidgetTester tester, String action) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(milliseconds: 700));
  tester.semantics.tap(find.semantics.byLabel(action));
  await tester.pump(const Duration(seconds: 1));
  await _settle(tester);
}

Future<void> _cancel(WidgetTester tester, String cancel) async {
  await tester.tap(find.text(cancel));
  await _settle(tester);
}

/// Unlocks the pushed PinLockScreen with the test PIN.
Future<void> _enterPin(WidgetTester tester) async {
  expect(find.text('Confirm to change protected settings'), findsOneWidget);
  for (final digit in ['1', '2', '3', '4']) {
    await tester.tap(find.text(digit));
    await tester.pump();
  }
  await tester.pump(const Duration(seconds: 1));
  await _settle(tester);
}

/// Toasts time out; flutter_animate's exit leaves one zero-length timer.
Future<void> _drainToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Future<PinCubit> _pin({bool guarded = true}) async {
  final cubit = PinCubit(_FakePinRepo());
  if (guarded) {
    await cubit.setup(
      type: PinType.custom,
      secret: '1234',
      scopes: {PinScope.settings},
    );
  }
  return cubit;
}

void main() {
  group('Settings', () {
    late _MockSettings settings;
    late AppSettings current;
    late _Store store;

    setUp(() async {
      await sl.reset();
      store = _Store();
      sl
        ..registerSingleton<AppUpgradeService>(_NoUpgrade())
        ..registerSingleton<LocalStore>(store)
        ..registerSingleton<AppGate>(AppGate());
      settings = _MockSettings();
      current = const AppSettings();
      when(() => settings.state).thenAnswer((_) => current);
      when(
        () => settings.setMasterEnabled(enabled: any(named: 'enabled')),
      ).thenAnswer((i) async {
        current = current.copyWith(
          masterEnabled: i.namedArguments[#enabled] as bool,
        );
      });
    });

    tearDown(sl.reset);

    Future<void> pump(WidgetTester tester, PinCubit pin) async {
      final unblock = _MockUnblock();
      when(() => unblock.state).thenReturn(const UnblockState());
      final router = GoRouter(
        initialLocation: Routes.settings,
        routes: [
          GoRoute(
            path: Routes.splash,
            builder: (_, _) => const Scaffold(body: Text('at splash')),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (_, _) => const SettingsScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<SettingsCubit>.value(value: settings),
            BlocProvider<UnblockCubit>.value(value: unblock),
            BlocProvider.value(value: pin),
            BlocProvider(create: (_) => PermissionsCubit(_NoPermissions())),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await _settle(tester);
    }

    testWidgets('master off: PIN first, then the sheet; cancel snaps back', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, await _pin());

      // A cancelled PIN never opens the sheet.
      await _toggle(tester, 'Blocking active');
      expect(find.text('Turn off blocking?'), findsNothing);
      await tester.tap(find.byTooltip('Cancel'));
      await _settle(tester);
      expect(find.text('Turn off blocking?'), findsNothing);

      await _toggle(tester, 'Blocking active');
      await _enterPin(tester);
      _expectSheet(
        tester,
        title: 'Turn off blocking?',
        message:
            'Reels, apps and sites stay unblocked until you turn it back on.',
        cancel: 'Keep blocking',
      );
      expect(
        _icon3d(Assets.images.icons.iconBlockAll, tint: true),
        findsOneWidget,
      );
      await _cancel(tester, 'Keep blocking');
      verifyNever(
        () => settings.setMasterEnabled(enabled: any(named: 'enabled')),
      );
      expect(_toggleValue(tester, 'Blocking active'), isTrue);
      semantics.dispose();
    });

    testWidgets('master off: the slide commits, then toasts', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, await _pin(guarded: false));
      await _toggle(tester, 'Blocking active');
      await _confirm(tester, 'Slide to turn off');
      verify(() => settings.setMasterEnabled(enabled: false)).called(1);
      expect(find.text('Blocking is off'), findsOneWidget);
      await _drainToast(tester);
      semantics.dispose();
    });

    testWidgets('master on stays direct, with no PIN', (tester) async {
      current = const AppSettings(masterEnabled: false);
      await pump(tester, await _pin());
      await _toggle(tester, 'Blocking active');
      expect(find.text('Confirm to change protected settings'), findsNothing);
      expect(find.text('Turn off blocking?'), findsNothing);
      verify(() => settings.setMasterEnabled(enabled: true)).called(1);
    });

    testWidgets('PIN lock off: PIN first, then confirmPinOff', (tester) async {
      final semantics = tester.ensureSemantics();
      final pin = await _pin();
      await pump(tester, pin);

      await _toggle(tester, 'PIN lock');
      await _enterPin(tester);
      _expectSheet(
        tester,
        title: 'Turn off PIN lock?',
        message: 'Detoxo and its protected settings stop asking for a PIN.',
        cancel: 'Keep it on',
      );
      expect(find.byType(DetoxoLogo), findsOneWidget);
      await _cancel(tester, 'Keep it on');
      expect(pin.state.isConfigured, isTrue);
      expect(_toggleValue(tester, 'PIN lock'), isTrue);

      await _toggle(tester, 'PIN lock');
      await _enterPin(tester);
      await _confirm(tester, 'Slide to turn off');
      expect(pin.state.isConfigured, isFalse);
      expect(find.text('PIN lock turned off'), findsOneWidget);
      await _drainToast(tester);
      semantics.dispose();
    });

    testWidgets('reset: PIN first, then the sheet; wipes with no toast', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, await _pin());
      final reset = find.text('Reset app data');
      await tester.scrollUntilVisible(
        reset,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(reset);
      await _settle(tester);
      await _enterPin(tester);
      _expectSheet(
        tester,
        title: 'Reset app data?',
        message:
            'Settings, blocklists, limits and your PIN are erased, and setup '
            'starts again.',
        cancel: 'Keep my data',
      );
      expect(find.byType(DetoxoLogo), findsOneWidget);
      await _cancel(tester, 'Keep my data');
      expect(store.cleared, isFalse);

      await tester.tap(reset);
      await _settle(tester);
      await _enterPin(tester);
      await _confirm(tester, 'Slide to reset');
      expect(store.cleared, isTrue);
      expect(find.text('at splash'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      semantics.dispose();
    });
  });

  testWidgets('PIN type None: confirmPinOff, then the toast and the pop', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final pin = await _pin();
    await tester.pumpWidget(
      BlocProvider.value(
        value: pin,
        child: MaterialApp(
          theme: AppTheme.dark(),
          // A Scaffold under the screen: the toast lands there after the pop.
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PinSetupScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    await tester.tap(find.text('PIN type').last);
    await _settle(tester);
    await tester.tap(find.text('None — no lock'));
    await _settle(tester);
    await tester.tap(find.text('Turn off PIN lock'));
    await _settle(tester);
    expect(find.text('Turn off PIN lock?'), findsOneWidget);
    await _confirm(tester, 'Slide to turn off');
    expect(pin.state.isConfigured, isFalse);
    expect(find.text('PIN lock turned off'), findsOneWidget);
    expect(find.text('open'), findsOneWidget); // popped
    await _drainToast(tester);
    semantics.dispose();
  });

  group('Web protection', () {
    late _MemSettings repo;

    setUp(() async {
      await sl.reset();
      repo = _MemSettings();
      final web = _MockWebRepo();
      final apps = _MockAppBlocks();
      final stats = _MockStats();
      when(web.load).thenAnswer((_) async => const []);
      when(apps.load).thenAnswer((_) async => const []);
      when(stats.load).thenAnswer((_) async => const WebBlockStats());
      when(stats.watch).thenAnswer((_) => const Stream.empty());
      sl
        ..registerSingleton<WebBlockRepository>(web)
        ..registerSingleton<SettingsRepository>(repo)
        ..registerSingleton<AppBlockRepository>(apps)
        ..registerSingleton<WebBlockStatsRepository>(stats)
        ..registerSingleton<EngineRepository>(_Engine());
    });

    tearDown(sl.reset);

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const WebProtectionScreen()),
      );
      await _settle(tester);
    }

    for (final (tile, title, message, cancel, toast, read) in [
      (
        'Block adult content (18+)',
        'Turn off the 18+ filter?',
        'Adult sites open again in every browser.',
        'Keep it on',
        '18+ filter off',
        (AppSettings s) => s.blockAdultWebsites,
      ),
      (
        'Block websites of blocked apps',
        'Unblock sites of blocked apps?',
        'Their websites open again in your browser.',
        'Keep them blocked',
        'Sites of blocked apps unblocked',
        (AppSettings s) => s.blockWebsitesForBlockedApps,
      ),
    ]) {
      testWidgets('$tile: on is direct; off asks, cancel snaps back', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pump(tester);

        await _toggle(tester, tile);
        expect(find.text(title), findsNothing);
        expect(read(repo.value), isTrue);

        await _toggle(tester, tile);
        _expectSheet(tester, title: title, message: message, cancel: cancel);
        expect(_icon3d(Assets.images.icons.iconWebBlocker), findsOneWidget);
        await _cancel(tester, cancel);
        expect(read(repo.value), isTrue);
        expect(_toggleValue(tester, tile), isTrue);

        await _toggle(tester, tile);
        await _confirm(tester, 'Slide to turn off');
        expect(read(repo.value), isFalse);
        expect(find.text(toast), findsOneWidget);
        await _drainToast(tester);
        semantics.dispose();
      });
    }
  });

  group('Delete rule', () {
    const rule = Rule(
      id: 'r1',
      name: 'Work hours',
      kind: RuleKind.schedule,
      createdAtMs: 0,
      schedule: RuleSchedule(days: {1}, startMin: 540, endMin: 1020),
    );
    late _MockRules rules;

    setUp(() async {
      await sl.reset();
      sl.registerSingleton<EngineRepository>(_Engine());
      rules = _MockRules();
      when(
        () => rules.state,
      ).thenReturn(const RulesState(loaded: true, rules: [rule]));
    });

    tearDown(sl.reset);

    Future<void> openAndSlide(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/edit'),
                child: const Text('rules'),
              ),
            ),
          ),
          GoRoute(
            path: '/edit',
            builder: (_, _) => const RuleEditorScreen(
              args: RuleEditorArgs(kind: RuleKind.schedule, rule: rule),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        BlocProvider<RulesCubit>.value(
          value: rules,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.tap(find.text('rules'));
      await _settle(tester);
      final delete = find.text('Delete rule');
      await tester.scrollUntilVisible(
        delete,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(delete);
      await _settle(tester);
      _expectSheet(
        tester,
        title: 'Delete Work hours?',
        message: 'Its apps and sites unblock right away.',
        cancel: 'Keep the rule',
      );
      expect(_icon3d(Assets.images.icons.iconBlockerRules), findsOneWidget);
      await _confirm(tester, 'Slide to delete');
    }

    testWidgets('success: toasts and pops', (tester) async {
      final semantics = tester.ensureSemantics();
      when(() => rules.remove('r1')).thenAnswer((_) async => true);
      await openAndSlide(tester);
      expect(find.text('Work hours deleted'), findsOneWidget);
      expect(find.text('rules'), findsOneWidget);
      await _drainToast(tester);
      semantics.dispose();
    });

    testWidgets('failure: the cubit error, no pop', (tester) async {
      final semantics = tester.ensureSemantics();
      when(() => rules.remove('r1')).thenAnswer((_) async => false);
      await openAndSlide(tester);
      expect(find.text(RulesCubit.saveFailed), findsOneWidget);
      expect(find.text('Work hours deleted'), findsNothing);
      expect(find.text('Delete rule'), findsOneWidget);
      await _drainToast(tester);
      semantics.dispose();
    });
  });
}
