import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:flutter/material.dart';

/// A motivational quote in a glass card that fades + scales in whenever the
/// [quote] changes (scale 0.8→1, opacity 0→1, per the reference app). The
/// parent owns rotation; this widget only animates transitions.
class QuoteBox extends StatelessWidget {
  const QuoteBox({required this.quote, super.key});

  final String quote;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final card = SectionCard(
      key: ValueKey(quote),
      child: Text(
        quote,
        textAlign: TextAlign.center,
        style: text.titleMedium?.copyWith(fontStyle: FontStyle.italic),
      ),
    );

    if (reduceMotion) return card;

    return AnimatedSwitcher(
      duration: AppDurations.normal,
      switchInCurve: AppCurves.decelerate,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1).animate(anim),
          child: child,
        ),
      ),
      child: card,
    );
  }
}
