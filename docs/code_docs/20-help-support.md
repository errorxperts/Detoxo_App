# Help & Support

The **Help & support** feature is the in-app support surface, reached from the right-side
[`AppDrawer`](../../lib/features/dashboard/presentation/widgets/app_drawer.dart) via a single
**Help & support** tile (`Routes.help`). It is a pure Dart/UI feature — no native code, no new
persistence, no new dependencies — that composes existing machinery (the `app_feedback` feature
and the `showcase_view` tour) behind a small hub.

It follows the app's feature-first Clean Architecture: `lib/features/help/` groups four
submodules, each reached only through the feature barrel
[`help.dart`](../../lib/features/help/help.dart).

## Hub

[`HelpScreen`](../../lib/features/help/presentation/help_screen.dart) (`Routes.help`) is a
`GlassScaffold` + `GlassAppBar` listing four `FeatureTile`s:

| Tile | Action |
|---|---|
| Report an issue | Opens `ReportIssueDialog` (a dialog — no route) |
| FAQ | Pushes `Routes.helpFaq` |
| Feature tutorials | Pushes `Routes.featureTutorial` |
| Share an idea | Pushes `Routes.shareIdeas` |

## 1. Report an issue (`report_issue/`)

[`ReportIssueDialog.show(context)`](../../lib/features/help/report_issue/presentation/report_issue_dialog.dart)
is a glass `AppDialog` (presentation-only). It explains the bug-report flow, hosts a live
`AdaptiveSwitchTile` bound to `settings.showFeedbackButton`
(`SettingsCubit.setShowFeedbackButton`), and offers **Report a bug now** which pops the dialog
and calls `FeedbackLauncher.show(context)` — the app-wide `BetterFeedback` overlay captures the
underlying screen, so the annotated screenshot is of the real screen, not the dialog. Delivery
reuses the `app_feedback` email path (`FeedbackRepository` → `errorxperts@gmail.com`).

## 2. FAQ (`faq/`)

A searchable, category-grouped list of static content that mirrors
[`info_docs/04-faqs.md`](../info_docs/04-faqs.md).

- [`FaqEntry` + `FaqCategory`](../../lib/features/help/faq/domain/entities/faq_entry.dart) — the
  immutable model; `FaqCategory` order is render order.
- [`faq_data.dart`](../../lib/features/help/faq/data/faq_data.dart) — the `kFaqEntries` list and a
  pure, unit-testable `filterFaqs(query)` (blank query → all; else case-insensitive match on
  question + answer).
- [`FaqCubit`](../../lib/features/help/faq/presentation/faq_cubit.dart) — holds only the search
  query (`Cubit<String>`); the view derives the filtered/grouped list.
- [`FaqScreen`](../../lib/features/help/faq/presentation/faq_screen.dart) — `AppSearchField` +
  per-category `SectionHeader`s of [`FaqExpansionTile`](../../lib/features/help/faq/presentation/widgets/faq_expansion_tile.dart);
  no matches renders an `EmptyState`.

## 3. Feature tutorials (`feature_tutorial/`)

[`FeatureTutorialScreen`](../../lib/features/help/feature_tutorial/presentation/feature_tutorial_screen.dart)
offers two replayable tours:

- **Dashboard tour** — the walkthrough **moved here from Settings**. Its target keys only exist
  on the dashboard, so it replays via the established pattern:
  `SettingsCubit.setShowcaseSeen(value: false)` + `context.go(Routes.home)`; the dashboard's
  coordinator restarts the tour on the flag's true→false edge once front-most.
- **Feedback button** — an independent, single-step coach-mark spotlighting the **real
  top-bar feedback button** (`FeedbackActionButton`), reusing the same `ShowcaseTooltipCard`
  and glass theme as the dashboard tour. Because that button is hidden while
  `showFeedbackButton` is off, tapping the tile enables it first
  (`SettingsCubit.setShowFeedbackButton(enabled: true)`) so there is something to point at.
  The screen supplies its own **keyed** `FeedbackActionButton` in the app bar and sets
  `GlassAppBar(globalActions: false)` to suppress the auto-appended global copy (avoiding a
  duplicate); the coach-mark's `GlobalKey` is attached to that instance.

Because `showcaseview` 5.1.0 is scope-based and the dashboard's default-scope host stays mounted
under pushed routes, the feedback tour uses an explicit **named scope** rather than a second
`ShowCaseWidget` (which would hijack the shared `currentScope`). The screen registers the scope
in `initState` and unregisters it in `dispose`, driving it by name. This is powered by helpers
added to the `showcase_view` feature (kept there so `help/` never imports `showcaseview`):

- `registerScopedShowcase({scope, onSeen})` → `ShowcaseView.register(scope: …)`.
- `scopedShowcaseTarget({scope, step, index, total, child})` → `Showcase.withWidget(scope: …)`
  with a scope-aware `ShowcaseTooltipCard`.
- `startScopedShowcase({scope, keys})` → `ShowcaseView.getNamed(scope).startShowCase(…)`.
- `unregisterScopedShowcase(scope)` → `ShowcaseView.getNamed(scope).unregister()`.

See [`feature_showcase.dart`](../../lib/features/additional_feature/showcase_view/presentation/feature_showcase.dart)
and [`showcase_tooltip_card.dart`](../../lib/features/additional_feature/showcase_view/presentation/widgets/showcase_tooltip_card.dart)
(the card gained an optional `scope`; `null` → the default `ShowcaseView.get()`).

## 4. Share an idea (`share_ideas/`)

A message-only suggestion form.
[`ShareIdeasCubit`](../../lib/features/help/share_ideas/presentation/share_ideas_cubit.dart)
(state: `editing / submitting / success / error`) reuses the shared `FeedbackRepository` — it
builds a `FeedbackReport(category: FeedbackCategory.suggestion, rating: 0, screenshot:
Uint8List(0))` and `send()`s it, which opens the device email composer prefilled to support. The
empty screenshot is tolerated by `EmailFeedbackRepositoryImpl` (no attachment).
[`ShareIdeasScreen`](../../lib/features/help/share_ideas/presentation/share_ideas_screen.dart)
disables Send until the message is non-blank, toasts success/failure via `GlassToast`, and pops
on success. There is **no new repository** — it is registered nowhere new in the injector.

## Wiring

- Routes `help`, `helpFaq`, `featureTutorial`, `shareIdeas` in
  [`routes.dart`](../../lib/core/navigation/routes.dart), registered flat in
  [`app_router.dart`](../../lib/core/navigation/app_router.dart).
- The **Help & support** drawer tile in
  [`app_drawer.dart`](../../lib/features/dashboard/presentation/widgets/app_drawer.dart).
- The **Dashboard tour** tile + `_replayShowcase` were **removed** from
  [`settings_screen.dart`](../../lib/features/settings/presentation/settings_screen.dart) (they
  now live on the Feature tutorials screen). The "Feedback button" toggle stays in Settings.
- No new DI (`FeedbackRepository` is already registered); FAQ content is static.

## Source files

- `lib/features/help/help.dart`
- `lib/features/help/presentation/help_screen.dart`
- `lib/features/help/report_issue/report_issue.dart`
- `lib/features/help/report_issue/presentation/report_issue_dialog.dart`
- `lib/features/help/faq/faq.dart`
- `lib/features/help/faq/domain/entities/faq_entry.dart`
- `lib/features/help/faq/data/faq_data.dart`
- `lib/features/help/faq/presentation/faq_cubit.dart`
- `lib/features/help/faq/presentation/faq_screen.dart`
- `lib/features/help/faq/presentation/widgets/faq_expansion_tile.dart`
- `lib/features/help/feature_tutorial/feature_tutorial.dart`
- `lib/features/help/feature_tutorial/presentation/feature_tutorial_screen.dart`
- `lib/features/help/share_ideas/share_ideas.dart`
- `lib/features/help/share_ideas/presentation/share_ideas_cubit.dart`
- `lib/features/help/share_ideas/presentation/share_ideas_screen.dart`
- `lib/features/additional_feature/showcase_view/presentation/feature_showcase.dart` (scoped-tour helpers)
- `lib/features/additional_feature/showcase_view/presentation/widgets/showcase_tooltip_card.dart` (optional `scope`)
- `lib/features/additional_feature/showcase_view/showcase_view.dart` (barrel doc)
- `lib/core/navigation/routes.dart`
- `lib/core/navigation/app_router.dart`
- `lib/core/design_system/foundations/ambient_background.dart` (`GlassAppBar.globalActions` opt-out)
- `lib/features/dashboard/presentation/widgets/app_drawer.dart`
- `lib/features/settings/presentation/settings_screen.dart` (tour tile removed)

## Related
- [12 Analytics, Notifications & Resilience](12-analytics-notifications-resilience.md) — the
  `app_feedback` email path and `SettingsCubit`.
- User-facing: [Feature Walkthroughs §11](../info_docs/02-feature-walkthroughs.md),
  [FAQs](../info_docs/04-faqs.md).
