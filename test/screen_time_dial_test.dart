import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/onboarding/presentation/widgets/screen_time_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _theme() => AppTheme.dark();

/// Under Reduce Motion, where `pumpAndSettle` also proves nothing loops.
Future<void> _pumpChild(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        theme: theme ?? _theme(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the daily-limit dial paints in both themes and steps by 15m', (
    tester,
  ) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      var value = const Duration(minutes: 90);
      await _pumpChild(
        tester,
        StatefulBuilder(
          builder: (context, setState) => ScreenTimeDial(
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
        theme: theme,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('1h 30m'), findsOneWidget);
      // The slider's increase action, as TalkBack sends it.
      tester
          .widget<Semantics>(
            find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == 'Daily limit',
            ),
          )
          .properties
          .onIncrease!();
      await tester.pumpAndSettle();
      expect(value, const Duration(minutes: 105));
      expect(find.text('1h 45m'), findsOneWidget);
    }
  });
}
