import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/content_count.dart';

/// Reads the native short-video counter and streams live updates.
abstract interface class ContentCounterRepository {
  /// One-shot pull of the current counter snapshot.
  Future<ContentCount> current();

  /// Initial snapshot followed by a live update on every counted reel.
  Stream<ContentCount> watch();

  /// Enable/disable counting natively (counting persists across UI death).
  Future<void> setEnabled({required bool enabled});
}
