import 'dart:io';

import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/app_gate.dart';
import 'package:detoxo/core/navigation/app_router.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/services/firebase/firebase.dart';
import 'package:detoxo/features/analytics/presentation/analytics_screen.dart';
import 'package:detoxo/features/analytics/presentation/widgets/by_app_section.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Only the observer is touched while building the graph.
class _StubAnalytics implements AnalyticsService {
  @override
  NavigatorObserver get navigatorObserver => NavigatorObserver();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// Every path `GoRouter` actually knows about, flattened out of the built
/// configuration rather than restated here — a hand-kept list would be the
/// same drift the test exists to catch.
Set<String> registeredPaths(List<RouteBase> routes, [String prefix = '']) {
  final paths = <String>{};
  for (final route in routes) {
    var full = prefix;
    if (route is GoRoute) {
      full = route.path.startsWith('/')
          ? route.path
          : '$prefix/${route.path}'.replaceAll('//', '/');
      paths.add(full);
    }
    paths.addAll(registeredPaths(route.routes, full));
  }
  return paths;
}

void main() {
  setUpAll(() {
    sl
      ..registerSingleton<AnalyticsService>(_StubAnalytics())
      ..registerSingleton<AppGate>(AppGate());
  });
  tearDownAll(sl.reset);

  test('every path in routes.dart resolves to a registered route', () {
    // routes.dart is read as TEXT on purpose. Dart has no mirrors here, and a
    // hand-maintained `Routes.all` list would just move the drift somewhere
    // else — this way a constant cannot be added without being registered.
    //
    // `Routes.pause`, `Routes.curious` and `Routes.unsupported` all sat
    // declared-but-unregistered before M6: navigating to any of them failed at
    // runtime, and nothing caught it.
    final source = File('lib/core/navigation/routes.dart').readAsStringSync();
    final declared = RegExp(
      r"static const String \w+ = '([^']+)';",
    ).allMatches(source).map((m) => m.group(1)!).toSet();
    final registered = registeredPaths(buildRouter().configuration.routes);

    expect(
      declared,
      isNotEmpty,
      reason: 'the regex must actually match routes.dart',
    );
    expect(
      declared.difference(registered),
      isEmpty,
      reason: 'declared in routes.dart but registered nowhere',
    );
  });

  test('routes.dart declares paths only', () {
    // The test above resolves every constant as a path, so a non-path constant
    // (a query-parameter name, say) would break it. Keep them out.
    final source = File('lib/core/navigation/routes.dart').readAsStringSync();
    for (final m in RegExp(
      r"static const String \w+ = '([^']+)';",
    ).allMatches(source)) {
      expect(m.group(1), startsWith('/'), reason: 'not a route path');
    }
  });

  test('no route is registered twice', () {
    // `/home` and `/blocklist` both built HomeShell before M6, which is how the
    // two tabs ended up sharing one navigation stack.
    final paths = <String>[];
    void walk(List<RouteBase> routes) {
      for (final r in routes) {
        if (r is GoRoute) paths.add(r.path);
        walk(r.routes);
      }
    }

    walk(buildRouter().configuration.routes);
    expect(paths.length, paths.toSet().length, reason: 'duplicate route path');
  });

  testWidgets('the Activity route opens By app on its ?segment=', (
    tester,
  ) async {
    // EVO-072: the home-widget tap writes the query, this builder reads it.
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));
    final config = buildRouter().configuration;
    final activity = config.routes.whereType<GoRoute>().singleWhere(
      (r) => r.path == Routes.analytics,
    );
    ByAppSegment opened(String location) {
      final uri = Uri.parse(location);
      final screen = activity.builder!(
        context,
        GoRouterState(
          config,
          uri: uri,
          matchedLocation: uri.path,
          fullPath: uri.path,
          pathParameters: const {},
          pageKey: const ValueKey('activity'),
        ),
      );
      return (screen as AnalyticsScreen).segment;
    }

    expect(opened('/analytics?segment=time'), ByAppSegment.time);
    expect(opened('/analytics'), ByAppSegment.reels);
    expect(opened('/analytics?segment=hourly'), ByAppSegment.reels);
  });
}
