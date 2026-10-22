import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/limits/limits.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the sheet and returns its answer.
Future<Future<Duration?>> _open(
  WidgetTester tester, {
  Duration? maxWindow,
  int? remaining,
}) async {
  late Future<Duration?> result;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showUnblockDurationSheet(
              context,
              title: 'Unblock YouTube?',
              icon: Assets.images.icons.iconAppBlocker,
              maxWindow: maxWindow,
              remaining: remaining,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(AppDurations.sheet);
  return result;
}

void main() {
  testWidgets('no allowances left: a toast, and no sheet', (tester) async {
    final result = await _open(tester, remaining: 0);
    expect(await result, isNull);
    expect(find.text(UnblockCubit.noGrantsLeft), findsOneWidget);
    expect(find.text('Unblock YouTube?'), findsNothing);
  });

  testWidgets('chips capped by maxWindow, 5 min picked, the allowances line; '
      'wait and slide return the window', (tester) async {
    final semantics = tester.ensureSemantics();
    final result = await _open(
      tester,
      maxWindow: const Duration(minutes: 30),
      remaining: 2,
    );
    expect(find.text('Unblock YouTube?'), findsOneWidget);
    expect(
      find.text('It gets blocked again when the time is up.'),
      findsOneWidget,
    );
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('60 min'), findsNothing);
    expect(find.text('2 allowances left in this period.'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('5 min')),
      isSemantics(hasSelectedState: true, isSelected: true),
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    tester.semantics.tap(find.semantics.byLabel('Slide to unblock'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(AppDurations.sheet);
    expect(await result, const Duration(minutes: 5));
    semantics.dispose();
  });

  testWidgets('Keep it blocked returns null', (tester) async {
    final result = await _open(tester);
    await tester.tap(find.text('Keep it blocked'));
    await tester.pump();
    await tester.pump(AppDurations.sheet);
    expect(await result, isNull);
  });
}
