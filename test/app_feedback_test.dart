import 'dart:typed_data';

import 'package:detoxo/features/additional_feature/app_feedback/domain/entities/feedback_category.dart';
import 'package:detoxo/features/additional_feature/app_feedback/domain/entities/feedback_report.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeedbackCategory', () {
    test('wire round-trips through fromWire', () {
      for (final category in FeedbackCategory.values) {
        expect(FeedbackCategory.fromWire(category.wire), category);
      }
    });

    test('fromWire falls back to other for unknown / null', () {
      expect(FeedbackCategory.fromWire('nope'), FeedbackCategory.other);
      expect(FeedbackCategory.fromWire(null), FeedbackCategory.other);
    });
  });

  group('FeedbackReport.fromUserFeedback', () {
    UserFeedback build(Map<String, dynamic>? extra) => UserFeedback(
      text: 'It broke',
      screenshot: Uint8List.fromList(const [1, 2, 3]),
      extra: extra,
    );

    test('maps text, category, rating and screenshot from extras', () {
      final report = FeedbackReport.fromUserFeedback(
        build(const {
          FeedbackReport.categoryKey: 'bug',
          FeedbackReport.ratingKey: 4,
        }),
      );
      expect(report.message, 'It broke');
      expect(report.category, FeedbackCategory.bug);
      expect(report.rating, 4);
      expect(report.screenshot, Uint8List.fromList(const [1, 2, 3]));
    });

    test('coerces a numeric (double) rating to int', () {
      final report = FeedbackReport.fromUserFeedback(
        build(const {FeedbackReport.ratingKey: 3.0}),
      );
      expect(report.rating, 3);
    });

    test('defaults to other / unrated when extras are missing or null', () {
      expect(
        FeedbackReport.fromUserFeedback(build(null)).category,
        FeedbackCategory.other,
      );
      expect(FeedbackReport.fromUserFeedback(build(null)).rating, 0);
      expect(
        FeedbackReport.fromUserFeedback(build(const {})).category,
        FeedbackCategory.other,
      );
    });
  });

  group('AppSettings.showFeedbackButton', () {
    test('defaults to false (opt-in; enabled via Help or Settings)', () {
      expect(const AppSettings().showFeedbackButton, isFalse);
    });

    test('copyWith + toJson serialize the flag', () {
      final settings = const AppSettings().copyWith(showFeedbackButton: false);
      expect(settings.showFeedbackButton, isFalse);
      expect(settings.toJson()['showFeedbackButton'], false);
    });

    test('fromJson defaults to false when the key is missing (back-compat)', () {
      expect(
        AppSettings.fromJson(const <String, dynamic>{}).showFeedbackButton,
        isFalse,
      );
    });

    test('survives a full JSON round-trip', () {
      final original = const AppSettings().copyWith(showFeedbackButton: false);
      expect(AppSettings.fromJson(original.toJson()), original);
    });
  });
}
