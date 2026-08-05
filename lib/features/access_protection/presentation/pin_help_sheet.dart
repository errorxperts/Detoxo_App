import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// What "Forgot PIN?" opens.
///
/// Detoxo has no recovery channel on purpose: the PIN never leaves the device
/// and there is no account behind it, so no code the app could accept would be
/// a recovery — it would be a bypass, available to anyone holding the phone.
/// This sheet says so plainly and names the one real escape hatch.
abstract final class PinHelpSheet {
  static Future<void> show(BuildContext context) {
    return GlassBottomSheet.show<void>(
      context: context,
      title: 'Forgot your PIN?',
      child: const _Body(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

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
            'Detoxo has no way to unlock this for you. Your PIN never leaves '
            'this phone and there is no account behind it — which is exactly '
            'what makes it a real commitment device.',
            style: muted,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'If you are locked out for good, uninstall Detoxo and install it '
            'again. That clears the PIN along with your settings, blocklists '
            'and counts, and you start fresh.',
            style: muted,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Turned on uninstall protection? Switch it off first in Android’s '
            'Settings → Security → Device admin apps.',
            style: text.bodySmall?.copyWith(color: context.glass.onGlassMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Got it',
            expand: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
