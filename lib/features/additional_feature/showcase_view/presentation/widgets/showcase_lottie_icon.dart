import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/additional_feature/showcase_view/domain/showcase_step.dart';
import 'package:flutter/material.dart';
import 'package:lottie_tgs/lottie.dart';

/// The small animated "feature icon" at the top of a showcase tooltip: a
/// tone-tinted [IconBadge] wrapping the step's Lottie, with a Lucide
/// [AppAnimatedIcon] fallback when the asset can't be decoded. Honours
/// reduce-motion (renders a static frame instead of looping).
class ShowcaseLottieIcon extends StatelessWidget {
  const ShowcaseLottieIcon({required this.step, this.size = 52, super.key});

  final ShowcaseStep step;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = toneColor(context, step.tone);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return IconBadge(
      size: size,
      color: color,
      fillAlpha: 0.16,
      bordered: true,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Lottie.asset(
          step.lottieAsset,
          fit: BoxFit.contain,
          repeat: !reduceMotion,
          animate: !reduceMotion,
          errorBuilder: (context, error, stackTrace) => AppAnimatedIcon(
            icon: step.fallbackIcon,
            size: size * 0.46,
            color: color,
            playOnAppear: true,
          ),
        ),
      ),
    );
  }
}
