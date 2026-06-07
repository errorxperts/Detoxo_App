import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:detoxo/features/blocking/shared/domain/entities/engine_event.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:detoxo/features/analytics/domain/repositories/analytics_repository.dart';

/// Loads the local block-event history and persists incoming block events.
class AnalyticsCubit extends Cubit<List<BlockEvent>> {
  AnalyticsCubit(this._repo, this._engine) : super(const []) {
    _engine.blockStream().listen(_repo.logBlock);
  }

  final AnalyticsRepository _repo;
  final EngineRepository _engine;

  Future<void> load() async => emit(await _repo.recent(limit: 100));
}
