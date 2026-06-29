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
/// off-screen targets into view.
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
    builder: (_) => child,
  );
}

/// Starts the five-step tour. Drives the tour through the registered
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
/// running, [child] renders and behaves exactly as before.
Widget showcaseTarget({
  required ShowcaseStep step,
  required int index,
  required Widget child,
}) {
  return Showcase.withWidget(
    key: step.key,
    container: ShowcaseTooltipCard(
      step: step,
      index: index,
      total: featureShowcaseStepCount,
    ),
    targetBorderRadius: BorderRadius.circular(AppRadius.lg),
    targetPadding: const EdgeInsets.all(6),
    overlayOpacity: 0.78,
    disableDefaultTargetGestures: true,
    child: child,
  );
}
