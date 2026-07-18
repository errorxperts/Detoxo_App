import 'dart:convert';

import 'package:detoxo/core/storage/local_store.dart';
import 'package:detoxo/features/limits/streak/domain/entities/streak.dart';
import 'package:detoxo/features/limits/streak/domain/repositories/streak_repository.dart';

/// "Days under your daily limit" streak persistence.
class StreakRepositoryImpl implements StreakRepository {
  StreakRepositoryImpl(this._store);

  final LocalStore _store;

  @override
  Future<Streak> load() async {
    final raw = _store.read(StoreKeys.streak);
    if (raw == null) return const Streak();
    return Streak.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(Streak streak) async {
    await _store.write(StoreKeys.streak, jsonEncode(streak.toJson()));
  }
}
