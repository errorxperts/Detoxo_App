import 'package:bloc_test/bloc_test.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/features/additional_feature/showcase_view/showcase_view.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/blocker_section.dart';
import 'package:detoxo/features/limits/limits.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// The test font draws every glyph 1 em wide, so the boxes are wider than a
/// 360 phone's 153 tile and 320 row: about 240 keeps "App Blocker" on one line
/// and 400 keeps "Blocker rules" on one, as Manrope does on the phone.
const _tileWidth = 240.0;
const _rowWidth = 400.0;

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  double textScale = 1,
  double width = _tileWidth,
}) => tester.pumpWidget(
  MaterialApp(
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        // A scroll view, as on Today: the tile's height is never bounded.
        body: ListView(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: child),
            ),
          ],
        ),
      ),
    ),
  ),
);

Widget _app(String letter) =>
    SiteLetter(letter, color: const Color(0xFF2B86FF));

BlockerTile _tile(BlockerStatus status, {VoidCallback? onTap}) => BlockerTile(
  icon: Assets.images.icons.iconAppBlocker,
  title: 'App Blocker',
  status: status,
  glow: AppTokens.light.tileApp,
  stack: [_app('Y'), _app('I'), _app('S')],
  more: 3,
  countLabel: '6 apps',
  onTap: onTap ?? () {},
);

class _MockSettings extends MockCubit<AppSettings> implements SettingsCubit {}

class _MockTargets extends MockCubit<TargetsState> implements TargetsCubit {}

class _MockRules extends MockCubit<RulesState> implements RulesCubit {}

class _MockUnblock extends MockCubit<UnblockState> implements UnblockCubit {}

class _MockAppRepo extends Mock implements AppBlockRepository {}

class _MockWebRepo extends Mock implements WebBlockRepository {}

class _MockSettingsRepo extends Mock implements SettingsRepository {}

class _MockEngine extends Mock implements EngineRepository {}

BlockTarget _feed(String id, String pkg) => BlockTarget(
  platformId: id,
  packageName: pkg,
  appName: pkg,
  displayName: id,
  iconUrl: '',
  detectionType: DetectionType.legacy,
  premiumExclusive: false,
  defaultEnabled: true,
  isBrowser: false,
);

void main() {
  group('BlockerTile', () {
    for (final dark in [false, true]) {
      for (final status in BlockerStatus.values) {
        testWidgets('${status.name}, ${dark ? 'dark' : 'light'}: 180 high at '
            '1x, grows without overflow at 2x', (tester) async {
          await _pump(tester, _tile(status), dark: dark);
          expect(tester.takeException(), isNull);
          expect(tester.getSize(find.byType(BlockerTile)).height, 180);

          await _pump(tester, _tile(status), dark: dark, textScale: 2);
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byType(BlockerTile)).height,
            greaterThan(180),
          );
        });
      }
    }

    testWidgets('On reads its count and shows three icons and +3', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _tile(BlockerStatus.on));
      expect(find.bySemanticsLabel('App Blocker, On, 6 apps'), findsOneWidget);
      expect(find.byType(SiteLetter), findsNWidgets(3));
      expect(find.text('+3'), findsOneWidget);
      expect(find.byType(Opacity), findsNothing);
      semantics.dispose();
    });

    testWidgets('Not set up says "Tap to set up" instead of the stack', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        BlockerTile(
          icon: Assets.images.icons.iconWebBlocker,
          title: 'Web Blocker',
          status: BlockerStatus.notSetUp,
          glow: AppTokens.light.tileWeb,
          onTap: () {},
        ),
      );
      expect(find.bySemanticsLabel('Web Blocker, Not set up'), findsOneWidget);
      expect(find.text('Tap to set up'), findsOneWidget);
      expect(find.text('Not set up'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('Paused fades the stack to .5; an empty stack shows the note', (
      tester,
    ) async {
      await _pump(tester, _tile(BlockerStatus.paused));
      final fade = find.ancestor(
        of: find.byType(SiteLetter).first,
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(fade).opacity, .5);
      expect(find.text('Paused'), findsOneWidget);

      await _pump(
        tester,
        BlockerTile(
          icon: Assets.images.icons.iconWebBlocker,
          title: 'Web Blocker',
          status: BlockerStatus.on,
          glow: AppTokens.light.tileWeb,
          note: 'Protection on',
          onTap: () {},
        ),
      );
      expect(find.text('Protection on'), findsOneWidget);
    });

    testWidgets('a tap fires', (tester) async {
      var taps = 0;
      await _pump(tester, _tile(BlockerStatus.on, onTap: () => taps++));
      await tester.tap(find.byType(BlockerTile));
      expect(taps, 1);
    });

    testWidgets('SiteLetter shows the first letter or digit, uppercased', (
      tester,
    ) async {
      await _pump(tester, _app('*.netflix.com'));
      expect(find.text('N'), findsOneWidget);
    });
  });

  group('BlockerRulesRow', () {
    testWidgets('64 high; reads its count and summary', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await _pump(
        tester,
        BlockerRulesRow(
          summary: 'Next: Bedtime at 11 PM',
          onCount: 2,
          onTap: () => taps++,
        ),
        width: _rowWidth,
      );
      expect(tester.getSize(find.byType(BlockerRulesRow)).height, 64);
      expect(find.text('Blocker rules'), findsOneWidget);
      expect(find.text('2 on'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Blocker rules, 2 on. Next: Bedtime at 11 PM'),
        findsOneWidget,
      );
      await tester.tap(find.byType(BlockerRulesRow));
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('no rules: the count is hidden', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        BlockerRulesRow(summary: 'Tap to set up', onCount: null, onTap: () {}),
        width: _rowWidth,
      );
      expect(find.textContaining(' on'), findsNothing);
      expect(
        find.bySemanticsLabel('Blocker rules. Tap to set up'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('2x text grows the row without overflow', (tester) async {
      await _pump(
        tester,
        BlockerRulesRow(
          summary: 'Next: Bedtime at 11 PM',
          onCount: 2,
          onTap: () {},
        ),
        textScale: 2,
        width: _rowWidth,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(BlockerRulesRow)).height,
        greaterThan(64),
      );
    });
  });

  group('BlockerSection', () {
    late _MockSettings settings;
    late _MockTargets targets;
    late _MockRules rules;
    late _MockUnblock unblock;

    setUp(() async {
      await sl.reset();
      final apps = _MockAppRepo();
      final web = _MockWebRepo();
      final settingsRepo = _MockSettingsRepo();
      final engine = _MockEngine();
      when(apps.load).thenAnswer(
        (_) async => const [
          AppBlockEntry(packageName: 'com.youtube', appName: 'YouTube'),
        ],
      );
      when(web.load).thenAnswer((_) async => const []);
      when(
        settingsRepo.load,
      ).thenAnswer((_) async => const AppSettings(blockAdultWebsites: true));
      when(engine.installedApps).thenAnswer((_) async => const []);
      sl
        ..registerSingleton<AppBlockRepository>(apps)
        ..registerSingleton<WebBlockRepository>(web)
        ..registerSingleton<SettingsRepository>(settingsRepo)
        ..registerSingleton<EngineRepository>(engine);

      settings = _MockSettings();
      when(() => settings.state).thenReturn(
        const AppSettings(enabledPlatformIds: {'ig_reels', 'ig_stories'}),
      );
      targets = _MockTargets();
      when(() => targets.state).thenReturn(
        TargetsState(
          targets: [
            _feed('ig_reels', 'com.instagram'),
            _feed('ig_stories', 'com.instagram'),
            _feed('yt_shorts', 'com.youtube.shorts'),
          ],
        ),
      );
      rules = _MockRules();
      when(() => rules.state).thenReturn(const RulesState());
      unblock = _MockUnblock();
      final now = DateTime.now().millisecondsSinceEpoch;
      when(() => unblock.state).thenReturn(
        UnblockState(
          active: [
            TemporaryUnblock(
              targetType: UnblockTargetType.app,
              targetId: 'com.youtube',
              startMs: now,
              endMs: now + 15 * 60000,
            ),
          ],
        ),
      );
    });

    tearDown(sl.reset);

    testWidgets('header, active unblocks, tiles, then the rules row', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<SettingsCubit>.value(value: settings),
            BlocProvider<TargetsCubit>.value(value: targets),
            BlocProvider<RulesCubit>.value(value: rules),
            BlocProvider<UnblockCubit>.value(value: unblock),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: buildFeatureShowcaseScope(
              onSeen: () {},
              child: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  children: const [BlockerSection()],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(); // the repository reads land

      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      // The grant row is named from the loaded lock, never its package id.
      expect(find.text('com.youtube'), findsNothing);
      expect(top('Blockers'), lessThan(top('YouTube')));
      expect(top('YouTube'), lessThan(top('App Blocker')));
      expect(top('App Blocker'), lessThan(top('Blocker rules')));

      // One YouTube lock plus Instagram's two feeds, which count once.
      expect(find.bySemanticsLabel('App Blocker, On, 2 apps'), findsOneWidget);
      // No sites, but the 18+ filter is on.
      expect(
        find.bySemanticsLabel('Web Blocker, On, Protection on'),
        findsOneWidget,
      );
      expect(find.text('2 of 2 on'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Blocker rules. Tap to set up'),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });
}
