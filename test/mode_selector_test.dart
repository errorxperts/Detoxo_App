import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/reel_session_state.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/mode_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme pulls google_fonts, which stalls under flutter_test — the selector
// only needs GlassTokens plus a ColorScheme.
final _theme = ThemeData(
  brightness: Brightness.dark,
  extensions: const [GlassTokens.dark],
);

Future<DashboardMode?> _pump(
  WidgetTester tester, {
  DashboardMode selected = DashboardMode.blockAll,
  ReelSessionState session = const ReelSessionState(),
}) async {
  DashboardMode? tapped;
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: ModeSelector(
            selected: selected,
            reelSession: session,
            onSelect: (m) => tapped = m,
          ),
        ),
      ),
    ),
  );
  // The test bundle has no assets, so a decode failure is expected noise.
  expect(tester.takeException(), anyOf(isNull, isA<FlutterError>()));
  return tapped;
}

void main() {
  testWidgets('renders one labelled illustration coin per mode', (
    tester,
  ) async {
    await _pump(tester);

    for (final label in [
      'Block All',
      'Conscious',
      'Pause',
      'One Reel',
      'Unblock',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    // Every pill carries artwork — a mode wired to a missing asset would drop
    // one of these.
    expect(find.byType(Image), findsNWidgets(5));
  });

  testWidgets('badges the active reel pill with the remaining count', (
    tester,
  ) async {
    await _pump(
      tester,
      selected: DashboardMode.unblock,
      session: const ReelSessionState(allowance: 5, consumed: 2, active: true),
    );
    expect(find.text('3'), findsOneWidget);
    // The badged pill keeps its artwork — the count is stacked on the coin,
    // not swapped for it.
    expect(find.byType(Image), findsNWidgets(5));

    // Inactive session → no badge.
    await _pump(tester, selected: DashboardMode.unblock);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('taps report the tapped mode', (tester) async {
    DashboardMode? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ModeSelector(
              selected: DashboardMode.blockAll,
              reelSession: const ReelSessionState(),
              onSelect: (m) => tapped = m,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), anyOf(isNull, isA<FlutterError>()));

    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(tapped, DashboardMode.pause);
  });
}
