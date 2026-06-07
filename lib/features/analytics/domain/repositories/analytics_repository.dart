import 'package:detoxo/features/blocking/shared/domain/entities/engine_event.dart';

/// Local block-event analytics buffer.
abstract interface class AnalyticsRepository {
  Future<void> logBlock(BlockEvent event);
  Future<List<BlockEvent>> recent({int limit = 50});
  Future<int> countToday();
}
