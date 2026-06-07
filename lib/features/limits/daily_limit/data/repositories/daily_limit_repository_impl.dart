import 'dart:convert';
import 'package:detoxo/features/limits/daily_limit/domain/entities/daily_limit.dart';
import 'package:detoxo/features/limits/daily_limit/domain/repositories/daily_limit_repository.dart';
import 'package:detoxo/core/storage/local_store.dart';

/// Daily usage quota persistence.
class DailyLimitRepositoryImpl implements DailyLimitRepository {
  DailyLimitRepositoryImpl(this._store);

  final LocalStore _store;

  @override
  Future<DailyLimit> load() async {
    final raw = _store.read(StoreKeys.dailyLimit);
    if (raw == null) return const DailyLimit();
    return DailyLimit.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(DailyLimit limit) async {
    await _store.write(StoreKeys.dailyLimit, jsonEncode(limit.toJson()));
  }
}
