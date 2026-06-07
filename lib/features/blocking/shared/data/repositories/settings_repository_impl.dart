import 'dart:async';
import 'dart:convert';

import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:detoxo/core/storage/local_store.dart';

/// Persists [AppSettings] as JSON in [LocalStore] and broadcasts changes.
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._store);

  final LocalStore _store;
  final _controller = StreamController<AppSettings>.broadcast();
  AppSettings? _cache;

  @override
  Future<AppSettings> load() async {
    if (_cache != null) return _cache!;
    final raw = _store.read(StoreKeys.settings);
    final settings = raw == null
        ? const AppSettings()
        : AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return _cache = settings;
  }

  @override
  Future<void> save(AppSettings settings) async {
    _cache = settings;
    await _store.write(StoreKeys.settings, jsonEncode(settings.toJson()));
    _controller.add(settings);
  }

  @override
  Stream<AppSettings> watch() => _controller.stream;
}
