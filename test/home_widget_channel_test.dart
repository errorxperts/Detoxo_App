import 'package:detoxo/core/constants/channel_constants.dart';
import 'package:detoxo/core/platform/platform_capabilities.dart';
import 'package:detoxo/core/platform_channels/engine_channel.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:detoxo/features/content_counter/home_content_counter/data/repositories/home_widget_repository_impl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real channel under the home-widget repository: native's answer to a
/// pin must reach the screen as three distinct outcomes, because each has its
/// own toast (pinned / add it by hand / something went wrong).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(Channels.commands);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late HomeWidgetRepositoryImpl repo;
  final calls = <MethodCall>[];

  setUp(() {
    // The channel short-circuits off-Android; the host runner isn't Android.
    PlatformCapabilities.debugForceAndroid = true;
    calls.clear();
    repo = HomeWidgetRepositoryImpl(EngineChannel());
  });

  tearDown(() {
    PlatformCapabilities.debugForceAndroid = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  void answer(Object? Function(MethodCall call) reply) =>
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return reply(call);
      });

  test(
    'a native throw (WIDGET_FAILED) reads as null, not "can\'t pin"',
    () async {
      answer((_) => throw PlatformException(code: 'WIDGET_FAILED'));
      expect(await repo.pin(WidgetFamily.bonsai), isNull);
      expect(calls.single.method, ChannelMethods.pinContentWidget);
      expect(calls.single.arguments, {'family': 'BONSAI'});
    },
  );

  test('a launcher that cannot pin reads as false', () async {
    answer((_) => false);
    expect(await repo.pin(WidgetFamily.count), isFalse);
  });

  test('a pin request the launcher accepts reads as true', () async {
    answer((_) => true);
    expect(await repo.pin(WidgetFamily.timeLimit), isTrue);
  });

  test('a failed payload build reads as the Empty payload', () async {
    answer((_) => throw PlatformException(code: 'WIDGET_FAILED'));
    expect(await repo.payload(), WidgetPayload.empty);
    expect(calls.single.method, ChannelMethods.contentWidgetPayload);
  });
}
