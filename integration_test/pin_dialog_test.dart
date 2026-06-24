import 'package:detoxo/core/design_system/components/dialog.dart';
import 'package:detoxo/core/design_system/components/overlays.dart';
import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Runs on the REAL macOS engine (native CNButton/CNSwitch), so it reproduces
/// native platform-view layout that `flutter test` fakes away.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('confirm dialog (turn-off PIN) lays out and is tappable',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => AppDialog.confirm(
                  context: context,
                  title: 'Turn off PIN lock?',
                  message:
                      'Detoxo and its protected sections will no longer ask '
                      'for a PIN.',
                  confirmLabel: 'Turn off',
                  cancelLabel: 'Keep it on',
                  destructive: true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'opening the dialog');
    expect(find.text('Turn off PIN lock?'), findsOneWidget);

    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'tapping confirm');
  });

  testWidgets('toast then pop (save PIN pattern) does not crash',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const _Host(),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('do save+pop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: 'toast + pop');
  });
}

class _Host extends StatelessWidget {
  const _Host();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Builder(
                    builder: (inner) => Center(
                      child: ElevatedButton(
                        onPressed: () {
                          GlassToast.show(inner, 'PIN saved.');
                          Navigator.of(inner).pop();
                        },
                        child: const Text('do save+pop'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      );
}
