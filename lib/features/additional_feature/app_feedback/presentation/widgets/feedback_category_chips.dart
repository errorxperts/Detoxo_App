import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/additional_feature/app_feedback/domain/entities/feedback_category.dart';
import 'package:flutter/material.dart';

/// A row of selectable glass chips for choosing the [FeedbackCategory].
class FeedbackCategoryChips extends StatelessWidget {
  const FeedbackCategoryChips({required this.selected, required this.onSelected, super.key});

  final FeedbackCategory selected;
  final ValueChanged<FeedbackCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final category in FeedbackCategory.values)
          AppChip(
            label: category.label,
            icon: category.icon,
            selected: category == selected,
            onSelected: () => onSelected(category),
          ),
      ],
    );
  }
}
