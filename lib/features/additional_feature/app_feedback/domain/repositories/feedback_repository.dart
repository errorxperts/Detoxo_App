import 'package:detoxo/features/additional_feature/app_feedback/domain/entities/feedback_report.dart';

/// Sends a [FeedbackReport] to support. Implementations decide the transport
/// (email composer, HTTP endpoint, …), keeping the UI and domain agnostic.
abstract interface class FeedbackRepository {
  /// Delivers [report]. Throws on failure (e.g. no email client available) so
  /// callers can surface an error to the user.
  Future<void> send(FeedbackReport report);
}
