import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_face_painter.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_tokens.g.dart';
import 'package:flutter/painting.dart';

/// 4 · Rhythm: today's time over 24 hourly bars with the peak hour lit; the
/// band names the peak. M and L add the reels chip (Library.dc.html
/// L242-290).
final class RhythmFace implements WidgetFace {
  const RhythmFace();

  @override
  void paint(FaceCanvas c, WidgetSize size, FaceFrame f) {
    final m = f.model;
    final look = tileLook(f.tier, dark: f.dark, brand: f.brand);
    final tile = c.tile(size, look);
    final band = FaceBand.of(size);
    final (font, left, top, bars, gap, radius) = switch (size) {
      WidgetSize.small => (
        const FaceFont(30, spacing: -1),
        18.0,
        20.0,
        Rect.fromLTRB(18, 60, c.w - 18, 100),
        1.5,
        2.0,
      ),
      WidgetSize.medium => (
        const FaceFont(34, spacing: -1.2),
        30.0,
        24.0,
        Rect.fromLTRB(172, 24, c.w - 30, 92),
        2.0,
        2.0,
      ),
      WidgetSize.large => (
        const FaceFont(64, spacing: -2.5),
        30.0,
        40.0,
        Rect.fromLTRB(30, 128, c.w - 30, 228),
        4.0,
        3.0,
      ),
    };
    // M sets the reels chip under the time, L top-right.
    final chip = switch (size) {
      WidgetSize.small => null,
      WidgetSize.medium => c.chip(
        m.reelsChip,
        x: 30,
        top: 66,
        fill: look.band,
        ink: look.muted,
      ),
      WidgetSize.large => c.chip(
        m.reelsChip,
        x: c.w - 30,
        top: 46,
        align: TextAlign.right,
        fill: look.band,
        ink: look.muted,
      ),
    };
    // The time ends short of whatever sits to its right: the inset on S, the
    // bars on M, the chip on L.
    final end = switch (size) {
      WidgetSize.small => c.w - band.pad,
      WidgetSize.medium => bars.left - WidgetTokens.bandGap,
      WidgetSize.large => chip!.left - WidgetTokens.bandGap,
    };
    c
      ..hero(m.time, font, look.count, left: left, top: top, end: end)
      ..bars(
        bars,
        gap: gap,
        radius: radius,
        values: f.bars,
        peak: m.peakHour,
        fill: look.fill,
        faint: look.faint,
      )
      ..band(
        tile,
        band,
        label: m.note ?? m.peakLabel,
        value: m.peakValue,
        clock: false,
        fill: look.band,
        labelInk: look.muted,
        valueInk: look.ink,
      );
  }
}
