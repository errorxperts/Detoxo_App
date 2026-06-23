import 'package:detoxo/core/design_system/adaptive/adaptive_controls.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_colors.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:flutter/material.dart';

/// A standalone themed switch with built-in selection haptics — the canonical
/// on/off control for feature code. Wraps the platform-adaptive [AdaptiveSwitch]
/// (native on iOS, Material on Android) and fires [AppHaptics.selection] on each
/// change. For a full settings row (leading icon, title, subtitle) use
/// `AdaptiveSwitchTile`; pass a [label] here only for a lightweight inline row.
class AppToggle extends StatelessWidget {
  const AppToggle({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.activeColor = AppColors.accent,
    this.label,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final Color activeColor;

  /// Optional inline label rendered to the left of the switch.
  final String? label;

  void _handle(bool v) {
    AppHaptics.selection();
    onChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final toggle = AdaptiveSwitch(
      value: value,
      enabled: enabled,
      activeColor: activeColor,
      onChanged: onChanged == null ? null : _handle,
    );
    if (label == null) return toggle;
    return Row(
      children: [
        Expanded(
          child: Text(label!, style: Theme.of(context).textTheme.bodyLarge),
        ),
        const SizedBox(width: AppSpacing.sm),
        toggle,
      ],
    );
  }
}
