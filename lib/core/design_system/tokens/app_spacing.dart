import 'package:flutter/widgets.dart';

/// 4-based spacing scale. Use instead of magic `SizedBox` heights / paddings.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16; // default card / screen padding
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Bottom clearance a scroll view needs so its last item isn't hidden behind
  /// the floating bottom nav (pill height + offset + breathing room). Add the
  /// device's bottom safe-area inset on top of this at the call site.
  static const double floatingNavClearance = 80;

  // Ready-made gaps to cut Column/Row boilerplate.
  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
  static const SizedBox gapXl = SizedBox(height: xl, width: xl);
}

/// Interactive-control sizing. [controlHeight] is the visual pill height (matches
/// Material's default button height); [minTapTarget] is the 48dp accessibility
/// floor. Material buttons pad their hit area to 48 automatically — use
/// [minTapTargetSquare] via `AppPressable.minTapTarget` on custom (non-Material)
/// controls that don't get that padding.
abstract final class AppSizes {
  static const double controlHeight = 44;
  static const double minTapTarget = 48;
  static const Size minTapTargetSquare = Size(minTapTarget, minTapTarget);
}

/// Corner radii. `lg`=20 matches the legacy Card radius; `md`=14 the input
/// radius; `pill` for chips and CTAs.
abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static final BorderRadius brSm = BorderRadius.circular(sm);
  static final BorderRadius brMd = BorderRadius.circular(md);
  static final BorderRadius brLg = BorderRadius.circular(lg);
  static final BorderRadius brXl = BorderRadius.circular(xl);
  static final BorderRadius brPill = BorderRadius.circular(pill);
}

/// Common edge insets so screens stop re-declaring `EdgeInsets.all(16)`.
abstract final class AppInsets {
  static const EdgeInsets screen = EdgeInsets.all(AppSpacing.md);
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: AppSpacing.md);
  static const EdgeInsets card = EdgeInsets.all(AppSpacing.md);
  static const EdgeInsets cardLg = EdgeInsets.all(AppSpacing.lg);
  static const EdgeInsets listTile =
      EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs);
}
