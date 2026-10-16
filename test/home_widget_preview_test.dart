import 'dart:ui' as ui;

import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/faces/plan_face.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_face_painter.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_geometry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The in-app home-widget preview (D2): every face draws every state in both
/// palettes, it never keeps a ticker alive when it must stay still, and its
/// painter repaints only on a visible change.
void main() {
  final now = DateTime.now().millisecondsSinceEpoch;
  final hours = WidgetPayload.demo(
    limitMinutes: 120,
    theme: 'system',
    reduceMotion: false,
    nowMs: now,
  ).hourlySeconds;

  /// The six DS-08 states, in [theme].
  List<WidgetPayload> states(String theme) {
    WidgetPayload p({
      int count = 152,
      int tier = 2,
      int watch = 4256,
      int limit = 120,
      int? updatedAt,
      bool tracking = true,
    }) => WidgetPayload(
      reelCount: count,
      watchSeconds: watch,
      reelTier: tier,
      hourlySeconds: hours,
      limitMinutes: limit,
      theme: theme,
      updatedAt: updatedAt ?? now,
      trackingEnabled: tracking,
    );
    return [
      WidgetPayload(theme: theme), // empty
      p(), // normal
      p(count: 1240, tier: 5, watch: 30000), // final, capped at 999+
      p(limit: 30), // over the limit
      p(updatedAt: now - const Duration(minutes: 61).inMilliseconds), // stale
      p(tracking: false), // tracking off
    ];
  }

  Widget host(Widget child, {bool disableAnimations = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );

  testWidgets('every family, size, palette and state draws cleanly', (
    tester,
  ) async {
    final payloads = [...states('light'), ...states('dark')];
    for (final family in WidgetFamily.values) {
      for (final size in WidgetSize.values) {
        // One State per face: the payloads then follow each other through
        // it, so every change also paints mid-way (ease + cross-fade).
        for (final payload in payloads) {
          await tester.pumpWidget(
            host(
              WidgetPreview(
                key: ValueKey((family, size)),
                family: family,
                size: size,
                payload: payload,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            tester.takeException(),
            isNull,
            reason: '${family.wire} ${size.wire} $payload',
          );
        }
      }
    }
    // Lets the last change settle before the tree goes.
    await tester.pump(const Duration(seconds: 1));
  });

  group('still previews keep no ticker', () {
    final moving = WidgetPayload.demo(
      limitMinutes: 120,
      theme: 'light',
      reduceMotion: false,
      nowMs: now,
    );
    final still = WidgetPayload.demo(
      limitMinutes: 120,
      theme: 'light',
      reduceMotion: true,
      nowMs: now,
    );

    Widget bonsai(WidgetPayload payload, {bool animate = true}) =>
        WidgetPreview(
          family: WidgetFamily.bonsai,
          size: WidgetSize.small,
          payload: payload,
          animate: animate,
        );

    testWidgets('a moving bonsai does tick (the control)', (tester) async {
      await tester.pumpWidget(host(bonsai(moving)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets("the payload's reduce motion", (tester) async {
      await tester.pumpWidget(host(bonsai(still)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
      // A change eases nothing either.
      await tester.pumpWidget(
        host(
          bonsai(
            WidgetPayload(
              reelCount: 420,
              reelTier: 5,
              theme: 'dark',
              reduceMotion: true,
              updatedAt: now,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets("the OS's remove animations", (tester) async {
      await tester.pumpWidget(host(bonsai(moving), disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a thumbnail (animate: false)', (tester) async {
      await tester.pumpWidget(host(bonsai(moving, animate: false)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  testWidgets('the painter repaints only on a visible change', (tester) async {
    CustomPainter painter() => tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(WidgetPreview),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter!;
    Future<CustomPainter> show(WidgetSize size, WidgetPayload payload) async {
      await tester.pumpWidget(
        host(
          WidgetPreview(
            family: WidgetFamily.count,
            size: size,
            payload: payload,
            animate: false,
          ),
        ),
      );
      return painter();
    }

    final base = states('light')[1];
    final first = await show(WidgetSize.small, base);
    expect(find.bySemanticsLabel(RegExp('^Count, Small preview: ')), findsOne);

    // An equal payload (a fresh instance) is not a change.
    final same = await show(WidgetSize.small, states('light')[1]);
    expect(identical(states('light')[1], base), isFalse);
    expect(same.shouldRepaint(first), isFalse);

    final recount = await show(WidgetSize.small, states('light')[2]);
    expect(recount.shouldRepaint(same), isTrue);

    final resized = await show(WidgetSize.large, states('light')[2]);
    expect(resized.shouldRepaint(recount), isTrue);
  });

  testWidgets("Bento Large's next-colour texts end where Kotlin's do", (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        WidgetPreview(
          family: WidgetFamily.bento,
          size: WidgetSize.large,
          payload: states('light')[1],
          animate: false,
        ),
      ),
    );
    // Each text is translate(left, cy), scale(fit), paragraph. The test
    // font's glyphs are an em wide, so both overflow and shrink to the cap.
    var left = 0.0;
    var fit = 1.0;
    final ends = <double>[];
    expect(
      tester.renderObject(
        find.descendant(
          of: find.byType(WidgetPreview),
          matching: find.byType(CustomPaint),
        ),
      ),
      paints..everything((method, args) {
        if (method == #translate) left = args[0] as double;
        if (method == #scale) fit = args[0] as double;
        // The next module's texts start at its left (174) + 18.
        if (method == #drawParagraph && left == 192) {
          ends.add(left + (args[0] as ui.Paragraph).maxIntrinsicWidth * fit);
        }
        return true;
      }),
    );
    // BentoFace.kt: the label's cap is mw - 80 - ROW_GAP (ends 8 short of
    // the ring's box at 268), the value's is mw - 42 (24 from the edge).
    expect(ends, [closeTo(260, 0.5), closeTo(306, 0.5)]);
  });

  testWidgets('the Plan face draws every plan state, size and palette', (
    tester,
  ) async {
    final plans = [
      PlanState.demo,
      const PlanState(plan: BlockingPlan.curious),
      const PlanState(plan: BlockingPlan.oneReel),
      const PlanState(
        plan: BlockingPlan.oneReel,
        reelAllowance: 5,
        reelsConsumed: 2,
      ),
      const PlanState(
        plan: BlockingPlan.oneReel,
        reelAllowance: 5,
        reelsConsumed: 5,
      ),
      PlanState(pauseUntil: now + const Duration(minutes: 4).inMilliseconds),
      const PlanState(blockingOn: false),
      const PlanState(serviceOn: false),
    ];
    for (final plan in plans) {
      final m = WidgetModel(
        WidgetPayload.empty,
        nowMs: now,
        zoneOffsetMin: 0,
        use24h: false,
        plan: plan,
      );
      for (final size in WidgetSize.values) {
        for (final dark in [false, true]) {
          final recorder = ui.PictureRecorder();
          const PlanFace().paint(
            FaceCanvas(Canvas(recorder), size.box, FaceTextCache()),
            size,
            FaceFrame(
              model: m,
              tier: 0,
              dark: dark,
              brand: 0xFF8B93FF,
              ring: 0,
              segments: 0,
              bars: m.bars,
              health: 0,
            ),
          );
          recorder.endRecording().dispose();
        }
      }
    }
    expect(tester.takeException(), isNull);
  });
}
