import 'package:detoxo/core/design_system/components/badges.dart';
import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_colors.dart';
import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/widgets/common_widgets.dart' show SectionCard;
import 'package:flutter/material.dart';

/// A frosted, optionally tappable surface. Use for hero/status cards and any
/// standalone glass panel. For titled sections use [SectionCard] (common_widgets).
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.onTap,
    this.padding = AppInsets.card,
    this.accent,
    this.blurSigma,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Tints the glass fill/border (e.g. status card uses [AppColors.accent]).
  final Color? accent;
  final double? blurSigma;

  @override
  Widget build(BuildContext context) {
    final card = GlassContainer(
      padding: padding,
      blurSigma: blurSigma ?? 16,
      tintTop: accent?.withValues(alpha: 0.20),
      tintBottom: accent?.withValues(alpha: 0.06),
      borderColor: accent?.withValues(alpha: 0.40),
      child: child,
    );
    if (onTap == null) return card;
    return AppPressable(onTap: onTap!, child: card);
  }
}

/// Optional trend marker for a [StatCard].
class TrendDelta {
  const TrendDelta(this.percent, {this.up = true});
  final int percent;
  final bool up;
}

/// A metric tile that animates its value (count-up) when it changes — making a
/// live refresh visible. Sits in a `Row` (caller wraps in `Expanded`); uses a
/// flat translucent glass (cheap, no per-frame saveLayer).
class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.unit,
    this.trend,
    super.key,
  });

  final String label;
  final int value;
  final IconData icon;
  final String? unit;
  final TrendDelta? trend;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassContainer(
      enableBlur: false,
      padding: const EdgeInsets.all(14),
      tintTop: AppColors.seed.withValues(alpha: 0.18),
      tintBottom: AppColors.seed.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: AppColors.accent),
              if (trend != null)
                AppBadge.label(
                  '${trend!.up ? '▲' : '▼'} ${trend!.percent}%',
                  tone: trend!.up ? AppTone.success : AppTone.danger,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          TweenAnimationBuilder<int>(
            key: ValueKey(value),
            tween: IntTween(begin: 0, end: value),
            duration: AppDurations.slow,
            curve: AppCurves.standard,
            builder: (context, v, _) => Text(
              unit == null ? '$v' : '$v $unit',
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(label, style: text.bodySmall),
        ],
      ),
    );
  }
}
