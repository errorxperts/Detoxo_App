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
    final ink2 = context.tokens.ink2;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Detoxo can’t unlock it for you: the PIN never leaves this phone. '
            'Reinstalling Detoxo clears it along with all your settings.',
            style: AppTypography.body.copyWith(color: ink2),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Turned on uninstall protection? Switch it off first in Android’s '
            'Settings → Security → Device admin apps.',
            style: AppTypography.subhead.copyWith(color: ink2),
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
