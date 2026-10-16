import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_frame.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_look.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_tokens.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _watch = Duration(seconds: 4328);

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  ),
);

BubblePreview _preview({
  int count = 152,
  BubbleVariant variant = BubbleVariant.mascot,
  bool animate = true,
  bool interactive = false,
  bool dockedRight = true,
  double size = 68,
  double area = 132,
  double? height,
  Key? key,
}) => BubblePreview(
  key: key,
  style: BubbleStyle(variant: variant, size: size),
  count: count,
  watch: _watch,
  area: area,
  height: height,
  animate: animate,
  interactive: interactive,
  dockedRight: dockedRight,
);

/// The frame the preview paints right now.
BubbleFrame _frame(WidgetTester tester) =>
    tester.state<BubblePreviewState>(find.byType(BubblePreview)).frame;

void main() {
  testWidgets('every variant builds still', (tester) async {
    for (final v in BubbleVariant.values) {
      for (final (right, tap) in [
        (true, false),
        (false, false),
        (true, true),
        (false, true),
      ]) {
        final why = '${v.name} right $right interactive $tap';
        final key = GlobalKey<BubblePreviewState>();
        await tester.pumpWidget(
          _app(
            _preview(
              key: key,
              variant: v,
              animate: false,
              interactive: tap,
              dockedRight: right,
            ),
          ),
        );
        expect(
          find.bySemanticsLabel(
            BubbleModel.collapsedLabel(152, 4328, v, tapHint: tap),
          ),
          findsOneWidget,
          reason: why,
        );
        expect(tester.binding.transientCallbackCount, 0, reason: why);
        if (!tap) continue; // a fitted preview never opens
        // Open, it paints the timer in one frame.
        key.currentState!.toggleTimer();
        await tester.pump();
        expect(_frame(tester).expand, 1, reason: why);
        expect(
          find.bySemanticsLabel(BubbleModel.openLabel(4328)),
          findsOneWidget,
          reason: why,
        );
        expect(tester.binding.transientCallbackCount, 0, reason: why);
      }
    }
  });

  testWidgets('a tap opens the timer and reads the open label', (tester) async {
    final key = GlobalKey<BubblePreviewState>();
    await tester.pumpWidget(_app(_preview(key: key, interactive: true)));

    await tester.tap(find.byType(BubblePreview));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(BubbleModel.openLabel(4328)), findsOneWidget);
    expect(key.currentState!.isOpen, isTrue);
    expect(_frame(tester).expand, 1);

    await tester.tap(find.byType(BubblePreview));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(
        BubbleModel.collapsedLabel(152, 4328, BubbleVariant.mascot),
      ),
      findsOneWidget,
    );
    expect(key.currentState!.isOpen, isFalse);
    expect(_frame(tester).expand, 0);
  });

  testWidgets('only an interactive preview promises a tap', (tester) async {
    final tap = RegExp('Tap to show the timer');
    await tester.pumpWidget(_app(_preview()));
    expect(
      find.bySemanticsLabel('152 reels today, 1h 12m watched.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(tap), findsNothing);

    await tester.pumpWidget(_app(_preview(interactive: true)));
    expect(find.bySemanticsLabel(tap), findsOneWidget);
  });

  testWidgets('an animation repaints without rebuilding', (tester) async {
    await tester.pumpWidget(
      _app(_preview(variant: BubbleVariant.ring, interactive: true, area: 220)),
    );
    await tester.tap(find.byType(BubblePreview));
    await tester.pump();
    CustomPaint canvas() => tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(BubblePreview),
        matching: find.byType(CustomPaint),
      ),
    );
    final built = canvas();
    final before = _frame(tester).expand;
    await tester.pump(const Duration(milliseconds: 120));
    expect(_frame(tester).expand, greaterThan(before));
    expect(identical(canvas(), built), isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets("every tier takes the primary of the device's brightness", (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    // Different backgrounds per brightness, so the two primaries differ.
    const dark = AppBackgroundStyle.dark4;
    const light = AppBackgroundStyle.light1;
    for (final (b, style) in [
      (Brightness.dark, dark),
      (Brightness.light, light),
    ]) {
      tester.platformDispatcher.platformBrightnessTestValue = b;
      for (final count in [0, 150, 450]) {
        await tester.pumpWidget(
          MaterialApp(
            home: BackgroundScope(
              dark: dark,
              light: light,
              child: Center(child: _preview(count: count, animate: false)),
            ),
          ),
        );
        expect(
          _frame(tester).look,
          BubbleLook.of(
            BubbleModel.tier(count),
            brand: brandFor(style, b).primary.toARGB32(),
          ),
          reason: '$b, $count reels',
        );
      }
    }
  });

  testWidgets('reduce motion schedules no frames', (tester) async {
    // Liquid loops on its own, so this also proves no loop ticker starts.
    Widget at(int count) => _app(
      _preview(count: count, variant: BubbleVariant.liquid, interactive: true),
      reduceMotion: true,
    );
    await tester.pumpWidget(at(99));
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(at(100)); // a tier up
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    final f = _frame(tester);
    // The pill is information: it swaps in, not slides.
    expect((f.tier, f.blend, f.pulse, f.pill), (2, 1.0, 0.0, 1.0));

    await tester.pump(const Duration(milliseconds: BubbleTokens.msPill));
    expect(tester.binding.transientCallbackCount, 0);
    expect(_frame(tester).pill, 0);
  });

  testWidgets('a fitted preview shrinks the bubble into a small area', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_preview(size: 80, area: 64)));
    expect(
      find.bySemanticsLabel(
        BubbleModel.collapsedLabel(
          152,
          4328,
          BubbleVariant.mascot,
          tapHint: false,
        ),
      ),
      findsOneWidget,
    );
    final f = _frame(tester);
    expect(f.s, 40 / 68); // min(80, 64 − 24) dp
    expect(f.body, const Rect.fromLTWH(12, 12, 40, 40)); // centred
    expect(tester.takeException(), isNull);
  });

  testWidgets('the stage opens its widest timer inside the area', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _preview(
          variant: BubbleVariant.ring,
          size: 80,
          area: 220,
          interactive: true,
        ),
      ),
    );
    await tester.tap(find.byType(BubblePreview));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final f = _frame(tester);
    expect(f.expand, 1);
    expect(f.s, 80 / 68); // the real size
    expect(f.body.right, 220 - 12);
    expect(f.body.left, greaterThanOrEqualTo(0));
    expect(
      find.descendant(
        of: find.byType(BubblePreview),
        matching: find.byType(ClipRect),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a short stage centres the bubble in its height', (tester) async {
    await tester.pumpWidget(
      _app(
        _preview(
          variant: BubbleVariant.ring,
          size: 80,
          area: 220,
          height: 168,
          interactive: true,
        ),
      ),
    );
    expect(tester.getSize(find.byType(BubblePreview)), const Size(220, 168));
    expect(_frame(tester).body.top, (168 - 80) / 2);
    await tester.tap(find.byType(BubblePreview));
    await tester.pumpAndSettle();
    expect(_frame(tester).body.left, greaterThanOrEqualTo(0));
  });

  testWidgets('the stage docks each face at its own edge gap', (tester) async {
    for (final (v, gap) in [
      (BubbleVariant.drop, 0.0),
      (BubbleVariant.ring, 12.0),
    ]) {
      for (final right in [true, false]) {
        await tester.pumpWidget(
          _app(
            _preview(
              key: ValueKey('$v $right'),
              variant: v,
              area: 220,
              interactive: true,
              animate: false,
              dockedRight: right,
            ),
          ),
        );
        final body = _frame(tester).body;
        expect(right ? 220 - body.right : body.left, gap, reason: '$v $right');
      }
    }
  });

  testWidgets('a burst across two tiers animates once and settles', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_preview(count: 99, interactive: true)));
    await tester.pumpWidget(_app(_preview(count: 200, interactive: true)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    final mid = _frame(tester);
    expect(mid.prevTier, 1);
    expect(mid.tier, 3);
    expect(mid.blend, inExclusiveRange(0, 1));
    expect(mid.pulse, greaterThan(0));
    expect(mid.pill, greaterThan(0));

    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    expect(
      find.bySemanticsLabel(
        BubbleModel.collapsedLabel(200, 4328, BubbleVariant.mascot),
      ),
      findsOneWidget,
    );
    expect(_frame(tester).pulse, 0);
  });

  testWidgets('a tier down only cross-fades', (tester) async {
    await tester.pumpWidget(_app(_preview(count: 250)));
    await tester.pumpWidget(_app(_preview(count: 0))); // midnight
    await tester.pump(const Duration(milliseconds: 200));
    final mid = _frame(tester);
    expect(mid.blend, inExclusiveRange(0, 1));
    expect((mid.pulse, mid.pill, mid.pop), (0.0, 0.0, 0.0));
    await tester.pumpAndSettle();
  });

  testWidgets('a card or thumbnail never shows the pill or the pulse', (
    tester,
  ) async {
    final key = GlobalKey<BubblePreviewState>();
    await tester.pumpWidget(_app(_preview(key: key, count: 99)));
    await tester.pumpWidget(_app(_preview(key: key, count: 100))); // tier up
    // Probe every frame until it settles: the colours still cross-fade.
    var blended = false;
    for (var i = 0; i == 0 || tester.binding.hasScheduledFrame; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final f = _frame(tester);
      expect((f.pill, f.pulse), (0.0, 0.0), reason: 'frame $i');
      blended |= f.blend < 1;
    }
    expect(blended, isTrue);

    // Its appear still plays, without the pill.
    key.currentState!.replayAppear();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    expect(_frame(tester).pill, 0);
    await tester.pumpAndSettle();
    expect(_frame(tester).pill, 0);
  });

  testWidgets('replayAppear settles', (tester) async {
    final key = GlobalKey<BubblePreviewState>();
    await tester.pumpWidget(_app(_preview(key: key, interactive: true)));

    key.currentState!.replayAppear();
    // Tickers start on the next frame; the pill holds 3 s, then folds.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_frame(tester).pill, greaterThan(0));
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: BubbleTokens.msPillOut));

    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
    expect(_frame(tester).pill, 0);
  });
}
