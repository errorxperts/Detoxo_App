import 'dart:async';

import 'package:detoxo/features/blocking/shared/domain/entities/engine_event.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Tracks the live native-engine status and block counters.
class ServiceCubit extends Cubit<ServiceSnapshot> {
  ServiceCubit(this._engine) : super(const ServiceSnapshot()) {
    _sub = _engine.statusStream().listen(emit);
  }

  final EngineRepository _engine;
  StreamSubscription<ServiceSnapshot>? _sub;

  Future<void> refresh() async => emit(await _engine.currentStatus());

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
