import 'package:bloc_test/bloc_test.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/features/blocking/plans/presentation/widgets/session_dialogs.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettings extends MockCubit<AppSettings> implements SettingsCubit {}

/// Opens [SessionDialogs.showPause] (or `showReels` when [reels]) over a
/// mocked [SettingsCubit]; [fails] makes its commit throw.
Future<_MockSettings> _open(
  WidgetTester tester, {
  bool reels = false,
  bool fails = false,
  ThemeData? theme,
  double textScale = 1,
  bool use24h = false,
}) async {
  final cubit = _MockSettings();
  when(() => cubit.state).thenReturn(const AppSettings());
  Future<void> commit(Invocation _) async {
    if (fails) throw Exception('settings write failed');
  }

  when(() => cubit.setOneReel(count: any(named: 'count'))).thenAnswer(commit);
  when(() => cubit.startPause(pause: any(named: 'pause'))).thenAnswer(commit);
  // Provider above the app, as in production: the sheet is its own route.
  await tester.pumpWidget(
    BlocProvider<SettingsCubit>.value(
      value: cubit,
      child: MaterialApp(
        theme: theme ?? AppTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: textScale != 1,
            alwaysUse24HourFormat: use24h,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => reels
                  ? SessionDialogs.showReels(context)
                  : SessionDialogs.showPause(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return cubit;
}

/// Taps Start and runs out the 1.1 s "Session started" hold.
Future<void> _start(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  expect(find.text('Session started'), findsOneWidget);
  await tester.pump(const Duration(milliseconds: 1100));
  await tester.pumpAndSettle();
  expect(find.text('Session blocker'), findsNothing, reason: 'closed');
}

void main() {
  setUpAll(() => registerFallbackValue(Duration.zero));

  group('Pause: By time', () {
    testWidgets('opens on 5 min; a pick, Start → startPause once', (
      tester,
    ) async {
      final cubit = await _open(tester);
      expect(find.text('By time'), findsOneWidget);
      expect(find.text('Start 5-min session'), findsOneWidget);
      expect(
        find.textContaining(
          RegExp(r'^Blocking resumes at \d{1,2}(:\d\d)? (AM|PM)$'),
        ),
        findsOneWidget,
        reason: 'now + 5 min on a 12-hour clock',
      );

      await tester.tap(find.bySemanticsLabel('1 minute'));
      await tester.pumpAndSettle();
      expect(find.text('Start 1-min session'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('10 minutes'));
      await tester.pumpAndSettle();
      await _start(tester, 'Start 10-min session');
      verify(
        () => cubit.startPause(pause: const Duration(minutes: 10)),
      ).called(1);
      verifyNever(() => cubit.setOneReel(count: any(named: 'count')));
    });

    testWidgets('the note follows the 24-hour setting', (tester) async {
      await _open(tester, use24h: true);
      expect(
        find.textContaining(RegExp(r'^Blocking resumes at \d\d:\d\d$')),
        findsOneWidget,
      );
    });
  });

  group('N reels: By reel count', () {
    testWidgets('opens on 10; step, pick, Start → setOneReel once', (
      tester,
    ) async {
      final cubit = await _open(tester, reels: true);
      expect(find.text('By reel count'), findsOneWidget);
      expect(find.text('Start 10-reel session'), findsOneWidget);
      expect(find.text('Blocking resumes after 10 reels'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('One more reel'));
      await tester.pumpAndSettle();
      expect(find.text('Start 11-reel session'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('20 reels'));
      await tester.pumpAndSettle();
      await _start(tester, 'Start 20-reel session');
      verify(() => cubit.setOneReel(count: 20)).called(1);
      verifyNever(() => cubit.startPause(pause: any(named: 'pause')));
    });

    testWidgets('one reel reads singular', (tester) async {
      await _open(tester, reels: true);
      await tester.tap(find.bySemanticsLabel('5 reels'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.bySemanticsLabel('One fewer reel'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Blocking resumes after 1 reel'), findsOneWidget);
      expect(find.text('Start 1-reel session'), findsOneWidget);
    });
  });

  testWidgets('a failed commit toasts and keeps the sheet open', (
    tester,
  ) async {
    final cubit = await _open(tester, reels: true, fails: true);
    await tester.tap(find.text('Start 10-reel session'));
    await tester.pumpAndSettle();
    verify(() => cubit.setOneReel(count: 10)).called(1);
    expect(find.text(SessionDialogs.startFailed), findsOneWidget);
    expect(find.text('Session started'), findsNothing);
    expect(find.text('Start 10-reel session'), findsOneWidget);
  });

  // Pre-delivery stress: a 360 dp phone at 2× text, landscape, and the light
  // theme, with reduce-motion on — both kinds must lay out without overflow.
  for (final reels in [false, true]) {
    for (final (size, scale, dark) in [
      (const Size(360, 640), 2.0, true),
      (const Size(360, 640), 2.0, false),
      (const Size(640, 360), 1.0, true),
    ]) {
      testWidgets('${reels ? 'reels' : 'time'} lays out at $size, '
          '${scale}x text, dark=$dark', (tester) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await _open(
          tester,
          reels: reels,
          textScale: scale,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
        );
        expect(tester.takeException(), isNull);
        if (reels) {
          // A custom value (no quick pick lit) must lay out too.
          await tester.tap(find.bySemanticsLabel('One more reel'));
          await tester.pumpAndSettle();
          expect(find.text('Start 11-reel session'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        // Short screens scroll instead of clipping Start.
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
