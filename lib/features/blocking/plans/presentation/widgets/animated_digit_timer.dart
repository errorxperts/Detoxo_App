import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:flutter/material.dart';

/// An `mm:ss` (or `h:mm:ss`) countdown where each character cell crossfades
/// independently when it changes — reproducing the reference app's per-digit
/// `AnimatedContent`. Reduce-motion renders plain text.
class AnimatedDigitTimer extends StatelessWidget {
  const AnimatedDigitTimer({required this.remaining, this.style, super.key});

  final Duration remaining;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final text = formatCountdown(remaining);
    final base = AppTypography.mono(style ?? Theme.of(context).textTheme.displaySmall);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < text.length; i++)
          if (reduceMotion)
            Text(text[i], style: base)
          else
            AnimatedSwitcher(
              duration: AppDurations.fast,
              switchInCurve: AppCurves.decelerate,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Text(text[i], key: ValueKey('$i:${text[i]}'), style: base),
            ),
      ],
    );
  }
}
