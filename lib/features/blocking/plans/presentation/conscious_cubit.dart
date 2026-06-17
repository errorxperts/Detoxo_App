import 'dart:async';

import 'package:detoxo/features/blocking/plans/domain/entities/conscious_state.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Mirrors the native Conscious bank for the UI. The engine pushes a
/// [ConsciousState] every second while Conscious is active; this relays it and
/// pulls one fresh snapshot at startup (via [refresh]) so the display is correct
/// before the first push lands. Enforcement never depends on this — the native
/// accountant owns the bank — so a momentarily stale read self-corrects in ~1s.
class ConsciousCubit extends Cubit<ConsciousState> {
  ConsciousCubit(this._engine) : super(const ConsciousState()) {
    _sub = _engine.consciousStream().listen(emit);
    refresh();
  }

  final EngineRepository _engine;
  StreamSubscription<ConsciousState>? _sub;

  Future<void> refresh() async => emit(await _engine.consciousCurrent());

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
