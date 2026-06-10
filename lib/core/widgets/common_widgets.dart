import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Shared composites kept at their original names/APIs so the ~13 screens that
/// already use them keep compiling — now reskinned over the glass design system.
/// New screens should prefer the design-system components directly
/// (`GlassCard`, `StatCard`, `GlassListTile`, `PrimaryButton`, …).

/// A titled, padded glass section used across screens.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    super.key,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          child,
        ],
      ),
    );
  }
}

/// A compact metric tile (e.g. "Blocks today: 12").
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassContainer(
        enableBlur: false,
        tintTop: AppColors.seed.withValues(alpha: 0.18),
        tintBottom: AppColors.seed.withValues(alpha: 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// A friendly empty / placeholder state. Pass [animatedIcon] for a morphing
/// glyph — [loopAnimation] runs it continuously (ambient), otherwise it plays
/// once on appear.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.animatedIcon,
    this.loopAnimation = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final AppIcon? animatedIcon;
  final bool loopAnimation;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (animatedIcon != null)
              AppAnimatedIcon(
                icon: animatedIcon!,
                size: 56,
                color: outline,
                loop: loopAnimation,
                playOnAppear: !loopAnimation,
              )
            else
              Icon(icon, size: 56, color: outline),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
          ],
        ),
      ),
    );
  }
}

/// A labelled navigation tile for the "more features" list. Pass [animatedIcon]
/// for a morphing badge glyph that plays on appear and replays on every tap;
/// [icon] is the static fallback for un-migrated call sites.
class FeatureTile extends StatefulWidget {
  const FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.animatedIcon,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final AppIcon? animatedIcon;

  @override
  State<FeatureTile> createState() => _FeatureTileState();
}

class _FeatureTileState extends State<FeatureTile> {
  final AnimatedIconController _iconController = AnimatedIconController();

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  void _onTap() {
    if (widget.animatedIcon != null &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _iconController
        ..reset()
        ..animate();
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final leading = widget.animatedIcon != null
        ? AppAnimatedIcon(
            icon: widget.animatedIcon!,
            size: 24,
            color: AppColors.accent,
            controller: _iconController,
            playOnAppear: true,
          )
        : Icon(widget.icon, color: AppColors.accent);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassListTile(
        onTap: _onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.16),
            borderRadius: AppRadius.brMd,
          ),
          child: Center(child: leading),
        ),
        title: widget.title,
        subtitle: widget.subtitle,
        trailing: widget.trailing ?? const Icon(Icons.chevron_right),
      ),
    );
  }
}

/// A full-width primary button for screen-level call-to-actions.
class FullWidthButton extends StatelessWidget {
  const FullWidthButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) =>
      PrimaryButton(label: label, onPressed: onPressed, expand: true);
}

/// Formats a [Duration] as mm:ss (or h:mm:ss).
String formatCountdown(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
