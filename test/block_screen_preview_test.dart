import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/block_screen/presentation/block_screen_style_screen.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStyle extends Mock implements BlockScreenStyleCubit {}

class _MockSettings extends Mock implements SettingsCubit {}

class _MockCounter extends Mock implements ContentCounterCubit {}

/// The block screen in the Flutter mirror: one Frozen Glass layout in both
/// themes, the reason's 3D icon, the entrance once and nothing after it —
/// and the editor's panels of options.
void main() {
  const style = BlockScreenStyle.defaults();

  // The off filter is always mounted; switched on it is the identity.
  bool greyed(WidgetTester tester) =>
      tester
          .widget<ColorFiltered>(find.byType(ColorFiltered).first)
          .colorFilter !=
      const ColorFilter.matrix(<double>[
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ]);

  Widget host(
    Widget child, {
    bool still = true,
    Brightness brightness = Brightness.light,
  }) => MaterialApp(
    theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );

  Icon3d hero(WidgetTester tester) => tester.widget<Icon3d>(
    find.descendant(
      of: find.byType(BlockScreenPreview),
      matching: find.byType(Icon3d),
    ),
  );

  testWidgets('one layout in both themes: the wordmark, the quote panel, the '
      'line, the meta and the exits', (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(
        host(
          const BlockScreenPreview(style: style, height: 640),
          brightness: b,
        ),
      );
      expect(find.text('Detoxo'), findsOneWidget, reason: '$b');
      expect(find.byType(DetoxoLogo), findsOneWidget);
      expect(
        find.text(
          'Do not let the behavior of others destroy your inner peace.',
        ),
        findsOneWidget,
      );
      expect(find.text('DALAI LAMA'), findsOneWidget);
      expect(
        find.text('Instagram can wait. Your peace can’t.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Block All is on · 12 reels today · Instagram opened 7 times today',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(LiquidPill, 'Open Detoxo'), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.text('Back to Instagram · 5'), findsOneWidget);
      // A plan block shows its mode icon, in the accent.
      expect(hero(tester).accentTint, isTrue);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the icon follows the block reason, as natively (heroIconFor)', (
    tester,
  ) async {
    BlockScreenPayload wall(
      BlockReason reason, {
      BlockingPlan? plan,
      int n = 1,
    }) => BlockScreenPayload(
      referenceType: BlockReferenceType.app,
      referenceId: 'com.a',
      displayName: 'A',
      blockReason: reason,
      plan: plan,
      allowance: n,
    );
    // The same table as FrozenGlassTest.everyBlockReasonHasItsOwnIconAndEveryIconShips.
    final table = {
      wall(BlockReason.plan, plan: BlockingPlan.blockAll): (
        'icon-block-all',
        true,
      ),
      wall(BlockReason.plan): ('icon-block-all', true),
      wall(BlockReason.plan, plan: BlockingPlan.curious): (
        'icon-conscious',
        true,
      ),
      wall(BlockReason.plan, plan: BlockingPlan.oneReel): (
        'icon-one-reel',
        true,
      ),
      wall(BlockReason.plan, plan: BlockingPlan.oneReel, n: 3): (
        'icon-pause',
        true,
      ),
      wall(BlockReason.appBlock): ('icon-app-blocker', false),
      wall(BlockReason.webRule): ('icon-web-blocker', false),
      wall(BlockReason.adult): ('icon-web-blocker', false),
      wall(BlockReason.schedule): ('icon-blocker-rules', false),
      wall(BlockReason.dailyLimit): ('icon-blocker-rules', false),
    };
    for (final MapEntry(key: p, value: (name, mode)) in table.entries) {
      await tester.pumpWidget(
        host(BlockScreenPreview(style: style, payload: p, height: 640)),
      );
      expect(
        hero(tester).asset.path,
        'assets/images/icons/$name.webp',
        reason: '${p.blockReason} ${p.plan} ${p.allowance}',
      );
      expect(hero(tester).accentTint, mode, reason: name);
    }
  });

  testWidgets(
    'the compact card: the header, a short quote and the button row',
    (tester) async {
      for (final b in Brightness.values) {
        await tester.pumpWidget(
          host(
            const BlockScreenPreview(style: style, height: 150, compact: true),
            still: false,
            brightness: b,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Detoxo'), findsOneWidget);
        expect(find.text('Lost time is never found again.'), findsOneWidget);
        expect(find.widgetWithText(LiquidPill, 'Open Detoxo'), findsOneWidget);
        expect(find.byType(Icon3d), findsNothing);
        expect(find.textContaining('Back to'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('the art ships in the bundle the native wall reads', (
    tester,
  ) async {
    for (final name in [
      'detoxo-logo',
      'icon-block-all',
      'icon-conscious',
      'icon-pause',
      'icon-one-reel',
      'icon-app-blocker',
      'icon-web-blocker',
      'icon-blocker-rules',
    ]) {
      final data = await tester.runAsync(
        () => rootBundle.load('assets/images/icons/$name.webp'),
      );
      expect(data!.lengthInBytes, greaterThan(0), reason: name);
    }
  });

  testWidgets('the entrance plays once, then the stage rests', (tester) async {
    await tester.pumpWidget(
      host(const BlockScreenPreview(style: style, height: 640), still: false),
    );
    expect(tester.binding.hasScheduledFrame, isTrue); // the quote fading up
    await tester.pumpAndSettle(); // nothing loops: this returns
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('under Remove animations nothing moves at all', (tester) async {
    for (final b in Brightness.values) {
      // A fresh tree per theme: Material's own theme-change tween is not
      // the stage's.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        host(
          const BlockScreenPreview(style: style, height: 640),
          brightness: b,
        ),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
  });

  testWidgets('switched off, the preview greys out under an Off badge', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        const BlockScreenPreview(
          style: BlockScreenStyle(enabled: false),
          height: 640,
        ),
        still: false,
      ),
    );
    expect(find.text('Off'), findsOneWidget);
    expect(greyed(tester), isTrue);
    expect(
      find.bySemanticsLabel(RegExp(r'^Block screen preview, off\. ')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('switching off eases to grey; on brings it back', (tester) async {
    Widget preview({required bool on}) => host(
      BlockScreenPreview(style: BlockScreenStyle(enabled: on), height: 640),
      still: false,
    );
    await tester.pumpWidget(preview(on: true));
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsNothing);
    expect(greyed(tester), isFalse);

    await tester.pumpWidget(preview(on: false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(greyed(tester), isTrue); // already easing
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);

    await tester.pumpWidget(preview(on: true));
    await tester.pumpAndSettle();
    expect(greyed(tester), isFalse);
    expect(find.text('Off'), findsNothing);
  });

  group('the editor', () {
    late _MockStyle cubit;
    late _MockCounter counter;

    Future<void> pumpEditor(
      WidgetTester tester, {
      BlockScreenStyle style = const BlockScreenStyle.defaults(),
      bool? overlayGranted,
    }) async {
      cubit = _MockStyle();
      counter = _MockCounter();
      final settings = _MockSettings();
      when(() => cubit.state).thenReturn(style);
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => settings.state).thenReturn(const AppSettings());
      when(() => settings.stream).thenAnswer((_) => const Stream.empty());
      when(
        () => counter.state,
      ).thenReturn(ContentCount(overlayGranted: overlayGranted));
      when(() => counter.stream).thenAnswer((_) => const Stream.empty());
      when(() => counter.requestOverlay()).thenAnswer((_) async {});
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<BlockScreenStyleCubit>.value(value: cubit),
            BlocProvider<SettingsCubit>.value(value: settings),
            BlocProvider<ContentCounterCubit>.value(value: counter),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const BlockScreenStyleScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    SecondaryButton tryIt(WidgetTester tester) => tester.widget(
      find.widgetWithText(SecondaryButton, 'Try it on your phone'),
    );

    testWidgets('its own switch, then three options on panels; no look '
        'picker, no Face Down or Spotlight', (tester) async {
      await pumpEditor(tester);

      expect(find.text('Show block screen'), findsOneWidget);
      expect(find.text('For app & website blocks'), findsOneWidget);
      expect(find.text('Follows your app theme'), findsOneWidget);
      expect(find.text('Try it on your phone'), findsOneWidget);
      expect(tryIt(tester).onPressed, isNotNull);
      expect(find.byType(InfoButton), findsOneWidget);
      expect(
        tester.widget<InfoButton>(find.byType(InfoButton)).message,
        'Shows a quote when something is blocked. It follows your app theme. '
        'Off, app and website blocks show a short message instead.',
      );
      expect(find.text('OPTIONS'), findsOneWidget);
      expect(find.byType(PanelGroup), findsNWidgets(2));
      for (final gone in [
        'DESIGN',
        'BACKGROUND',
        'THEME',
        'Classic',
        'Auto',
        'Color by usage',
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      expect(find.textContaining('Face Down'), findsNothing);
      expect(find.textContaining('Spotlight'), findsNothing);
      expect(find.text('Needs Usage access'), findsOneWidget);
      // Each row is one TalkBack node: its caption is read with its switch.
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.text('Needs Usage access')),
        isSemantics(
          label: 'Times opened today\nNeeds Usage access',
          isToggled: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();

      final toggles = find.byType(AppToggle);
      expect(toggles, findsNWidgets(4));
      for (var i = 0; i < 4; i++) {
        await tester.tap(toggles.at(i));
        await tester.pump(const Duration(milliseconds: 200)); // press timers
      }
      verify(() => cubit.setEnabled(enabled: false)).called(1);
      verify(() => cubit.setShowCount(show: false)).called(1);
      verify(() => cubit.setShowOpens(show: false)).called(1);
      verify(() => cubit.setBackDelay(on: false)).called(1);
    });

    testWidgets('switched off, Try it and the options wait for the switch', (
      tester,
    ) async {
      await pumpEditor(tester, style: const BlockScreenStyle(enabled: false));

      expect(tryIt(tester).onPressed, isNull);
      final toggles = tester.widgetList<AppToggle>(find.byType(AppToggle));
      expect(toggles.first.enabled, isTrue); // the switch itself stays live
      expect(toggles.skip(1).map((t) => t.enabled), everyElement(isFalse));

      final all = find.byType(AppToggle);
      await tester.tap(all.at(1), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      verifyNever(() => cubit.setShowCount(show: any(named: 'show')));
      await tester.tap(all.first);
      await tester.pump(const Duration(milliseconds: 200));
      verify(() => cubit.setEnabled(enabled: true)).called(1);
    });

    testWidgets('a missing overlay grant is fixed in place, not by a toast', (
      tester,
    ) async {
      await pumpEditor(tester, overlayGranted: false);

      expect(tryIt(tester).onPressed, isNull);
      const notice = 'Needs “Display over other apps” — tap to allow';
      expect(find.text(notice), findsOneWidget);
      await tester.tap(find.text(notice));
      await tester.pump(const Duration(milliseconds: 200));
      verify(() => counter.requestOverlay()).called(1);
    });
  });
}
