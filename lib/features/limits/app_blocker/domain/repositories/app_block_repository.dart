import 'package:detoxo/features/limits/app_blocker/domain/entities/app_block_entry.dart';

/// Full-app blocklist CRUD + installed-app discovery.
abstract interface class AppBlockRepository {
  Future<List<AppBlockEntry>> load();
  Future<void> save(List<AppBlockEntry> entries);
}
