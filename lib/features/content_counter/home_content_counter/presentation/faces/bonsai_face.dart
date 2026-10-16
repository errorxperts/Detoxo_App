import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_face_painter.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_tokens.g.dart';
import 'package:flutter/painting.dart';

/// 5 · Bonsai: a tree on a neutral tile that loses a stage every 100 reels;
/// S names the stage in the band, M details it in a panel with a health bar,
/// L adds the reels chip (Library.dc.html L292-410).
final class BonsaiFace implements WidgetFace {
  const BonsaiFace();

  @override
  void paint(FaceCanvas c, WidgetSize size, FaceFrame f) {
    final m = f.model;
    final look = bonsaiLook(f.tier, dark: f.dark, brand: f.brand);
    final tile = c.shape(size);
    c.surface(tile, look.bg, look.hairline);
    // The tree's box: S 112 at top 2 and L 236 at top 10, centred across;
    // M 148 at (8, 4).
    final tree = switch (size) {
      WidgetSize.small => Rect.fromLTWH((c.w - 112) / 2, 2, 112, 112),
      WidgetSize.medium => const Rect.fromLTWH(8, 4, 148, 148),
      WidgetSize.large => Rect.fromLTWH((c.w - 236) / 2, 10, 236, 236),
    };
    if (size == WidgetSize.large) {
      c.chip(m.reelsChip, x: 30, top: 30, fill: look.band, ink: look.muted);
    }
    c.bonsai(tree, f.tier, look, sway: f.sway, leaf: f.leaf);
    switch (size) {
      case WidgetSize.small:
        c.band(
          tile,
          FaceBand.small,
          label: m.note ?? m.bonsaiStage,
          value: m.countText,
          clock: false,
          fill: look.band,
          labelInk: look.muted,
          valueInk: look.ink,
        );
      case WidgetSize.medium:
        final panel = c.panel(
          Rect.fromLTRB(160, 18, c.w - 18, c.h - 18),
          look.band,
        );
        final [label, reels, health, time] = c.column(panel, const [
          WidgetTokens.lineLabelS,
          WidgetTokens.lineValueL,
          _healthHeight,
          WidgetTokens.lineValueS,
        ]);
        final bar = Rect.fromLTWH(
          panel.left,
          health - _healthHeight / 2,
          panel.width,
          _healthHeight,
        );
        c
          ..text(
            m.note ?? m.stageHealth,
            FaceFonts.lblS,
            look.muted,
            x: panel.left,
            cy: label,
            maxWidth: panel.width,
          )
          ..text(
            m.reelsChip,
            FaceFonts.val,
            look.ink,
            x: panel.left,
            cy: reels,
            maxWidth: panel.width,
          )
          ..surface(_rounded(bar), look.track)
          ..surface(
            _rounded(
              Rect.fromLTWH(
                bar.left,
                bar.top,
                bar.width * f.health / 100,
                bar.height,
              ),
            ),
            look.bar,
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
          label: m.note ?? m.stageHealth,
          value: m.time,
          clock: true,
          fill: look.band,
          labelInk: look.muted,
          valueInk: look.ink,
        );
    }
  }

  /// The M panel's health bar: 6 high, fully rounded.
  static const _healthHeight = 6.0;

  static RRect _rounded(Rect r) =>
      RRect.fromRectAndRadius(r, const Radius.circular(_healthHeight / 2));
}
