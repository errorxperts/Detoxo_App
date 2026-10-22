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

/// The block screen in the Flutter mirror: the app theme picks the look (Face
/// Down light, Spotlight dark), motion only on the full stage, the app's own
/// primary button — and the editor's one panel of options.
void main() {
  const style = BlockScreenStyle.defaults();

  // The off filter is always mounted; switched on it is the identity.
  bool greyed(WidgetTester tester) =>
      tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter !=
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
    theme: ThemeData(brightness: brightness),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );

  testWidgets('a light app theme draws Face Down', (tester) async {
    await tester.pumpWidget(
      host(const BlockScreenPreview(style: style, height: 640)),
    );
    expect(find.text('Instagram can wait. Your peace can’t.'), findsOneWidget);
    expect(
      find.text(
        'Block All is on · 12 reels today · Instagram opened 7 times today',
      ),
      findsOneWidget,
    );
    expect(find.text('Dalai Lama'), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.text('Back to Instagram · 5'), findsOneWidget);
  });

  testWidgets('a dark app theme draws Spotlight', (tester) async {
    await tester.pumpWidget(
      host(
        const BlockScreenPreview(style: style, height: 640),
        brightness: Brightness.dark,
      ),
    );
    expect(find.text('Instagram can wait. Your peace can’t.'), findsOneWidget);
    expect(find.text('HERMANN HESSE'), findsOneWidget);
  });

  testWidgets('Open Detoxo is the wall’s lit pill, full and compact', (
    tester,
  ) async {
    for (final compact in [false, true]) {
      await tester.pumpWidget(
        host(BlockScreenPreview(style: style, height: 200, compact: compact)),
      );
      expect(find.text('Open Detoxo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the logo ships in the bundle the native wall reads', (
    tester,
  ) async {
    final data = await tester.runAsync(
      () => rootBundle.load('assets/images/Detoxo_logo.png'),
    );
    expect(data!.lengthInBytes, greaterThan(0));
  });

  testWidgets('both walls draw the app logo once it has decoded', (
    tester,
  ) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(
        host(
          const BlockScreenPreview(style: style, height: 640),
          brightness: b,
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const ResizeImage(
            AssetImage('assets/images/Detoxo_logo.png'),
            width: 512,
          ),
          tester.element(find.byType(BlockScreenPreview)),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      // The board under the off filter: the recorder can't push its layer.
      expect(
        find.descendant(
          of: find.byType(BlockScreenPreview),
          matching: find.byType(FittedBox),
        ),
        paints..drawImageRect(),
      );
    }
  });

  testWidgets('the stage holds still under Remove animations', (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(
        host(
          const BlockScreenPreview(style: style, height: 640),
          brightness: b,
        ),
      );
      await tester.pumpAndSettle(); // a live loop would time out here
    }
  });

  testWidgets('the stage moves; a compact card never runs a ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const BlockScreenPreview(style: style, height: 640), still: false),
    );
    // Past both fade-ups (1.2 s, writer 1.5 s): only the loop can still ask
    // for frames.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isTrue);

    for (final b in Brightness.values) {
      await tester.pumpWidget(
        host(
          const BlockScreenPreview(style: style, height: 150, compact: true),
          still: false,
          brightness: b,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('can wait'), findsNothing);
      expect(find.textContaining('Back to'), findsNothing);
    }
  });

  testWidgets('switched off, the preview greys out under an Off badge and '
      'holds still', (tester) async {
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
    await tester.pumpAndSettle(); // no loop runs while off
    semantics.dispose();
  });

  testWidgets('switching off eases to grey and stops the loop; on brings '
      'both back', (tester) async {
    Widget preview({required bool on}) => host(
      BlockScreenPreview(style: BlockScreenStyle(enabled: on), height: 640),
      still: false,
    );
    await tester.pumpWidget(preview(on: true));
    await tester.pump(const Duration(seconds: 2)); // past the fade-ups
    expect(find.text('Off'), findsNothing);
    expect(greyed(tester), isFalse);

    await tester.pumpWidget(preview(on: false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(greyed(tester), isTrue); // already easing
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);

    await tester.pumpWidget(preview(on: true));
    await tester.pump(const Duration(milliseconds: 400)); // the grey eases out
    await tester.pump(const Duration(milliseconds: 16));
    expect(greyed(tester), isFalse);
    expect(find.text('Off'), findsNothing);
    expect(tester.binding.hasScheduledFrame, isTrue); // the loop runs again
  });

  group('the editor', () {
    setUp(() => PlatformAdaptive.debugUseCupertino = false);
    tearDown(() => PlatformAdaptive.debugUseCupertino = null);

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
      await tester.pump(); // no pumpAndSettle: the ambient background loops
    }

    SecondaryButton tryIt(WidgetTester tester) => tester.widget(
      find.widgetWithText(SecondaryButton, 'Try it on your phone'),
    );

    testWidgets('its own switch, then three options; no Design, Background '
        'or Theme picker', (tester) async {
      await pumpEditor(tester);

      expect(find.text('Show block screen'), findsOneWidget);
      expect(find.text('For app & website blocks'), findsOneWidget);
      expect(find.text('Spotlight · follows your app theme'), findsOneWidget);
      expect(find.text('Try it on your phone'), findsOneWidget);
      expect(tryIt(tester).onPressed, isNotNull);
      expect(find.byType(InfoButton), findsOneWidget);
      expect(find.text('OPTIONS'), findsOneWidget);
      for (final gone in [
        'DESIGN',
        'BACKGROUND',
        'THEME',
        'Classic',
        'Quotes',
        'Auto',
        'Color by usage',
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
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
