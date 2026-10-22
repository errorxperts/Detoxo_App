// ignore_for_file: deprecated_member_use
//
// All legacy `ShowCaseWidget` API usage is funnelled through this one file. In
// showcaseview 5.1.0 the builder-based `ShowCaseWidget` controller is
// `@Deprecated` (scheduled for removal in the package's v6), but our pubspec
// pins `^5.1.0`, so it is the correct, stable surface — we deliberately avoid
// the v6 `ShowcaseView.register()` controller. Scoping the ignore to this file
// keeps every other dashboard widget lint-clean.

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/additional_feature/showcase_view/data/feature_showcase_steps.dart';
import 'package:detoxo/features/additional_feature/showcase_view/domain/showcase_step.dart';
import 'package:detoxo/features/additional_feature/showcase_view/presentation/widgets/showcase_tooltip_card.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

/// Wraps [child] (the dashboard subtree) in the tour host. Place this as an
/// ancestor of every showcase target; [startFeatureTour] then drives the tour
/// from any descendant.
///
/// [onSeen] persists the "seen" flag and fires on BOTH natural completion
/// (`onFinish`) and dismissal (`onDismiss`, i.e. Skip), so skipping the tour is
/// remembered too. The barrier blocks stray taps and auto-scroll brings
/// off-screen targets into view. The tooltip never bobs: it moves only on its
/// own entrance, which Reduce Motion skips.
Widget buildFeatureShowcaseScope({
  required Widget child,
  required VoidCallback onSeen,
}) {
  return ShowCaseWidget(
    onFinish: onSeen,
    onDismiss: (_) => onSeen(),
    enableAutoScroll: true,
    blurValue: 1,
    disableBarrierInteraction: true,
    disableMovingAnimation: true,
    builder: (_) => child,
  );
}

/// Starts the six-step tour. Drives the tour through the registered
/// [ShowcaseView] singleton rather than `ShowCaseWidget.of(context)` so it works
/// regardless of the caller's position in the tree (the tooltip below is
/// rendered in the root overlay, with no `ShowCaseWidget` ancestor).
///
/// A short start delay lets the dashboard's entrance animation settle so the
/// first spotlight lands on a stationary hero.
void startFeatureTour() => ShowcaseView.get().startShowCase(
  FeatureShowcaseKeys.ordered,
  delay: AppDurations.medium,
);

/// Wraps a dashboard target so the tour can spotlight it with a glass tooltip.
///
/// Default target gestures are disabled: while the tour runs, a tapped target
/// must NOT fire its real action (open a dialog, push a route) — advancing
/// happens only through the tooltip's Next / Skip controls. When the tour is not
/// running, [child] renders and behaves exactly as before. The spotlight's
/// corners follow [radius]: the mode options keep [AppRadius.chip], the
/// blocker tiles pass [AppRadius.card].
Widget showcaseTarget({
  required ShowcaseStep step,
  required int index,
  required Widget child,
  double radius = AppRadius.chip,
}) => _target(
  step: step,
  index: index,
  total: featureShowcaseStepCount,
  radius: radius,
  child: child,
);

/// The spotlight + [ShowcaseTooltipCard] shared by both tours. A null [scope]
/// drives the current default scope (`ShowcaseView.get()`, the dashboard
/// tour), a named one an independent tour (`getNamed`). The controller is
/// looked up on tap: the card renders in the root overlay, with no
/// `ShowCaseWidget` ancestor for an `.of` lookup.
Widget _target({
  required ShowcaseStep step,
  required int index,
  required int total,
  required double radius,
  required Widget child,
  String? scope,
}) {
  ShowcaseView view() =>
      scope == null ? ShowcaseView.get() : ShowcaseView.getNamed(scope);
  return Showcase.withWidget(
    key: step.key,
    scope: scope,
    container: ShowcaseTooltipCard(
      step: step,
      index: index,
      total: total,
      onNext: () => view().next(),
      onSkip: () => view().dismiss(),
    ),
    targetBorderRadius: BorderRadius.circular(radius),
    targetPadding: const EdgeInsets.all(6),
    overlayOpacity: 0.78,
    disableDefaultTargetGestures: true,
    child: child,
  );
}

// ── Independent, named-scope tours ──────────────────────────────────────────
//
// The dashboard tour above uses the legacy default-scope `ShowCaseWidget`, which
// stays mounted even while another screen is pushed on top of it. showcaseview
// 5.1.0 is scope-based: a second tour must register its OWN named scope rather
// than mounting a second `ShowCaseWidget` (which would hijack the shared
// `currentScope` and cross-wire the two). These helpers let any pushed screen
// run a self-contained tour that coexists with the dashboard host — the caller
// registers a scope in `initState`, drives it by name, and unregisters in
// `dispose`. Note `ShowcaseView.get()` takes no arguments; the scoped accessor
// is `getNamed(scope)`.

/// Registers an isolated tour controller under [scope]. Call once from the
/// hosting screen's `State.initState`; pair with [unregisterScopedShowcase] in
/// `dispose`. [onSeen] fires on natural completion AND on Skip/dismiss.
void registerScopedShowcase({
  required String scope,
  required VoidCallback onSeen,
}) {
  ShowcaseView.register(
    scope: scope,
    onFinish: onSeen,
    onDismiss: (_) => onSeen(),
    enableAutoScroll: true,
    blurValue: 1,
    disableBarrierInteraction: true,
    disableMovingAnimation: true,
  );
}

/// Wraps [child] as a spotlight target bound to [scope] (never the ambient
/// `currentScope`), rendering the same [ShowcaseTooltipCard] as the dashboard
/// tour. As with [showcaseTarget], the target's own gestures are disabled
/// while the tour runs. The spotlight is a pill: the target is a header button.
Widget scopedShowcaseTarget({
  required String scope,
  required ShowcaseStep step,
  required int index,
  required int total,
  required Widget child,
}) => _target(
  scope: scope,
  step: step,
  index: index,
  total: total,
  radius: AppRadius.pill,
  child: child,
);

/// Starts the [scope] tour over [keys]. A short delay lets layout settle.
void startScopedShowcase({
  required String scope,
  required List<GlobalKey> keys,
}) => ShowcaseView.getNamed(
  scope,
).startShowCase(keys, delay: AppDurations.medium);

/// Tears down the [scope] controller, restoring the previous (dashboard) scope.
void unregisterScopedShowcase(String scope) =>
    ShowcaseView.getNamed(scope).unregister();
