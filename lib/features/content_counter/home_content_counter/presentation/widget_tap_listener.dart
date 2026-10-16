import 'dart:async';

import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/app_gate.dart';
import 'package:detoxo/core/navigation/app_router.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/services/firebase/analytics/analytics_service.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/widget_tap.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/repositories/home_widget_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Opens what a home-widget tap asked for (IM-08): the screen behind the
/// tapped widget's number (EVO-072), or the setting / grant that fixes a
/// widget that can't track.
///
/// Mounted next to `PendingUnblockListener` in `MaterialApp.router`'s
/// `builder`, so it survives every route change but sits above the
/// `Navigator`: it routes through [appNavigatorKey].
///
/// The tap launches Detoxo and native holds it until `takePendingWidgetTap`
/// reads it, so this drains once the gate opens (a cold or PIN-locked
/// launch) and on every resume (a warm one).
class WidgetTapListener extends StatefulWidget {
  const WidgetTapListener({required this.child, super.key});

  final Widget child;

  @override
  State<WidgetTapListener> createState() => _WidgetTapListenerState();
}

class _WidgetTapListenerState extends State<WidgetTapListener>
    with WidgetsBindingObserver {
  final AppGate _gate = sl<AppGate>();

  /// A tap read just before a re-lock went up, opened once it is dismissed.
  WidgetTap? _held;

  @override
  void initState() {
    super.initState();
    _gate.screensMayOpenChanged.addListener(_drain);
    WidgetsBinding.instance.addObserver(this);
    _drain();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gate.screensMayOpenChanged.removeListener(_drain);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _drain();
  }

  /// Waits behind the PIN (the launch gate and a resume's re-lock) and the
  /// first run rather than dropping the tap: the read clears it natively, so
  /// it is taken only once it can open.
  void _drain() {
    if (!_gate.screensMayOpen) return;
    final held = _held;
    _held = null;
    if (held != null) {
      _route(held);
    } else {
      unawaited(_take());
    }
  }

  Future<void> _take() async {
    final tap = await sl<HomeWidgetRepository>().takePendingTap();
    if (tap == null) return;
    // A re-lock that went up during the read: open the tap once it is gone.
    if (!_gate.screensMayOpen) {
      _held = tap;
      return;
    }
    _route(tap);
  }

  void _route(WidgetTap tap) {
    // ponytail: a tap read while no Navigator is mounted is dropped. With the
    // gate open the router is up, so only a mid-teardown read can lose one;
    // re-queue it natively if that ever shows up.
    final nav = appNavigatorKey.currentContext;
    if (nav == null || !nav.mounted) return;
    unawaited(
      sl<AnalyticsService>().logWidgetOpened(
        family: tap.family.wire,
        size: tap.size.wire,
      ),
    );
    final router = GoRouter.of(nav);
    final to = _location(tap);
    if (to == Routes.home) return _toDashboard(router);
    // Tapping again while that screen is still on top replaces it, so the
    // back stack doesn't grow by one copy per tap.
    final onTop = router.state.uri.path == Uri.parse(to).path;
    unawaited(onTop ? router.pushReplacement<void>(to) : router.push<void>(to));
  }

  /// A Plan tap (EVO-073): the Dashboard, where plans switch, is the stack's
  /// root HomeShell, so it pops back to that shell — never a second one —
  /// and asks it for its Dashboard tab. Not over a screen holding unsaved
  /// input: like AppGate's permissions funnel, the tap is not worth the
  /// user's work, so they stay where they are.
  void _toDashboard(GoRouter router) {
    final stack = router.routerDelegate.currentConfiguration.matches;
    if (stack.any((m) => _keepsInput.contains(m.matchedLocation))) return;
    router.go(
      Uri(
        path: Routes.home,
        queryParameters: {'dashboard': '${++_dashboardRequests}'},
      ).toString(),
    );
  }

  /// Screens whose unsaved input a Plan tap must not throw away.
  static const _keepsInput = {Routes.ruleEditor, Routes.pinSetup};

  /// Makes every Plan tap a new request, so a repeat tap brings the
  /// Dashboard tab forward again.
  static var _dashboardRequests = 0;

  /// The screen behind the tapped widget's number (EVO-072). Exhaustive over
  /// [WidgetFamily] (DS-10), so a new family must pick its screen to compile.
  static String _location(WidgetTap tap) => switch (tap.target) {
    WidgetTapTarget.appearance => Routes.appearance,
    WidgetTapTarget.permissions => Routes.permissions,
    WidgetTapTarget.settings => Routes.settings,
    WidgetTapTarget.activity => switch (tap.family) {
      // The widget's own meter, "12 of 30 min used", and the slider that
      // sets one when the widget says "No daily limit".
      // ponytail: a limit set only by a reel time-limit rule opens a Daily
      // limit screen reading "No daily limit set"; open Routes.rules for it
      // if that shows up.
      WidgetFamily.timeLimit => Routes.dailyLimit,
      // Where the watch time went, app by app: By app on Time. `segment` is
      // read by `ByAppSegment.fromQuery` in app_router.dart. Without Usage
      // access there is no Time segment and Activity shows Reels.
      WidgetFamily.rhythm => '${Routes.analytics}?segment=time',
      // The Dashboard's mode selector, where plans switch (EVO-073).
      WidgetFamily.plan => Routes.home,
      // Today's reels: the Today panel's Reels tile, By app on Reels.
      WidgetFamily.count ||
      WidgetFamily.nextColour ||
      WidgetFamily.bonsai ||
      WidgetFamily.bento => Routes.analytics,
    },
  };

  @override
  Widget build(BuildContext context) => widget.child;
}
