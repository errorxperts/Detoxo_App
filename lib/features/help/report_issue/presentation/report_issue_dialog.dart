import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/additional_feature/app_feedback/app_feedback.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The "Report an issue" entry point. An [AppDialog] sheet that says what
/// "Report a bug" does in one line, holds a flat row for the always-visible
/// top-bar feedback button, and launches the annotated-screenshot overlay.
///
/// "Report a bug" pops the sheet first, then calls [FeedbackLauncher.show]
/// with the caller's (screen) context so the `BetterFeedback` overlay
/// captures the underlying screen — not the sheet.
abstract final class ReportIssueDialog {
  static Future<void> show(BuildContext context) {
    return AppDialog.show<void>(
      context: context,
      title: 'Report an issue',
      icon: Icons.bug_report_outlined,
      message:
          'Tap Report a bug to capture this screen, mark it up and send it to '
          'us with your device details.',
      content: const _FeedbackButtonToggle(),
      actions: [
        SecondaryButton(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        PrimaryButton(
          label: 'Report a bug',
          icon: Icons.bug_report_outlined,
          onPressed: () {
            Navigator.of(context).pop();
            FeedbackLauncher.show(context);
          },
        ),
      ],
    );
  }
}

/// The live toggle bound to `settings.showFeedbackButton`: a flat row under a
/// hairline (the sheet is its surface). Wrapped in a [BlocBuilder] so it
/// reflects the flag immediately as it's flipped.
class _FeedbackButtonToggle extends StatelessWidget {
  const _FeedbackButtonToggle();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, AppSettings>(
      builder: (context, settings) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1),
            AppToggleTile(
              leading: Icon(
                Icons.feedback_outlined,
                color: context.tokens.ink2,
              ),
              title: 'Feedback button',
              subtitle: 'Show a feedback button in every top bar',
              value: settings.showFeedbackButton,
              onChanged: (v) => context
                  .read<SettingsCubit>()
                  .setShowFeedbackButton(enabled: v),
            ),
          ],
        );
      },
    );
  }
}
