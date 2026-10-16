import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:detoxo/features/content_counter/content_counter_appearance/presentation/home_widget_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements HomeWidgetRepository {
  WidgetPayload payloadAnswer = WidgetPayload.empty;
  Error? payloadError;
  bool? pinAnswer = true;
  final pinned = <WidgetFamily>[];
  var payloadCalls = 0;

  @override
  Future<WidgetPayload> payload() async {
    payloadCalls++;
    if (payloadError case final e?) throw e;
    return payloadAnswer;
  }

  @override
  Future<bool?> pin(WidgetFamily family) async {
    pinned.add(family);
    return pinAnswer;
  }

  @override
  Future<void> push({WidgetPushReason reason = WidgetPushReason.refresh}) =>
      throw UnimplementedError();

  @override
  Future<WidgetTap?> takePendingTap() => throw UnimplementedError();
}

void main() {
  late _FakeRepo repo;
  late HomeWidgetCubit cubit;

  final demo = WidgetPayload.demo(
    limitMinutes: 120,
    theme: 'system',
    reduceMotion: false,
    nowMs: 1,
  );

  setUp(() {
    repo = _FakeRepo();
    cubit = HomeWidgetCubit(repo);
  });

  tearDown(() => cubit.close());

  test('starts on Count / Small, Empty, loading', () {
    final s = cubit.state;
    expect(
      (s.family, s.size, s.payload, s.loading),
      (WidgetFamily.count, WidgetSize.small, WidgetPayload.empty, true),
    );
  });

  test('load passes the payload through', () async {
    repo.payloadAnswer = demo;
    await cubit.load();
    expect(cubit.state.payload, demo);
    expect(cubit.state.loading, isFalse);
    expect(repo.payloadCalls, 1);
  });

  test('a failed load keeps the last payload and stops loading', () async {
    repo.payloadAnswer = demo;
    await cubit.load();
    repo.payloadError = StateError('channel');
    await cubit.load();
    expect(cubit.state.payload, demo);
    expect(cubit.state.loading, isFalse);
  });

  test('select and selectSize move only their own field', () {
    cubit
      ..select(WidgetFamily.rhythm)
      ..selectSize(WidgetSize.large);
    expect(cubit.state.family, WidgetFamily.rhythm);
    expect(cubit.state.size, WidgetSize.large);
    expect(cubit.state.payload, WidgetPayload.empty);
  });

  test('pin pins the selected family and answers the launcher', () async {
    cubit.select(WidgetFamily.bonsai);
    expect(await cubit.pin(), isTrue);
    repo.pinAnswer = false;
    expect(await cubit.pin(), isFalse);
    expect(repo.pinned, [WidgetFamily.bonsai, WidgetFamily.bonsai]);
  });

  test('a failed pin call answers null, not "can\'t pin"', () async {
    repo.pinAnswer = null;
    expect(await cubit.pin(), isNull);
  });
}
