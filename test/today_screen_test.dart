import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/features/additional_feature/showcase_view/showcase_view.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/conscious_state.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/reel_session_state.dart';
import 'package:detoxo/features/blocking/plans/presentation/conscious_cubit.dart';
import 'package:detoxo/features/blocking/plans/presentation/reel_session_cubit.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:detoxo/features/dashboard/dashboard.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/blocker_section.dart';
import 'package:detoxo/features/limits/limits.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:showcaseview/showcaseview.dart';

// C11: Today is the TabHeader, the TimeLeftRing with its stats, the
// ModeCard and the Blockers section, over the ambient lights.

class _MockSettings extends MockCubit<AppSettings> implements SettingsCubit {}

class _MockCounter extends MockCubit<ContentCount>
    implements ContentCounterCubit {}

class _MockDaily extends MockCubit<DailyLimit> implements DailyLimitCubit {}

class _MockStreak extends MockCubit<Streak> implements StreakCubit {}

class _MockReels extends MockCubit<ReelSessionState>
    implements ReelSessionCubit {}

class _MockConscious extends MockCubit<ConsciousState>
    implements ConsciousCubit {}

class _MockTargets extends MockCubit<TargetsState> implements TargetsCubit {}

class _MockRules extends MockCubit<RulesState> implements RulesCubit {}

class _MockUnblock extends MockCubit<UnblockState> implements UnblockCubit {}

class _MockAppRepo extends Mock implements AppBlockRepository {}

class _MockWebRepo extends Mock implements WebBlockRepository {}

class _MockSettingsRepo extends Mock implements SettingsRepository {}

class _MockEngine extends Mock implements EngineRepository {}

const _labels = ['Block All', 'Conscious', 'One Reel', 'Pause', 'Unblock'];

/// 45 min of a 3 h limit, 20 reels, a 1 day streak.
const _counted = ContentCount(today: 20, timeToday: Duration(minutes: 45));

/// A 10 min break, 18 s in.
AppSettings _pausing({BlockingPlan base = BlockingPlan.blockAll}) =>
    AppSettings(
      hasSeenFeatureShowcase: true,
      activePlan: base,
      baseMode: base,
      pauseSession: PauseSession(
        startedAt: DateTime.now().subtract(const Duration(seconds: 18)),
        pauseDuration: const Duration(minutes: 10),
        cooldownDuration: Duration.zero,
        planToResume: base,
      ),
    );

late _MockSettings _settings;
late _MockCounter _counter;
late _MockStreak _streak;

Future<void> _pump(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(hasSeenFeatureShowcase: true),
  ContentCount counter = _counted,
  ReelSessionState reels = const ReelSessionState(),
  bool dark = false,
  double textScale = 1,
}) async {
  when(() => _settings.state).thenReturn(settings);
  when(() => _counter.state).thenReturn(counter);
  final reelCubit = _MockReels();
  when(() => reelCubit.state).thenReturn(reels);
  final conscious = _MockConscious();
  when(() => conscious.state).thenReturn(const ConsciousState());
  final daily = _MockDaily();
  when(() => daily.state).thenReturn(
    const DailyLimit(limit: Duration(hours: 3), dateSignature: '23-10-2026'),
  );
  final targets = _MockTargets();
  when(() => targets.state).thenReturn(const TargetsState());
  final rules = _MockRules();
  when(() => rules.state).thenReturn(const RulesState());
  final unblock = _MockUnblock();
  when(() => unblock.state).thenReturn(const UnblockState());

  // A fresh tree each time: no sheet or route left over from the last pump.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>.value(value: _settings),
        BlocProvider<ContentCounterCubit>.value(value: _counter),
        BlocProvider<DailyLimitCubit>.value(value: daily),
        BlocProvider<StreakCubit>.value(value: _streak),
        BlocProvider<ReelSessionCubit>.value(value: reelCubit),
        BlocProvider<ConsciousCubit>.value(value: conscious),
        BlocProvider<TargetsCubit>.value(value: targets),
        BlocProvider<RulesCubit>.value(value: rules),
        BlocProvider<UnblockCubit>.value(value: unblock),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: buildFeatureShowcaseScope(
          onSeen: () {},
          child: Scaffold(body: DashboardTab(onMenu: () {})),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _option(String label) =>
    find.descendant(of: find.byType(ModeCard), matching: find.text(label));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(BlockingPlan.blockAll);
    registerFallbackValue(Duration.zero);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() async {
    await sl.reset();
    final apps = _MockAppRepo();
    final web = _MockWebRepo();
    final settingsRepo = _MockSettingsRepo();
    final engine = _MockEngine();
    when(apps.load).thenAnswer((_) async => const []);
    when(web.load).thenAnswer((_) async => const []);
    when(settingsRepo.load).thenAnswer((_) async => const AppSettings());
    when(engine.installedApps).thenAnswer((_) async => const []);
    sl
      ..registerSingleton<AppBlockRepository>(apps)
      ..registerSingleton<WebBlockRepository>(web)
      ..registerSingleton<SettingsRepository>(settingsRepo)
      ..registerSingleton<EngineRepository>(engine);

    _settings = _MockSettings();
    when(() => _settings.setPlan(any())).thenAnswer((_) async {});
    when(_settings.resumeNow).thenAnswer((_) async {});
    when(
      () => _settings.setOneReel(count: any(named: 'count')),
    ).thenAnswer((_) async {});
    _counter = _MockCounter();
    when(_counter.refresh).thenAnswer((_) async {});
    _streak = _MockStreak();
    when(() => _streak.state).thenReturn(const Streak(base: 1));
    when(
      () => _streak.observe(
        now: any(named: 'now'),
        underLimit: any(named: 'underLimit'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(sl.reset);

  testWidgets('header, 14, ring and stats, 20, mode card, 32, Blockers', (
    tester,
  ) async {
    await _pump(tester);

    Rect rect(Type t) => tester.getRect(find.byType(t));
    expect(rect(TimeLeftRing).top - rect(TabHeader).bottom, AppSpacing.gap);
    expect(rect(ModeCard).top - rect(TimeLeftRing).bottom, AppSpacing.lg);
    expect(
      rect(BlockerSection).top - rect(ModeCard).bottom,
      AppSpacing.section,
    );
    // Gutter 20, inset 8 on top, 132 for the tab bar below.
    expect(rect(ModeCard).left, AppSpacing.gutter);
    expect(rect(TabHeader).top, AppSpacing.inset);
    expect(
      tester.getSize(find.byType(SingleChildScrollView).first).width -
          rect(ModeCard).right,
      AppSpacing.gutter,
    );
    final scrollEnd = tester.getBottomLeft(
      find
          .descendant(
            of: find.byType(SingleChildScrollView).first,
            matching: find.byType(Stack),
          )
          .first,
    );
    expect(
      scrollEnd.dy - rect(BlockerSection).bottom,
      AppSpacing.floatingNavClearance,
    );
    // The lights sit behind the content, in a box that scrolls with it.
    expect(find.byType(AmbientLights), findsOneWidget);

    expect(find.text('TIME LEFT'), findsOneWidget);
    expect(find.text('2h 15m'), findsOneWidget);
    expect(find.text('45m of 3h used'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
  });

  testWidgets('the mode card reads Block All, Conscious, One Reel, Pause, '
      'Unblock; a lit Block All has no description', (tester) async {
    await _pump(tester);
    final card = tester.widget<ModeCard>(find.byType(ModeCard));
    expect(card.options.map((o) => o.label), _labels);
    expect(card.selectedIndex, 0);
    expect(card.title, isNull);
    expect(find.text('All reels blocked'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ModeCard),
        matching: find.byType(StatusDot),
      ),
      findsNothing,
    );

    // Blocking off still says so.
    await _pump(
      tester,
      settings: const AppSettings(
        hasSeenFeatureShowcase: true,
        masterEnabled: false,
      ),
    );
    expect(find.text('Blocking is off'), findsOneWidget);
    expect(find.text('Turn it on in Settings'), findsOneWidget);
  });

  testWidgets('Unblock, the fifth option, opens the Session sheet By reel '
      'count', (tester) async {
    await _pump(tester);
    // The ring holds no pill: Unblock is only the mode option.
    expect(find.byType(LiquidPill), findsNothing);
    expect(find.text('Unblock'), findsOneWidget);
    await _tap(tester, _option('Unblock'));
    expect(find.text('Session blocker'), findsOneWidget);
    expect(find.text('By reel count'), findsOneWidget);
  });

  testWidgets('Pause opens the Session sheet By time', (tester) async {
    await _pump(tester);
    await _tap(tester, _option('Pause'));
    expect(find.text('By time'), findsOneWidget);
  });

  testWidgets('Block All is direct; tapping it again does nothing', (
    tester,
  ) async {
    await _pump(tester);
    await _tap(tester, _option('Block All'));
    verifyNever(() => _settings.setPlan(any()));

    await _pump(
      tester,
      settings: const AppSettings(
        hasSeenFeatureShowcase: true,
        activePlan: BlockingPlan.curious,
        baseMode: BlockingPlan.curious,
      ),
    );
    expect(find.text('Earning 1 min for every 10 min away'), findsOneWidget);
    await _tap(tester, _option('Block All'));
    verify(() => _settings.setPlan(BlockingPlan.blockAll)).called(1);
    expect(find.byType(ConfirmSheet), findsNothing);
  });

  testWidgets('Conscious opens its sheet: the intro, or the live one', (
    tester,
  ) async {
    await _pump(tester);
    await _tap(tester, _option('Conscious'));
    expect(find.text('Turn on Conscious'), findsOneWidget);

    await _pump(
      tester,
      settings: const AppSettings(
        hasSeenFeatureShowcase: true,
        activePlan: BlockingPlan.curious,
      ),
    );
    await _tap(tester, _option('Conscious'));
    expect(find.text('Turn off Conscious'), findsOneWidget);
  });

  testWidgets('One Reel: the ConfirmSheet, then one reel and a toast', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    await _tap(tester, _option('One Reel'));
    expect(find.text('Watch one reel?'), findsOneWidget);
    expect(
      find.text('Reels are blocked again as soon as it ends.'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Icon3d &&
            w.asset.path == Assets.images.icons.iconOneReel.path &&
            w.size == ConfirmSheet.iconSize &&
            w.accentTint,
      ),
      findsOneWidget,
    );

    // Keep it blocked commits nothing.
    await tester.tap(find.text('Keep it blocked'));
    await tester.pumpAndSettle();
    verifyNever(() => _settings.setOneReel(count: any(named: 'count')));

    await _tap(tester, _option('One Reel'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 700));
    tester.semantics.tap(find.semantics.byLabel('Slide to unblock'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    verify(() => _settings.setOneReel(count: 1)).called(1);
    expect(find.text('One reel unblocked'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a live Pause: re-tapping the lit Pause resumes', (tester) async {
    await _pump(tester, settings: _pausing());
    expect(tester.widget<ModeCard>(find.byType(ModeCard)).selectedIndex, 3);
    expect(find.text('REELS ALLOWED'), findsOneWidget);
    expect(find.text('of a 10 min break'), findsOneWidget);
    expect(find.textContaining('Blocking resumes in 09:'), findsOneWidget);

    await _tap(tester, _option('Pause'));
    verify(_settings.resumeNow).called(1);
    expect(find.text('By time'), findsNothing);
    verifyNever(() => _settings.setPlan(any()));
  });

  testWidgets('an N-reel unblock lights Unblock; re-tapping it returns to '
      'the base mode', (tester) async {
    await _pump(
      tester,
      settings: const AppSettings(
        hasSeenFeatureShowcase: true,
        activePlan: BlockingPlan.oneReel,
        reelAllowance: 5,
        baseMode: BlockingPlan.curious,
      ),
      reels: const ReelSessionState(allowance: 5, consumed: 2, active: true),
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.text('of 5 reels'), findsOneWidget);
    expect(find.text('3 reels left, then blocked again'), findsOneWidget);
    expect(tester.widget<ModeCard>(find.byType(ModeCard)).selectedIndex, 4);

    await _tap(tester, _option('Unblock'));
    verify(() => _settings.setPlan(BlockingPlan.curious)).called(1);
    verifyNever(_settings.resumeNow);
    expect(find.text('By reel count'), findsNothing);
  });

  testWidgets('the lit One Reel blocks now, with no confirm', (tester) async {
    await _pump(
      tester,
      settings: const AppSettings(
        hasSeenFeatureShowcase: true,
        activePlan: BlockingPlan.oneReel,
      ),
    );
    expect(find.text('One reel left'), findsOneWidget);
    await _tap(tester, _option('One Reel'));
    verify(() => _settings.setPlan(BlockingPlan.blockAll)).called(1);
    expect(find.text('Watch one reel?'), findsNothing);
  });

  testWidgets('the 1 Hz ticker runs only while a Pause is live', (
    tester,
  ) async {
    await _pump(tester);
    await tester.binding.delayed(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);

    await _pump(tester, settings: _pausing());
    await tester.binding.delayed(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isTrue);

    // The Pause ends: the ticker stops with it.
    await _pump(tester);
    await tester.binding.delayed(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the mode options are tour steps 0-4', (tester) async {
    await _pump(tester);
    for (var i = 0; i < _labels.length; i++) {
      expect(featureShowcaseSteps[i].title, _labels[i]);
      final step = find.descendant(
        of: find.byType(ModeCard),
        matching: find.byWidgetPredicate(
          (w) => w is Showcase && w.showcaseKey == featureShowcaseSteps[i].key,
        ),
      );
      expect(
        find.descendant(of: step, matching: find.text(_labels[i])),
        findsOneWidget,
        reason: _labels[i],
      );
    }
  });

  testWidgets('the streak is observed only on a measured, loaded day', (
    tester,
  ) async {
    await _pump(tester);
    verify(
      () => _streak.observe(now: any(named: 'now'), underLimit: true),
    ).called(greaterThan(0));

    clearInteractions(_streak);
    await _pump(tester, counter: const ContentCount(enabled: false));
    verifyNever(
      () => _streak.observe(
        now: any(named: 'now'),
        underLimit: any(named: 'underLimit'),
      ),
    );
    // Counting off: no number and dashed stats.
    expect(find.text('Counting is off'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(3));
  });

  testWidgets('the ring remounts when the first counter read lands', (
    tester,
  ) async {
    final reads = StreamController<ContentCount>();
    addTearDown(reads.close);
    whenListen(
      _counter,
      reads.stream,
      initialState: const ContentCount.empty(),
    );
    await _pump(tester, counter: const ContentCount.empty());
    final placeholder = tester.element(find.byType(TimeLeftRing));

    when(() => _counter.state).thenReturn(_counted);
    reads.add(_counted);
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(TimeLeftRing)), isNot(placeholder));
    expect(find.text('2h 15m'), findsOneWidget);
  });

  testWidgets('2x text on a 360 dp phone, in both themes', (tester) async {
    tester.view
      ..physicalSize = const Size(360 * 3, 640 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    for (final dark in [false, true]) {
      for (final settings in [
        const AppSettings(hasSeenFeatureShowcase: true),
        _pausing(),
      ]) {
        await _pump(tester, settings: settings, dark: dark, textScale: 2);
        expect(tester.takeException(), isNull, reason: 'dark $dark');
        expect(
          tester.getSize(find.byType(TimeLeftRing)).width,
          lessThanOrEqualTo(360 - 2 * AppSpacing.gutter),
        );
      }
    }
  });
}
