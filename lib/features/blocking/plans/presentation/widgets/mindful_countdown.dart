import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/emoji_band.dart';
import 'package:detoxo/features/blocking/plans/presentation/widgets/animated_digit_timer.dart';
import 'package:detoxo/features/blocking/plans/presentation/widgets/animated_emoji.dart';
import 'package:detoxo/features/blocking/plans/presentation/widgets/quote_box.dart';
import 'package:flutter/material.dart';

/// The Mindful Countdown: a glass progress ring with a per-digit ticking timer,
/// a duration/progress-bucketed animated emoji band, and a rotating quote.
/// Reused by the Pause and Curious screens for every phase.
class MindfulCountdown extends StatelessWidget {
  const MindfulCountdown({
    required this.phaseLabel,
    required this.remaining,
    required this.progress,
    required this.quote,
    this.emoji,
    super.key,
  });

  /// e.g. "Blocking resumes in", "Cooling down", "Reels allowed for".
  final String phaseLabel;
  final Duration remaining;

  /// 0..1 remaining fraction for the ring.
  final double progress;

  /// The currently rotating quote text.
  final String quote;

  /// The matched emoji band item for the current bucket (null → hide band).
  final EmojiItem? emoji;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final band = emoji;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ProgressRing(
          progress: progress,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                phaseLabel,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: context.glass.onGlassMuted),
              ),
              const SizedBox(height: AppSpacing.xs),
              AnimatedDigitTimer(remaining: remaining),
            ],
          ),
        ),
        if (band != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AnimatedEmoji(emoji: band.emoji, animation: band.animation, size: 64),
          const SizedBox(height: AppSpacing.sm),
          Text(
            band.title,
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (band.description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              band.description,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: context.glass.onGlassMuted),
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.lg),
        QuoteBox(quote: quote),
      ],
    );
  }
}
