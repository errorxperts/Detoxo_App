import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/services/firebase/firebase.dart';
import 'package:detoxo/features/additional_feature/app_upgrader/app_upgrader.dart';
import 'package:detoxo/features/additional_feature/showcase_view/showcase_view.dart';
import 'package:detoxo/features/analytics/presentation/analytics_screen.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/features/dashboard/presentation/dashboard_tab.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The main authenticated surface: the Today and Insights tabs over the ground
/// gradient, with the static glass [AppTabBar] floating 30 above the bottom
/// inset on a fade to `bgBottom`. The sidebar ([AppDrawer]) opens from each
/// tab header's Menu button. Only the active tab is built.
class HomeShell extends StatefulWidget {
  const HomeShell({this.dashboardRequest, this.tabBuilder, super.key});

  /// Changes each time something asks for the Today tab (a Plan widget tap,
  /// EVO-073, via `/home?dashboard=<n>`): the shell switches to it even when
  /// it is already showing, on another tab.
  final String? dashboardRequest;

  /// Builds tab `index`'s body in place of Today / Insights, so a test can
  /// pump the shell without every cubit the real tabs read.
  @visibleForTesting
  final Widget Function(int index, VoidCallback onMenu)? tabBuilder;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void didUpdateWidget(HomeShell old) {
    super.didUpdateWidget(old);
    final request = widget.dashboardRequest;
    if (request != null && request != old.dashboardRequest) _index = 0;
  }

  // Drives the end-drawer (the sidebar) via the inner Scaffold.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  void _openDrawer() => _scaffoldKey.currentState?.openEndDrawer();

  static const _tabs = <TabItem>[
    (
      label: 'Today',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    (
      label: 'Insights',
      icon: Icons.leaderboard_outlined,
      selectedIcon: Icons.leaderboard,
    ),
  ];

  /// The `screen_view` name of each tab: the names from before the
  /// Today / Insights rename, so the analytics series stay continuous.
  static const _screens = ['Dashboard', 'Activity'];

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    // Tabs don't change the route, so log the view manually.
    unawaited(sl<AnalyticsService>().logScreenView(_screens[i]));
  }

  Widget _tab() =>
      widget.tabBuilder?.call(_index, _openDrawer) ??
      switch (_index) {
        0 => DashboardTab(onMenu: _openDrawer),
        _ => AnalyticsTab(onMenu: _openDrawer),
      };

  @override
  Widget build(BuildContext context) {
    // Lighter drawer dim in light theme: the scrim sits behind the glass drawer
    // and is blurred into it, so a heavy black scrim would make the frosted
    // panel read murky/dark instead of as light glass.
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Provides the UpgradeCubit + runs the automatic update check, and shows the
    // glass update dialog. Wrapping the scaffold puts the drawer in cubit scope
    // for the manual "Check for updates" entry.
    return UpgradeGate(
      child: GlassScaffold(
        safeArea: false,
        scaffoldKey: _scaffoldKey,
        endDrawer: const AppDrawer(),
        drawerScrimColor: Colors.black.withValues(alpha: dark ? 0.5 : 0.22),
        // The Scaffold's bottom bar, so floating toasts sit above it.
        bottomBar: _TabBarHost(
          items: _tabs,
          current: _index,
          onSelect: _select,
        ),
        body: buildFeatureShowcaseScope(
          // Persist on finish AND dismiss so a skipped tour is remembered too.
          onSeen: () =>
              context.read<SettingsCubit>().setShowcaseSeen(value: true),
          child: SafeArea(
            bottom: false,
            // With the lists' `inset` on top, the tab header sits headerTop
            // below the screen top, or `inset` below a taller status bar.
            minimum: const EdgeInsets.only(
              top: AppSpacing.headerTop - AppSpacing.inset,
            ),
            child: _tab(),
          ),
        ),
      ),
    );
  }
}

/// The bottom bar slot: a fade to `bgBottom` behind the [AppTabBar], which
/// floats [_lift] above the bottom inset. The fade never takes a touch, so
/// the list under it stays scrollable.
class _TabBarHost extends StatelessWidget {
  const _TabBarHost({
    required this.items,
    required this.current,
    required this.onSelect,
  });

  final List<TabItem> items;
  final int current;
  final ValueChanged<int> onSelect;

  /// The bar's gap above the bottom inset (spec TabBar).
  static const double _lift = 30;

  /// How far the fade reaches above the bar.
  static const double _fade = AppSpacing.xl;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final ground = context.tokens.bgBottom;
    return SizedBox(
      height: _fade + AppTabBar.size.height + _lift + inset,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [ground.withValues(alpha: 0), ground],
                    stops: const [0, .55],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: _lift + inset),
            child: AppTabBar(
              items: items,
              current: current,
              onSelect: onSelect,
            ),
          ),
        ],
      ),
    );
  }
}
