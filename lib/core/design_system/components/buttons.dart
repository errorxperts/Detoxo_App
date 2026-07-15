import 'package:detoxo/core/design_system/adaptive/adaptive_controls.dart';
import 'package:detoxo/core/design_system/foundations/animated_icons.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_colors.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:flutter/material.dart';

/// Primary call-to-action. Filled & brand-tinted (native CNButton on iOS).
/// `expand: true` makes it full-width (the old `FullWidthButton` behaviour).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.expand = false,
    this.icon,
    this.tint = AppColors.seed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final IconData? icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => AdaptiveButton(
        label: label,
        onPressed: onPressed,
        tint: tint,
        expand: expand,
        icon: icon,
      );
}

/// Lower-emphasis tonal button (e.g. "Restore purchases", "Resume now").
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.expand = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => AdaptiveButton(
        label: label,
        onPressed: onPressed,
        variant: AdaptiveButtonVariant.tinted,
        expand: expand,
        icon: icon,
      );
}

/// Text-only, lowest emphasis (e.g. "Skip", "Maybe later").
class GhostButton extends StatelessWidget {
  const GhostButton({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AdaptiveButton(
        label: label,
        onPressed: onPressed,
        variant: AdaptiveButtonVariant.plain,
      );
}

/// A filled CTA whose leading icon plays its morph on every press (and a
/// scale-squish from [AppPressable]). Fully Flutter-rendered so the animated
/// icon shows on every platform — use for hero actions ("Enable now",
/// "Upgrade", "Save limit"). Reduce-motion skips the morph.
class AnimatedIconButton extends StatefulWidget {
  const AnimatedIconButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tint = AppColors.seed,
    this.expand = false,
    super.key,
  });

  final String label;
  final AppIcon icon;
  final VoidCallback? onPressed;
  final Color tint;
  final bool expand;

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton> {
  final AnimatedIconController _iconController = AnimatedIconController();

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  void _onTap() {
    if (widget.onPressed == null) return;
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _iconController
        ..reset()
        ..animate();
    }
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final pill = Container(
      height: AppSizes.controlHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: disabled ? widget.tint.withValues(alpha: 0.4) : widget.tint,
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppAnimatedIcon(
            icon: widget.icon,
            size: 20,
            color: Colors.white,
            controller: _iconController,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            widget.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
    final content = widget.expand ? SizedBox(width: double.infinity, child: pill) : pill;
    if (disabled) return Opacity(opacity: 0.6, child: content);
    return AppPressable(
      onTap: _onTap,
      minTapTarget: AppSizes.minTapTargetSquare,
      child: content,
    );
  }
}
