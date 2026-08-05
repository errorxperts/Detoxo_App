import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/permissions/presentation/permissions_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Walks the user out of Android's restricted-settings (13/14) / Enhanced
/// Confirmation Mode (15+) gate, which silently refuses the Accessibility,
/// overlay and device-admin toggles when the installer isn't the Play Store.
///
/// The escape hatch is identical on 13/14 and 15+ (App info → ⋮ → "Allow
/// restricted settings"); only the system dialog's wording differs, so the copy
/// names both variants rather than branching on the SDK level. The allowance is
/// per app, not per permission — one confirmation unblocks all three toggles.
abstract final class RestrictedSettingsSheet {
  static Future<void> show(BuildContext context) {
    final cubit = context.read<PermissionsCubit>();
    return GlassBottomSheet.show<void>(
      context: context,
      title: 'Android is blocking this switch',
      child: _Body(cubit: cubit),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.cubit});

  final PermissionsCubit cubit;

  static const List<String> _steps = [
    'Tap Open app info below.',
    'Tap the ⋮ menu at the top right.',
    'Choose Allow restricted settings.',
    'Come back to Detoxo and tap Grant again.',
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium?.copyWith(color: context.glass.onGlassMuted);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Because Detoxo wasn't installed from the Play Store, Android locks "
            'a few switches until you confirm you meant to turn them on. You may '
            'have seen a message about a "restricted setting", or "app was '
            'denied access".',
            style: muted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "It's a one-time confirmation. After it, Accessibility and Display "
            'over apps both work normally.',
            style: muted,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _Step(number: i + 1, text: _steps[i]),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            "Don't see it in the ⋮ menu? Scroll to the bottom of App info — some "
            'phones list it there instead.',
            style: text.bodySmall?.copyWith(color: context.glass.onGlassMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Open app info',
            expand: true,
            onPressed: () {
              Navigator.of(context).pop();
              cubit.openAppSettings();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          GhostButton(
            label: 'Not now',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      ],
    );
  }
}
