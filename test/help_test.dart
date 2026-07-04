import 'package:detoxo/features/additional_feature/app_feedback/domain/entities/feedback_category.dart';
import 'package:detoxo/features/additional_feature/app_feedback/domain/entities/feedback_report.dart';
import 'package:detoxo/features/additional_feature/app_feedback/domain/repositories/feedback_repository.dart';
import 'package:detoxo/features/help/faq/data/faq_data.dart';
import 'package:detoxo/features/help/faq/domain/entities/faq_entry.dart';
import 'package:detoxo/features/help/faq/presentation/faq_cubit.dart';
import 'package:detoxo/features/help/share_ideas/presentation/share_ideas_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the last report, or throws to simulate "no email app".
class _FakeFeedbackRepository implements FeedbackRepository {
  _FakeFeedbackRepository({this.throwOnSend = false});

  final bool throwOnSend;
  FeedbackReport? sent;

  @override
  Future<void> send(FeedbackReport report) async {
    if (throwOnSend) throw Exception('no mail app');
    sent = report;
  }
}

void main() {
  group('filterFaqs', () {
    test('empty or blank query returns all entries', () {
      expect(filterFaqs(''), kFaqEntries);
      expect(filterFaqs('   '), kFaqEntries);
    });

    test('matches question and answer case-insensitively', () {
      final results = filterFaqs('ACCESSIBILITY');
      expect(results, isNotEmpty);
      expect(results.every((e) => e.matches('accessibility')), isTrue);
    });

    test('unmatched query returns an empty list', () {
      expect(filterFaqs('zzz-not-a-real-term'), isEmpty);
    });

    test('every category has at least one entry', () {
      for (final category in FaqCategory.values) {
        expect(
          kFaqEntries.where((e) => e.category == category),
          isNotEmpty,
          reason: 'no FAQ entries for ${category.name}',
        );
      }
    });
  });

  group('FaqCubit', () {
    test('starts empty and emits the search query', () {
      final cubit = FaqCubit();
      expect(cubit.state, '');
      cubit.search('pin');
      expect(cubit.state, 'pin');
    });
  });

  group('ShareIdeasCubit', () {
    test('blank message cannot submit; submit is a no-op', () async {
      final repo = _FakeFeedbackRepository();
      final cubit = ShareIdeasCubit(repo);
      expect(cubit.state.canSubmit, isFalse);
      cubit.setMessage('   ');
      expect(cubit.state.canSubmit, isFalse);
      await cubit.submit();
      expect(repo.sent, isNull);
      expect(cubit.state.status, ShareStatus.editing);
    });

    test('submit sends a trimmed Suggestion and emits success', () async {
      final repo = _FakeFeedbackRepository();
      final cubit = ShareIdeasCubit(repo)..setMessage('  Add dark mode  ');
      expect(cubit.state.canSubmit, isTrue);
      await cubit.submit();
      expect(cubit.state.status, ShareStatus.success);
      expect(repo.sent, isNotNull);
      expect(repo.sent!.category, FeedbackCategory.suggestion);
      expect(repo.sent!.message, 'Add dark mode');
      expect(repo.sent!.rating, 0);
      expect(repo.sent!.screenshot, isEmpty);
    });

    test('a send failure emits error with a message', () async {
      final repo = _FakeFeedbackRepository(throwOnSend: true);
      final cubit = ShareIdeasCubit(repo)..setMessage('idea');
      await cubit.submit();
      expect(cubit.state.status, ShareStatus.error);
      expect(cubit.state.error, isNotNull);
    });
  });
}
