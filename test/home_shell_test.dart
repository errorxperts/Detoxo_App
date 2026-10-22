import 'package:detoxo/core/constants/app_constants.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/services/firebase/firebase.dart';
import 'package:detoxo/features/additional_feature/app_upgrader/app_upgrader.dart';
import 'package:detoxo/features/dashboard/presentation/home_shell.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Analytics implements AnalyticsService {
  final screens = <String>[];

  @override
  Future<void> logScreenView(String screenName) async =>
      screens.add(screenName);

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _NoUpgrade implements AppUpgradeService {
  @override
  Future<UpgradeStatus?> check({bool force = false}) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// HomeShell with stand-in tabs: each a tab list headed 'Tab <i>', a toast
/// trigger, then a tall tap target that runs under the tab bar.
void main() {
  late _Analytics analytics;
  var bodyTaps = 0;

  setUp(() async {
    await sl.reset();
    analytics = _Analytics();
    bodyTaps = 0;
    sl
      ..registerSingleton<AnalyticsService>(analytics)
      ..registerSingleton<AppUpgradeService>(_NoUpgrade());
  });

  tearDown(sl.reset);

  Widget tab(int i, VoidCallback onMenu) => Builder(
    builder: (context) => ListView(
      padding: TabHeader.listPadding(context),
      children: [
        TabHeader(title: 'Tab $i', onMenu: onMenu),
        TextButton(
          onPressed: () => GlassToast.show(context, 'Saved'),
          child: const Text('toast'),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => bodyTaps++,
          child: const SizedBox(height: 2000),
        ),
      ],
    ),
  );

  Future<void> pumpShell(WidgetTester tester, {String? request}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeShell(dashboardRequest: request, tabBuilder: tab),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tabBar(String label) =>
      find.descendant(of: find.byType(AppTabBar), matching: find.text(label));

  testWidgets('Today / Insights tabs keep the old screen_view names', (
    tester,
  ) async {
    await pumpShell(tester);
    expect(tabBar('Today'), findsOneWidget);
    expect(find.text('Tab 0'), findsOneWidget);

    await tester.tap(tabBar('Insights'));
    await tester.pumpAndSettle();
    // Only the active tab is built.
    expect(find.text('Tab 0'), findsNothing);
    expect(find.text('Tab 1'), findsOneWidget);

    await tester.tap(tabBar('Insights'));
    await tester.tap(tabBar('Today'));
    await tester.pumpAndSettle();
    expect(find.text('Tab 0'), findsOneWidget);
    // A tap on the current tab logs nothing.
    expect(analytics.screens, ['Activity', 'Dashboard']);
  });

  testWidgets('a new ?dashboard= request forces Today', (tester) async {
    await pumpShell(tester);
    await tester.tap(tabBar('Insights'));
    await tester.pumpAndSettle();
    expect(find.text('Tab 1'), findsOneWidget);

    await pumpShell(tester, request: '1');
    expect(find.text('Tab 0'), findsOneWidget);
  });

  testWidgets('the bar floats 30 above the inset; the fade takes no taps', (
    tester,
  ) async {
    tester.view.viewPadding = const FakeViewPadding(bottom: 24 * 3);
    tester.view.padding = const FakeViewPadding(bottom: 24 * 3);
    addTearDown(tester.view.reset);
    await pumpShell(tester);

    final screen = tester.getRect(find.byType(HomeShell));
    final bar = tester.getRect(find.byType(AppTabBar));
    expect(bar.size, AppTabBar.size);
    expect(bar.center.dx, screen.center.dx);
    expect(bar.bottom, screen.bottom - 24 - 30);

    // Just above the bar, in the fade, and beside it: the list gets both.
    await tester.tapAt(Offset(bar.center.dx, bar.top - 12));
    await tester.tapAt(Offset(screen.left + 30, bar.center.dy));
    expect(bodyTaps, 2);
  });

  testWidgets('a floating toast sits above the bar', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.text('toast'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Saved')).bottom,
      lessThan(tester.getRect(find.byType(AppTabBar)).top),
    );
  });

  testWidgets('the tab header sits max(54, safe top + 8) from the top', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    for (final (safeTop, headerTop) in [
      (0.0, 54.0),
      (24.0, 54.0),
      (60.0, 68.0),
    ]) {
      tester.view.padding = FakeViewPadding(top: safeTop * 3);
      tester.view.viewPadding = FakeViewPadding(top: safeTop * 3);
      await pumpShell(tester);
      expect(
        tester.getTopLeft(find.byType(TabHeader)).dy,
        headerTop,
        reason: 'safe top $safeTop',
      );
    }
  });

  testWidgets('the sidebar: a sheet of flat rows, no Activity', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    final drawer = find.byType(AppDrawer);
    Finder inDrawer(Finder f) => find.descendant(of: drawer, matching: f);
    for (final label in [
      'Daily limit',
      'Appearance',
      'PIN lock',
      'Settings',
      'Help & support',
    ]) {
      expect(inDrawer(find.text(label)), findsOneWidget, reason: label);
    }
    expect(inDrawer(find.text('Activity')), findsNothing);
    expect(inDrawer(find.byType(GlassListTile)), findsNWidgets(5));
    // Hairlines between the rows, an ink-3 chevron on each.
    expect(inDrawer(find.byType(Divider)), findsNWidgets(4));
    expect(inDrawer(find.byType(Glyph)), findsNWidgets(5));
    expect(inDrawer(find.text('v${AppConstants.appVersion}')), findsOneWidget);

    // The sheet sits 10 in from the screen's right edge, radius 40.
    final sheet = tester.widget<GlassContainer>(
      inDrawer(find.byType(GlassContainer)).first,
    );
    expect(sheet.surface, DxSurface.sheet);
    expect(
      tester.getRect(inDrawer(find.byType(GlassContainer)).first).right,
      tester.getRect(find.byType(HomeShell)).right - 10,
    );
  });
}
