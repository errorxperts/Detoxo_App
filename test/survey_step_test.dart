import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/onboarding/domain/entities/onboarding_progress.dart';
import 'package:detoxo/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:detoxo/features/onboarding/presentation/onboarding_cubit.dart';
import 'package:detoxo/features/onboarding/presentation/steps/survey_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryRepo implements OnboardingRepository {
  OnboardingProgress saved = const OnboardingProgress();

  @override
  Future<OnboardingProgress> load() async => saved;

  @override
  Future<void> save(OnboardingProgress progress) async => saved = progress;

  @override
  Future<void> clear() async => saved = const OnboardingProgress();
}

void main() {
  test('Continue skips answered cards; only the picks gate', () {
    const none = OnboardingProgress();
    const timed = OnboardingProgress(band: ScreenTimeBand.dontKnow);
    const done = OnboardingProgress(
      band: ScreenTimeBand.over7h,
      mattersMost: MattersMost.focus,
    );
    expect(SurveyStep.nextPage(none, SurveyStep.namePage), SurveyStep.timePage);
    expect(
      SurveyStep.nextPage(timed, SurveyStep.namePage),
      SurveyStep.goalPage,
    );
    expect(SurveyStep.nextPage(done, SurveyStep.namePage), SurveyStep.planPage);
    expect(SurveyStep.canContinue(none, SurveyStep.namePage), isTrue);
    expect(SurveyStep.canContinue(none, SurveyStep.timePage), isFalse);
    expect(SurveyStep.canContinue(timed, SurveyStep.goalPage), isFalse);
    expect(SurveyStep.canContinue(timed, SurveyStep.planPage), isFalse);
    expect(SurveyStep.canContinue(done, SurveyStep.planPage), isTrue);
  });

  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    testWidgets('a pick writes, then moves on after a beat ($name)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final cubit = OnboardingCubit(_MemoryRepo());
      var page = SurveyStep.timePage;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: BlocProvider.value(
            value: cubit,
            child: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) =>
                    BlocBuilder<OnboardingCubit, OnboardingProgress>(
                      builder: (_, p) => SurveyStep(
                        progress: p,
                        page: page,
                        onPage: (i) => setState(() => page = i),
                      ),
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tap or drag the bars'), findsOneWidget);

      await tester.tap(find.text('2–3'));
      await tester.pump();
      expect(cubit.state.band, ScreenTimeBand.between2And3h);
      expect(find.text('≈ 38 days a year on short videos'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(page, SurveyStep.goalPage);

      await tester.tap(find.text('Sleep'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(cubit.state.mattersMost, MattersMost.sleep);
      expect(page, SurveyStep.planPage);
      expect(find.text('You’re all set'), findsOneWidget);
      expect(find.text('Starting point: 2–3 h a day'), findsOneWidget);
      // Read from the sleep preset (22:00), never restated in the survey.
      expect(find.text('Sets up a bedtime rule from 10 PM'), findsWidgets);

      // The dimmed card above is one button that brings it back.
      await tester.tap(find.bySemanticsLabel('Change what matters most'));
      await tester.pumpAndSettle();
      expect(page, SurveyStep.goalPage);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
