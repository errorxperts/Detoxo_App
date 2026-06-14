import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/plans/data/repositories/content_repository_impl.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/emoji_band.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/sessions.dart';
import 'package:detoxo/features/blocking/plans/presentation/widgets/animated_digit_timer.dart';
import 'package:detoxo/features/blocking/plans/presentation/widgets/animated_emoji.dart';
import 'package:detoxo/features/blocking/plans/presentation/widgets/mindful_countdown.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/engine_event.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmojiAnimation.fromWire', () {
    test('parses every wire token case-insensitively', () {
      expect(EmojiAnimation.fromWire('BREATHING'), EmojiAnimation.breathing);
      expect(EmojiAnimation.fromWire('shake'), EmojiAnimation.shake);
      expect(EmojiAnimation.fromWire('FLY'), EmojiAnimation.fly);
    });
    test('falls back to breathing on unknown/null', () {
      expect(EmojiAnimation.fromWire('nope'), EmojiAnimation.breathing);
      expect(EmojiAnimation.fromWire(null), EmojiAnimation.breathing);
    });
  });

  group('EmojiItem / EmojiPlacement matching', () {
    const a = EmojiItem(
      id: 'a', rangeMin: 0, rangeMax: 2, emoji: '✨', title: 'Demure',
      description: '', animation: EmojiAnimation.breathing,
    );
    const b = EmojiItem(
      id: 'b', rangeMin: 3, rangeMax: 5, emoji: '👀', title: 'Side Eye',
      description: '', animation: EmojiAnimation.scanning,
    );
    const placement = EmojiPlacement(
      placementId: 'P', enabled: true,
      set: EmojiSet(setId: 's', placementId: 'P', enabled: true, items: [a, b]),
    );

    test('covers is inclusive at both bounds', () {
      expect(a.covers(0), isTrue);
      expect(a.covers(2), isTrue);
      expect(a.covers(3), isFalse);
    });
    test('itemFor picks the band whose range covers the value', () {
      expect(placement.itemFor(1)?.id, 'a');
      expect(placement.itemFor(4)?.id, 'b');
      expect(placement.itemFor(99), isNull);
    });
    test('disabled set yields nothing', () {
      const disabled = EmojiPlacement(
        placementId: 'P', enabled: true,
        set: EmojiSet(setId: 's', placementId: 'P', enabled: false, items: [a]),
      );
      expect(disabled.itemFor(0), isNull);
      expect(disabled.isUsable, isFalse);
    });
    test('fromBundle reads the first set', () {
      final p = EmojiPlacement.fromBundle({
        'emojiSets': [
          {
            'setId': 's1',
            'placementId': 'EMOJI_CURIOUS_PLAN',
            'enabled': true,
            'emojis': [
              {
                'emojiId': 'e1', 'rangeMin': 0, 'rangeMax': 5, 'emoji': '🎯',
                'title': 'Stay Sharp', 'description': 'x', 'animation': 'BREATHING',
              },
            ],
          },
        ],
      });
      expect(p.isUsable, isTrue);
      expect(p.placementId, 'EMOJI_CURIOUS_PLAN');
      expect(p.itemFor(3)?.title, 'Stay Sharp');
    });
    test('fromBundle on empty json is a safe disabled placement', () {
      final p = EmojiPlacement.fromBundle(const {});
      expect(p.isUsable, isFalse);
    });
  });

  group('Session helpers', () {
    final start = DateTime(2026, 1, 1, 10);

    test('PauseSession cooldownProgressPct ramps 0→100 across cooldown', () {
      final s = PauseSession(
        startedAt: start,
        pauseDuration: const Duration(minutes: 5),
        cooldownDuration: const Duration(minutes: 10),
        planToResume: BlockingPlan.blockAll,
      );
      expect(s.cooldownProgressPct(start.add(const Duration(minutes: 5))), 0);
      expect(s.cooldownProgressPct(start.add(const Duration(minutes: 10))), 50);
      expect(s.cooldownProgressPct(start.add(const Duration(minutes: 15))), 100);
    });

    test('CuriousSession minutes elapsed + cooldown lock', () {
      final s = CuriousSession(
        startedAt: start,
        sessionDuration: const Duration(minutes: 25),
        cooldownDuration: const Duration(minutes: 5),
        disablePlanSwitchInCooldown: true,
      );
      expect(s.minutesElapsedInSession(start.add(const Duration(minutes: 11))), 11);
      // In session → not locked; in cooldown → locked.
      expect(s.planSwitchLockedAt(start.add(const Duration(minutes: 10))), isFalse);
      expect(s.planSwitchLockedAt(start.add(const Duration(minutes: 27))), isTrue);
    });
  });

  group('AppSettings derived enforcement', () {
    final now = DateTime(2026, 1, 1, 12);

    AppSettings pause({required bool allow, required BlockingPlan resume}) => AppSettings(
          activePlan: BlockingPlan.paused,
          pauseSession: PauseSession(
            startedAt: now,
            pauseDuration: const Duration(minutes: 5),
            cooldownDuration: const Duration(minutes: 5),
            planToResume: resume,
            allowInCooldown: allow,
          ),
        );

    test('pause window allows content (suspended through cooldown by default)', () {
      final s = pause(allow: true, resume: BlockingPlan.oneReel);
      final mid = now.add(const Duration(minutes: 2));
      expect(s.isPaused(mid), isTrue);
      // Allowed cooldown → suspended right through to the contract end.
      expect(s.nativePauseUntil(mid), now.add(const Duration(minutes: 10)));
    });

    test('allowed cooldown keeps content suspended (the fix)', () {
      final s = pause(allow: true, resume: BlockingPlan.blockAll);
      final cooldown = now.add(const Duration(minutes: 7));
      expect(s.isPauseContractLive(cooldown), isTrue);
      expect(s.isPaused(cooldown), isFalse); // not the allowed window…
      expect(s.nativePauseUntil(cooldown), now.add(const Duration(minutes: 10))); // …but still allowed
    });

    test('un-allowed cooldown blocks via the resume plan (no Block-All override)', () {
      final s = pause(allow: false, resume: BlockingPlan.oneReel);
      final cooldown = now.add(const Duration(minutes: 7));
      expect(s.nativePauseUntil(cooldown), isNull);
      expect(s.effectiveNativePlan(cooldown), BlockingPlan.oneReel);
    });

    test('curious: session allowed; cooldown blocks/allows per toggle; lock', () {
      final blocking = AppSettings(
        activePlan: BlockingPlan.curious,
        curiousSession: CuriousSession(
          startedAt: now,
          sessionDuration: const Duration(minutes: 5),
          cooldownDuration: const Duration(minutes: 5),
          disablePlanSwitchInCooldown: true,
        ),
      );
      final inSession = now.add(const Duration(minutes: 1));
      final cooldown = now.add(const Duration(minutes: 7));
      // Session → content allowed (suspended), switcher free.
      expect(blocking.nativePauseUntil(inSession), now.add(const Duration(minutes: 5)));
      expect(blocking.switcherEnabled(inSession), isTrue);
      // Cooldown (toggle off) → blocked (Block-All), no suspension, switcher locked.
      expect(blocking.nativePauseUntil(cooldown), isNull);
      expect(blocking.effectiveNativePlan(cooldown), BlockingPlan.blockAll);
      expect(blocking.switcherEnabled(cooldown), isFalse);

      final allowed = AppSettings(
        activePlan: BlockingPlan.curious,
        curiousSession: CuriousSession(
          startedAt: now,
          sessionDuration: const Duration(minutes: 5),
          cooldownDuration: const Duration(minutes: 5),
          allowInCooldown: true,
        ),
      );
      // Cooldown (toggle on) → still suspended (allowed).
      expect(allowed.nativePauseUntil(cooldown), now.add(const Duration(minutes: 10)));
    });

    test('JSON round-trips with both sessions', () {
      final s = AppSettings(
        activePlan: BlockingPlan.paused,
        pauseSession: PauseSession(
          startedAt: now,
          pauseDuration: const Duration(minutes: 5),
          cooldownDuration: const Duration(minutes: 5),
          planToResume: BlockingPlan.blockAll,
        ),
        curiousSession: CuriousSession(
          startedAt: now,
          sessionDuration: const Duration(minutes: 25),
          cooldownDuration: const Duration(minutes: 5),
          disablePlanSwitchInCooldown: true,
        ),
      );
      final back = AppSettings.fromJson(s.toJson());
      expect(back.pauseSession, s.pauseSession);
      expect(back.curiousSession, s.curiousSession);
      expect(back.activePlan, BlockingPlan.paused);
    });
  });

  group('SettingsCubit transitions', () {
    late _FakeSettingsRepo settings;
    late _FakeEngineRepo engine;
    late SettingsCubit cubit;

    setUp(() {
      settings = _FakeSettingsRepo(const AppSettings());
      engine = _FakeEngineRepo();
      cubit = SettingsCubit(settings, engine);
    });

    tearDown(() async {
      await cubit.close(); // cancels the session ticker
    });

    test('startPause enters paused with a live contract', () async {
      await cubit.startPause(pause: const Duration(minutes: 5));
      expect(cubit.state.activePlan, BlockingPlan.paused);
      expect(cubit.state.pauseSession, isNotNull);
      expect(cubit.state.isPaused(), isTrue);
      expect(engine.pushed, isNotEmpty);
    });

    test('resumeNow ends the contract and resumes the plan', () async {
      await cubit.startPause(pause: const Duration(minutes: 5));
      await cubit.resumeNow();
      expect(cubit.state.pauseSession, isNull);
      expect(cubit.state.activePlan, BlockingPlan.blockAll); // resumed plan
    });

    test('startCurious then stopCurious clears the contract', () async {
      await cubit.startCurious();
      expect(cubit.state.activePlan, BlockingPlan.curious);
      expect(cubit.state.curiousSession, isNotNull);
      await cubit.stopCurious();
      expect(cubit.state.activePlan, BlockingPlan.blockAll);
      expect(cubit.state.curiousSession, isNull);
    });

    test('setPlan is ignored while a curious cooldown locks the switcher', () async {
      await cubit.startCurious(
        session: Duration.zero, // immediately in cooldown (default 5-min cooldown)
        disablePlanSwitchInCooldown: true,
      );
      expect(cubit.state.switcherEnabled(), isFalse);
      await cubit.setPlan(BlockingPlan.blockAll);
      expect(cubit.state.activePlan, BlockingPlan.curious); // unchanged
    });
  });

  group('Mindful Countdown widgets', () {
    testWidgets('AnimatedEmoji builds for all 14 animations', (tester) async {
      for (final anim in EmojiAnimation.values) {
        await tester.pumpWidget(MaterialApp(
          home: Center(child: AnimatedEmoji(emoji: '🎯', animation: anim)),
        ));
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.text('🎯'), findsOneWidget, reason: 'anim=$anim');
      }
      await tester.pumpWidget(const SizedBox()); // dispose tickers
    });

    testWidgets('AnimatedDigitTimer renders mm:ss', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(child: AnimatedDigitTimer(remaining: Duration(seconds: 125))),
        ),
      ));
      await tester.pump();
      expect(find.text('0'), findsWidgets); // 02:05 → has digit cells
      expect(find.text('2'), findsWidgets);
      expect(find.text(':'), findsOneWidget);
    });

    testWidgets('MindfulCountdown shows phase label, emoji band and quote',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: MindfulCountdown(
            phaseLabel: 'Blocking resumes in',
            remaining: Duration(minutes: 4, seconds: 12),
            progress: 0.8,
            quote: 'Reels can wait.',
            emoji: EmojiItem(
              id: 'x', rangeMin: 0, rangeMax: 5, emoji: '🎯', title: 'Stay Sharp',
              description: 'Focus.', animation: EmojiAnimation.breathing,
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Blocking resumes in'), findsOneWidget);
      expect(find.text('Stay Sharp'), findsOneWidget);
      expect(find.text('Reels can wait.'), findsOneWidget);
      expect(find.text('🎯'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('ContentRepository emoji bundle (real assets)', () {
    testWidgets('curious band bucket 0 is "Stay Sharp"', (tester) async {
      final repo = ContentRepositoryImpl();
      final items = await repo.emojiFor(EmojiPlacementId.curiousPlan, 0);
      expect(items, isNotEmpty);
      expect(items.first.title, 'Stay Sharp');
    });
  });
}

class _FakeSettingsRepo implements SettingsRepository {
  _FakeSettingsRepo(this._initial);
  final AppSettings _initial;
  AppSettings? saved;

  @override
  Future<AppSettings> load() async => _initial;

  @override
  Future<void> save(AppSettings settings) async => saved = settings;

  @override
  Stream<AppSettings> watch() => const Stream.empty();
}

class _FakeEngineRepo implements EngineRepository {
  final List<AppSettings> pushed = [];

  @override
  Future<void> pushSettings(AppSettings settings) async => pushed.add(settings);

  @override
  Future<void> pushConfig(String configJson) async {}

  @override
  Stream<ServiceSnapshot> statusStream() => const Stream.empty();

  @override
  Stream<BlockEvent> blockStream() => const Stream.empty();

  @override
  Future<ServiceSnapshot> currentStatus() async => const ServiceSnapshot();

  @override
  Future<void> performBack() async {}

  @override
  Future<void> killApp(String packageName) async {}

  @override
  Future<void> lockScreen() async {}
}
