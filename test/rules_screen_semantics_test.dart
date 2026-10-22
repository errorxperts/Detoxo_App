import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:detoxo/features/limits/limits.dart';
import 'package:detoxo/features/limits/rules/presentation/rules_screen.dart';
import 'package:detoxo/features/usage/usage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockEngine extends Mock implements EngineRepository {}

class _FakeRules implements RuleRepository {
  _FakeRules(this.rules);
  List<Rule> rules;
  bool failSave = false;

  @override
  Future<List<Rule>> load() async => rules;

  @override
  Future<void> save(List<Rule> next) async {
    if (failSave) throw Exception('disk full');
    rules = next;
  }
}

class _FakeDailyLimit implements DailyLimitRepository {
  @override
  Future<DailyLimit> load() async => const DailyLimit();

  @override
  Future<void> save(DailyLimit limit) async {}
}

class _FakeUsage implements UsageRepository {
  @override
  Future<bool?> hasAccess() async => false;

  @override
  Future<UsageQueryResult<List<AppUsage>>> queryAppUsage(
    DateTime start,
    DateTime end,
  ) async => const UsageDenied();

  @override
  Future<UsageQueryResult<List<UsageEvent>>> queryUsageEvents(
    DateTime start,
    DateTime end,
  ) async => const UsageDenied();
}

ThemeData _theme() => AppTheme.dark();

const _limitRule = Rule(
  id: 't1',
  name: 'Insta budget',
  kind: RuleKind.timeLimit,
  createdAtMs: 1,
  selection: RuleSelection(apps: ['com.instagram.android']),
  thresholdMs: 30 * 60000,
);

/// Same `!semantics.parentDataDirty` regression class as
/// `web_block_screen_semantics_test.dart` (seen live on-device 2026-08-17).
/// This list is MORE exposed than that one: the usage-access hint, the pinned
/// daily-limit row and every status pill mount and unmount from `resync()`,
/// which fires on a native `ruleBoundary` event and on a self-armed timer
/// while the screen is open.
void main() {
  // Built INSIDE the test body, never in setUp: a cubit constructed outside
  // testWidgets' FakeAsync zone owns futures that zone never pumps, and the
  // first `await` on one of them deadlocks the test.
  Future<(RulesCubit, StreamController<int>)> pumpScreen(
    WidgetTester tester, {
    _FakeRules? repo,
  }) async {
    final engine = _MockEngine();
    // ignore: close_sinks — handed back and closed by each test body.
    final boundaries = StreamController<int>.broadcast();
    when(() => engine.pushRules(any(), any())).thenAnswer((_) async => true);
    when(engine.ruleBoundaryStream).thenAnswer((_) => boundaries.stream);
    final rules = RulesCubit(
      repo ?? _FakeRules([_limitRule]),
      _FakeDailyLimit(),
      _FakeUsage(),
      engine,
      clock: () => DateTime(2026, 9, 2, 10),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: rules),
            BlocProvider(create: (_) => DailyLimitCubit(_FakeDailyLimit())),
          ],
          child: const RulesScreen(),
        ),
      ),
    );
    await tester.pump();
    // Entrance animations, over fixed frames.
    await tester.pump(const Duration(milliseconds: 700));
    return (rules, boundaries);
  }

  testWidgets('a ruleBoundary while open keeps semantics alive', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final (rules, boundaries) = await pumpScreen(tester);
    await rules.load();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // The usage-access hint mounts once resync answers "denied" — a structural
    // insert above the list, exactly what corrupted the sibling's tree.
    expect(find.byType(RulesScreen), findsOneWidget);

    boundaries.add(DateTime(2026, 9, 2, 17).millisecondsSinceEpoch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.takeException(), isNull);
    await rules.close();
    await boundaries.close();
    semantics.dispose();
  });

  testWidgets('toggling a rule off re-renders its pill safely', (tester) async {
    final semantics = tester.ensureSemantics();
    final (rules, boundaries) = await pumpScreen(tester);
    await rules.load();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.bySemanticsLabel('Enable Insta budget'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.takeException(), isNull);
    expect(rules.state.rules.single.enabled, isFalse);
    await rules.close();
    await boundaries.close();
    semantics.dispose();
  });

  /// M4: one panel per section, compact copy, the device clock on presets.
  testWidgets('compact rows, the usage-access line and no chevron icons', (
    tester,
  ) async {
    final (rules, boundaries) = await pumpScreen(tester);
    addTearDown(boundaries.close);
    await rules.load();
    await settle(tester);
    expect(find.text('Usage access needed'), findsOneWidget);
    expect(find.text('Grant'), findsOneWidget);
    expect(find.text('30m a day · 1 app'), findsOneWidget);
    expect(find.text('Needs usage access'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    await rules.close();
  });

  testWidgets('presets read in the 12-hour clock, as one panel', (
    tester,
  ) async {
    final (rules, boundaries) = await pumpScreen(tester, repo: _FakeRules([]));
    addTearDown(boundaries.close);
    await rules.load();
    await settle(tester);
    expect(find.text('Weekdays 9 AM–5 PM · reels and social'), findsOneWidget);
    expect(find.text('Reel budget'), findsOneWidget);
    expect(
      find.text('30m of reels a day, then blocked until midnight'),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Reel budget'),
        matching: find.byType(PanelGroup),
      ),
      findsOneWidget,
    );
    await rules.close();
  });

  /// C10: one tap turns a rule off; once the state lands, '<rule> off' offers
  /// an Undo, re-resolved by rule id at tap time.
  group('Undo toast', () {
    Future<RulesCubit> loaded(WidgetTester tester, {_FakeRules? repo}) async {
      final (rules, boundaries) = await pumpScreen(tester, repo: repo);
      addTearDown(boundaries.close);
      await rules.load();
      await settle(tester);
      return rules;
    }

    testWidgets('off toasts "<rule> off"; Undo turns it back on', (
      tester,
    ) async {
      final rules = await loaded(tester);
      await tester.tap(find.bySemanticsLabel('Enable Insta budget'));
      await settle(tester);
      expect(rules.state.rules.single.enabled, isFalse);
      expect(find.text('Insta budget off'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(rules.state.rules.single.enabled, isTrue);
      await rules.close();
    });

    testWidgets('Undo does nothing once the rule is deleted', (tester) async {
      final rules = await loaded(tester);
      await tester.tap(find.bySemanticsLabel('Enable Insta budget'));
      await settle(tester);
      unawaited(rules.remove(_limitRule.id));
      await settle(tester);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(rules.state.rules, isEmpty);
      await rules.close();
    });

    testWidgets('turning a rule on shows no toast', (tester) async {
      final rules = await loaded(
        tester,
        repo: _FakeRules([_limitRule.copyWith(enabled: false)]),
      );
      await tester.tap(find.bySemanticsLabel('Enable Insta budget'));
      await settle(tester);
      expect(rules.state.rules.single.enabled, isTrue);
      expect(find.text('Undo'), findsNothing);
      await rules.close();
    });

    testWidgets('a failed save shows no success toast', (tester) async {
      final repo = _FakeRules([_limitRule]);
      final rules = await loaded(tester, repo: repo);
      repo.failSave = true;
      await tester.tap(find.bySemanticsLabel('Enable Insta budget'));
      await settle(tester);
      expect(rules.state.rules.single.enabled, isTrue, reason: 'reverted');
      expect(find.text('Insta budget off'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      await rules.close();
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}
