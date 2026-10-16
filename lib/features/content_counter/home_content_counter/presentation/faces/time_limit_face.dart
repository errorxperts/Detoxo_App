import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_face_painter.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_tokens.g.dart';
import 'package:flutter/painting.dart';

/// 3 · Time limit: the time left of today's soonest reel limit (or the
/// overrun) above twelve segments; M and L add the reels chip
/// (Library.dc.html L192-240).
final class TimeLimitFace implements WidgetFace {
  const TimeLimitFace();

  @override
  void paint(FaceCanvas c, WidgetSize size, FaceFrame f) {
    final m = f.model;
    final look = tileLook(f.tier, dark: f.dark, brand: f.brand);
    final tile = c.tile(size, look);
    final band = FaceBand.of(size);
    final (font, left, top, segments, gap, radius, chipAt) = switch (size) {
      WidgetSize.small => (
        const FaceFont(40, spacing: -1.5),
        18.0,
        20.0,
        Rect.fromLTRB(18, 76, c.w - 18, 88),
        3.0,
        3.0,
        null,
      ),
      WidgetSize.medium => (
        const FaceFont(48, spacing: -1.8),
        30.0,
        20.0,
        Rect.fromLTRB(30, 82, c.w - 30, 94),
        4.0,
        4.0,
        const (right: 24.0, top: 26.0),
      ),
      WidgetSize.large => (
        const FaceFont(88, spacing: -3.5),
        30.0,
        40.0,
        Rect.fromLTRB(30, 158, c.w - 30, 222),
        5.0,
        8.0,
        const (right: 30.0, top: 40.0),
      ),
    };
    final chip = chipAt == null
        ? null
        : c.chip(
            m.reelsChip,
            x: c.w - chipAt.right,
            top: chipAt.top,
            align: TextAlign.right,
            fill: look.band,
            ink: look.muted,
          );
    c
      ..hero(
        m.leftBig,
        font,
        look.count,
        left: left,
        top: top,
        end: chip == null ? c.w - band.pad : chip.left - WidgetTokens.bandGap,
      )
      ..segments(
        segments,
        gap: gap,
        radius: radius,
        on: f.segments,
        fill: look.fill,
        faint: look.faint,
      )
      // With no limit the hero already shows the time watched, so the band
      // keeps only its label.
      ..band(
        tile,
        band,
        label: m.note ?? m.limitLabel,
        value: m.hasLimit ? m.time : '',
        clock: size != WidgetSize.small,
        fill: look.band,
        labelInk: look.muted,
        valueInk: look.ink,
      );
  }
}
