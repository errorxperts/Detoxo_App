import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/limits/limits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// The card says what is left, derived from the clock and `overridesLeft` at
/// build time, so it must repaint on the resync emit that moves `overridesLeft`
/// on an unchanged ledger — a ledger-only `buildWhen` used to filter exactly
/// that one. It never counts what was spent or lists the reasons.

/// A cubit whose state the test sets directly; nothing else on it is called.
class _StubUnblock extends Cubit<UnblockState> implements UnblockCubit {
  _StubUnblock(super.state);

  void push(UnblockState next) => emit(next);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnsupportedError('${i.memberName} not used by the card');
}

void main() {
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final ledger = [
    BypassEntry(
      kind: BypassKind.override,
      atMs: nowMs - 3600000,
      reason: OverrideReason.family,
    ),
  ];
  UnblockState state(
    int left, {
    List<BypassEntry>? spent,
    BypassConfig config = BypassConfig.defaults,
  }) => UnblockState(
    loaded: true,
    ledgerLoaded: true,
    ledger: spent ?? ledger,
    config: config,
    overridesLeft: left,
  );

  Future<_StubUnblock> pump(WidgetTester tester, UnblockState initial) async {
    final cubit = _StubUnblock(initial);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: BlocProvider<UnblockCubit>.value(
            value: cubit,
            child: const OverrideHistoryCard(),
          ),
        ),
      ),
    );
    await tester.pump();
    return cubit;
  }

  testWidgets('a resync that moves overridesLeft on the same ledger repaints', (
    tester,
  ) async {
    final cubit = await pump(tester, state(1));
    expect(find.text('1 override left this week'), findsOneWidget);
    // What is left, never the ledger: no reason, no spent count.
    expect(find.textContaining('Family'), findsNothing);
    expect(find.textContaining('this period'), findsNothing);
    // One standalone row, its own panel.
    expect(find.byType(GlassListTile), findsOneWidget);
    expect(find.byType(GlassContainer), findsOneWidget);

    // The period rolled over and the timer resync re-derived the quota: the
    // ledger is the same list, only `overridesLeft` moved.
    cubit.push(state(2));
    // One pump delivers the stream event, the next paints the rebuild.
    await tester.pump();
    await tester.pump();
    expect(find.text('2 overrides left this week'), findsOneWidget);
    expect(find.text('1 override left this week'), findsNothing);
    expect(find.textContaining('Family'), findsNothing);
  });

  testWidgets('a daily quota says today, and none left says so', (
    tester,
  ) async {
    await pump(
      tester,
      state(0, config: const BypassConfig(overridePeriod: BypassPeriod.day)),
    );
    expect(find.text('No overrides left today'), findsOneWidget);
  });

  testWidgets('nothing spent this period draws nothing', (tester) async {
    await pump(tester, state(2, spent: const []));
    expect(find.byType(GlassListTile), findsNothing);
    expect(find.textContaining('override'), findsNothing);
  });
}
