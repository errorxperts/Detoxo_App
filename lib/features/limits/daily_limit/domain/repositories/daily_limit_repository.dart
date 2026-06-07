import 'package:detoxo/features/limits/daily_limit/domain/entities/daily_limit.dart';

/// Daily usage quota persistence.
abstract interface class DailyLimitRepository {
  Future<DailyLimit> load();
  Future<void> save(DailyLimit limit);
}
