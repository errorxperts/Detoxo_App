import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_face_painter.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_tokens.g.dart';
import 'package:flutter/painting.dart';

/// 6 · Bento: a neutral shell of modules where only the count module carries
/// the tier; the time module (S bottom, M right, L bottom-left) is where a
/// stale or tracking-off note goes (Library.dc.html L412-469).
final class BentoFace implements WidgetFace {
  const BentoFace();

  static const _r16 = Radius.circular(16);
  static const _r28 = Radius.circular(28);
  static const _r66 = Radius.circular(66);
  static const _timeSpent = 'Time spent';

  @override
  void paint(FaceCanvas c, WidgetSize size, FaceFrame f) {
    final tier = tileLook(f.tier, dark: f.dark, brand: f.brand);
    final look = bentoLook(f.tier, dark: f.dark, brand: f.brand);
    c.surface(c.shape(size), look.shell, look.hairline);
    switch (size) {
      case WidgetSize.small:
        _small(c, f, tier, look);
      case WidgetSize.medium:
        _medium(c, f, tier, look);
      case WidgetSize.large:
        _large(c, f, tier, look);
    }
  }

  /// The count module over a bottom `label | time` module.
  void _small(FaceCanvas c, FaceFrame f, TileLook tier, BentoLook look) {
    final m = f.model;
    final count = RRect.fromLTRBR(8, 8, c.w - 8, 104, _r28);
    final time = Rect.fromLTRB(8, c.h - 48, c.w - 8, c.h - 8);
    c
      ..tierFill(count, tier)
      ..text(
        m.countText,
        const FaceFont(52, spacing: -2),
        tier.count,
        x: count.left + 14,
        cy: count.bottom - 12 - 26,
        maxWidth: count.width - 28,
      )
      ..surface(RRect.fromRectAndRadius(time, _r16), look.module)
      ..row(
        time,
        12,
        FaceBand.small,
        label: m.note ?? m.todayShort,
        value: m.time,
        labelInk: look.muted,
        valueInk: look.ink,
      );
  }

  /// The count module (tier chip, count) beside the time module: `Time
  /// spent`, the time, then the next colour after a tier dot.
  void _medium(FaceCanvas c, FaceFrame f, TileLook tier, BentoLook look) {
    final m = f.model;
    final count = RRect.fromLTRBR(8, 8, 194, c.h - 8, _r28);
    final module = Rect.fromLTRB(202, 8, c.w - 8, c.h - 8);
    final box = module.deflate(16);
    final [label, time, next] = c.column(box, const [
      WidgetTokens.lineLabelS,
      28,
      WidgetTokens.lineLabelS,
    ], spread: true);
    c
      ..tierFill(count, tier)
      ..chip(
        m.tierChip,
        x: count.left + 14,
        top: count.top + 14,
        fill: tier.band,
        ink: tier.muted,
      )
      ..text(
        m.countText,
        const FaceFont(WidgetTokens.countM, spacing: -3),
        tier.count,
        x: count.left + 16,
        cy: count.bottom - 14 - 36,
        maxWidth: count.width - 32,
      )
      ..surface(RRect.fromRectAndRadius(module, _r28), look.module)
      ..text(
        m.note ?? _timeSpent,
        FaceFonts.lblS,
        look.muted,
        x: box.left,
        cy: label,
        maxWidth: box.width,
      )
      ..text(
        m.time,
        const FaceFont(28, weight: FontWeight.w800, spacing: -0.6),
        look.ink,
        x: box.left,
        cy: time,
        maxWidth: box.width,
      )
      ..text(
        m.nextShort,
        FaceFonts.lblS,
        look.muted,
        x: box.left + 8 + 6,
        cy: next,
        maxWidth: box.width - 8 - 6,
      );
    c.canvas.drawCircle(
      Offset(box.left + 4, next),
      4,
      Paint()..color = look.dot,
    );
  }

  /// The wide count module (tier chip, count) over the time module and the
  /// next-colour module with its mini ring.
  void _large(FaceCanvas c, FaceFrame f, TileLook tier, BentoLook look) {
    final m = f.model;
    final count = RRect.fromLTRBAndCorners(
      10,
      10,
      c.w - 10,
      202,
      topLeft: _r66,
      topRight: _r66,
      bottomRight: _r28,
      bottomLeft: _r28,
    );
    final time = Rect.fromLTRB(10, 210, 166, c.h - 10);
    final timeBox = const EdgeInsets.fromLTRB(24, 18, 18, 18).deflateRect(time);
    final [timeLabel, timeValue] = c.column(timeBox, const [
      WidgetTokens.lineLabelS,
      WidgetTokens.lineValueL,
    ], spread: true);
    final next = Rect.fromLTRB(c.w - 166, 210, c.w - 10, c.h - 10);
    final ring = Offset(next.right - 18 - 22, next.top + 12 + 22);
    c
      ..tierFill(count, tier)
      ..chip(
        m.tierChip,
        x: count.right - 28,
        top: count.top + 30,
        align: TextAlign.right,
        fill: tier.band,
        ink: tier.muted,
      )
      ..text(
        m.countText,
        const FaceFont(WidgetTokens.countL, spacing: -5),
        tier.count,
        x: count.left + 28,
        cy: count.bottom - 22 - 56,
        maxWidth: count.width - 56,
      )
      ..surface(
        RRect.fromRectAndCorners(
          time,
          topLeft: _r28,
          topRight: _r28,
          bottomRight: _r28,
          bottomLeft: _r66,
        ),
        look.module,
      )
      ..text(
        m.note ?? _timeSpent,
        FaceFonts.lblS,
        look.muted,
        x: timeBox.left,
        cy: timeLabel,
        maxWidth: timeBox.width,
      )
      ..text(
        m.time,
        FaceFonts.val,
        look.ink,
        x: timeBox.left,
        cy: timeValue,
        maxWidth: timeBox.width,
      )
      ..surface(
        RRect.fromRectAndCorners(
          next,
          topLeft: _r28,
          topRight: _r28,
          bottomRight: _r66,
          bottomLeft: _r28,
        ),
        look.module,
      )
      ..ring(ring, 17, 6, f.ring, track: look.faint, fill: look.dot)
      // The label stops a row gap short of the ring's 44-unit box; the value
      // keeps 18 / 24 like the time module (Kotlin's `room`).
      ..text(
        m.bentoNextLabel,
        FaceFonts.lblS,
        look.muted,
        x: next.left + 18,
        cy: next.top + 18 + WidgetTokens.lineLabelS / 2,
        maxWidth: ring.dx - 22 - WidgetTokens.bandGap - (next.left + 18),
      )
      ..text(
        m.bentoNextValue,
        FaceFonts.val,
        look.ink,
        x: next.left + 18,
        cy: next.bottom - 18 - WidgetTokens.lineValueL / 2,
        maxWidth: next.width - 18 - 24,
      );
  }
}
