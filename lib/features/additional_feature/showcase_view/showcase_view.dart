/// Feature showcase / walkthrough — a one-time guided tour of Detoxo's core
/// features (Block All, Conscious, Pause, App Blocker, Web Blocker), auto-shown
/// once to new users and re-triggerable from Settings.
///
/// Public surface:
/// - `buildFeatureShowcaseScope` — wrap the dashboard subtree (the tour host).
/// - `startFeatureTour` — begin the tour from a descendant context.
/// - `showcaseTarget` — wrap a widget so a step can spotlight it.
/// - `featureShowcaseSteps` / `FeatureShowcaseKeys` — the ordered step data.
/// - `registerScopedShowcase` / `scopedShowcaseTarget` / `startScopedShowcase` /
///   `unregisterScopedShowcase` — build an independent, named-scope tour on a
///   pushed screen (e.g. the Help feature tutorial) that coexists with the
///   always-mounted dashboard host.
/// - `ShowcaseStep` — the step model for both the dashboard and scoped tours.
library;

export 'data/feature_showcase_steps.dart';
export 'domain/showcase_step.dart';
export 'presentation/feature_showcase.dart';
