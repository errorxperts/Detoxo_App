import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:detoxo/features/limits/app_blocker/domain/entities/app_block_entry.dart';
import 'package:detoxo/features/limits/app_blocker/domain/repositories/app_block_repository.dart';
import 'package:detoxo/features/limits/app_blocker/presentation/app_block_cubit.dart';
import 'package:detoxo/features/limits/app_blocker/presentation/app_block_screen.dart';
import 'package:detoxo/features/limits/unblock/domain/entities/temporary_unblock.dart';
import 'package:detoxo/features/limits/unblock/domain/repositories/unblock_repositories.dart';
import 'package:detoxo/features/limits/unblock/presentation/unblock_cubit.dart';
import 'package:detoxo/features/limits/web_blocker/domain/repositories/web_block_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockEngine extends Mock implements EngineRepository {}

class _MockWebRepo extends Mock implements WebBlockRepository {}

class _MockTargets extends MockCubit<TargetsState> implements TargetsCubit {}

class _FakeAppBlocks implements AppBlockRepository {
  _FakeAppBlocks(this.entries);
  List<AppBlockEntry> entries;
  bool failSave = false;

  @override
  Future<List<AppBlockEntry>> load() async => entries;

  @override
  Future<void> save(List<AppBlockEntry> next) async {
    if (failSave) throw Exception('disk full');
    entries = next;
  }
}

class _FakeSettings implements SettingsRepository {
  _FakeSettings(this.settings);
  AppSettings settings;
  bool failSave = false;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings next) async {
    if (failSave) throw Exception('disk full');
    settings = next;
  }

  @override
  Stream<AppSettings> watch() => const Stream.empty();
}

class _Grants implements TemporaryUnblockRepository {
  List<TemporaryUnblock> grants = const [];

  @override
  Future<List<TemporaryUnblock>> load() async => grants;

  @override
  Future<void> save(List<TemporaryUnblock> next) async => grants = next;
}

class _EmptyLedger implements BypassLedgerRepository {
  @override
  Future<BypassLedger> load() async => const BypassLedger();

  @override
  Future<void> save(BypassLedger ledger) async {}
}

const _reels = BlockTarget(
  platformId: 'ig_reels',
  packageName: 'com.instagram.android',
  appName: 'Instagram',
  displayName: 'Instagram Reels',
  iconUrl: '',
  detectionType: DetectionType.legacy,
  premiumExclusive: false,
  defaultEnabled: true,
  isBrowser: false,
);

const _foo = AppBlockEntry(packageName: 'com.foo.app', appName: 'Foo');

/// C10: one tap switches a custom lock or a built-in feed off (or removes a
/// lock); once the state lands, a toast offers Undo, re-resolved at tap time.
void main() {
  late _FakeAppBlocks appBlocks;
  late _FakeSettings settingsRepo;
  late _MockTargets targets;
  late _MockEngine engine;
  late _Grants grants;

  setUp(() async {
    await sl.reset();
    grants = _Grants();
    appBlocks = _FakeAppBlocks([_foo]);
    settingsRepo = _FakeSettings(
      const AppSettings(enabledPlatformIds: {'ig_reels'}),
    );
    targets = _MockTargets();
    whenListen(
      targets,
      const Stream<TargetsState>.empty(),
      initialState: const TargetsState(targets: [_reels]),
    );
    engine = _MockEngine();
    final web = _MockWebRepo();
    when(web.load).thenAnswer((_) async => const []);
    when(() => engine.installedApps()).thenAnswer((_) async => null);
    when(engine.reelSessionStream).thenAnswer((_) => const Stream.empty());
    when(() => engine.pushSettings(any())).thenAnswer((_) async {});
    when(() => engine.pushAppBlocklist(any())).thenAnswer((_) async {});
    when(() => engine.pushWebBlocklist(any())).thenAnswer((_) async {});
    when(() => engine.pushTemporaryUnblocks(any())).thenAnswer((_) async {});
    when(() => engine.takePendingUnblock()).thenAnswer((_) async => null);
    sl
      ..registerSingleton<AppBlockRepository>(appBlocks)
      ..registerSingleton<SettingsRepository>(settingsRepo)
      ..registerSingleton<WebBlockRepository>(web)
      ..registerSingleton<EngineRepository>(engine);
  });

  setUpAll(() => registerFallbackValue(const AppSettings()));

  tearDown(sl.reset);

  Future<SettingsCubit> pumpScreen(WidgetTester tester) async {
    final settings = SettingsCubit(settingsRepo, engine);
    unawaited(settings.bootstrap());
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => UnblockCubit(grants, _EmptyLedger(), engine)..load(),
          ),
          BlocProvider.value(value: settings),
          BlocProvider<TargetsCubit>.value(value: targets),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const AppBlockScreen(),
        ),
      ),
    );
    await settle(tester);
    return settings;
  }

  AppBlockCubit appCubit(WidgetTester tester) =>
      tester.element(find.text('Foo')).read<AppBlockCubit>();

  /// Unblock/Block and Remove live in the row's swipe pane.
  Future<void> openPane(WidgetTester tester) async {
    await tester.drag(find.text('Foo'), const Offset(-300, 0));
    await settle(tester);
  }

  group('custom lock', () {
    testWidgets('off toasts "<app> unblocked"; Undo turns it back on', (
      tester,
    ) async {
      await pumpScreen(tester);
      await openPane(tester);
      await tester.tap(find.bySemanticsLabel('Unblock Foo'));
      await settle(tester);
      expect(appBlocks.entries.single.enabled, isFalse);
      expect(find.text('Foo unblocked'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(appBlocks.entries.single.enabled, isTrue);
    });

    testWidgets('Undo does nothing once the lock is gone', (tester) async {
      await pumpScreen(tester);
      await openPane(tester);
      await tester.tap(find.bySemanticsLabel('Unblock Foo'));
      await settle(tester);
      // Removed from elsewhere, so the toast and its Undo stay up.
      unawaited(appCubit(tester).removeAt(0));
      await settle(tester);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(appBlocks.entries, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('turning a lock on shows no toast', (tester) async {
      appBlocks.entries = [_foo.copyWith(enabled: false)];
      await pumpScreen(tester);
      await openPane(tester);
      await tester.tap(find.bySemanticsLabel('Block Foo'));
      await settle(tester);
      expect(appBlocks.entries.single.enabled, isTrue);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('a failed save shows no toast', (tester) async {
      await pumpScreen(tester);
      appBlocks.failSave = true;
      await openPane(tester);
      await tester.tap(find.bySemanticsLabel('Unblock Foo'));
      await settle(tester);
      expect(find.text('Foo unblocked'), findsNothing);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('Remove toasts "<app> removed"; Undo puts it back intact', (
      tester,
    ) async {
      appBlocks.entries = [
        const AppBlockEntry(packageName: 'com.bar.app', appName: 'Bar'),
        _foo.copyWith(enabled: false),
      ];
      await pumpScreen(tester);
      await openPane(tester);
      await tester.tap(find.bySemanticsLabel('Remove Foo'));
      await settle(tester);
      expect(appBlocks.entries.map((e) => e.appName), ['Bar']);
      expect(find.text('Foo removed'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(appBlocks.entries.map((e) => e.appName), ['Bar', 'Foo']);
      expect(appBlocks.entries.last.enabled, isFalse, reason: 'fields intact');
    });

    testWidgets('an off lock reads "Not blocked"; a tap offers Block', (
      tester,
    ) async {
      appBlocks.entries = [_foo.copyWith(enabled: false)];
      await pumpScreen(tester);
      expect(find.text('Not blocked'), findsOneWidget);
      expect(find.byTooltip('Allow Foo for a while'), findsNothing);
      expect(find.text('Block'), findsNothing, reason: 'pane starts closed');

      // A tap opens the pane too (the screen-reader path).
      await tester.tap(find.text('Foo'));
      await settle(tester);
      expect(find.text('Block'), findsOneWidget);
      expect(find.text('Unblock'), findsNothing);
      expect(find.text('Remove'), findsOneWidget);

      await tester.tap(find.text('Block'));
      await settle(tester);
      expect(appBlocks.entries.single.enabled, isTrue);
      expect(find.text('Not blocked'), findsNothing);
      expect(find.byTooltip('Allow Foo for a while'), findsOneWidget);
    });
  });

  testWidgets('the row is one button that says it opens the pane', (
    tester,
  ) async {
    await pumpScreen(tester);
    final row = tester.getSemantics(find.text('Foo'));
    expect(
      row,
      isSemantics(
        label: 'Foo',
        hint: 'Opens block and remove actions',
        isButton: true,
        hasTapAction: true,
      ),
    );
    // Not merged into the row: a screen reader still reaches the timer.
    final timer = tester.getSemantics(find.byTooltip('Allow Foo for a while'));
    expect(timer.id, isNot(row.id));

    tester.semantics.tap(find.semantics.byLabel('Foo'));
    await settle(tester);
    expect(find.text('Unblock'), findsOneWidget);
  });

  testWidgets('a live grant reads "Allowed until"; Block now ends it', (
    tester,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    grants.grants = [
      TemporaryUnblock(
        targetType: UnblockTargetType.app,
        targetId: _foo.packageName,
        startMs: now,
        endMs: now + const Duration(minutes: 30).inMilliseconds,
      ),
    ];
    await pumpScreen(tester);
    expect(find.textContaining('Allowed until'), findsOneWidget);
    expect(find.byTooltip('Allow Foo for a while'), findsNothing);

    await tester.tap(find.text('Block now'));
    await settle(tester);
    expect(find.textContaining('Allowed until'), findsNothing);
    expect(find.byTooltip('Allow Foo for a while'), findsOneWidget);
    final later = DateTime.now().millisecondsSinceEpoch;
    expect(grants.grants.where((g) => g.isActiveAt(later)), isEmpty);
  });

  group('built-in feed', () {
    testWidgets('off toasts "<feed> unblocked"; Undo turns it back on', (
      tester,
    ) async {
      final settings = await pumpScreen(tester);
      await tester.tap(find.bySemanticsLabel('Block Instagram Reels'));
      await settle(tester);
      expect(settings.state.enabledPlatformIds, isEmpty);
      expect(find.text('Instagram Reels unblocked'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(settings.state.enabledPlatformIds, {'ig_reels'});
    });

    testWidgets('Undo does nothing once the feed is gone', (tester) async {
      final settings = await pumpScreen(tester);
      await tester.tap(find.bySemanticsLabel('Block Instagram Reels'));
      await settle(tester);
      // Instagram uninstalled meanwhile: the catalog no longer lists it.
      when(() => targets.state).thenReturn(const TargetsState());

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(settings.state.enabledPlatformIds, isEmpty);
    });

    testWidgets('turning a feed on shows no toast', (tester) async {
      settingsRepo.settings = const AppSettings();
      final settings = await pumpScreen(tester);
      await tester.tap(find.bySemanticsLabel('Block Instagram Reels'));
      await settle(tester);
      expect(settings.state.enabledPlatformIds, {'ig_reels'});
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('a failed save shows no toast', (tester) async {
      await pumpScreen(tester);
      settingsRepo.failSave = true;
      // SettingsCubit's commit throws rather than reverting; the throw is
      // what keeps the toast from being reached.
      Object? thrown;
      await runZonedGuarded(() async {
        await tester.tap(find.bySemanticsLabel('Block Instagram Reels'));
        await settle(tester);
      }, (e, _) => thrown = e);
      expect(thrown, isException);
      expect(find.text('Instagram Reels unblocked'), findsNothing);
      expect(find.text('Undo'), findsNothing);
    });
  });
}

/// Fixed frames: enough for the entrance and a sheet or toast to land.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}
