import 'dart:convert';
import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_entry.dart';
import 'package:detoxo/features/limits/web_blocker/domain/repositories/web_block_repository.dart';
import 'package:detoxo/core/storage/local_store.dart';

/// Website blocklist persistence (JSON list in [LocalStore]).
class WebBlockRepositoryImpl implements WebBlockRepository {
  WebBlockRepositoryImpl(this._store);

  final LocalStore _store;

  @override
  Future<List<WebBlockEntry>> load() async {
    final raw = _store.read(StoreKeys.webBlocklist);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => WebBlockEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> save(List<WebBlockEntry> entries) async {
    await _store.write(
      StoreKeys.webBlocklist,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }
}
