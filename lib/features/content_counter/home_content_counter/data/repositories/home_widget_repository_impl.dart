import 'package:detoxo/core/platform_channels/engine_channel.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/widget_payload.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/widget_tap.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/repositories/home_widget_repository.dart';

/// Home-widget control over the single command channel. `pinContentWidget`
/// answers truthfully (false when the launcher can't pin, null when the call
/// failed); the payload and the pending tap travel as text and are parsed
/// here. Off-Android the channel short-circuits to null / no-op, so the
/// payload reads as Empty.
class HomeWidgetRepositoryImpl implements HomeWidgetRepository {
  HomeWidgetRepositoryImpl(this._channel);

  final EngineChannel _channel;

  @override
  Future<bool?> pin(WidgetFamily family) =>
      _channel.pinContentWidget(family: family.wire);

  @override
  Future<void> push({WidgetPushReason reason = WidgetPushReason.refresh}) =>
      _channel.refreshContentWidget(reason: reason.wire);

  @override
  Future<WidgetPayload> payload() async =>
      WidgetPayload.parse(await _channel.contentWidgetPayload());

  @override
  Future<WidgetTap?> takePendingTap() async =>
      WidgetTap.parse(await _channel.takePendingWidgetTap());
}
