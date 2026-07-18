import 'dart:async';

import 'package:detoxo/features/blocking/plans/domain/entities/reel_session_state.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Mirrors the native One Reel / Unblock session for the UI. The engine pushes a
/// [ReelSessionState] whenever a reel is allowed or blocked; this relays it and
/// pulls one fresh snapshot at startup (via [refresh]) so the "N of M reels left"
/// display is correct before the first push. Enforcement never depends on this —
/// the native engine owns the consumed-count.
class ReelSessionCubit extends Cubit<ReelSessionState> {
  ReelSessionCubit(this._engine) : super(const ReelSessionState()) {
    _sub = _engine.reelSessionStream().listen(emit);
    refresh();
  }

  final EngineRepository _engine;
  StreamSubscription<ReelSessionState>? _sub;

  Future<void> refresh() async => emit(await _engine.reelSessionCurrent());

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
