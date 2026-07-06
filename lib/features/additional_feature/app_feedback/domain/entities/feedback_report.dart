import 'dart:typed_data';

import 'package:detoxo/features/additional_feature/app_feedback/domain/entities/feedback_category.dart';
import 'package:feedback/feedback.dart';

/// Immutable, transport-agnostic feedback payload assembled from the
/// [UserFeedback] captured by the `feedback` package. The delivery mechanism
/// (email, HTTP, …) is chosen by the repository — this only carries data.
class FeedbackReport {
  const FeedbackReport({
    required this.message,
    required this.category,
    required this.rating,
    required this.screenshot,
  });

  /// Builds a [FeedbackReport] from the package's [UserFeedback]. The custom
  /// form stores the category & rating in [UserFeedback.extra]; the screenshot
  /// is captured and attached by the framework.
  factory FeedbackReport.fromUserFeedback(UserFeedback feedback) {
    final extra = feedback.extra ?? const <String, dynamic>{};
    return FeedbackReport(
      message: feedback.text,
      category: FeedbackCategory.fromWire(extra[categoryKey] as String?),
      rating: (extra[ratingKey] as num?)?.toInt() ?? 0,
      screenshot: feedback.screenshot,
    );
  }

  /// The free-text message the user typed.
  final String message;

  /// The chosen feedback category.
  final FeedbackCategory category;

  /// 0 = unrated, otherwise 1–5 stars.
  final int rating;

  /// PNG-encoded, possibly annotated screenshot captured by the framework.
  final Uint8List screenshot;

  /// Key used for the category in the `feedback` package `extras` map.
  static const String categoryKey = 'category';

  /// Key used for the rating in the `feedback` package `extras` map.
  static const String ratingKey = 'rating';
}
