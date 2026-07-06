import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/additional_feature/app_feedback/domain/entities/feedback_category.dart';
import 'package:detoxo/features/additional_feature/app_feedback/domain/entities/feedback_report.dart';
import 'package:detoxo/features/additional_feature/app_feedback/presentation/widgets/feedback_category_chips.dart';
import 'package:detoxo/features/additional_feature/app_feedback/presentation/widgets/feedback_rating_selector.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';

/// The compact glassmorphism feedback form used as the `feedback` package's
/// `feedbackBuilder`. Collects a category, an optional rating and a message,
/// then hands them to [OnSubmit] as `extras` — the framework attaches the
/// (annotated) screenshot and forwards everything to the top-level handler.
///
/// Layout mirrors the package's own sheet: a scrollable body inside an
/// [Expanded] with the submit button pinned below it. The package positions the
/// whole sheet directly above the keyboard, so no manual inset handling is
/// needed here.
class GlassFeedbackForm extends StatefulWidget {
  const GlassFeedbackForm({required this.onSubmit, this.scrollController, super.key});

  final OnSubmit onSubmit;

  /// Non-null only while the feedback sheet is draggable; passed to the scroll
  /// view so scrolling expands the sheet.
  final ScrollController? scrollController;

  @override
  State<GlassFeedbackForm> createState() => _GlassFeedbackFormState();
}

class _GlassFeedbackFormState extends State<GlassFeedbackForm> {
  final TextEditingController _messageController = TextEditingController();
  FeedbackCategory _category = FeedbackCategory.suggestion;
  int _rating = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
  }

  @override
  void dispose() {
    _messageController
      ..removeListener(_onMessageChanged)
      ..dispose();
    super.dispose();
  }

  void _onMessageChanged() => setState(() {});

  bool get _canSubmit => _messageController.text.trim().isNotEmpty && !_sending;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _sending = true);
    try {
      await widget.onSubmit(
        _messageController.text.trim(),
        extras: <String, dynamic>{
          FeedbackReport.categoryKey: _category.wire,
          FeedbackReport.ratingKey: _rating,
        },
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final text = Theme.of(context).textTheme;
    final draggable = widget.scrollController != null;
    return GlassContainer(
      blurSigma: AppBlur.sheet,
      borderRadius: AppRadius.xl,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                ListView(
                  controller: widget.scrollController,
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    draggable ? AppSpacing.lg : AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.rate_review_outlined, color: AppColors.accent, size: 20),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Share your feedback',
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: glass.onGlass,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FeedbackCategoryChips(
                      selected: _category,
                      onSelected: (category) => setState(() {
                        _category = category;
                        // Bug reports aren't rated, so clear any stale rating.
                        if (category == FeedbackCategory.bug) {
                          _rating = 0;
                        }
                      }),
                    ),
                    // A rating only makes sense for suggestions / general
                    // feedback, not bug reports.
                    if (_category != FeedbackCategory.bug) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Text(
                            'Rate us',
                            style: text.bodyMedium?.copyWith(color: glass.onGlassMuted),
                          ),
                          const Spacer(),
                          FeedbackRatingSelector(
                            rating: _rating,
                            onChanged: (rating) => setState(() => _rating = rating),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: _messageController,
                      minLines: 2,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      style: TextStyle(color: glass.onGlass),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'What went well, or what could be better?',
                        hintStyle: TextStyle(color: glass.onGlassMuted),
                        helperText: 'A screenshot is attached automatically.',
                        helperStyle: text.bodySmall?.copyWith(color: glass.onGlassMuted),
                        filled: true,
                        fillColor: glass.fillTop,
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.brMd,
                          borderSide: BorderSide(color: glass.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppRadius.brMd,
                          borderSide: BorderSide(color: glass.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppRadius.brMd,
                          borderSide: const BorderSide(color: AppColors.accent),
                        ),
                      ),
                    ),
                  ],
                ),
                if (draggable)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: AppSpacing.xs),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: glass.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md + MediaQuery.paddingOf(context).bottom,
            ),
            child: PrimaryButton(
              label: _sending ? 'Sending…' : 'Send feedback',
              icon: Icons.send_rounded,
              expand: true,
              onPressed: _canSubmit ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }
}
