import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_face_painter.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_tokens.g.dart';
import 'package:flutter/painting.dart';

/// 1 · Count: today's count on the tier tile, the time in the band; M and L
/// add the tier chip (Library.dc.html L100-139).
final class CountFace implements WidgetFace {
  const CountFace();

  @override
  void paint(FaceCanvas c, WidgetSize size, FaceFrame f) {
    final m = f.model;
    final look = tileLook(f.tier, dark: f.dark, brand: f.brand);
    final tile = c.tile(size, look);
    final band = FaceBand.of(size);
    final (font, left, top, chipAt) = switch (size) {
      WidgetSize.small => (
        const FaceFont(WidgetTokens.countS, spacing: -2.5),
        18.0,
        20.0,
        null,
      ),
      WidgetSize.medium => (
        const FaceFont(WidgetTokens.countM, spacing: -3),
        30.0,
        22.0,
        const (right: 24.0, top: 26.0),
      ),
      WidgetSize.large => (
        const FaceFont(WidgetTokens.countL, spacing: -5),
        30.0,
        40.0,
        const (right: 30.0, top: 40.0),
      ),
    };
    final chip = chipAt == null
        ? null
        : c.chip(
            m.tierChip,
            x: c.w - chipAt.right,
            top: chipAt.top,
            align: TextAlign.right,
            fill: look.band,
            ink: look.muted,
          );
    c
      ..hero(
        m.countText,
        font,
        look.count,
        left: left,
        top: top,
        end: chip == null ? c.w - band.pad : chip.left - WidgetTokens.bandGap,
      )
      ..band(
        tile,
        band,
        label:
            m.note ?? (size == WidgetSize.small ? m.todayShort : m.todayLong),
        value: m.time,
        clock: true,
        fill: look.band,
        labelInk: look.muted,
        valueInk: look.ink,
      );
  }
}
