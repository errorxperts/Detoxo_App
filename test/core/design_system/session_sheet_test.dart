import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens a [SessionSheet] with the C8 configs: reels 1–20 (default 10, picks
/// 5·10·15·20), time 1–10 min (default 5, picks 1·3·5·10). Returns the values
/// `onStart` received.
///
/// The default 600 dp screen leaves the test font (every glyph 1 em wide)
/// room for one-line headings; [size] narrows it.
Future<List<int>> _open(
  WidgetTester tester, {
  SessionKind kind = SessionKind.reels,
  int? initial,
  ThemeData? theme,
  double textScale = 1,
  bool reduceMotion = false,
  bool started = true,
  Size size = const Size(600, 900),
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final reels = kind == SessionKind.reels;
  final starts = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => SessionSheet.show(
              context,
              kind: kind,
              min: 1,
              max: reels ? 20 : 10,
              initial: initial ?? (reels ? 10 : 5),
              picks: reels ? const [5, 10, 15, 20] : const [1, 3, 5, 10],
              note: (v) => reels
                  ? 'Blocking resumes after $v reels'
                  : 'Blocking resumes at 7:45 PM',
              startLabel: (v) =>
                  reels ? 'Start $v-reel session' : 'Start $v-min session',
              onStart: (v) async {
                starts.add(v);
                return started;
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return starts;
}

final _sheet = find.byWidgetPredicate(
  (w) => w is GlassContainer && w.surface == DxSurface.sheet,
);
final _minus = find.bySemanticsLabel('One fewer reel');
final _plus = find.bySemanticsLabel('One more reel');

Finder _reelsNote(int n) => find.text('Blocking resumes after $n reels');

/// The Start pill's painter, by its gradient.
Finder _pill(List<Color> gradient) => find.byWidgetPredicate(
  (w) =>
      w is CustomPaint &&
      w.painter is DxSurfacePainter &&
      listEquals((w.painter! as DxSurfacePainter).gradient, gradient),
);

void main() {
  for (final kind in SessionKind.values) {
    for (final dark in [false, true]) {
      testWidgets('${kind.name} in ${dark ? 'Dark' : 'Light'}: 434 tall, '
          'start colours, the picked label', (tester) async {
        final theme = dark ? AppTheme.dark() : AppTheme.light();
        final t = AppTokens.forBrightness(theme.brightness);
        await _open(tester, kind: kind, theme: theme);

        expect(tester.getSize(_sheet).height, 434);
        expect(_pill([t.startFrom, t.startTo]), findsOneWidget);
        // The default is a pick: its label is accent text in Light, ink in
        // Dark; the others stay ink-2.
        final picked = find.text(kind == SessionKind.reels ? '10' : '5').last;
        final other = find.text(kind == SessionKind.reels ? '20' : '10').last;
        Color? color(Finder f) =>
            DefaultTextStyle.of(tester.element(f)).style.color;
        expect(color(picked), dark ? t.ink : t.accentText(t.brand));
        expect(color(other), t.ink2);
      });
    }
  }

  group('reels stepper', () {
    testWidgets('stops at the bounds, where the button disables', (
      tester,
    ) async {
      await _open(tester, initial: 2);
      await tester.tap(_minus);
      await tester.pumpAndSettle();
      expect(_reelsNote(1), findsOneWidget);
      expect(
        tester.getSemantics(_minus),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
      AnimatedOpacity fade(Finder f) => tester.widget(
        find.descendant(of: f, matching: find.byType(AnimatedOpacity)),
      );
      expect(fade(_minus).opacity, .35);
      expect(fade(_plus).opacity, 1);

      await tester.tap(_minus, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_reelsNote(1), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await _open(tester, initial: 19);
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      expect(_reelsNote(20), findsOneWidget);
      expect(
        tester.getSemantics(_plus),
        isSemantics(hasEnabledState: true, isEnabled: false),
      );
    });

    testWidgets('a tap steps once; so does a screen-reader tap', (
      tester,
    ) async {
      await _open(tester);
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      expect(_reelsNote(11), findsOneWidget);

      tester.semantics.tap(find.semantics.byLabel('One more reel'));
      await tester.pumpAndSettle();
      expect(_reelsNote(12), findsOneWidget);
    });

    testWidgets('holding repeats at 420 ms, ×.78 each time, down to 60 ms', (
      tester,
    ) async {
      await _open(tester, initial: 1);
      final hold = await tester.startGesture(tester.getCenter(_plus));
      await tester.pump();
      expect(_reelsNote(2), findsOneWidget, reason: 'steps on down');

      await tester.pump(const Duration(milliseconds: 419));
      expect(_reelsNote(2), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(_reelsNote(3), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 327));
      expect(_reelsNote(3), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1)); // 327.6
      expect(_reelsNote(4), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 256)); // 255.5
      expect(_reelsNote(5), findsOneWidget);

      // 199, 155, 121, 95, 74, then 60 ms a step: 20 by 2.25 s.
      await tester.pump(const Duration(milliseconds: 1244));
      expect(_reelsNote(20), findsOneWidget);
      // Disabled mid-press at the bound, it does not stay pressed.
      final scale = tester.widget<AnimatedScale>(
        find.descendant(of: _plus, matching: find.byType(AnimatedScale)),
      );
      expect(scale.scale, 1);

      await hold.up();
      await tester.pumpAndSettle();
      expect(_reelsNote(20), findsOneWidget);
    });

    testWidgets('releasing ends the hold without an extra step', (
      tester,
    ) async {
      await _open(tester);
      final hold = await tester.startGesture(tester.getCenter(_plus));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_reelsNote(12), findsOneWidget);
      await hold.up();
      await tester.pump(const Duration(seconds: 2));
      expect(_reelsNote(12), findsOneWidget);
    });
  });

  testWidgets('the quick-pick chip hides on a custom value', (tester) async {
    await _open(tester);
    AnimatedOpacity chip() => tester.widget(find.byKey(SessionSheet.chipKey));
    expect(chip().opacity, 1);

    await tester.tap(_minus);
    await tester.pumpAndSettle();
    expect(_reelsNote(9), findsOneWidget);
    expect(chip().opacity, 0);
    expect(
      tester.getSemantics(find.bySemanticsLabel('10 reels')),
      isSemantics(isSelected: false, isInMutuallyExclusiveGroup: true),
    );

    await tester.tap(find.bySemanticsLabel('15 reels'));
    await tester.pumpAndSettle();
    expect(_reelsNote(15), findsOneWidget);
    expect(chip().opacity, 1);
    final slot = tester.widget<AnimatedAlign>(
      find.ancestor(
        of: find.byKey(SessionSheet.chipKey),
        matching: find.byType(AnimatedAlign),
      ),
    );
    expect((slot.alignment as Alignment).x, closeTo(1 / 3, 1e-9));
  });

  group('time dial', () {
    testWidgets('keys: arrows ±1, Page Up / Down ±5, Home / End', (
      tester,
    ) async {
      await _open(tester, kind: SessionKind.time);
      Focus.of(tester.element(find.byKey(SessionSheet.dialKey))).requestFocus();
      await tester.pump();

      for (final (key, minutes) in [
        (LogicalKeyboardKey.arrowRight, 6),
        (LogicalKeyboardKey.arrowUp, 7),
        (LogicalKeyboardKey.arrowLeft, 6),
        (LogicalKeyboardKey.arrowDown, 5),
        (LogicalKeyboardKey.pageUp, 10),
        (LogicalKeyboardKey.pageUp, 10),
        (LogicalKeyboardKey.pageDown, 5),
        (LogicalKeyboardKey.home, 1),
        (LogicalKeyboardKey.end, 10),
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(
          find.text('Start $minutes-min session'),
          findsOneWidget,
          reason: '$key',
        );
      }
    });

    testWidgets('drag sets the value; the bottom gap is ignored', (
      tester,
    ) async {
      await _open(tester, kind: SessionKind.time);
      final origin = tester.getTopLeft(find.byKey(SessionSheet.dialKey));

      // 12 o'clock is the middle of 1–10.
      await tester.tapAt(origin + const Offset(89, 23));
      await tester.pumpAndSettle();
      expect(find.text('Start 6-min session'), findsOneWidget);

      // Round to 3 o'clock: 225° of 270°.
      await tester.dragFrom(
        origin + const Offset(89, 23),
        const Offset(66, 66),
      );
      await tester.pumpAndSettle();
      expect(find.text('Start 9-min session'), findsOneWidget);

      await tester.tapAt(origin + const Offset(89, 150));
      await tester.pumpAndSettle();
      expect(find.text('Start 9-min session'), findsOneWidget);
    });
  });

  group('Start', () {
    testWidgets('true: "Session started", held, closes after 1.1 s', (
      tester,
    ) async {
      final t = AppTokens.forBrightness(Brightness.dark);
      final starts = await _open(tester);
      await tester.tap(find.text('Start 10-reel session'));
      await tester.pump();
      expect(starts, [10]);
      expect(find.text('Session started'), findsOneWidget);
      expect(_pill([t.startedFrom, t.startedTo]), findsOneWidget);

      // Held until it closes itself: back does nothing.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Session started'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1099));
      expect(find.text('Session started'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
    });

    testWidgets('false: the sheet stays as it was', (tester) async {
      final starts = await _open(tester, started: false);
      await tester.tap(find.text('Start 10-reel session'));
      await tester.pump(const Duration(seconds: 2));
      expect(starts, [10]);
      expect(find.text('Session started'), findsNothing);
      expect(find.text('Start 10-reel session'), findsOneWidget);

      await tester.tap(find.text('Start 10-reel session'));
      await tester.pump();
      expect(starts, [10, 10]);
    });
  });

  testWidgets('Close closes it', (tester) async {
    await _open(tester);
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(_sheet, findsNothing);
  });

  group('semantics', () {
    testWidgets('reels: steppers, the live value, radios', (tester) async {
      await _open(tester, initial: 12);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Session blocker')),
        isSemantics(isHeader: true),
      );
      expect(
        tester.getSemantics(_minus),
        isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(_plus),
        isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('12 reels')),
        isSemantics(isLiveRegion: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('5 reels')),
        isSemantics(
          isButton: true,
          isInMutuallyExclusiveGroup: true,
          hasSelectedState: true,
          isSelected: false,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Close')),
        isSemantics(isButton: true),
      );
      expect(find.bySemanticsLabel('Quick pick'), findsOneWidget);
    });

    testWidgets('time: a slider with its value', (tester) async {
      await _open(tester, kind: SessionKind.time);
      final dial = find.bySemanticsLabel('Session length');
      expect(
        tester.getSemantics(dial),
        isSemantics(
          isSlider: true,
          value: '5 minutes',
          increasedValue: '6 minutes',
          decreasedValue: '4 minutes',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      tester.semantics.increase(find.semantics.byLabel('Session length'));
      await tester.pumpAndSettle();
      expect(find.text('Start 6-min session'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('1 minute')),
        isSemantics(isInMutuallyExclusiveGroup: true),
      );
    });
  });

  for (final kind in SessionKind.values) {
    testWidgets('${kind.name} at 2.0x text on a 360 dp screen', (tester) async {
      await _open(tester, kind: kind, textScale: 2, size: const Size(360, 780));
      expect(tester.takeException(), isNull);
      expect(_sheet, findsOneWidget);
    });
  }

  for (final still in [false, true]) {
    testWidgets(
      'Reduce Motion ${still ? 'on: nothing moves' : 'off: picks animate'}',
      (tester) async {
        await _open(tester, reduceMotion: still);
        await tester.tap(find.bySemanticsLabel('15 reels'));
        await tester.pump();
        // Running tickers, not housekeeping frames (focus, semantics).
        bool moving() => tester.binding.transientCallbackCount > 0;
        expect(moving(), !still, reason: 'slide, squish, bump');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start 15-reel session'));
        await tester.pump();
        expect(find.text('Session started'), findsOneWidget);
        expect(moving(), !still, reason: 'check draw');
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
      },
    );
  }
}
