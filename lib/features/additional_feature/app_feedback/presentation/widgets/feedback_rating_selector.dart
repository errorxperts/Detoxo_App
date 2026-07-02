import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// A compact 1–5 star rating row. Tapping the current rating again clears it
/// back to 0 (unrated), so a rating is always optional.
class FeedbackRatingSelector extends StatelessWidget {
  const FeedbackRatingSelector({
    required this.rating,
    required this.onChanged,
    super.key,
  });

  /// Current rating, 0 (unrated) to 5.
  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: () => onChanged(star == rating ? 0 : star),
            icon: Icon(
              star <= rating ? Icons.star_rounded : Icons.star_border_rounded,
              color: star <= rating
                  ? AppColors.warning
                  : context.glass.onGlassMuted,
              size: 24,
            ),
          ),
      ],
    );
  }
}
