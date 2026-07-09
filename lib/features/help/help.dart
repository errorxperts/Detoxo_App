/// Help & support feature — a drawer hub grouping four help actions:
///
/// - **report_issue** — a dialog explaining the bug-report flow, toggling the
///   top-bar feedback button, and launching the annotated-screenshot overlay.
/// - **faq** — a searchable, category-grouped FAQ (static content).
/// - **feature_tutorial** — replayable guided tours (dashboard walkthrough +
///   an independent, scoped feedback-button showcase).
/// - **share_ideas** — a message-only suggestion form that emails support.
/// - **legal** — the Privacy Policy and Terms & Conditions, shown in-app via a
///   reusable web view.
///
/// Screens are registered in `core/navigation` (the composition root); other
/// features should reach Help only through this barrel — never its internals.
library;

export 'faq/domain/entities/faq_entry.dart';
export 'legal/legal.dart';
export 'presentation/help_screen.dart';
export 'report_issue/report_issue.dart';
