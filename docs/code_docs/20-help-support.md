# Help & Support

The **Help & support** feature is the in-app support surface, reached from the right-side
[`AppDrawer`](../../lib/features/dashboard/presentation/widgets/app_drawer.dart) via a single
**Help & support** tile (`Routes.help`). It is a pure Dart/UI feature — no native code, no new
persistence — that composes existing machinery (the `app_feedback` feature and the
`showcase_view` tour) behind a small hub. The only added dependency is `webview_flutter`, used by
the Legal submodule to render the hosted Privacy Policy / Terms pages in-app.

It follows the app's feature-first Clean Architecture: `lib/features/help/` groups five
submodules, each reached only through the feature barrel
[`help.dart`](../../lib/features/help/help.dart).

## Hub

[`HelpScreen`](../../lib/features/help/presentation/help_screen.dart) (`Routes.help`) is a
`GlassScaffold` + `GlassAppBar` with three sections — **Get help**, **Learn & share** and
**Legal** — each an uppercase `SectionHeader` over **one** `PanelGroup` of flat `FeatureTile`
rows (ink-2 glyph, label/ink title, subhead/ink-2 subtitle, the row's own ink-3 chevron,
hairline-divided), inside the 20 px gutter:

| Tile | Action |
|---|---|
| Report an issue | Opens `ReportIssueDialog` (a sheet — no route) |
| FAQ | Pushes `Routes.helpFaq` |
| Feature tutorials | Pushes `Routes.featureTutorial` |
| Share an idea | Pushes `Routes.shareIdeas` |
| Privacy Policy | Pushes `Routes.privacyPolicy` |
| Terms & Conditions | Pushes `Routes.termsConditions` |

## 1. Report an issue (`report_issue/`)

[`ReportIssueDialog.show(context)`](../../lib/features/help/report_issue/presentation/report_issue_dialog.dart)
is an `AppDialog` in the design system's sheet (presentation-only). Its one-line message names
the button it describes ("Tap Report a bug to capture this screen, mark it up and send it to us
with your device details."); below it, a flat `AppToggleTile` row under a hairline (ink-2 glyph,
no panel — the sheet is its surface) bound to `settings.showFeedbackButton`
(`SettingsCubit.setShowFeedbackButton`). **Report a bug** (`PrimaryButton`, over **Close**) pops
the sheet and calls `FeedbackLauncher.show(context)` — the app-wide `BetterFeedback` overlay
captures the underlying screen, so the annotated screenshot is of the real screen, not the
sheet. Delivery reuses the `app_feedback` email path (`FeedbackRepository` →
`errorxperts@gmail.com`).

The overlay's form,
[`GlassFeedbackForm`](../../lib/features/additional_feature/app_feedback/presentation/widgets/glass_feedback_form.dart),
is drawn as the spec SHEET (10 in from the edges, `AppSpacing.sheetSide` inside, a 40×5
`grabber` while the package lets it be dragged) and gets `AppTheme` from `main.dart`, so its
message field is the app's input theme (quiet fill, radius 22, 2 px focus border). The header
glyph is ink, the category picker is OPTION `AppChip`s, and the rating stars are ink filled /
ink-2 idle ([`FeedbackRatingSelector`](../../lib/features/additional_feature/app_feedback/presentation/widgets/feedback_rating_selector.dart)).
[`glassFeedbackTheme`](../../lib/features/additional_feature/app_feedback/presentation/theme/feedback_theme.dart)
paints the package's own chrome: `bgBottom` behind the screenshot, the active Navigate / Draw
control in ink (the accent is reserved), draw colours `over` / `pause` main.

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
  per category a `SectionHeader` over one `PanelGroup` of
  [`FaqExpansionTile`](../../lib/features/help/faq/presentation/widgets/faq_expansion_tile.dart)
  rows; no matches renders an `EmptyState` naming `AppSupport.supportEmail`.
- `FaqExpansionTile` — a flat row (no surface of its own): the question in label/ink on an
  `AppPressable` with an ink-3 chevron that turns from down to up, and the answer in
  subhead/ink-2 opening below it, clipped while it grows (the spec `.dx-detail`:
  `AppDurations.detail` on `AppCurves.detail`, through `context.motion`, so nothing moves under
  Reduce Motion). The question is one merged semantics node with the expanded state; a closed
  answer leaves the tree.
- Copy follows the voice rules (no "!", Title Case feature names): the category is **App
  Blocker & Web Blocker**, Pause is "pick 1 to 10 minutes and tap Start", turning blocking off is
  **Blocking active** + PIN + wait and slide, the count lives "on Today and in Insights", and the
  permission is "Display over other apps". `test/help_test.dart` pins the search and a stale-name
  / "!" sweep over every entry, plus the tile's open/close and semantics.

## 3. Feature tutorials (`feature_tutorial/`)

[`FeatureTutorialScreen`](../../lib/features/help/feature_tutorial/presentation/feature_tutorial_screen.dart)
offers two replayable tours, as two `FeatureTile` rows in one `PanelGroup` under the **Guided
tours** `SectionHeader` (the old lightbulb hint row is gone; the Feedback button row's subtitle
says the tour points it out and turns it on):

- **Today tour** (the tile's label) — the walkthrough **moved here from Settings**. Its
  target keys only exist on the Today tab, so it replays via the established pattern:
  `SettingsCubit.setShowcaseSeen(value: false)` + `context.go(Routes.home)`; Today's
  (`dashboard_tab.dart`) coordinator restarts the tour on the flag's true→false edge once front-most. The tour is
  **six steps** (`featureShowcaseStepCount = 6`, defined in
  [`feature_showcase_steps.dart`](../../lib/features/additional_feature/showcase_view/data/feature_showcase_steps.dart)):
  it spotlights all **four mode options** — Block All, Conscious, Pause (a timed break; the
  ring's Unblock pill owns the reel count), **One Reel** (position 4) — in the Today `ModeCard`'s
  option order at indices 0–3 (wrapped by `ModeCard.decorateOption`, which `dashboard_tab.dart`
  points at `showcaseTarget(step: featureShowcaseSteps[i])`) — then the **App Blocker** and **Web Blocker** tiles at
  `featureShowcaseSteps[4]` / `[5]`. `showcaseTarget(radius:)` rounds the spotlight to its target
  (`AppRadius.chip` 20 for the mode options by default; the tiles pass `AppRadius.card` 28; the
  scoped header-button target is a pill). Each step's badge shows the same spec 3D icon as the
  widget it points at: `ShowcaseStep.image` is an `AssetGenImage`
  (`Assets.images.icons.iconBlockAll`, `iconConscious`, `iconPause` — the stopwatch —,
  `iconOneReel`, `iconAppBlocker`, `iconWebBlocker` — the globe), drawn bare by `Icon3d` at 56,
  **uncropped** (the spec never crops its icons). `ShowcaseStep.accentTint` (true for the four
  mode steps) tints it to the live accent, as the `ModeCard` tints its options; the blocker
  steps stay untinted like their tiles. `ShowcaseStep.icon` (`IconData`) is the alternative for
  a step with no 3D icon — a neutral 56 `IconBadge`, used by the feedback coach-mark below. A
  step asserts that at least one is set; `image` wins when both are. Steps carry no tone.
- **The tooltip card**
  ([`ShowcaseTooltipCard`](../../lib/features/additional_feature/showcase_view/presentation/widgets/showcase_tooltip_card.dart))
  is presentational: `step`, `index`, `total`, `onNext`, `onSkip`. It is 280 wide in the sheet
  material (`GlassContainer(surface: DxSurface.sheet, borderRadius: AppRadius.card)`): badge +
  `headline` ink title, `subhead` ink-2 body, progress dots (the active one a wide ink pill, the
  rest hairline) inside `Semantics(label: 'Step N of M')`, then a `SecondaryButton` **Skip** (48
  dp) and an expanded `PrimaryButton` **Next** / **Done** (54). It fades in once through
  `.entrance()` (skipped under Reduce Motion) and never moves after that: both tour hosts set
  `disableMovingAnimation: true`, which stops the package's endless 7 px bob (it ignored Reduce
  Motion), and a custom container gets no package scale animation.
- **Feedback button** — an independent, single-step coach-mark spotlighting the **real
  top-bar feedback button** (`FeedbackActionButton`), reusing the same sheet-material
  `ShowcaseTooltipCard` as the Today tour. Because that button is hidden while
  `showFeedbackButton` is off, tapping the tile enables it first
  (`SettingsCubit.setShowFeedbackButton(enabled: true)`) so there is something to point at.
  The screen supplies its own **keyed** `FeedbackActionButton` in the app bar and sets
  `GlassAppBar(globalActions: false)` to suppress the auto-appended global copy (avoiding a
  duplicate); the coach-mark's `GlobalKey` is attached to that instance.

Because `showcaseview` 5.1.0 is scope-based and the home shell's default-scope host stays mounted
under pushed routes, the feedback tour uses an explicit **named scope** rather than a second
`ShowCaseWidget` (which would hijack the shared `currentScope`). The screen registers the scope
in `initState` and unregisters it in `dispose`, driving it by name. This is powered by helpers
added to the `showcase_view` feature (kept there so `help/` never imports `showcaseview`):

- `registerScopedShowcase({scope, onSeen})` → `ShowcaseView.register(scope: …)`.
- `scopedShowcaseTarget({scope, step, index, total, child})` → `Showcase.withWidget(scope: …)`
  with the same `ShowcaseTooltipCard`, through the private `_target` both tours share.
- `startScopedShowcase({scope, keys})` → `ShowcaseView.getNamed(scope).startShowCase(…)`.
- `unregisterScopedShowcase(scope)` → `ShowcaseView.getNamed(scope).unregister()`.

See [`feature_showcase.dart`](../../lib/features/additional_feature/showcase_view/presentation/feature_showcase.dart)
and [`showcase_tooltip_card.dart`](../../lib/features/additional_feature/showcase_view/presentation/widgets/showcase_tooltip_card.dart)
(`_target` resolves the controller on tap: a `null` scope drives `ShowcaseView.get()`, a named
one `ShowcaseView.getNamed(scope)`; the card renders in the root overlay, with no
`ShowCaseWidget` ancestor for an `.of` lookup). Test:
[`feature_tour_card_test.dart`](../../test/feature_tour_card_test.dart) (48 dp Skip/Next, 'Step
2 of 6', one `onNext` per tap, no scheduled frame after the entrance or under Reduce Motion, 2×
text in both themes, `disableMovingAnimation` on both hosts).

## 4. Share an idea (`share_ideas/`)

A message-only suggestion form.
[`ShareIdeasCubit`](../../lib/features/help/share_ideas/presentation/share_ideas_cubit.dart)
(state: `editing / submitting / success / error`) reuses the shared `FeedbackRepository` — it
builds a `FeedbackReport(category: FeedbackCategory.suggestion, rating: 0, screenshot:
Uint8List(0))` and `send()`s it, which opens the device email composer prefilled to support. The
empty screenshot is tolerated by `EmailFeedbackRepositoryImpl` (no attachment).
[`ShareIdeasScreen`](../../lib/features/help/share_ideas/presentation/share_ideas_screen.dart)
disables Send until the message is non-blank, toasts success ("Your idea is on its way. Thank
you.") / failure via `GlassToast`, and pops on success. Layout: one subhead/ink-2 intro line; a
**Your idea** `SectionHeader` over one panel holding the collapsed `TextField` (body/ink, ink-2
hint, the spec `FocusRing` around the panel while it has focus) and the count ("Every idea
helps" when empty); **Need a nudge?** over momentary OPTION `AppChip`s that insert a starter
phrase; then `PrimaryButton` **Send idea** and the email footnote. There is **no new
repository** — it is registered nowhere new in the injector.

## 5. Legal (`legal/`)

The Privacy Policy and Terms & Conditions, shown **in-app** rather than in an external browser.
Both tiles push the same reusable
[`LegalWebViewScreen`](../../lib/features/help/legal/presentation/legal_web_view_screen.dart)
(`StatefulWidget`, `const` ctor), which differs only by its `title` and `url`:

- The screen owns a `webview_flutter` `WebViewController` built in `initState` with
  `JavaScriptMode.unrestricted` — **required**, because the hosted pages are a single-page site
  that routes by URL fragment (`#privacy` / `#terms`); without JS the correct section won't
  render. A `NavigationDelegate` clears the first-load `LoadingState` on `onPageFinished` and
  shows the error state on a main-frame `onWebResourceError`: an `EmptyState` ("Couldn't load
  this page") with a `PrimaryButton` **Retry**. Both states are `LegalPageStatus`, public so
  `test/legal_web_view_test.dart` checks them without a platform web view.
- Chrome is the standard `GlassScaffold` + `GlassAppBar(title: …)`; the app bar's default back
  button pops.
- The canonical URLs are the single source of truth in
  [`AppLegal`](../../lib/core/constants/app_constants.dart) (`privacyPolicyUrl`, `termsUrl`).
  There is **no new DI** and no persistence.

## Wiring

- Routes `help`, `helpFaq`, `featureTutorial`, `shareIdeas`, `privacyPolicy`, `termsConditions`
  in [`routes.dart`](../../lib/core/navigation/routes.dart), registered flat in
  [`app_router.dart`](../../lib/core/navigation/app_router.dart) (the two legal routes build
  `LegalWebViewScreen` with the `AppLegal` URLs).
- The **Help & support** drawer tile in
  [`app_drawer.dart`](../../lib/features/dashboard/presentation/widgets/app_drawer.dart).
- The tour tile (now **Today tour**) + `_replayShowcase` were **removed** from
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
- `lib/features/help/legal/legal.dart`
- `lib/features/help/legal/presentation/legal_web_view_screen.dart` (`LegalWebViewScreen`, `LegalPageStatus`)
- `lib/features/additional_feature/app_feedback/presentation/widgets/glass_feedback_form.dart`, `feedback_rating_selector.dart`, `feedback_category_chips.dart`, `presentation/theme/feedback_theme.dart` (the report form)
- `lib/core/constants/app_constants.dart` (`AppLegal` URLs)
- `pubspec.yaml` (`webview_flutter` dependency)
- `lib/features/additional_feature/showcase_view/data/feature_showcase_steps.dart` (6-step keys/order/content, the spec icons)
- `lib/features/additional_feature/showcase_view/domain/showcase_step.dart` (`image` 3D icon / `icon` glyph badge art, `accentTint`)
- `lib/features/additional_feature/showcase_view/presentation/feature_showcase.dart` (both hosts with `disableMovingAnimation`, scoped-tour helpers, shared `_target`)
- `lib/features/additional_feature/showcase_view/presentation/widgets/showcase_tooltip_card.dart` (sheet-material card, `onNext` / `onSkip`; `_StepBadge` draws `Icon3d` at 56)
- `test/feature_tour_card_test.dart`
- `lib/core/design_system/components/dx_icons.dart` (`Icon3d`), `assets/images/icons/` (the tour's badge art)
- `lib/features/additional_feature/showcase_view/showcase_view.dart` (barrel doc)
- `lib/core/navigation/routes.dart`
- `lib/core/navigation/app_router.dart`
- `lib/core/design_system/foundations/glass_scaffold.dart` (`GlassAppBar.globalActions` opt-out)
- `lib/features/dashboard/presentation/widgets/app_drawer.dart`
- `lib/features/settings/presentation/settings_screen.dart` (tour tile removed)

## Related
- [12 Analytics, Notifications & Resilience](12-analytics-notifications-resilience.md) — the
  `app_feedback` email path and `SettingsCubit`.
- User-facing: [Feature Walkthroughs §11](../info_docs/02-feature-walkthroughs.md),
  [FAQs](../info_docs/04-faqs.md).
