import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/limits/limits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Today's "allowed right now" rows: the caller's name for the grant, never
/// the raw id when one is known; "Block now" ends exactly that grant; nothing
/// at all while nothing is allowed.

/// A cubit whose state the test sets; `endEarly` is recorded, nothing else
/// on it is called.
class _StubUnblock extends Cubit<UnblockState> implements UnblockCubit {
  _StubUnblock(super.state);

  final ended = <(UnblockTargetType, String)>[];

  @override
  Future<bool> endEarly(
    UnblockTargetType type,
    String targetId, {
    List<String> alsoEnd = const [],
  }) async {
    ended.add((type, targetId));
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnsupportedError('${i.memberName} not used by the card');
}

void main() {
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final grant = TemporaryUnblock(
    targetType: UnblockTargetType.app,
    targetId: 'com.instagram.android',
    startMs: nowMs - 60000,
    endMs: nowMs + 15 * 60000,
  );

  Future<_StubUnblock> pump(
    WidgetTester tester,
    List<TemporaryUnblock> active,
  ) async {
    final cubit = _StubUnblock(UnblockState(loaded: true, active: active));
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BlocProvider<UnblockCubit>.value(
            value: cubit,
            child: ActiveUnblocksCard(
              nameOf: (g) =>
                  g.targetId == 'com.instagram.android' ? 'Instagram' : '?',
            ),
          ),
        ),
      ),
    );
    return cubit;
  }

  testWidgets('shows the name, not the id, and when it closes', (tester) async {
    await pump(tester, [grant]);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('com.instagram.android'), findsNothing);
    expect(find.textContaining('Allowed until '), findsOneWidget);
  });

  testWidgets('"Block now" ends that grant, and says which', (tester) async {
    final semantics = tester.ensureSemantics();
    final cubit = await pump(tester, [grant]);
    expect(find.bySemanticsLabel('Block Instagram now'), findsOneWidget);
    await tester.tap(find.text('Block now'));
    expect(cubit.ended, [(UnblockTargetType.app, 'com.instagram.android')]);
    semantics.dispose();
  });

  testWidgets('renders nothing when nothing is allowed', (tester) async {
    await pump(tester, const []);
    expect(find.byType(GlassListTile), findsNothing);
    expect(find.text('Block now'), findsNothing);
  });
}
