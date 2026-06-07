import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';

/// Owns the user's [AppSettings]. Every mutation persists locally and pushes the
/// new settings to the native engine so the running service stays in sync.
class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit(this._settings, this._engine) : super(const AppSettings());

  final SettingsRepository _settings;
  final EngineRepository _engine;

  Future<void> bootstrap() async {
    final loaded = await _settings.load();
    emit(loaded);
    await _engine.pushSettings(loaded);
  }

  Future<void> _commit(AppSettings next) async {
    emit(next);
    await _settings.save(next);
    await _engine.pushSettings(next);
  }

  Future<void> setPlan(BlockingPlan plan) =>
      _commit(state.copyWith(activePlan: plan, clearPause: plan != BlockingPlan.paused));

  Future<void> setDefaultBlockMode(BlockingMode mode) =>
      _commit(state.copyWith(defaultBlockMode: mode));

  Future<void> setMasterEnabled(bool enabled) =>
      _commit(state.copyWith(masterEnabled: enabled));

  Future<void> setVibration(bool enabled) =>
      _commit(state.copyWith(vibrationEnabled: enabled));

  Future<void> setOnboarded(bool value) =>
      _commit(state.copyWith(onboarded: value));

  Future<void> togglePlatform(String platformId, bool enabled) {
    final next = Set<String>.from(state.enabledPlatformIds);
    if (enabled) {
      next.add(platformId);
    } else {
      next.remove(platformId);
    }
    return _commit(state.copyWith(enabledPlatformIds: next));
  }

  Future<void> setEnabledPlatforms(Set<String> ids) =>
      _commit(state.copyWith(enabledPlatformIds: ids));

  Future<void> pauseFor(Duration duration) => _commit(
        state.copyWith(
          activePlan: BlockingPlan.paused,
          pauseUntil: DateTime.now().add(duration),
        ),
      );

  Future<void> resume() => _commit(
        state.copyWith(activePlan: BlockingPlan.blockAll, clearPause: true),
      );
}
