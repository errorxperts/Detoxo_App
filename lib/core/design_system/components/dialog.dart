import 'package:detoxo/core/design_system/components/buttons.dart';
import 'package:detoxo/core/design_system/components/cards.dart';
import 'package:detoxo/core/design_system/components/overlays.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';

/// A standard prompt, shown in the [GlassBottomSheet]: an optional neutral
/// icon, a centred title, a [message] and/or custom [content], then the
/// [actions] stacked full-width. Use [AppDialog.show] for a custom prompt and
/// [AppDialog.confirm] for a yes/no one.
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    this.message,
    this.content,
    this.actions,
    this.icon,
    super.key,
  });

  final String title;

  /// A simple body line.
  final String? message;

  /// Custom body (e.g. form fields), below [message] if both are given.
  final Widget? content;

  /// Passed in reading order, `[cancel, confirm]`; stacked last-first, so
  /// the confirm sits on top.
  final List<Widget>? actions;
  final IconData? icon;

  /// Shows an [AppDialog] in the sheet. Returns whatever it is popped with.
  /// [dismissible] false makes it mandatory (e.g. a forced app update): the
  /// caller must then supply an action that pops it.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? message,
    Widget? content,
    List<Widget>? actions,
    IconData? icon,
    bool dismissible = true,
  }) {
    return GlassBottomSheet.show<T>(
      context: context,
      dismissible: dismissible,
      child: AppDialog(
        title: title,
        message: message,
        content: content,
        actions: actions,
        icon: icon,
      ),
    );
  }

  /// A yes/no confirmation. Resolves to `true` when confirmed, `false` when
  /// cancelled or dismissed.
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    String? message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    IconData? icon,
  }) async {
    final confirmed = await show<bool>(
      context: context,
      title: title,
      message: message,
      icon: icon,
      actions: [
        SecondaryButton(
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        PrimaryButton(
          label: confirmLabel,
          expand: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final actionList = actions ?? const <Widget>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header + content scroll on overflow (large text scale + IME on a
        // short screen); the actions below stay pinned and reachable.
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (icon != null) ...[
                  Center(
                    child: IconBadge(icon: icon, color: t.ink2),
                  ),
                  const SizedBox(height: AppSpacing.gap),
                ],
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTypography.titleSheet.copyWith(color: t.ink),
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: AppTypography.message.copyWith(color: t.ink2),
                  ),
                ],
                if (content != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  content!,
                ],
              ],
            ),
          ),
        ),
        if (actionList.isNotEmpty) const SizedBox(height: AppSpacing.sheetSide),
        for (final (i, action) in actionList.reversed.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          action,
        ],
      ],
    );
  }
}
