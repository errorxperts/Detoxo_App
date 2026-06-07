import 'dart:convert';
import 'package:detoxo/features/limits/app_blocker/domain/entities/app_block_entry.dart';
import 'package:detoxo/features/limits/app_blocker/domain/repositories/app_block_repository.dart';
import 'package:detoxo/core/storage/local_store.dart';

/// Full-app blocklist persistence.
class AppBlockRepositoryImpl implements AppBlockRepository {
  AppBlockRepositoryImpl(this._store);

  final LocalStore _store;

  @override
  Future<List<AppBlockEntry>> load() async {
    final raw = _store.read(StoreKeys.appBlocklist);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => AppBlockEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> save(List<AppBlockEntry> entries) async {
    await _store.write(
      StoreKeys.appBlocklist,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }
}
