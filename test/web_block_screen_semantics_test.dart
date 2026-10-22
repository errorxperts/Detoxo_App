import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:detoxo/features/limits/app_blocker/domain/repositories/app_block_repository.dart';
import 'package:detoxo/features/limits/unblock/domain/entities/temporary_unblock.dart';
import 'package:detoxo/features/limits/unblock/domain/repositories/unblock_repositories.dart';
import 'package:detoxo/features/limits/unblock/presentation/unblock_cubit.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/popular_site.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_entry.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_source.dart';
import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_stats.dart';
import 'package:detoxo/features/limits/web_blocker/domain/repositories/web_block_repository.dart';
import 'package:detoxo/features/limits/web_blocker/domain/repositories/web_block_stats_repository.dart';
import 'package:detoxo/features/limits/web_blocker/presentation/web_block_cubit.dart';
import 'package:detoxo/features/limits/web_blocker/presentation/web_block_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWebRepo extends Mock implements WebBlockRepository {}

class _MockSettingsRepo extends Mock implements SettingsRepository {}

class _MockAppBlockRepo extends Mock implements AppBlockRepository {}

class _MockStatsRepo extends Mock implements WebBlockStatsRepository {}

class _MockEngine extends Mock implements EngineRepository {}

/// The row reads its "Allowed until" pill off this (M8), so the screen needs
/// one above it — empty stores mean no grants and no quota spent.
class _EmptyGrants implements TemporaryUnblockRepository {
  @override
  Future<List<TemporaryUnblock>> load() async => const [];

  @override
  Future<void> save(List<TemporaryUnblock> grants) async {}
}

class _EmptyLedger implements BypassLedgerRepository {
  @override
  Future<BypassLedger> load() async => const BypassLedger();

  @override
  Future<void> save(BypassLedger ledger) async {}
}

ThemeData _theme() => AppTheme.dark();

/// Regression tests for the `!semantics.parentDataDirty` framework assertion:
/// with semantics enabled (TalkBack, or any debug session after the first
/// `SemanticsBinding` client attaches), structural changes inside this
/// screen's ListView — the stats section appearing on the first webBlocked
/// event, rows appearing/disappearing — must not corrupt the semantics tree.
/// Seen live on-device 2026-08-17: first block while the screen was open
/// blanked the body and error-looped into a Crashlytics OOM.
void main() {
  late _MockWebRepo repo;
  late _MockSettingsRepo settings;
  late _MockAppBlockRepo appBlocks;
  late _MockStatsRepo statsRepo;
  late _MockEngine engine;
  late StreamController<WebBlockStats> statsCtrl;

  setUpAll(() => registerFallbackValue(<WebBlockEntry>[]));

  setUp(() async {
    await sl.reset();
    repo = _MockWebRepo();
    settings = _MockSettingsRepo();
    appBlocks = _MockAppBlockRepo();
    statsRepo = _MockStatsRepo();
    engine = _MockEngine();
    statsCtrl = StreamController<WebBlockStats>.broadcast();
    when(() => repo.load()).thenAnswer(
      (_) async => [
        WebBlockEntry(pattern: 'example.com', createdAt: DateTime(2026)),
      ],
    );
    when(() => settings.load()).thenAnswer((_) async => const AppSettings());
    when(() => appBlocks.load()).thenAnswer((_) async => const []);
    when(() => statsRepo.load()).thenAnswer((_) async => const WebBlockStats());
    when(() => statsRepo.watch()).thenAnswer((_) => statsCtrl.stream);
    when(() => engine.pushWebBlocklist(any())).thenAnswer((_) async {});
    when(() => engine.pushTemporaryUnblocks(any())).thenAnswer((_) async {});
    when(() => engine.takePendingUnblock()).thenAnswer((_) async => null);
    sl
      ..registerSingleton<WebBlockRepository>(repo)
      ..registerSingleton<SettingsRepository>(settings)
      ..registerSingleton<AppBlockRepository>(appBlocks)
      ..registerSingleton<WebBlockStatsRepository>(statsRepo)
      ..registerSingleton<EngineRepository>(engine);
  });

  tearDown(() async {
    await statsCtrl.close();
    await sl.reset();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider(
        create: (_) =>
            UnblockCubit(_EmptyGrants(), _EmptyLedger(), engine)..load(),
        child: MaterialApp(theme: _theme(), home: const WebBlockScreen()),
      ),
    );
    await tester.pump(); // load() future completes
    // Entrance animations (fadeIn/slideY). Never pumpAndSettle: the
    // GlassScaffold ambient background repeats forever.
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('first stats event while open keeps semantics alive', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpScreen(tester);
    expect(find.text('Blocked today'), findsNothing);

    // First-ever webBlocked event → hasStats flips → stats section inserted.
    statsCtrl.add(
      const WebBlockStats(
        totalBlocked: 1,
        blockedToday: 1,
        mostBlockedHost: 'example.com',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.takeException(), isNull);
    expect(find.text('Blocked today'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('row toggle flip (pause button appears/disappears) is safe', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    when(() => repo.save(any())).thenAnswer((_) async {});
    await pumpScreen(tester);

    // Disable → the conditional pause action unmounts from the swipe pane.
    await tester.tap(find.bySemanticsLabel('Block example.com'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    // Re-enable → it mounts again.
    await tester.tap(find.bySemanticsLabel('Block example.com'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('swipe pane reveals delete and removes the row', (tester) async {
    when(() => repo.save(any())).thenAnswer((_) async {});
    await pumpScreen(tester);
    expect(find.text('Delete'), findsNothing);

    // Swipe the row left to open the end action pane.
    await tester.drag(find.text('example.com'), const Offset(-300, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.takeException(), isNull);
    final saved =
        verify(() => repo.save(captureAny())).captured.single
            as List<WebBlockEntry>;
    expect(saved, isEmpty);
    expect(find.text('example.com'), findsNothing);

    // C10: the delete toasts with an Undo that puts the row back.
    expect(find.text('example.com removed'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(verify(() => repo.save(captureAny())).captured.single, [
      WebBlockEntry(pattern: 'example.com', createdAt: DateTime(2026)),
    ]);
    expect(find.text('example.com'), findsOneWidget);
  });

  /// C10: one tap switches a site or a popular chip off; once the state
  /// lands, a toast offers Undo, re-resolved by pattern at tap time.
  group('Undo toasts', () {
    final youtube = PopularSites.all.firstWhere((s) => s.id == 'youtube');
    final popular = WebBlockEntry(
      pattern: youtube.primaryDomain,
      displayName: youtube.name,
      source: WebBlockSource.popular,
      brandColor: youtube.brandColor,
      createdAt: DateTime(2026),
    );
    late List<List<WebBlockEntry>> saves;

    setUp(() {
      saves = [];
      when(() => repo.save(any())).thenAnswer(
        (i) async =>
            saves.add(i.positionalArguments.single as List<WebBlockEntry>),
      );
    });

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }

    Finder chip() => find.widgetWithText(AppChip, youtube.name);

    WebBlockCubit cubitOf(WidgetTester tester) =>
        tester.element(find.byType(SectionHeader).first).read<WebBlockCubit>();

    testWidgets('site off toasts "<site> unblocked"; Undo turns it on', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.tap(find.bySemanticsLabel('Block example.com'));
      await settle(tester);
      expect(saves.last.single.enabled, isFalse);
      expect(find.text('example.com unblocked'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(saves.last.single.enabled, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('site Undo does nothing once the site is gone', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.bySemanticsLabel('Block example.com'));
      await settle(tester);
      final cubit = cubitOf(tester);
      unawaited(cubit.removeEntry(cubit.state.entries.single));
      await settle(tester);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(saves, hasLength(2), reason: 'off, then the removal only');
      expect(cubit.state.entries, isEmpty);
    });

    testWidgets('turning a site on shows no toast', (tester) async {
      when(() => repo.load()).thenAnswer(
        (_) async => [
          WebBlockEntry(
            pattern: 'example.com',
            enabled: false,
            createdAt: DateTime(2026),
          ),
        ],
      );
      await pumpScreen(tester);
      await tester.tap(find.bySemanticsLabel('Block example.com'));
      await settle(tester);
      expect(saves.last.single.enabled, isTrue);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('a failed site save shows no success toast', (tester) async {
      when(() => repo.save(any())).thenThrow(Exception('disk full'));
      await pumpScreen(tester);
      await tester.tap(find.bySemanticsLabel('Block example.com'));
      await settle(tester);
      expect(find.text('example.com unblocked'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      expect(find.text("Couldn't save — try again"), findsOneWidget);
    });

    testWidgets('chip off toasts "<site> unblocked"; Undo restores it', (
      tester,
    ) async {
      when(() => repo.load()).thenAnswer((_) async => [popular]);
      await pumpScreen(tester);
      await tester.tap(chip());
      await settle(tester);
      expect(saves.last, isEmpty);
      expect(find.text('YouTube unblocked'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(saves.last, [popular]);
    });

    testWidgets('chip Undo does nothing once the site is back', (tester) async {
      when(() => repo.load()).thenAnswer((_) async => [popular]);
      await pumpScreen(tester);
      await tester.tap(chip());
      await settle(tester);
      await tester.tap(chip()); // on again: no toast of its own
      await settle(tester);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(saves, hasLength(2), reason: 'off, then on again only');
      expect(saves.last.single.pattern, youtube.primaryDomain);
    });

    testWidgets('turning a chip on shows no toast', (tester) async {
      when(() => repo.load()).thenAnswer((_) async => const []);
      await pumpScreen(tester);
      await tester.tap(chip());
      await settle(tester);
      expect(saves.last.single.pattern, youtube.primaryDomain);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('a failed chip save shows no success toast', (tester) async {
      when(() => repo.load()).thenAnswer((_) async => [popular]);
      when(() => repo.save(any())).thenThrow(Exception('disk full'));
      await pumpScreen(tester);
      await tester.tap(chip());
      await settle(tester);
      expect(find.text('YouTube unblocked'), findsNothing);
      expect(find.text('Undo'), findsNothing);
    });
  });
}
