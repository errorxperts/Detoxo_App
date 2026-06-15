import 'dart:async';

import 'package:detoxo/core/constants/channel_constants.dart';
import 'package:detoxo/core/platform/platform_capabilities.dart';
import 'package:detoxo/core/utils/app_logger.dart';
import 'package:flutter/services.dart';

/// Low-level wrapper over the native command MethodChannel and the engine
/// EventChannel. Repositories build on top of this; it owns no domain logic.
class EngineChannel {
  EngineChannel()
      : _commands = const MethodChannel(Channels.commands),
        _events = const EventChannel(Channels.events);

  final MethodChannel _commands;
  final EventChannel _events;

  Stream<Map<String, dynamic>>? _eventStream;

  /// Broadcast stream of native engine events (status / detection / blocked).
  ///
  /// Off-Android there is no native engine, so the stream is empty (subscribing
  /// to the EventChannel would otherwise emit a logged error every launch).
  Stream<Map<String, dynamic>> events() {
    if (!PlatformCapabilities.supportsBlockingEngine) {
      return const Stream<Map<String, dynamic>>.empty();
    }
    return _eventStream ??= _events
        .receiveBroadcastStream()
        .map((dynamic e) => Map<String, dynamic>.from(e as Map))
        .handleError((Object error) {
          AppLogger.e('engine event stream error', error);
        })
        .asBroadcastStream();
  }

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    // No native engine off-Android: short-circuit so screens render with safe
    // defaults instead of paying a MissingPluginException round-trip per call.
    if (!PlatformCapabilities.supportsBlockingEngine) return null;
    try {
      return await _commands.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      AppLogger.e('channel $method failed', e);
      return null;
    } on MissingPluginException {
      // Running on a platform without the native side (e.g. tests / iOS).
      return null;
    }
  }

  Future<bool> invokeBool(String method, [Map<String, dynamic>? args]) async =>
      (await _invoke<bool>(method, args)) ?? false;

  Future<void> invokeVoid(String method, [Map<String, dynamic>? args]) async =>
      _invoke<void>(method, args);

  Future<Map<String, dynamic>> invokeMap(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    final res = await _invoke<Map<dynamic, dynamic>>(method, args);
    return res == null ? <String, dynamic>{} : Map<String, dynamic>.from(res);
  }

  // Convenience wrappers used across repositories.
  Future<void> pushConfig(String json) =>
      invokeVoid(ChannelMethods.pushConfig, {'json': json});

  Future<void> pushSettings(Map<String, dynamic> settings) =>
      invokeVoid(ChannelMethods.pushSettings, settings);

  Future<bool> isAccessibilityEnabled() =>
      invokeBool(ChannelMethods.isAccessibilityEnabled);

  Future<void> openAccessibilitySettings() =>
      invokeVoid(ChannelMethods.openAccessibilitySettings);

  Future<bool> canDrawOverlays() => invokeBool(ChannelMethods.canDrawOverlays);
  Future<void> requestOverlay() =>
      invokeVoid(ChannelMethods.requestOverlayPermission);

  Future<bool> hasUsageAccess() => invokeBool(ChannelMethods.hasUsageAccess);
  Future<void> openUsageAccess() =>
      invokeVoid(ChannelMethods.openUsageAccessSettings);

  Future<bool> isIgnoringBattery() =>
      invokeBool(ChannelMethods.isIgnoringBatteryOptimizations);
  Future<void> requestIgnoreBattery() =>
      invokeVoid(ChannelMethods.requestIgnoreBatteryOptimizations);

  Future<bool> isDeviceAdminActive() =>
      invokeBool(ChannelMethods.isDeviceAdminActive);
  Future<void> requestDeviceAdmin() =>
      invokeVoid(ChannelMethods.requestDeviceAdmin);
  Future<void> removeDeviceAdmin() =>
      invokeVoid(ChannelMethods.removeDeviceAdmin);

  Future<void> performBack() => invokeVoid(ChannelMethods.performBack);
  Future<void> killApp(String pkg) =>
      invokeVoid(ChannelMethods.killApp, {'package': pkg});
  Future<void> lockScreen() => invokeVoid(ChannelMethods.lockScreen);

  Future<Map<String, dynamic>> blockStats() =>
      invokeMap(ChannelMethods.blockStats);

  Future<Map<String, dynamic>> consciousState() =>
      invokeMap(ChannelMethods.consciousState);
}
