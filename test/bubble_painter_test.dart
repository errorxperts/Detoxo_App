import 'dart:ui';

import 'package:detoxo/features/content_counter/content_counter_bubble/domain/bubble_model.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_brush.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_face.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_frame.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_look.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_painter.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_tokens.g.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/brand_tint.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_tokens.g.dart';
import 'package:flutter_test/flutter_test.dart';

const _canvas = Size(200, 160);

/// A frame at size `68·s` on a 200×160 canvas: the collapsed square sits at
/// the docked side, and the body widens inward to the timer width with
/// [expand].
BubbleFrame frameFor(
  BubbleVariant v, {
  int count = 152,
  int seconds = 4328,
  double expand = 0,
  double pill = 0,
  double pulse = 0,
  double loopT = 0,
  bool dockedRight = true,
  int tier = 2,
  int prevTier = 2,
  double blend = 1,
  double s = 1,
  double pop = 0,
}) {
  final size = BubbleTokens.size * s;
  final w = lerpDouble(size, BubbleModel.timerWidth(seconds, v) * s, expand)!;
  final top = (_canvas.height - size) / 2;
  final body = dockedRight
      ? Rect.fromLTWH(_canvas.width - w, top, w, size)
      : Rect.fromLTWH(0, top, w, size);
  return BubbleFrame(
    body: body,
    s: s,
    look: BubbleLook.lerp(BubbleLook.of(prevTier), BubbleLook.of(tier), blend),
    tier: tier,
    prevTier: prevTier,
    blend: blend,
    count: count,
    pct: BubbleModel.pct(count),
    countText: BubbleModel.countText(count),
    clock: BubbleModel.clock(seconds),
    shortTime: BubbleModel.shortTime(seconds),
    expand: expand,
    pop: pop,
    pulse: pulse,
    pill: pill,
    loopT: loopT,
    open: expand > 0,
    dockedRight: dockedRight,
  );
}

/// Records which face passes the painter runs.
final class _SpyFace extends BubbleFace {
  _SpyFace();

  final calls = <String>[];

  @override
  void drawBackground(BubbleFrame f, BubbleBrush b) {
    calls.add('background');
    super.drawBackground(f, b);
  }

  @override
  void drawDial(BubbleFrame f, BubbleBrush b) => calls.add('dial');

  @override
  void drawOverlay(BubbleFrame f, BubbleBrush b) => calls.add('overlay');
}

List<String> _passes({BubbleFrame? frame, int? remaining}) {
  final face = _SpyFace();
  final recorder = PictureRecorder();
  BubblePainter(
    frame: frame ?? frameFor(BubbleVariant.mascot),
    face: face,
    opacity: 1,
    remaining: remaining,
  ).paint(Canvas(recorder), _canvas);
  recorder.endRecording().dispose();
  return face.calls;
}

List<Color> _fields(BubbleLook l) => [
  l.fillFrom,
  l.fillTo,
  l.ring,
  l.ink,
  l.faint,
  l.mark,
  l.halo,
  l.shadow,
];

/// Tier [t]'s gradient end in the fallback brand's ramp.
Color _to(int t) =>
    Color(BrandTint.ramp(BrandTint.fallback, BrandTint.tileTo[t - 1]));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BubbleLook', () {
    test('tier 0 is the navy glass ink until the theme is pushed', () {
      expect(BubbleLook.of(0).ink, const Color(BrandTint.fallback));
    });
    test('tiers 1..3 use the dark widget ink', () {
      expect(BubbleLook.of(3).ink, WidgetTokens.widgetInk);
    });
    test('tiers 4..5 use the inverse widget ink', () {
      expect(BubbleLook.of(4).ink, WidgetTokens.widgetInkInverse);
    });
    test('the ring is the tier gradient end', () {
      expect(BubbleLook.of(2).ring, _to(2));
    });
    test('lerp at 1 is the target look, field by field', () {
      expect(
        _fields(BubbleLook.lerp(BubbleLook.of(1), BubbleLook.of(2), 1)),
        _fields(BubbleLook.of(2)),
      );
    });
    test('lerp halfway blends each colour', () {
      expect(
        BubbleLook.lerp(BubbleLook.of(1), BubbleLook.of(2), 0.5).fillTo,
        Color.lerp(_to(1), _to(2), 0.5),
      );
    });
  });

  group('paints every variant in every state', () {
    final states = <String, (BubbleFrame Function(BubbleVariant), int?)>{
      'collapsed': (frameFor, null),
      'open': ((v) => frameFor(v, expand: 1), null),
      'pill': ((v) => frameFor(v, pill: 1), null),
      'pulse': ((v) => frameFor(v, pulse: 0.5), null),
      'loop': ((v) => frameFor(v, loopT: 0.3), null),
      'loop open': ((v) => frameFor(v, loopT: 0.3, expand: 1), null),
      'docked left': ((v) => frameFor(v, dockedRight: false), null),
      'docked left open': (
        (v) => frameFor(v, dockedRight: false, expand: 1),
        null,
      ),
      'size 136 open with pill and pulse': (
        (v) => frameFor(v, s: 2, expand: 1, pill: 1, pulse: 0.5),
        null,
      ),
      'size 136 collapsed with pill': ((v) => frameFor(v, s: 2, pill: 1), null),
      'pop peak': ((v) => frameFor(v, pop: 0.4), null),
      'remaining': (frameFor, 3),
      'tier 0 glass': (
        (v) => frameFor(v, count: 0, seconds: 0, tier: 0, prevTier: 0),
        null,
      ),
      'tier 5 blending from 4': (
        (v) => frameFor(v, count: 452, tier: 5, prevTier: 4, blend: 0.5),
        null,
      ),
    };
    for (final v in BubbleVariant.values) {
      for (final MapEntry(key: name, value: (build, remaining))
          in states.entries) {
        test('${v.label} · $name', () {
          final recorder = PictureRecorder();
          final canvas = Canvas(recorder);
          final painter = BubblePainter(
            frame: build(v),
            face: v.face,
            opacity: 0.8,
            remaining: remaining,
          );
          expect(() => painter.paint(canvas, _canvas), returnsNormally);
          recorder.endRecording().dispose();
        });
      }
    }
  });

  group('reels left', () {
    test('a face draws background, dial and overlay', () {
      expect(_passes(), ['background', 'dial', 'overlay']);
    });
    test('keeps the background but skips the dial and overlay', () {
      expect(_passes(remaining: 3), ['background']);
    });
    test('every face paints it open', () {
      for (final v in BubbleVariant.values) {
        final recorder = PictureRecorder();
        expect(
          () => BubblePainter(
            frame: frameFor(v, expand: 1),
            face: v.face,
            opacity: 1,
            remaining: 3,
          ).paint(Canvas(recorder), _canvas),
          returnsNormally,
          reason: v.name,
        );
        recorder.endRecording().dispose();
      }
    });
  });

  group('pill', () {
    test('shows while collapsed', () {
      expect(
        BubblePainter.showsPill(frameFor(BubbleVariant.mascot, pill: 1)),
        isTrue,
      );
      expect(BubblePainter.showsPill(frameFor(BubbleVariant.mascot)), isFalse);
    });
    test('is not drawn while the timer is open', () {
      expect(
        BubblePainter.showsPill(
          frameFor(BubbleVariant.mascot, expand: 1, pill: 1),
        ),
        isFalse,
      );
    });
  });

  group('face hooks', () {
    test('only Hourglass drops a timer grain', () {
      expect(BubbleVariant.values.where((v) => v.face.timerGrain), [
        BubbleVariant.hourglass,
      ]);
    });
    test('only Drop breathes', () {
      expect(BubbleVariant.drop.face.breathScale(0.5), closeTo(1.06, 1e-9));
      for (final v in BubbleVariant.values.where(
        (v) => v != BubbleVariant.drop,
      )) {
        expect(v.face.breathScale(0.5), 1, reason: v.name);
      }
    });
    test('Drop points its docked side into the edge', () {
      expect(BubbleVariant.drop.face.radiusEdge, 10);
      expect(BubbleVariant.drop.face.edge, 0);
    });
    test('only Hourglass glows its text', () {
      expect(BubbleVariant.values.where((v) => v.face.countGlow > 0), [
        BubbleVariant.hourglass,
      ]);
      expect(BubbleVariant.hourglass.face.countGlow, 8);
    });
  });

  group('shouldRepaint', () {
    BubblePainter painter(BubbleFrame f) =>
        BubblePainter(frame: f, face: BubbleVariant.ring.face, opacity: 1);

    test('is false for an equal frame', () {
      expect(
        painter(
          frameFor(BubbleVariant.ring),
        ).shouldRepaint(painter(frameFor(BubbleVariant.ring))),
        isFalse,
      );
    });
    test('is true when the frame differs', () {
      expect(
        painter(
          frameFor(BubbleVariant.ring, count: 153),
        ).shouldRepaint(painter(frameFor(BubbleVariant.ring))),
        isTrue,
      );
    });
  });
}
