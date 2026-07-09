import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/additional_feature/app_upgrader/domain/entities/upgrade_status.dart';
import 'package:flutter/material.dart';

/// The glass "Update available" prompt. Rendered over the app's frosted
/// [AppDialog] so it matches the design system (upgrader's own Material dialog
/// is never used).
///
/// For a blocking update ([UpgradeStatus.isBlocking]) the dialog is
/// non-dismissible: the only action is "Update now", there is no "Later"/"Skip",
/// and both the barrier tap and the back button are disabled.
///
/// Dismissal is handled here; the `onUpdate`/`onLater`/`onSkip` callbacks carry
/// out the side effect (launch store / persist choice) and are wired to the
/// `UpgradeCubit` by the caller.
abstract final class AppUpgradeDialog {
  static Future<void> show(
    BuildContext context,
    UpgradeStatus status, {
    required VoidCallback onUpdate,
    VoidCallback? onLater,
    VoidCallback? onSkip,
  }) {
    final canDismiss = status.canDismiss;
    return AppDialog.show<void>(
      context: context,
      // A forced update must not be dismissible.
      barrierDismissible: canDismiss,
      blocking: !canDismiss,
      icon: Icons.system_update,
      accent: canDismiss ? null : AppColors.warning,
      title: canDismiss ? 'Update available' : 'Update required',
      message: _message(status),
      content: _Body(
        status: status,
        // Skip is a "don't ask again for this version" action — only offered for
        // optional updates, and kept subtle below the release notes.
        onSkip: canDismiss && onSkip != null
            ? () {
                Navigator.of(context).pop();
                onSkip();
              }
            : null,
      ),
      actions: [
        if (canDismiss)
          GhostButton(
            label: 'Later',
            onPressed: () {
              Navigator.of(context).pop();
              onLater?.call();
            },
          ),
        PrimaryButton(
          label: 'Update now',
          icon: Icons.system_update,
          onPressed: () {
            // Optional updates dismiss on tap; a blocking dialog stays up so the
            // user remains gated until they actually update.
            if (canDismiss) Navigator.of(context).pop();
            onUpdate();
          },
        ),
      ],
    );
  }

  static String _message(UpgradeStatus status) {
    final version = status.storeVersion;
    final headline = version != null
        ? 'Detoxo $version is available.'
        : 'A new version of Detoxo is available.';
    final tail = status.isBlocking
        ? ' This update is required to keep using Detoxo.'
        : ' Update now to get the latest features and fixes.';
    return '$headline$tail';
  }
}

/// The dialog body: optional "What's new" notes (scrollable, since store notes
/// can be long) and, for optional updates, a subtle "Skip this version" action.
class _Body extends StatelessWidget {
  const _Body({required this.status, this.onSkip});

  final UpgradeStatus status;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final notes = status.releaseNotes?.trim();
    final hasNotes = notes != null && notes.isNotEmpty;

    if (!hasNotes && onSkip == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasNotes) ...[
          Text(
            "What's new",
            style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.glass.fillBottom,
              borderRadius: AppRadius.brMd,
              border: Border.all(color: context.glass.border),
            ),
            child: SingleChildScrollView(
              child: Text(
                notes,
                style: text.bodySmall?.copyWith(
                  color: context.glass.onGlassMuted,
                ),
              ),
            ),
          ),
        ],
        if (onSkip != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: GhostButton(label: 'Skip this version', onPressed: onSkip),
          ),
        ],
      ],
    );
  }
}
