import 'dart:async';

import 'package:detoxo/features/blocking/blocking.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements BlockScreenRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const BlockScreenStyle.defaults());
    registerFallbackValue(BlockScreenPayload.preview());
  });

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.setStyle(any())).thenAnswer((_) async {});
  });

  test('hydrates from the repository', () async {
    const persisted = BlockScreenStyle(enabled: false, showOpens: false);
    when(repo.style).thenAnswer((_) async => persisted);
    final cubit = BlockScreenStyleCubit(repo);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, persisted);
    await cubit.close();
  });

  test('a burst of edits persists once, after the debounce', () async {
    when(repo.style).thenAnswer((_) async => const BlockScreenStyle.defaults());
    final cubit = BlockScreenStyleCubit(repo);
    await Future<void>.delayed(Duration.zero);

    cubit
      ..setShowCount(show: false)
      ..setShowOpens(show: false)
      ..setBackDelay(on: false);
    expect(cubit.state.showCount, isFalse);
    expect(cubit.state.showOpens, isFalse);
    expect(cubit.state.backDelaySec, 0);
    verifyNever(() => repo.setStyle(any()));

    await Future<void>.delayed(const Duration(milliseconds: 200));
    verify(() => repo.setStyle(cubit.state)).called(1);
    await cubit.close();
  });

  test('an edit that beats the hydrate wins', () async {
    final hydrate = Completer<BlockScreenStyle>();
    when(repo.style).thenAnswer((_) => hydrate.future);
    final cubit = BlockScreenStyleCubit(repo)..setEnabled(enabled: false);
    hydrate.complete(const BlockScreenStyle(showCount: false));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.enabled, isFalse);
    expect(cubit.state.showCount, isTrue); // not snapped back
    await cubit.close();
  });

  test('switching the wall off pushes enabled=false', () async {
    when(repo.style).thenAnswer((_) async => const BlockScreenStyle.defaults());
    final cubit = BlockScreenStyleCubit(repo);
    await Future<void>.delayed(Duration.zero);

    cubit.setEnabled(enabled: false);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final pushed =
        verify(() => repo.setStyle(captureAny())).captured.single
            as BlockScreenStyle;
    expect(pushed.enabled, isFalse);
    expect(pushed.toWire()['enabled'], isFalse);
    await cubit.close();
  });

  test('the back delay toggles between 5 s and instant', () async {
    when(repo.style).thenAnswer((_) async => const BlockScreenStyle.defaults());
    final cubit = BlockScreenStyleCubit(repo);
    await Future<void>.delayed(Duration.zero);

    cubit.setBackDelay(on: false);
    expect(cubit.state.backDelaySec, 0);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final pushed =
        verify(() => repo.setStyle(captureAny())).captured.single
            as BlockScreenStyle;
    expect(pushed.toWire(), {
      'enabled': true,
      'showCount': true,
      'showOpens': true,
      'backDelaySec': 0,
    });
    cubit.setBackDelay(on: true);
    expect(cubit.state.backDelaySec, 5);
    await cubit.close();
  });

  test('Try it right after the switch pushes the switch first', () async {
    when(repo.style).thenAnswer(
      (_) async => const BlockScreenStyle(enabled: false),
    );
    when(() => repo.preview(any())).thenAnswer((_) async => true);
    final cubit = BlockScreenStyleCubit(repo);
    await Future<void>.delayed(Duration.zero);

    cubit.setEnabled(enabled: true); // still inside the 120 ms debounce
    expect(await cubit.preview(BlockScreenPayload.preview()), isTrue);
    verifyInOrder([
      () => repo.setStyle(const BlockScreenStyle()),
      () => repo.preview(any()),
    ]);

    // Flushed, not repeated once the debounce would have fired (the push
    // above is already verified, so any further one would show here).
    await Future<void>.delayed(const Duration(milliseconds: 200));
    verifyNever(() => repo.setStyle(any()));
    await cubit.close();
  });

  test('Try it with nothing pending goes straight to the wall', () async {
    when(repo.style).thenAnswer((_) async => const BlockScreenStyle());
    when(() => repo.preview(any())).thenAnswer((_) async => true);
    final cubit = BlockScreenStyleCubit(repo);
    await Future<void>.delayed(Duration.zero);

    await cubit.preview(BlockScreenPayload.preview());
    verifyNever(() => repo.setStyle(any()));
    verify(() => repo.preview(any())).called(1);
    await cubit.close();
  });

  test('a failed hydrate keeps the defaults and never throws', () async {
    when(repo.style).thenThrow(Exception('channel down'));
    final cubit = BlockScreenStyleCubit(repo);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, const BlockScreenStyle.defaults());
    await cubit.close();
  });
}
