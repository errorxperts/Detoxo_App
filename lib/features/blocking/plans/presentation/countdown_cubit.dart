import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

/// A generic 1 Hz countdown to a target time. Reused by the pause / mindful
/// countdown screens. Emits the remaining duration, clamped at zero.
class CountdownCubit extends Cubit<Duration> {
  CountdownCubit() : super(Duration.zero);

  Timer? _timer;
  DateTime? _target;

  void start(DateTime target) {
    _target = target;
    _timer?.cancel();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    final target = _target;
    if (target == null) return;
    final remaining = target.difference(DateTime.now());
    if (remaining.isNegative || remaining == Duration.zero) {
      emit(Duration.zero);
      stop();
    } else {
      emit(remaining);
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
