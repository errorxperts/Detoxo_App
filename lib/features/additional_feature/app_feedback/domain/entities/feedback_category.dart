import 'package:flutter/material.dart';

/// The kind of feedback a user is sending. Drives the email subject line and
/// helps triage submissions on the receiving end.
enum FeedbackCategory {
  bug,
  suggestion,
  other;

  /// Human-readable label shown on the form chips.
  String get label => switch (this) {
    FeedbackCategory.bug => 'Bug',
    FeedbackCategory.suggestion => 'Suggestion',
    FeedbackCategory.other => 'Other',
  };

  /// Leading icon for the chip.
  IconData get icon => switch (this) {
    FeedbackCategory.bug => Icons.bug_report_outlined,
    FeedbackCategory.suggestion => Icons.lightbulb_outline,
    FeedbackCategory.other => Icons.chat_bubble_outline,
  };

  /// Stable value carried in the `feedback` package `extras` map.
  String get wire => name;

  /// Parses a persisted [wire] value, defaulting to [FeedbackCategory.other].
  static FeedbackCategory fromWire(String? value) {
    for (final category in FeedbackCategory.values) {
      if (category.wire == value) return category;
    }
    return FeedbackCategory.other;
  }
}
