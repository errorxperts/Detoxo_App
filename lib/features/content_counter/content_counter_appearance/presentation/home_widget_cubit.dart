import 'package:detoxo/core/utils/app_logger.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/widget_payload.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/repositories/home_widget_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeWidgetState extends Equatable {
  const HomeWidgetState({
    this.family = WidgetFamily.count,
    this.size = WidgetSize.small,
    this.payload = WidgetPayload.empty,
    this.loading = true,
  });

  /// The family the stage shows and Add pins. The rail and the stage both
  /// follow it.
  final WidgetFamily family;

  /// Preview-only: a pinned widget lands 2×2 and the user resizes it.
  final WidgetSize size;

  /// What the previews draw. Its theme is overlaid by the screen from
  /// `CounterAppearanceCubit`, which owns that setting.
  final WidgetPayload payload;

  /// True until the first payload lands. A reload keeps the last payload on
  /// screen, so returning from the daily-limit screen does not flash Empty.
  final bool loading;

  HomeWidgetState copyWith({
    WidgetFamily? family,
    WidgetSize? size,
    WidgetPayload? payload,
    bool? loading,
  }) => HomeWidgetState(
    family: family ?? this.family,
    size: size ?? this.size,
    payload: payload ?? this.payload,
    loading: loading ?? this.loading,
  );

  @override
  List<Object?> get props => [family, size, payload, loading];
}

/// The home-widget picker: which family and size the user is looking at, and
/// the payload the previews draw. Screen-scoped (created by the screen).
class HomeWidgetCubit extends Cubit<HomeWidgetState> {
  HomeWidgetCubit(this._repo) : super(const HomeWidgetState());

  final HomeWidgetRepository _repo;

  /// Pulls a fresh payload: native shows the demo until the first reel is
  /// ever counted, the live data after (doc 17 §5.2). Off-Android it reads as
  /// Empty.
  Future<void> load() async {
    try {
      final payload = await _repo.payload();
      if (!isClosed) emit(state.copyWith(payload: payload, loading: false));
    } on Object catch (e, s) {
      // The previews keep the last payload; the picker still works.
      AppLogger.e('home widget payload failed', e, s);
      if (!isClosed) emit(state.copyWith(loading: false));
    }
  }

  void select(WidgetFamily family) => emit(state.copyWith(family: family));

  void selectSize(WidgetSize size) => emit(state.copyWith(size: size));

  /// Asks the launcher to pin the selected family; false when it can't, null
  /// when the call failed.
  Future<bool?> pin() => _repo.pin(state.family);
}
