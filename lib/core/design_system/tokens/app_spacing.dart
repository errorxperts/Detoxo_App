import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/widgets.dart';

/// Spacing: a 4-based scale plus the spec's named steps ([inset] … [section],
/// generated from tool/design). Use instead of magic `SizedBox` heights /
/// paddings.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16; // default card / screen padding
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  /// Inside the mode card, between its edge and the chip.
  static const double inset = AppTokens.spaceInset;

  /// Between blocker tiles, and between the tiles and the rules row.
  static const double gap = AppTokens.spaceGap;

  /// Padding inside tiles.
  static const double card = AppTokens.spaceCard;

  /// Screen side margins.
  static const double gutter = AppTokens.spaceGutter;

  /// Above a section title.
  static const double section = AppTokens.spaceSection;

  /// Sheet padding, sides and bottom.
  static const double sheetSide = AppTokens.spaceSheetSide;

  /// Screen top to the tab header row, safe area included: use
  /// `max(headerTop, safeTop + xs)`.
  static const double headerTop = AppTokens.spaceHeaderTop;

  /// Bottom clearance a scroll view needs so its last item isn't hidden behind
  /// the floating tab bar: the spec leaves 132 for the bar, its lift and
  /// breathing room. Add the device's bottom safe-area inset on top of this at
  /// the call site.
  static const double floatingNavClearance = 132;
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
/// radius; `pill` for chips and CTAs. The spec's named radii ([icon] …
/// [sheet], [pill]) are generated from tool/design.
abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;

  /// App icon squircles in a tile's icon stack (site icons are round).
  static const double icon = AppTokens.radiusIcon;

  /// Selected-mode chip: [card] minus the 8 px inset.
  static const double chip = AppTokens.radiusChip;

  /// Rows and frosted panels.
  static const double row = AppTokens.radiusRow;

  /// Blocker tiles and the mode card.
  static const double card = AppTokens.radiusCard;

  /// Quick-pick card and the tab lens.
  static const double cardSm = AppTokens.radiusCardSm;

  /// Tab bar and the slide track.
  static const double bar = AppTokens.radiusBar;

  /// Confirm sheet.
  static const double sheet = AppTokens.radiusSheet;

  /// Pills, buttons, the tab lens, status dots.
  static const double pill = AppTokens.radiusPill;

  static final BorderRadius brSm = BorderRadius.circular(sm);
  static final BorderRadius brMd = BorderRadius.circular(md);
  static final BorderRadius brLg = BorderRadius.circular(lg);
  static final BorderRadius brPill = BorderRadius.circular(pill);

  /// The border of a surface with corner [radius]: a true [StadiumBorder] at
  /// [pill], else a [RoundedRectangleBorder] with circular corners (no
  /// squircle). Pass a [side] to also stroke the edge.
  static ShapeBorder continuous(
    double radius, {
    BorderSide side = BorderSide.none,
  }) {
    if (radius >= pill) return StadiumBorder(side: side);
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: side,
    );
  }
}

/// Common edge insets so screens stop re-declaring `EdgeInsets.all(16)`.
abstract final class AppInsets {
  /// The spec's screen side margins.
  static const EdgeInsets screen = EdgeInsets.symmetric(
    horizontal: AppSpacing.gutter,
  );
  static const EdgeInsets screenH = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
  );
  static const EdgeInsets card = EdgeInsets.all(AppSpacing.md);
  static const EdgeInsets listTile = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.xxs,
  );
}
