import 'package:detoxo/core/constants/app_constants.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/features/additional_feature/app_feedback/domain/entities/feedback_report.dart';
import 'package:detoxo/features/additional_feature/app_feedback/domain/repositories/feedback_repository.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';

/// Entry point that opens the `feedback` overlay and routes the captured
/// [UserFeedback] to the [FeedbackRepository]. Keeps trigger sites (app-bar
/// button, settings tile) a one-liner: `FeedbackLauncher.show(context)`.
abstract final class FeedbackLauncher {
  static void show(BuildContext context) {
    // Captured synchronously so we can report errors after the async submit
    // without touching a possibly-stale BuildContext.
    final messenger = ScaffoldMessenger.of(context);
    BetterFeedback.of(context).show((UserFeedback userFeedback) async {
      try {
        await sl<FeedbackRepository>().send(
          FeedbackReport.fromUserFeedback(userFeedback),
        );
      } catch (_) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(_errorSnackBar());
      }
    });
  }

  /// Glass-styled failure toast, shown when no email app is available. Built
  /// standalone (rather than via `GlassToast`) so it can run off a captured
  /// messenger after the async submit.
  static SnackBar _errorSnackBar() => SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    content: GlassContainer(
      blurSigma: AppBlur.bar,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      borderColor: AppColors.danger.withValues(alpha: 0.4),
      child: const Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              "Couldn't open an email app. Reach us at ${AppSupport.supportEmail}",
            ),
          ),
        ],
      ),
    ),
  );
}
