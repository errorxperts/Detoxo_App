import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// A wrap of selected chips that each remove their own item on tap — the
/// editor's picked apps and sites, the website sheet's custom hosts.
class RemovableChips extends StatelessWidget {
  const RemovableChips({
    required this.items,
    required this.onRemove,
    this.label,
    super.key,
  });

  final List<String> items;
  final void Function(String) onRemove;

  /// Display text per item; defaults to the item itself.
  final String Function(String)? label;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xs,
    children: [
      for (final item in items)
        AppChip(
          label: label?.call(item) ?? item,
          // The chip LOOKS selected but activating it deletes the target —
          // "Instagram, selected" would be a trap for a screen reader user.
          // Momentary: a one-shot removal, so no selected state and no check
          // beside the close icon.
          semanticLabel: 'Remove ${label?.call(item) ?? item}',
          selected: true,
          momentary: true,
          icon: Icons.close,
          onSelected: () => onRemove(item),
        ),
    ],
  );
}
