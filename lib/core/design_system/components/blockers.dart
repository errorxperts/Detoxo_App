import 'package:detoxo/core/design_system/components/badges.dart';
import 'package:detoxo/core/design_system/components/dx_icons.dart';
import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// A blocker's state, said by the tile's status word.
enum BlockerStatus { on, paused, notSetUp }

/// The App Blocker or Web Blocker tile (spec BlockerTile): the 3D [icon] and
/// a chevron, the [title], the status word, then the first blocked apps or
/// sites ([stack]) and a "+[more]" pill. It is at least 180 high and grows
/// with large text instead of clipping.
///
/// Not set up shows "Tap to set up" in place of the stack, an empty stack
/// shows [note], and Paused fades and greys the stack.
class BlockerTile extends StatelessWidget {
  const BlockerTile({
    required this.icon,
    required this.title,
    required this.status,
    required this.glow,
    required this.onTap,
    this.stack = const [],
    this.more = 0,
    this.roundStack = false,
    this.countLabel,
    this.note,
    super.key,
  });

  final AssetGenImage icon;
  final String title;
  final BlockerStatus status;

  /// The tile colour (`tileApp` / `tileWeb`): the corner glow and, when On,
  /// the glow under the card shadow.
  final Color glow;
  final VoidCallback onTap;

  /// The first three blocked apps or sites, 28 px each.
  final List<Widget> stack;

  /// How many are left out of [stack].
  final int more;

  /// Sites are circles; apps are [AppRadius.icon] squircles.
  final bool roundStack;

  /// "6 apps", read after the status word.
  final String? countLabel;

  /// Shown in place of an empty [stack] ("Protection on").
  final String? note;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final on = status == BlockerStatus.on;
    final (word, dot) = switch (status) {
      BlockerStatus.on => ('On', t.statusOn),
      BlockerStatus.paused => ('Paused', t.statusPaused),
      BlockerStatus.notSetUp => ('Not set up', t.statusSetup),
    };
    final count = status == BlockerStatus.notSetUp ? null : countLabel ?? note;
    const radius = BorderRadius.all(Radius.circular(AppRadius.card));

    // Min size + spaceBetween: the floor (or a stretched row's height) is
    // what pushes the title to the bottom, never a bounded parent.
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon3d(icon, size: 56),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Glyph(Assets.svg.chevronRight, size: 18, color: t.ink3),
            ),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.headline.copyWith(color: t.ink)),
            const SizedBox(height: AppSpacing.xxs),
            Pill(label: word, dotColor: dot),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 28),
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: _stack(t),
              ),
            ),
          ],
        ),
      ],
    );

    return AppPressable(
      onTap: onTap,
      radius: radius,
      semanticLabel: [title, word, ?count].join(', '),
      child: ExcludeSemantics(
        child: CustomPaint(
          // CSS lists the On glow after the card shadow, so it paints under it.
          painter: on
              ? DxSurfacePainter(
                  radius: radius,
                  shadows: [
                    DxShadow(
                      color: glow.withValues(alpha: t.kTileGlow),
                      offset: const Offset(0, 18),
                      blur: 34,
                      spread: -18,
                    ),
                  ],
                  inner: false,
                )
              : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 180),
            child: GlassContainer(
              surface: DxSurface.tile,
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  // Passthrough keeps the 180 floor, so the text sits at the
                  // bottom.
                  fit: StackFit.passthrough,
                  children: [
                    // The corner glow: a 210 light in the tile colour.
                    Positioned(
                      left: -54,
                      top: -64,
                      width: 210,
                      height: 210,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              glow.withValues(
                                alpha: on ? t.kBloomOn : t.kBloomOff,
                              ),
                              glow.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.card),
                      child: content,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stack(AppTokens t) {
    final quiet = AppTypography.count.copyWith(color: t.ink2);
    if (status == BlockerStatus.notSetUp) {
      return Text('Tap to set up', style: quiet);
    }
    if (stack.isEmpty) {
      return note == null ? const SizedBox.shrink() : Text(note!, style: quiet);
    }
    final radius = BorderRadius.circular(
      roundStack ? AppRadius.pill : AppRadius.icon,
    );
    // Each item wears a ring in the card colour and a soft drop (spec
    // `.dx-app`); later items overlap the one before by 8.
    final shadows = [
      DxShadow(color: t.cardTo, spread: 2),
      DxShadow(
        color: Colors.black.withValues(alpha: .25),
        offset: const Offset(0, 4),
        blur: 10,
      ),
    ];
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28 + 20.0 * (stack.length - 1),
          height: 28,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < stack.length; i++)
                Positioned(
                  left: 20.0 * i,
                  width: 28,
                  height: 28,
                  child: CustomPaint(
                    painter: DxSurfacePainter(
                      radius: radius,
                      shadows: shadows,
                      inner: false,
                    ),
                    child: stack[i],
                  ),
                ),
            ],
          ),
        ),
        if (more > 0) ...[const SizedBox(width: 7), AppBadge.label('+$more')],
      ],
    );
    if (status != BlockerStatus.paused) return row;
    // Spec `grayscale(.7)`, which is CSS `saturate(.3)`.
    return Opacity(
      opacity: .5,
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(cssSaturate(.3)),
        child: row,
      ),
    );
  }
}

/// A site in a Web Blocker stack: a 28 circle in [color] (lighter at the top
/// left) holding the first letter or digit of [label].
class SiteLetter extends StatelessWidget {
  const SiteLetter(
    this.label, {
    required this.color,
    this.size = 28,
    super.key,
  });

  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter =
        RegExp(r'[\p{L}\p{N}]', unicode: true).firstMatch(label)?.group(0) ??
        '';
    // Fixed inks, not the theme's: the circle is the same in both themes.
    final ink = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : AppTokens.light.ink;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, .2)!, color],
        ),
      ),
      child: Text(
        letter.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: ink,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

/// The last row of the Blockers section (spec BlockerRulesRow): the rules
/// icon, "Blocker rules" over a one-line [summary], "N on" and a chevron. It
/// opens the rules screen.
class BlockerRulesRow extends StatelessWidget {
  const BlockerRulesRow({
    required this.summary,
    required this.onCount,
    required this.onTap,
    super.key,
  });

  final String summary;

  /// Rules switched on; null (no rules yet) hides the count.
  final int? onCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final count = onCount == null ? null : '$onCount on';
    return AppPressable(
      onTap: onTap,
      semanticLabel: count == null
          ? 'Blocker rules. $summary'
          : 'Blocker rules, $count. $summary',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: GlassContainer(
            // The spec's 0 vertical padding, plus 8 so 2x text clears the
            // edges; at 1x the 64 floor is unchanged.
            padding: const EdgeInsets.fromLTRB(
              10,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: Icon3d(
                      Assets.images.icons.iconBlockerRules,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Blocker rules',
                        style: AppTypography.labelStrong.copyWith(color: t.ink),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.subhead.copyWith(color: t.ink2),
                      ),
                    ],
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    count,
                    style: AppTypography.count.copyWith(color: t.ink2),
                  ),
                ],
                const SizedBox(width: AppSpacing.sm),
                Glyph(Assets.svg.chevronRight, size: 18, color: t.ink3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
