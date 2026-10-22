import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/onboarding/domain/entities/onboarding_progress.dart';
import 'package:detoxo/features/onboarding/domain/onboarding_script.dart';
import 'package:detoxo/features/onboarding/presentation/onboarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Walks [surveyQuestions] and renders whatever is in the list. All three
/// questions sit on one screen — a survey is a survey, not three page turns —
/// and each answer is written to the store the moment it is given.
class SurveyStep extends StatelessWidget {
  const SurveyStep({required this.progress, super.key});

  final OnboardingProgress progress;

  /// The answers the user must give before Next unlocks. Derived from the
  /// script, so a new required question gates the step with no other edit.
  static bool isComplete(OnboardingProgress p) => surveyQuestions
      .where((q) => !q.optional)
      .every((q) => _valueOf(p, q.field) != null);

  static String? _valueOf(OnboardingProgress p, String field) =>
      switch (field) {
        fieldName => p.name,
        fieldBand => p.band?.wire,
        fieldMattersMost => p.mattersMost?.wire,
        _ => null,
      };

  /// Leading glyphs for chip answers, keyed by wire token so the script stays
  /// Flutter-free. A token with no entry renders a plain chip.
  static const _icons = <String, IconData>{
    'FOCUS': Icons.center_focus_strong_rounded,
    'SLEEP': Icons.bedtime_rounded,
    'PRESENT': Icons.people_rounded,
    'MENTAL': Icons.favorite_rounded,
    'OTHER': Icons.more_horiz_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cubit = context.read<OnboardingCubit>();
    final days = progress.daysPerYear;
    return EntranceList(
      children: [
        Text(
          'A few quick things',
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Stays on this device. Shapes what Detoxo sets up for you.',
          style: text.bodyMedium?.copyWith(color: context.tokens.ink2),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final q in surveyQuestions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: _Question(
              question: q,
              value: _valueOf(progress, q.field),
              onAnswer: (v) => cubit.answer(q.field, v),
              // The number the projection will count up, the moment a band
              // lands. Keyed by band so a re-pick replays the entrance.
              footer: q.field == fieldBand && days != null
                  ? KeyedSubtree(
                      key: ValueKey(progress.band),
                      child: Text(
                        'About $days days a year',
                        style: text.labelMedium?.copyWith(
                          color: context.tokens.accentText(
                            context.tokens.brand,
                          ),
                        ),
                      ).entrance(),
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.question,
    required this.value,
    required this.onAnswer,
    this.footer,
  });

  final OnboardingQuestion question;
  final String? value;
  final ValueChanged<String?> onAnswer;

  /// Live feedback under the answer (never part of the answer itself).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A text field already names itself with the prompt (its Semantics
        // label and hint); a second visible copy is a row of nothing.
        if (question.kind != QuestionKind.text) ...[
          Text(
            question.prompt,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        switch (question.kind) {
          QuestionKind.text => _TextAnswer(
            hint: question.hint,
            label: question.prompt,
            initial: value,
            onAnswer: onAnswer,
          ),
          // No run spacing: `AppChip` already pads itself to the 48 dp target,
          // so rows pitch at 48 with a visual gap between the pills.
          QuestionKind.chips => Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final o in question.options)
                AppChip(
                  label: o.label,
                  icon: SurveyStep._icons[o.wire],
                  selected: value == o.wire,
                  // Single-select and never deselectable: a required question
                  // with nothing chosen is a dead Next button the user cannot
                  // explain, so re-tapping the chosen chip is a no-op.
                  onSelected: () => onAnswer(o.wire),
                ),
            ],
          ),
        },
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: footer,
          ),
      ],
    );
  }
}

/// Free-text answer. Writes on every edit (debounced by the field's own change
/// cadence, not by a timer) so an abandoned run keeps whatever was typed.
class _TextAnswer extends StatefulWidget {
  const _TextAnswer({
    required this.hint,
    required this.label,
    required this.initial,
    required this.onAnswer,
  });

  final String? hint;

  /// What a screen reader announces as the field's name.
  final String label;
  final String? initial;
  final ValueChanged<String?> onAnswer;

  @override
  State<_TextAnswer> createState() => _TextAnswerState();
}

class _TextAnswerState extends State<_TextAnswer> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The prompt is no longer a sibling Text, and a collapsed decoration's
    // hintText is only announced while the field is empty — so once the user
    // types, the field would have no label at all. Name it explicitly.
    return Semantics(
      textField: true,
      label: widget.label,
      child: GlassContainer(
        surface: DxSurface.option,
        color: context.tokens.fillQuiet,
        borderRadius: AppRadius.md,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: TextField(
          controller: _controller,
          // Bounded like every other input in the app (rule_editor_screen uses
          // the same 40): this is persisted and rendered into a headline.
          maxLength: 40,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration.collapsed(
            hintText: widget.hint,
            hintStyle: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: context.tokens.ink2),
          ),
          onChanged: widget.onAnswer,
        ),
      ),
    );
  }
}
