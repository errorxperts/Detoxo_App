import 'dart:ui' show Tristate;

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/blocking.dart' show BlockingMode;
import 'package:detoxo/features/settings/presentation/widgets/block_mode_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _theme = AppTheme.dark();

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  testWidgets('offers the four modes and announces the selected one', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      BlockModeOptions(selected: BlockingMode.blockScreen, onSelect: (_) {}),
    );

    for (final label in [
      'Press back',
      'Block screen',
      'Close the app',
      'Lock app',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    // Exactly one row is selected, and the check is not the only signal.
    final selected = tester
        .widgetList<GlassListTile>(find.byType(GlassListTile))
        .where((t) => t.selected ?? false)
        .toList();
    expect(selected.map((t) => t.title), ['Block screen']);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Closes the app'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Block screen')).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(find.text('Press back')).flagsCollection.isSelected,
      isNot(Tristate.isTrue),
    );
    handle.dispose();
  });

  testWidgets('tapping a row reports that mode', (tester) async {
    BlockingMode? picked;
    await _pump(
      tester,
      BlockModeOptions(
        selected: BlockingMode.pressBack,
        onSelect: (m) => picked = m,
      ),
    );
    await tester.tap(find.text('Close the app'));
    expect(picked, BlockingMode.killApp);
  });

  testWidgets(
    'the entry tile names the mode and warns only without the grant',
    (tester) async {
      var granted = 0;
      await _pump(
        tester,
        BlockModeTile(
          mode: BlockingMode.blockScreen,
          needsOverlay: true,
          onTap: () {},
          onGrant: () => granted++,
        ),
      );
      expect(find.text('Block screen'), findsOneWidget);
      expect(find.text('Display over other apps'), findsOneWidget);
      expect(find.text('Needs access'), findsOneWidget);
      await tester.tap(find.text('Display over other apps'));
      expect(granted, 1);

      await _pump(
        tester,
        BlockModeTile(
          mode: BlockingMode.blockScreen,
          needsOverlay: false,
          onTap: () {},
          onGrant: () {},
        ),
      );
      expect(find.text('Needs access'), findsNothing);
    },
  );
}
