import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_face_painter.dart';
import 'package:flutter/painting.dart';

/// 7 · Plan (EVO-073): whether blocking is on and which plan runs, on
/// Bento's neutral shell — no tier, no accent colour (DS-02). The ring is
/// protection in force: full for Block All and Conscious, filling as a One
/// Reel / Unblock allowance is spent, empty while paused or off. Kotlin
/// `PlanFace` draws the same.
final class PlanFace implements WidgetFace {
  const PlanFace();

  @override
  void paint(FaceCanvas c, WidgetSize size, FaceFrame f) {
    final m = f.model;
    final look = bentoLook(0, dark: f.dark, brand: f.brand);
    final tile = c.shape(size);
    final band = FaceBand.of(size);
    final pct = m.planRingPct.toDouble();
    c.surface(tile, look.shell, look.hairline);
    switch (size) {
      case WidgetSize.small:
        // Bottom-right, 8 clear of the band.
        c
          ..hero(
            m.planTitle,
            const FaceFont(30, spacing: -1),
            look.ink,
            left: 18,
            top: 20,
            end: c.w - 18,
          )
          ..ring(
            Offset(c.w - 39.5, c.h - band.height - 29.5),
            18,
            7,
            pct,
            track: look.faint,
            fill: look.ink,
          );
      case WidgetSize.medium:
        // The ring's outer edge at right 30, centred above the band.
        c
          ..ring(
            Offset(c.w - 58.5, (c.h - band.height) / 2),
            24,
            9,
            pct,
            track: look.faint,
            fill: look.ink,
          )
          ..hero(
            m.planTitle,
            const FaceFont(48, spacing: -1.8),
            look.ink,
            left: 30,
            top: 20,
            end: c.w - 95,
          );
      case WidgetSize.large:
        // Centred between the title's line box (40..104) and the band.
        final centre = Offset(c.w / 2, (104 + c.h - band.height) / 2);
        c
          ..hero(
            m.planTitle,
            const FaceFont(64, spacing: -2.5),
            look.ink,
            left: 30,
            top: 40,
            end: c.w - 30,
          )
          ..ring(centre, 52, 14, pct, track: look.faint, fill: look.ink)
          ..text(
            m.planRingText,
            const FaceFont(30, spacing: -1),
            look.ink,
            x: centre.dx,
            cy: centre.dy,
            align: TextAlign.center,
            maxWidth: 2 * 52 - 14,
          );
    }
    final small = size == WidgetSize.small;
    c.band(
      tile,
      band,
      label: small ? m.planLabelShort : m.planLabelLong,
      value: small ? m.planValueShort : m.planValueLong,
      clock: m.planClock && !small,
      fill: look.module,
      labelInk: look.muted,
      valueInk: look.ink,
    );
  }
}
