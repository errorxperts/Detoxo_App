import 'package:flutter/widgets.dart';

/// Motion durations. Pairs with flutter_animate's `.ms` ergonomics.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 180); // toggles
  static const Duration normal = Duration(milliseconds: 300); // entrance fades
  static const Duration medium = Duration(milliseconds: 400); // page / sheet
  static const Duration slow = Duration(milliseconds: 700); // shimmer / reveal
  static const Duration stagger = Duration(milliseconds: 80); // list interval

  // ── Frozen Glass (bundle.css transitions) ──────────────────────────────────
  /// Press: every pressable's scale (`.dx-press`).
  static const Duration press = Duration(milliseconds: 400);

  /// A selection chip sliding to its pick (mode card, segments, quick picks).
  static const Duration chip = Duration(milliseconds: 500);

  /// The tab-bar lens sliding to the current tab.
  static const Duration lens = Duration(milliseconds: 550);

  /// A detail row opening or closing (`.dx-detail`).
  static const Duration detail = Duration(milliseconds: 500);

  /// Any accent change cross-fading.
  static const Duration glide = Duration(milliseconds: 1000);

  /// A bottom sheet sliding in.
  static const Duration sheet = Duration(milliseconds: 450);

  /// A bottom sheet sliding out: exits run shorter than entries.
  static const Duration sheetOut = Duration(milliseconds: 300);

  /// The scrim behind a sheet fading in, leading the sheet's slide.
  static const Duration scrim = Duration(milliseconds: 300);
}

/// Motion curves: calm eases, plus the spec's short overshoots for presses
/// and sliding chips.
abstract final class AppCurves {
  static const Curve standard = Curves.easeOutCubic; // entrances
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve decelerate = Curves.easeOut;

  // ── Frozen Glass (bundle.css cubic-beziers) ────────────────────────────────
  /// Press: a short overshoot back to rest.
  static const Curve press = Cubic(0.34, 1.56, 0.64, 1);

  /// A chip slide.
  static const Curve chip = Cubic(0.34, 1.25, 0.64, 1);

  /// The tab-lens slide.
  static const Curve lens = Cubic(0.34, 1.3, 0.64, 1);

  /// Each keyframe segment of a squish.
  static const Curve squish = Cubic(0.3, 0.7, 0.3, 1);

  /// A detail row opening, and the ring arc moving.
  static const Curve detail = Cubic(0.2, 0.8, 0.2, 1);

  /// An accent cross-fade, and the sheet scrim's fade (CSS `ease`).
  static const Curve glide = Curves.ease;

  /// A bottom sheet's slide: an even ease-out, so the travel spreads over
  /// the whole slide instead of landing in its first frames.
  static const Curve sheet = Curves.easeOutCubic;
}

extension AppMotionX on BuildContext {
  /// [d], or zero when the person asked to remove animations.
  Duration motion(Duration d) =>
      (MediaQuery.maybeDisableAnimationsOf(this) ?? false) ? Duration.zero : d;
}
