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
    BetterFeedback.of(context).show((UserFeedback userFeedback) async {
      try {
        await sl<FeedbackRepository>().send(
          FeedbackReport.fromUserFeedback(userFeedback),
        );
      } catch (_) {
        // No email app. The trigger (app-bar button, settings tile) is still
        // on screen once the overlay closes; if it is not, there is nowhere
        // to toast.
        if (!context.mounted) return;
        GlassToast.show(
          context,
          "Couldn't open an email app. Reach us at ${AppSupport.supportEmail}",
          tone: AppTone.danger,
        );
      }
    });
  }
}
