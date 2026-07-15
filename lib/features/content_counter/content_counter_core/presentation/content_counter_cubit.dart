import 'dart:async';

import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/content_count.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/repositories/content_counter_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Streams the live [ContentCount] from the native counter into the UI.
class ContentCounterCubit extends Cubit<ContentCount> {
  ContentCounterCubit(this._repo) : super(const ContentCount.empty()) {
    _sub = _repo.watch().listen(emit);
  }

  final ContentCounterRepository _repo;
  late final StreamSubscription<ContentCount> _sub;

  Future<void> setEnabled({required bool enabled}) =>
      _repo.setEnabled(enabled: enabled);

  /// Re-pulls the native snapshot so today's usage time is fresh on demand
  /// (it advances between counted reels, which the event stream doesn't emit).
  Future<void> refresh() async => emit(await _repo.current());

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
