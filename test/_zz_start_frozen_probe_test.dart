import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import 'package:flutter_test/flutter_test.dart';

// Probe: does BottomBar re-read `start` after the inset changes? Mount at
// inset 0, rebuild at inset 48 (portrait 3-button nav), hide, measure the bar.
const _h = 800.0;
const _barKey = ValueKey('bar');

Widget _shell(double inset, double Function(double inset) start) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(400, _h),
      padding: EdgeInsets.only(bottom: inset),
      viewPadding: EdgeInsets.only(bottom: inset),
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(
        builder: (context) => BottomBar(
          fit: StackFit.expand,
          barColor: Colors.transparent,
          width: 128,
          offset: AppSpacing.floatingNavLift,
          start: start(MediaQuery.paddingOf(context).bottom),
          duration: AppDurations.normal,
          curve: AppCurves.standard,
          showIcon: false,
          body: (context, controller) => ListView(
            controller: controller,
            children: [
              for (var i = 0; i < 60; i++)
                const SizedBox(height: 50, child: Text('row')),
            ],
          ),
          child: const SizedBox(
            key: _barKey,
            height: AppSpacing.floatingNavHeight,
          ),
        ),
      ),
    ),
  );
}

double _derived(double inset) =>
    1 + (AppSpacing.floatingNavLift + inset) / AppSpacing.floatingNavHeight;
double _const3(double _) => 3;

Future<Rect> _hiddenRect(
  WidgetTester tester,
  double Function(double) start,
) async {
  await tester.pumpWidget(_shell(0, start));
  await tester.pumpAndSettle();
  // Inset arrives later (rotation to portrait under 3-button nav).
  await tester.pumpWidget(_shell(48, start));
  await tester.pumpAndSettle();
  final shown = tester.getRect(find.byKey(_barKey));
  expect(shown.bottom, _h - 48 - AppSpacing.floatingNavLift);
  // Scroll down => hide.
  await tester.drag(find.byType(ListView), const Offset(0, -300));
  await tester.pumpAndSettle();
  return tester.getRect(find.byKey(_barKey));
}

void main() {
  testWidgets('derived start frozen at first build', (tester) async {
    final r = await _hiddenRect(tester, _derived);
    // ignore: avoid_print
    print('DERIVED hidden rect: $r  (screen h=$_h) visibleBand=${_h - r.top}');
  });

  testWidgets('const start 3', (tester) async {
    final r = await _hiddenRect(tester, _const3);
    // ignore: avoid_print
    print('CONST3 hidden rect: $r  (screen h=$_h) visibleBand=${_h - r.top}');
  });

  testWidgets('derived start, portrait-first then landscape then portrait', (
    tester,
  ) async {
    await tester.pumpWidget(_shell(48, _derived));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_shell(0, _derived));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_shell(48, _derived));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    final r = tester.getRect(find.byKey(_barKey));
    // ignore: avoid_print
    print('PORTRAIT-FIRST hidden rect: $r visibleBand=${_h - r.top}');
  });
}
