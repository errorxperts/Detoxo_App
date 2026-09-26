import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/features/limits/rules/presentation/widgets/removable_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one shared "remove this target" chip wrap: its label maps through,
/// a screen reader hears "Remove …" rather than "…, selected", and a tap
/// hands back the raw item, not the label.
void main() {
  testWidgets('labels, announces removal, and pops the raw item', (
    tester,
  ) async {
    final removed = <String>[];
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        // AppTheme pulls google_fonts, which stalls under flutter_test.
        theme: ThemeData(
          brightness: Brightness.dark,
          extensions: const [GlassTokens.dark],
        ),
        home: Scaffold(
          body: RemovableChips(
            items: const ['com.a', 'com.b'],
            label: (id) => id == 'com.a' ? 'Alpha' : id,
            onRemove: removed.add,
          ),
        ),
      ),
    );
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('com.b'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Alpha')).label,
      contains('Remove Alpha'),
    );
    await tester.tap(find.text('Alpha'));
    expect(removed, ['com.a']);
    semantics.dispose();
  });
}
