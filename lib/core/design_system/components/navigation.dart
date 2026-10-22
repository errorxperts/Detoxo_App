import 'package:detoxo/core/design_system/components/buttons.dart';
import 'package:detoxo/core/design_system/components/dx_icons.dart';
import 'package:detoxo/core/design_system/foundations/accent.dart';
import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// One [AppTabBar] tab: its label, and the outlined `icon` it shows idle and
/// the filled `selectedIcon` it shows when current.
typedef TabItem = ({String label, IconData icon, IconData selectedIcon});

/// The spec TabBar (named apart from Material's `TabBar`): a 208 × 64 glass
/// bar whose accent lens slides behind the current tab with the lens timing
/// and a squish. Idle tabs are an outlined icon over the label in ink-2; the
/// current one is the filled icon, 1.08 larger, in the accent text colour.
///
/// Text scale is clamped at 1.3 so the labels always fit the fixed bar, and
/// under Reduce Motion nothing moves.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    required this.items,
    required this.current,
    required this.onSelect,
    super.key,
  });

  /// The bar's fixed size (`.dx-tabbar`).
  static const Size size = Size(208, 64);

  @visibleForTesting
  static const Key lensKey = ValueKey('AppTabBar.lens');

  /// Between the bar's edge and the lens.
  static const double _pad = 6;

  final List<TabItem> items;
  final int current;

  /// Called with the tapped tab's index, the current one included.
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = context.accent;
    final n = items.length;
    final on = t.accentText(accent);
    // Dark accent text on the lens is 3.9–4.5:1, under the 4.5:1 text floor
    // for most palettes, so the Dark current label reads in ink (the
    // filled icon keeps the accent; contrast_test pins both).
    final onLabel = t.brightness == Brightness.dark ? t.ink : on;
    final fade = context.motion(AppDurations.medium);
    final lens = AnimatedAlign(
      duration: context.motion(AppDurations.lens),
      curve: AppCurves.lens,
      alignment: Alignment(n > 1 ? -1 + 2 * current / (n - 1) : 0, 0),
      child: Squish(
        trigger: current,
        duration: AppDurations.lens,
        child: FractionallySizedBox(
          widthFactor: 1 / n,
          child: CustomPaint(
            key: lensKey,
            painter: DxSurfacePainter(
              radius: AppRadius.brPill,
              color: accent.main.withValues(alpha: t.kTab),
              gradient: [t.lensHi, t.lensLo],
              shadows: [
                ...t.lensEdge,
                DxShadow(
                  color: accent.main.withValues(alpha: t.kTabGlow),
                  offset: const Offset(0, 6),
                  blur: 16,
                  spread: -6,
                ),
              ],
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SizedBox.fromSize(
        size: size,
        child: GlassContainer(
          surface: DxSurface.glass,
          borderRadius: AppRadius.bar,
          padding: const EdgeInsets.all(_pad),
          child: Stack(
            fit: StackFit.expand,
            children: [
              lens,
              Row(
                children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: AppPressable(
                        onTap: () {
                          AppHaptics.selection();
                          onSelect(i);
                        },
                        haptic: false,
                        pressedScale: 1,
                        radius: AppRadius.brPill,
                        selected: i == current,
                        child: _Tab(
                          item: items[i],
                          current: i == current,
                          iconColor: on,
                          labelColor: onLabel,
                          duration: fade,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tab's icon over its label, tweening ink-2 → the current colours
/// (`.dx-tab`, `color .4s ease`).
class _Tab extends StatelessWidget {
  const _Tab({
    required this.item,
    required this.current,
    required this.iconColor,
    required this.labelColor,
    required this.duration,
  });

  final TabItem item;
  final bool current;
  final Color iconColor;
  final Color labelColor;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: current ? 1.0 : 0.0),
      duration: duration,
      curve: AppCurves.glide,
      builder: (_, v, _) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.scale(
            scale: 1 + .08 * v,
            child: Icon(
              current ? item.selectedIcon : item.icon,
              size: 24,
              color: Color.lerp(t.ink2, iconColor, v),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.tab.copyWith(
              color: Color.lerp(t.ink2, labelColor, v),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tab's header row: the [title] in title-xl ink (a heading for screen
/// readers), then [actions], then the glass "Menu" button that opens the
/// sidebar.
///
/// Put it first in a list padded with [listPadding]. Its top then sits
/// [AppSpacing.headerTop] below the screen top when the tab's body is inset
/// to `max(safe top, headerTop - inset)`, as `HomeShell` does.
class TabHeader extends StatelessWidget {
  const TabHeader({
    required this.title,
    required this.onMenu,
    this.actions = const [],
    super.key,
  });

  final String title;
  final VoidCallback? onMenu;
  final List<Widget> actions;

  /// A tab list's padding: the gutter on the sides, [AppSpacing.inset] on
  /// top, and room for the floating tab bar and the bottom inset below.
  static EdgeInsets listPadding(BuildContext context) => EdgeInsets.fromLTRB(
    AppSpacing.gutter,
    AppSpacing.inset,
    AppSpacing.gutter,
    AppSpacing.floatingNavClearance + MediaQuery.viewPaddingOf(context).bottom,
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: AppTypography.titleXl.copyWith(color: t.ink),
            ),
          ),
        ),
        for (final action in actions) ...[
          action,
          const SizedBox(width: AppSpacing.xs),
        ],
        GlassIconButton(
          icon: Glyph(Assets.svg.sidebar, size: 22, color: t.ink),
          semanticLabel: 'Menu',
          onPressed: onMenu,
        ),
      ],
    );
  }
}
