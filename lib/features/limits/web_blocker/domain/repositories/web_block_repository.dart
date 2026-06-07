import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_entry.dart';

/// Website blocklist CRUD.
abstract interface class WebBlockRepository {
  Future<List<WebBlockEntry>> load();
  Future<void> save(List<WebBlockEntry> entries);
}
