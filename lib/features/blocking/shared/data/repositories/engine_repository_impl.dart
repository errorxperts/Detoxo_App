import 'dart:async';

import 'package:detoxo/core/constants/channel_constants.dart';
import 'package:detoxo/core/platform_channels/engine_channel.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/engine_event.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';

/// Bridges the native engine to the domain. Translates raw channel maps into
/// typed [ServiceSnapshot] / [BlockEvent] streams and pushes config/settings.
class EngineRepositoryImpl implements EngineRepository {
  EngineRepositoryImpl(this._channel);

  final EngineChannel _channel;

  int _today = 0;
  int _total = 0;

  @override
  Stream<ServiceSnapshot> statusStream() async* {
    yield await currentStatus();
    await for (final e in _channel.events()) {
      final type = e['type'] as String?;
      if (type == ChannelEvents.serviceStatus) {
        yield ServiceSnapshot(
          status: (e['running'] as bool? ?? false)
              ? ServiceStatus.running
              : ServiceStatus.stopped,
          blocksToday: _today,
          blocksTotal: _total,
        );
      } else if (type == ChannelEvents.blocked) {
        _today = e['today'] as int? ?? _today;
        _total = e['total'] as int? ?? _total;
        yield ServiceSnapshot(
          status: ServiceStatus.running,
          blocksToday: _today,
          blocksTotal: _total,
        );
      }
    }
  }

  @override
  Stream<BlockEvent> blockStream() async* {
    await for (final e in _channel.events()) {
      if (e['type'] != ChannelEvents.blocked) continue;
      yield BlockEvent(
        platformId: e['platformId'] as String? ?? 'unknown',
        packageName: e['package'] as String? ?? '',
        mode: BlockingMode.fromWire(e['mode'] as String?),
        timestamp: DateTime.now(),
      );
    }
  }

  @override
  Future<ServiceSnapshot> currentStatus() async {
    final enabled = await _channel.isAccessibilityEnabled();
    final stats = await _channel.blockStats();
    _today = stats['today'] as int? ?? 0;
    _total = stats['total'] as int? ?? 0;
    return ServiceSnapshot(
      status: enabled ? ServiceStatus.running : ServiceStatus.stopped,
      blocksToday: _today,
      blocksTotal: _total,
    );
  }

  @override
  Future<void> pushConfig(String configJson) => _channel.pushConfig(configJson);

  @override
  Future<void> pushSettings(AppSettings settings) {
    // Push the *derived* enforcement state so Pause/Curious contracts work over
    // the existing channel: native is suspended only during the pause window
    // (nativePauseUntil); cooldown/curious resolve to a concrete blocking plan.
    final now = DateTime.now();
    return _channel.pushSettings({
      'activePlan': settings.effectiveNativePlan(now).wire,
      'defaultBlockMode': settings.defaultBlockMode.wire,
      'enabledPlatforms': settings.enabledPlatformIds.toList(),
      'vibration': settings.vibrationEnabled,
      'masterEnabled': settings.masterEnabled,
      'pauseUntil': settings.nativePauseUntil(now)?.millisecondsSinceEpoch ?? 0,
    });
  }

  @override
  Future<void> performBack() => _channel.performBack();

  @override
  Future<void> killApp(String packageName) => _channel.killApp(packageName);

  @override
  Future<void> lockScreen() => _channel.lockScreen();
}
