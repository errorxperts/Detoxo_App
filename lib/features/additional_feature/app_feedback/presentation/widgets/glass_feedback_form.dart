import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/additional_feature/app_feedback/domain/entities/feedback_category.dart';
import 'package:detoxo/features/additional_feature/app_feedback/domain/entities/feedback_report.dart';
import 'package:detoxo/features/additional_feature/app_feedback/presentation/widgets/feedback_category_chips.dart';
import 'package:detoxo/features/additional_feature/app_feedback/presentation/widgets/feedback_rating_selector.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';

/// The compact feedback form, drawn as the spec SHEET, used as the `feedback`
/// package's `feedbackBuilder`. Collects a category, an optional rating and a message,
/// then hands them to [OnSubmit] as `extras` — the framework attaches the
/// (annotated) screenshot and forwards everything to the top-level handler.
///
/// Layout mirrors the package's own sheet: a scrollable body inside an
/// [Expanded] with the submit button pinned below it. The package positions the
/// whole sheet directly above the keyboard, so no manual inset handling is
/// needed here.
class GlassFeedbackForm extends StatefulWidget {
  const GlassFeedbackForm({
    required this.onSubmit,
    this.scrollController,
    super.key,
  });

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
    final t = context.tokens;
    final draggable = widget.scrollController != null;
    // The spec SHEET chrome: 10 in from the edges, 22 inside, a 40×5 grabber
    // while the package lets the sheet be dragged. The package already sits
    // the sheet above the keyboard; only the system bar is cleared here.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _inset,
        0,
        _inset,
        _inset + MediaQuery.paddingOf(context).bottom,
      ),
      child: GlassContainer(
        surface: DxSurface.sheet,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  ListView(
                    controller: widget.scrollController,
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.sheetSide,
                      // The grabber's 30 px zone, as on `GlassBottomSheet`.
                      draggable ? 30 : AppSpacing.sheetSide,
                      AppSpacing.sheetSide,
                      AppSpacing.sm,
                    ),
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.rate_review_outlined,
                            color: t.ink,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              'Share your feedback',
                              style: AppTypography.headline.copyWith(
                                color: t.ink,
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
                              style: AppTypography.body.copyWith(color: t.ink2),
                            ),
                            const Spacer(),
                            FeedbackRatingSelector(
                              rating: _rating,
                              onChanged: (rating) =>
                                  setState(() => _rating = rating),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      // Fill, radius, focus border and hint come from the
                      // app's input theme (the form sits under `AppTheme`).
                      TextField(
                        controller: _messageController,
                        minLines: 2,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        style: AppTypography.body.copyWith(color: t.ink),
                        decoration: InputDecoration(
                          hintText: 'What went well, or what could be better?',
                          helperText: 'A screenshot is attached automatically.',
                          helperStyle: AppTypography.subhead.copyWith(
                            color: t.ink2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (draggable)
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(top: AppSpacing.sm),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: t.grabber,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sheetSide,
                0,
                AppSpacing.sheetSide,
                AppSpacing.sheetSide,
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
      ),
    );
  }

  /// The sheet's gap to the screen edges (`.dx-sheet`).
  static const double _inset = 10;
}
