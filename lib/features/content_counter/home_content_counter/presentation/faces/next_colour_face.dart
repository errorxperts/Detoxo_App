import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_face_painter.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_tokens.g.dart';
import 'package:flutter/painting.dart';

/// 2 · Next colour: the ring fills over each block of 100 reels around the
/// count; S says how far to go in a chip, M in a panel, L in the band
/// (Library.dc.html L141-190).
final class NextColourFace implements WidgetFace {
  const NextColourFace();

  @override
  void paint(FaceCanvas c, WidgetSize size, FaceFrame f) {
    final m = f.model;
    final look = tileLook(f.tier, dark: f.dark, brand: f.brand);
    final tile = c.tile(size, look);
    // The ring's box: S 104 at top 12 and M 124 at (18, 18) left, L 200 at
    // top 26; S and L centred across.
    final (centre, radius, stroke, font) = switch (size) {
      WidgetSize.small => (
        Offset(c.w / 2, 12 + 52),
        44.0,
        10.0,
        const FaceFont(30, spacing: -1),
      ),
      WidgetSize.medium => (
        Offset(18 + 62, c.h / 2),
        52.0,
        12.0,
        const FaceFont(36, spacing: -1.2),
      ),
      WidgetSize.large => (
        Offset(c.w / 2, 26 + 100),
        86.0,
        18.0,
        const FaceFont(64, spacing: -2.5),
      ),
    };
    c
      ..ring(centre, radius, stroke, f.ring, track: look.faint, fill: look.fill)
      ..text(
        m.countText,
        font,
        look.count,
        x: centre.dx,
        cy: centre.dy,
        align: TextAlign.center,
        maxWidth: 2 * radius - stroke,
      );
    switch (size) {
      case WidgetSize.small:
        c.chip(
          m.note ?? m.nextShort,
          x: c.w / 2,
          top: c.h - 36,
          align: TextAlign.center,
          fill: look.band,
          ink: look.muted,
        );
      case WidgetSize.medium:
        final panel = c.panel(
          Rect.fromLTRB(160, 18, c.w - 18, c.h - 18),
          look.band,
        );
        final [label, value, time] = c.column(panel, const [
          WidgetTokens.lineLabelS,
          WidgetTokens.lineValueL,
          WidgetTokens.lineValueS,
        ]);
        c
          ..text(
            m.note ?? m.nextLabel,
            FaceFonts.lblS,
            look.muted,
            x: panel.left,
            cy: label,
            maxWidth: panel.width,
          )
          ..text(
            m.nextValue,
            FaceFonts.val,
            look.ink,
            x: panel.left,
            cy: value,
            maxWidth: panel.width,
          )
          ..text(
            m.time,
            FaceFonts.valS,
            look.ink,
            x: panel.left,
            cy: time,
            maxWidth: panel.width,
            clock: clockS,
          );
      case WidgetSize.large:
        c.band(
          tile,
          FaceBand.large,
          label: m.note ?? m.nextLong,
          value: m.time,
          clock: true,
          fill: look.band,
          labelInk: look.muted,
          valueInk: look.ink,
        );
    }
  }
}
