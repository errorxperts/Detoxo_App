import 'package:bloc_test/bloc_test.dart';
import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/sessions.dart';
import 'package:detoxo/features/blocking/plans/presentation/widgets/session_dialogs.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettings extends MockCubit<AppSettings> implements SettingsCubit {}

// AppTheme pulls google_fonts, which stalls under flutter_test.
final _theme = ThemeData(
  brightness: Brightness.dark,
  extensions: const [GlassTokens.dark],
);

Future<_MockSettings> _open(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
  ThemeData? theme,
  double textScale = 1,
}) async {
  final cubit = _MockSettings();
  when(() => cubit.state).thenReturn(settings);
  when(
    () => cubit.setOneReel(count: any(named: 'count')),
  ).thenAnswer((_) async {});
  when(
    () => cubit.startPause(pause: any(named: 'pause')),
  ).thenAnswer((_) async {});
  // Provider above the app, as in production: the sheet is its own route.
  await tester.pumpWidget(
    BlocProvider<SettingsCubit>.value(
      value: cubit,
      child: MaterialApp(
        theme: theme ?? _theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: textScale != 1,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => SessionDialogs.showPause(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  setUpAll(() => registerFallbackValue(Duration.zero));

  testWidgets('opens on Time: step, hold to repeat, quick pick, pause', (
    tester,
  ) async {
    final cubit = await _open(tester);
    expect(find.text('Unblock for 4 min'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('More minutes'));
    await tester.pumpAndSettle();
    expect(find.text('Unblock for 5 min'), findsOneWidget);

    // Holding + keeps stepping after the long-press fires.
    final hold = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('More minutes')),
    );
    await tester.pump(const Duration(milliseconds: 600)); // long press → 6
    await tester.pump(const Duration(milliseconds: 200)); // → 7
    await tester.pump(const Duration(milliseconds: 160)); // → 8
    await hold.up();
    await tester.pumpAndSettle();
    expect(find.text('Unblock for 8 min'), findsOneWidget);

    await tester.tap(find.text('10'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unblock for 10 min'));
    await tester.pumpAndSettle();
    verify(
      () => cubit.startPause(pause: const Duration(minutes: 10)),
    ).called(1);
    verifyNever(() => cubit.setOneReel(count: any(named: 'count')));
  });

  testWidgets('Reels tab: adjustable, quick pick, unlock', (tester) async {
    final cubit = await _open(tester);
    await tester.tap(find.text('Reels'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Unlock 5 reels'), findsOneWidget);
    // TalkBack can adjust the count directly and hears every change.
    expect(
      tester.getSemantics(find.bySemanticsLabel('Reels to unlock')),
      isSemantics(
        value: '5 reels',
        isSlider: true,
        isLiveRegion: true,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );

    await tester.tap(find.bySemanticsLabel('More reels'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock 6 reels'), findsOneWidget);

    await tester.tap(find.text('20'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlock 20 reels'));
    await tester.pumpAndSettle();
    verify(() => cubit.setOneReel(count: 20)).called(1);
    verifyNever(() => cubit.startPause(pause: any(named: 'pause')));
  });

  testWidgets('a Pause in progress shows the live view', (tester) async {
    await _open(
      tester,
      settings: AppSettings(
        pauseSession: PauseSession(
          startedAt: DateTime.now(),
          pauseDuration: const Duration(minutes: 5),
          cooldownDuration: Duration.zero,
          planToResume: BlockingPlan.blockAll,
        ),
      ),
    );
    expect(find.text('Pause active'), findsOneWidget);
    expect(find.text('Resume blocking now'), findsOneWidget);
  });

  // Pre-delivery stress: a 360 dp phone at 2× text, landscape, and the light
  // theme, with reduce-motion on — both tabs must lay out without overflow.
  for (final (size, scale, dark) in [
    (const Size(360, 640), 2.0, true),
    (const Size(360, 640), 2.0, false),
    (const Size(640, 360), 1.0, true),
  ]) {
    testWidgets('lays out at $size, ${scale}x text, dark=$dark', (
      tester,
    ) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _open(
        tester,
        textScale: scale,
        theme: ThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
          extensions: [if (dark) GlassTokens.dark else GlassTokens.light],
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Reels'), warnIfMissed: false);
      await tester.pumpAndSettle();
      // A custom value (no quick pick lit) must lay out too.
      await tester.tap(find.bySemanticsLabel('More reels'));
      await tester.pumpAndSettle();
      expect(find.text('Unlock 6 reels'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Short screens scroll instead of clipping the CTA.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
