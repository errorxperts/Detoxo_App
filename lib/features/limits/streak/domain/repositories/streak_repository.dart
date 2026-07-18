import 'package:detoxo/features/limits/streak/domain/entities/streak.dart';

/// "Days under your daily limit" streak persistence.
abstract interface class StreakRepository {
  Future<Streak> load();
  Future<void> save(Streak streak);
}
