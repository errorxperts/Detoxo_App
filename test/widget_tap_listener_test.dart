import 'dart:async';

import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/app_gate.dart';
import 'package:detoxo/core/navigation/app_router.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/services/firebase/firebase.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Native's pending tap, read and cleared like `takePendingWidgetTap`, and
/// parsed the way the real repository parses it.
class _Taps implements HomeWidgetRepository {
  String? raw;
  var takes = 0;

  @override
  Future<WidgetTap?> takePendingTap() async {
    takes++;
    final tap = WidgetTap.parse(raw);
    raw = null;
    return tap;
  }

  @override
  Future<bool?> pin(WidgetFamily family) => throw UnimplementedError();

  @override
  Future<void> push({WidgetPushReason reason = WidgetPushReason.refresh}) =>
      throw UnimplementedError();

  @override
  Future<WidgetPayload> payload() => throw UnimplementedError();
}

class _Analytics implements AnalyticsService {
  final opened = <(String, String)>[];

  @override
  Future<void> logWidgetOpened({
    required String family,
    required String size,
  }) async => opened.add((family, size));

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// IM-08: a home-widget tap opens its screen once the gate lets it, and logs
/// which widget it was.
void main() {
  late AppGate gate;
  late _Taps taps;
  late _Analytics analytics;

  setUp(() async {
    await sl.reset();
    gate = AppGate();
    taps = _Taps();
    analytics = _Analytics();
    sl
      ..registerSingleton<AppGate>(gate)
      ..registerSingleton<HomeWidgetRepository>(taps)
      ..registerSingleton<AnalyticsService>(analytics);
  });

  tearDown(sl.reset);

  /// Each route names itself (and its query) so the test can read where the
  /// tap landed.
  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    MaterialApp.router(
      routerConfig: GoRouter(
        navigatorKey: appNavigatorKey,
        routes: [
          for (final path in [
            Routes.splash,
            Routes.home,
            Routes.settings,
            Routes.analytics,
            Routes.dailyLimit,
            Routes.appearance,
            Routes.permissions,
            Routes.ruleEditor,
          ])
            GoRoute(path: path, builder: (_, state) => Text('at ${state.uri}')),
        ],
      ),
      builder: (context, child) => WidgetTapListener(child: child!),
    ),
  );

  void openGate() => gate.update(ready: true, onboarded: true);

  /// The shell's route, with the Plan tap's per-tap `?dashboard=` request.
  final dashboard = find.textContaining(
    RegExp('^at ${RegExp.escape(Routes.home)}\\?dashboard=\\d+\$'),
  );

  testWidgets('an ACTIVITY tap opens Activity and logs it', (tester) async {
    taps.raw = 'BONSAI|LARGE|ACTIVITY';
    await pumpApp(tester);
    // Still booting: the tap waits in native rather than being read.
    expect(taps.takes, 0);

    openGate();
    await tester.pumpAndSettle();

    expect(find.text('at /analytics'), findsOneWidget);
    expect(analytics.opened, [('BONSAI', 'LARGE')]);
  });

  testWidgets('it waits behind the PIN', (tester) async {
    taps.raw = 'COUNT|SMALL|ACTIVITY';
    await pumpApp(tester);
    gate.update(ready: true, onboarded: true, pinLocked: true);
    await tester.pumpAndSettle();
    expect(taps.takes, 0);

    gate.unlockPin();
    await tester.pumpAndSettle();
    expect(find.text('at /analytics'), findsOneWidget);
  });

  for (final (target, route) in [
    ('APPEARANCE', Routes.appearance),
    ('PERMISSIONS', Routes.permissions),
  ]) {
    testWidgets('a $target tap opens $route', (tester) async {
      taps.raw = 'RHYTHM|MEDIUM|$target';
      await pumpApp(tester);
      openGate();
      await tester.pumpAndSettle();
      expect(find.text('at $route'), findsOneWidget);
      expect(analytics.opened, [('RHYTHM', 'MEDIUM')]);
    });
  }

  testWidgets('a Plan tap with blocking switched off opens Settings', (
    tester,
  ) async {
    taps.raw = 'PLAN|MEDIUM|SETTINGS';
    await pumpApp(tester);
    openGate();
    await tester.pumpAndSettle();
    expect(find.text('at ${Routes.settings}'), findsOneWidget);
    expect(analytics.opened, [('PLAN', 'MEDIUM')]);
  });

  for (final (family, location) in [
    ('COUNT', '/analytics'),
    ('NEXT_COLOUR', '/analytics'),
    ('BONSAI', '/analytics'),
    ('BENTO', '/analytics'),
    ('RHYTHM', '/analytics?segment=time'),
    ('TIME_LIMIT', '/daily-limit'),
  ]) {
    testWidgets('a tracking $family tap opens $location', (tester) async {
      taps.raw = '$family|SMALL|ACTIVITY';
      await pumpApp(tester);
      openGate();
      await tester.pumpAndSettle();
      expect(find.text('at $location'), findsOneWidget);
      expect(analytics.opened, [(family, 'SMALL')]);
    });
  }

  testWidgets('a warm tap is drained on resume', (tester) async {
    await pumpApp(tester);
    openGate();
    await tester.pumpAndSettle();
    expect(find.text('at /'), findsOneWidget);

    taps.raw = 'BENTO|SMALL|ACTIVITY';
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('at /analytics'), findsOneWidget);
  });

  void resume(WidgetTester tester) => tester.binding
    ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
    ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

  testWidgets('it waits out a resume re-lock instead of opening above it', (
    tester,
  ) async {
    await pumpApp(tester);
    openGate();
    await tester.pumpAndSettle();

    taps.raw = 'COUNT|SMALL|ACTIVITY';
    final reads = taps.takes; // the empty read when the gate opened
    // PinAutoRelock raises the flag before any other resume observer runs.
    gate.relocking.value = true;
    resume(tester);
    await tester.pumpAndSettle();
    expect(taps.takes, reads);
    expect(find.text('at /'), findsOneWidget);

    gate.relocking.value = false; // unlocked
    await tester.pumpAndSettle();
    expect(find.text('at /analytics'), findsOneWidget);
  });

  testWidgets('a tap read just as a re-lock goes up opens after it', (
    tester,
  ) async {
    await pumpApp(tester);
    openGate();
    await tester.pumpAndSettle();

    taps.raw = 'RHYTHM|LARGE|ACTIVITY';
    final reads = taps.takes;
    resume(tester); // starts the read
    gate.relocking.value = true; // ...which lands while the lock is up
    await tester.pumpAndSettle();
    expect(taps.takes, reads + 1);
    expect(find.text('at /'), findsOneWidget);

    gate.relocking.value = false;
    await tester.pumpAndSettle();
    expect(find.text('at /analytics?segment=time'), findsOneWidget);
  });

  testWidgets('tapping again replaces the open screen instead of stacking', (
    tester,
  ) async {
    taps.raw = 'BENTO|SMALL|ACTIVITY';
    await pumpApp(tester);
    openGate();
    await tester.pumpAndSettle();

    taps.raw = 'RHYTHM|MEDIUM|ACTIVITY';
    resume(tester);
    await tester.pumpAndSettle();
    expect(find.text('at /analytics?segment=time'), findsOneWidget);
    expect(analytics.opened, [('BENTO', 'SMALL'), ('RHYTHM', 'MEDIUM')]);

    // One Back reaches where the user was.
    GoRouter.of(appNavigatorKey.currentContext!).pop();
    await tester.pumpAndSettle();
    expect(find.text('at /'), findsOneWidget);
  });

  testWidgets('a different screen is pushed; Back returns to the first', (
    tester,
  ) async {
    taps.raw = 'BENTO|SMALL|ACTIVITY';
    await pumpApp(tester);
    openGate();
    await tester.pumpAndSettle();
    expect(find.text('at /analytics'), findsOneWidget);

    taps.raw = 'TIME_LIMIT|SMALL|ACTIVITY';
    resume(tester);
    await tester.pumpAndSettle();
    expect(find.text('at /daily-limit'), findsOneWidget);

    GoRouter.of(appNavigatorKey.currentContext!).pop();
    await tester.pumpAndSettle();
    expect(find.text('at /analytics'), findsOneWidget);
  });

  testWidgets(
    'a working Plan tap goes to the Dashboard, never a second shell',
    (tester) async {
      taps.raw = 'PLAN|SMALL|ACTIVITY';
      await pumpApp(tester);
      openGate();
      await tester.pumpAndSettle();
      expect(dashboard, findsOneWidget);
      final first = (tester.widget<Text>(dashboard).data)!;
      expect(analytics.opened, [('PLAN', 'SMALL')]);
      // `go`, not `push`: the shell is the root, so there is nothing to pop.
      expect(GoRouter.of(appNavigatorKey.currentContext!).canPop(), isFalse);

      // Tapped again with the Dashboard on top: a new request (so a shell
      // left on another tab comes back to Dashboard), still one shell.
      taps.raw = 'PLAN|LARGE|ACTIVITY';
      resume(tester);
      await tester.pumpAndSettle();
      expect(dashboard, findsOneWidget);
      expect(tester.widget<Text>(dashboard).data, isNot(first));
      expect(GoRouter.of(appNavigatorKey.currentContext!).canPop(), isFalse);
    },
  );

  testWidgets('a Plan tap above another screen pops back to the one shell', (
    tester,
  ) async {
    taps.raw = 'BENTO|SMALL|ACTIVITY';
    await pumpApp(tester);
    openGate();
    await tester.pumpAndSettle();
    expect(find.text('at /analytics'), findsOneWidget);

    taps.raw = 'PLAN|MEDIUM|ACTIVITY';
    resume(tester);
    await tester.pumpAndSettle();
    expect(dashboard, findsOneWidget);
    expect(find.text('at /analytics'), findsNothing);
    expect(GoRouter.of(appNavigatorKey.currentContext!).canPop(), isFalse);
  });

  testWidgets('a Plan tap never throws away a rule being edited', (
    tester,
  ) async {
    await pumpApp(tester);
    openGate();
    await tester.pumpAndSettle();
    unawaited(
      GoRouter.of(
        appNavigatorKey.currentContext!,
      ).push<void>(Routes.ruleEditor),
    );
    await tester.pumpAndSettle();
    expect(find.text('at ${Routes.ruleEditor}'), findsOneWidget);

    taps.raw = 'PLAN|SMALL|ACTIVITY';
    resume(tester);
    await tester.pumpAndSettle();
    // Read and logged, but the editor (and its unsaved rule) stays on top.
    expect(analytics.opened, [('PLAN', 'SMALL')]);
    expect(find.text('at ${Routes.ruleEditor}'), findsOneWidget);
    expect(dashboard, findsNothing);
  });

  for (final raw in ['garbage', 'BONSAI|HUGE|ACTIVITY', 'COUNT|SMALL']) {
    testWidgets('"$raw" opens nothing and logs nothing', (tester) async {
      taps.raw = raw;
      await pumpApp(tester);
      openGate();
      await tester.pumpAndSettle();

      expect(taps.takes, 1);
      expect(find.text('at /'), findsOneWidget);
      expect(analytics.opened, isEmpty);
    });
  }
}
