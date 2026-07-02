/// In-app feedback feature: a global glass feedback button, a compact
/// glassmorphism feedback form (category + rating + message) rendered over an
/// annotated screenshot via the `feedback` package, and email delivery of the
/// screenshot to support.
///
/// Wiring: register `EmailFeedbackRepositoryImpl` in the DI container, wrap the
/// app in `BetterFeedback` with `glassFeedbackTheme` + `GlassFeedbackForm`, and
/// set `GlassAppBar.globalActionsBuilder` to inject `FeedbackActionButton`.
library;

export 'data/repositories/email_feedback_repository_impl.dart';
export 'domain/entities/feedback_category.dart';
export 'domain/entities/feedback_report.dart';
export 'domain/repositories/feedback_repository.dart';
export 'presentation/feedback_launcher.dart';
export 'presentation/theme/feedback_theme.dart';
export 'presentation/widgets/feedback_action_button.dart';
export 'presentation/widgets/feedback_category_chips.dart';
export 'presentation/widgets/feedback_rating_selector.dart';
export 'presentation/widgets/glass_feedback_form.dart';
