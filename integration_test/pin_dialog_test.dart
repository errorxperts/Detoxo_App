import 'package:detoxo/core/design_system/components/confirm_sheet.dart';
import 'package:detoxo/core/design_system/components/overlays.dart';
import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/features/access_protection/access_protection.dart';
import 'package:detoxo/features/access_protection/presentation/pin_cubit.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class _FakePinRepo implements PinRepository {
  PinConfig _stored = const PinConfig(type: PinType.custom);
  @override
  Future<PinConfig> load() async => _stored;
  @override
  Future<void> save(PinConfig config) async => _stored = config;
  @override
  Future<void> setSecureScreen({required bool enabled}) async {}
  @override
  Future<int> lastScreenOffMillis() async => 0;
  @override
  Future<({int elapsedMs, int bootCount})?> monotonicNow() async => null;
}

/// Runs on the REAL macOS engine (native CNButton/CNSwitch), so it reproduces
/// native platform-view layout that `flutter test` fakes away.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Opens `confirmPinOff` over a configured PIN; returns its answer.
  Future<({PinCubit cubit, Future<bool> answer})> open(
    WidgetTester tester,
  ) async {
    final repo = _FakePinRepo();
    final cubit = PinCubit(repo);
    await cubit.load();
    late Future<bool> answer;
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => answer = confirmPinOff(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull, reason: 'opening the sheet');
    return (cubit: cubit, answer: answer);
  }

  testWidgets('confirmPinOff lays out, waits, then confirms', (tester) async {
    final semantics = tester.ensureSemantics();
    final (:cubit, :answer) = await open(tester);
    expect(find.text('Turn off PIN lock?'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(ConfirmSheet.knobKey)),
      isSemantics(isEnabled: false),
      reason: 'disabled during the wait',
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    tester.semantics.tap(find.semantics.byLabel('Slide to turn off'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'confirming');
    expect(await answer, isTrue);
    expect(cubit.state.isConfigured, isFalse);
    semantics.dispose();
  });

  testWidgets('confirmPinOff: cancel returns false', (tester) async {
    final (:cubit, :answer) = await open(tester);
    await tester.tap(find.text('Keep it on'));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);
    expect(cubit.state.isConfigured, isTrue);
  });

  testWidgets('toast then pop (save PIN pattern) does not crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const _Host()),
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
