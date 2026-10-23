import 'dart:math' as math;

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

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
final _dial = find.byKey(SessionSheet.dialKey);

/// The point on the ring slider's arc at [deg] canvas degrees (clockwise
/// from 3 o'clock): the 160 px slider's 12 px bar runs at radius 74, from
/// 150° (min) through 270° (12 o'clock) to 30° (max).
Offset _onRing(WidgetTester tester, double deg) {
  final a = deg * math.pi / 180;
  return tester.getCenter(_dial) + Offset(math.cos(a), math.sin(a)) * 74;
}

/// Drags along the arc through [degs], a frame per step: the package reads
/// its geometry from the last paint, so a move before it lands is dropped.
Future<void> _drag(WidgetTester tester, List<double> degs) async {
  final g = await tester.startGesture(_onRing(tester, degs.first));
  await tester.pump();
  for (final d in degs.skip(1)) {
    await g.moveTo(_onRing(tester, d));
    await tester.pump();
  }
  await g.up();
  await tester.pumpAndSettle();
}

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
        // The old pickers' ring: 8 track, 12 bar, an 8 white handle, no
        // shadow or easing, the dial's brand stops (reversed for the sweep).
        final ring = tester.widget<SleekCircularSlider>(_dial).appearance;
        final p = t.brand;
        expect(ring.size, 160);
        expect((ring.startAngle, ring.angleRange), (150, 240));
        expect(
          (ring.trackWidth, ring.progressBarWidth, ring.handlerSize),
          (8, 12, 8),
        );
        expect(ring.animationEnabled, isFalse);
        expect(ring.hideShadow, isTrue);
        expect(ring.dotColor, Colors.white);
        expect(ring.trackColor, t.control);
        expect(
          ring.progressBarColors,
          dark
              ? [p.deep, p.main, p.light]
              : [
                  p.deep,
                  Color.lerp(p.main, p.deep, AppTokens.arcMidMix),
                  p.main,
                ],
        );
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

  testWidgets('the quick-pick chip hides on a custom value', (tester) async {
    await _open(tester);
    AnimatedOpacity chip() => tester.widget(find.byKey(SessionSheet.chipKey));
    expect(chip().opacity, 1);

    tester.semantics.decrease(find.semantics.byLabel('Reel count'));
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

  group('ring slider', () {
    for (final (kind, steps) in [
      (
        SessionKind.time,
        [
          (LogicalKeyboardKey.arrowRight, 'Start 6-min session'),
          (LogicalKeyboardKey.arrowUp, 'Start 7-min session'),
          (LogicalKeyboardKey.arrowLeft, 'Start 6-min session'),
          (LogicalKeyboardKey.arrowDown, 'Start 5-min session'),
          (LogicalKeyboardKey.pageUp, 'Start 10-min session'),
          (LogicalKeyboardKey.pageUp, 'Start 10-min session'),
          (LogicalKeyboardKey.pageDown, 'Start 5-min session'),
          (LogicalKeyboardKey.home, 'Start 1-min session'),
          (LogicalKeyboardKey.end, 'Start 10-min session'),
        ],
      ),
      (
        SessionKind.reels,
        [
          (LogicalKeyboardKey.arrowRight, 'Start 11-reel session'),
          (LogicalKeyboardKey.arrowDown, 'Start 10-reel session'),
          (LogicalKeyboardKey.pageDown, 'Start 5-reel session'),
          (LogicalKeyboardKey.home, 'Start 1-reel session'),
          (LogicalKeyboardKey.arrowLeft, 'Start 1-reel session'),
          (LogicalKeyboardKey.end, 'Start 20-reel session'),
          (LogicalKeyboardKey.pageUp, 'Start 20-reel session'),
        ],
      ),
    ]) {
      testWidgets('${kind.name} keys: arrows ±1, Page Up / Down ±5, '
          'Home / End', (tester) async {
        await _open(tester, kind: kind);
        Focus.of(tester.element(_dial)).requestFocus();
        await tester.pump();

        for (final (key, label) in steps) {
          await tester.sendKeyEvent(key);
          await tester.pump();
          expect(find.text(label), findsOneWidget, reason: '$key');
        }
      });
    }

    testWidgets('time: drag sets the value; the bottom gap is ignored', (
      tester,
    ) async {
      await _open(tester, kind: SessionKind.time);

      // 12 o'clock is the middle of 1–10.
      await tester.tapAt(_onRing(tester, 270));
      await tester.pumpAndSettle();
      expect(find.text('Start 6-min session'), findsOneWidget);

      // Round to 3 o'clock: 210° of 240°.
      await _drag(tester, [270, 300, 330, 360]);
      expect(find.text('Start 9-min session'), findsOneWidget);

      await tester.tapAt(_onRing(tester, 90));
      await tester.pumpAndSettle();
      expect(find.text('Start 9-min session'), findsOneWidget);
    });

    testWidgets('reels: drag to either end, then a pick moves the handle', (
      tester,
    ) async {
      await _open(tester);
      await _drag(tester, [270, 320, 10, 30]);
      expect(_reelsNote(20), findsOneWidget);

      await tester.tapAt(_onRing(tester, 155));
      await tester.pumpAndSettle();
      expect(_reelsNote(1), findsOneWidget);

      // The pick re-fires the slider's onChange; the value holds.
      await tester.tap(find.bySemanticsLabel('15 reels'));
      await tester.pumpAndSettle();
      expect(_reelsNote(15), findsOneWidget);
      expect(tester.widget<SleekCircularSlider>(_dial).initialValue, 15);
      expect(tester.takeException(), isNull);
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
    testWidgets('reels: a slider with its value, radios', (tester) async {
      await _open(tester, initial: 12);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Session blocker')),
        isSemantics(isHeader: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Reel count')),
        isSemantics(
          isSlider: true,
          value: '12 reels',
          increasedValue: '13 reels',
          decreasedValue: '11 reels',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      tester.semantics.increase(find.semantics.byLabel('Reel count'));
      await tester.pumpAndSettle();
      expect(find.text('Start 13-reel session'), findsOneWidget);
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
