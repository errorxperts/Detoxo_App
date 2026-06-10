import 'package:detoxo/features/blocking/shared/domain/entities/app_notice.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/block_target.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/engine_event.dart';

/// Loads the detection config (offline bundle, refreshed remotely) and exposes
/// it as user-facing block targets.
abstract interface class ConfigRepository {
  Future<List<BlockTarget>> loadBlockTargets();

  /// The raw platforms-config JSON to push to the native engine.
  Future<String> rawConfigJson();

  /// Default in-app notices parsed from initial_config.
  Future<List<AppNotice>> loadNotices();
}

/// Persists and streams the user's [AppSettings].
abstract interface class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
  Stream<AppSettings> watch();
}

/// The native engine bridge (MethodChannel + EventChannel).
abstract interface class EngineRepository {
  Stream<ServiceSnapshot> statusStream();
  Stream<BlockEvent> blockStream();

  Future<void> pushConfig(String configJson);
  Future<void> pushSettings(AppSettings settings);

  Future<ServiceSnapshot> currentStatus();

  Future<void> performBack();
  Future<void> killApp(String packageName);
  Future<void> lockScreen();
}
