import 'package:detoxo/features/limits/web_blocker/domain/entities/web_block_stats.dart';

/// Website-blocking analytics: a persisted rolling count fed by the native
/// `webBlocked` event stream.
abstract interface class WebBlockStatsRepository {
  /// The current persisted stats (today's count resets on a new calendar day).
  Future<WebBlockStats> load();

  /// Emits updated stats each time native reports a website block.
  Stream<WebBlockStats> watch();
}
