import 'package:flutter/foundation.dart';

/// The topic a [FaqEntry] belongs to. The order here is the order categories
/// render on the FAQ screen, so keep it reader-friendly (setup first, edge
/// cases last).
enum FaqCategory {
  setup,
  blocking,
  counter,
  blockersLimits,
  pin,
  privacy,
  platform,
  troubleshooting;

  /// Section header shown above the group.
  String get label => switch (this) {
    FaqCategory.setup => 'Setup & permissions',
    FaqCategory.blocking => 'Blocking & plans',
    FaqCategory.counter => 'Reel counter',
    FaqCategory.blockersLimits => 'App & web blocker',
    FaqCategory.pin => 'PIN & recovery',
    FaqCategory.privacy => 'Privacy & data',
    FaqCategory.platform => 'Platform & iOS',
    FaqCategory.troubleshooting => 'Troubleshooting',
  };
}

/// One question/answer pair. Immutable static content — there is no persistence
/// or repository behind the FAQ; entries live in `data/faq_data.dart`.
@immutable
class FaqEntry {
  const FaqEntry({
    required this.question,
    required this.answer,
    required this.category,
  });

  final String question;
  final String answer;
  final FaqCategory category;

  /// Whether this entry matches a search term. [lowerQuery] must already be
  /// lower-cased and trimmed by the caller (see `filterFaqs`).
  bool matches(String lowerQuery) =>
      question.toLowerCase().contains(lowerQuery) ||
      answer.toLowerCase().contains(lowerQuery);
}
