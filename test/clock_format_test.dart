import 'package:detoxo/core/utils/clock_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Formats [minutes] under the device's 12/24-hour setting.
Future<String> _format(
  WidgetTester tester,
  int minutes, {
  required bool use24,
}) async {
  late String out;
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(alwaysUse24HourFormat: use24),
        child: Builder(
          builder: (context) {
            out = formatLocalTime(context, minutes);
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return out;
}

void main() {
  testWidgets('a 12-hour clock drops a zero minute', (tester) async {
    expect(await _format(tester, 23 * 60, use24: false), '11 PM');
    expect(await _format(tester, 7 * 60 + 30, use24: false), '7:30 AM');
    expect(await _format(tester, 12 * 60 + 5, use24: false), '12:05 PM');
  });

  testWidgets('a 24-hour clock keeps it', (tester) async {
    expect(await _format(tester, 23 * 60, use24: true), '23:00');
    expect(await _format(tester, 7 * 60 + 30, use24: true), '07:30');
  });
}
