/// Feature showcase / walkthrough — a one-time guided tour of Detoxo's core
/// features (Block All, Conscious, Pause, App Blocker, Web Blocker), auto-shown
/// once to new users and re-triggerable from Settings.
///
/// Public surface:
/// - `buildFeatureShowcaseScope` — wrap the dashboard subtree (the tour host).
/// - `startFeatureTour` — begin the tour from a descendant context.
/// - `showcaseTarget` — wrap a widget so a step can spotlight it.
/// - `featureShowcaseSteps` / `FeatureShowcaseKeys` — the ordered step data.
library;

export 'data/feature_showcase_steps.dart';
export 'domain/showcase_step.dart';
export 'presentation/feature_showcase.dart';
